import Foundation

enum HTTP {
    /// `application/x-www-form-urlencoded` body. Space → `+`, everything else
    /// outside the unreserved set percent-encoded.
    static func formBody(_ params: [String: String]) -> Data {
        formBody(params.map { ($0.key, $0.value) })
    }

    /// Ordered variant — needed for forms that repeat a key (`DoKogo[]=1&DoKogo[]=2`).
    static func formBody(_ pairs: [(String, String)]) -> Data {
        let unreserved = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        func enc(_ s: String) -> String {
            var out = ""
            for scalar in s.unicodeScalars {
                if scalar == " " {
                    out += "+"
                } else if unreserved.contains(scalar) {
                    out.unicodeScalars.append(scalar)
                } else {
                    for byte in String(scalar).utf8 {
                        out += String(format: "%%%02X", byte)
                    }
                }
            }
            return out
        }
        return Data(pairs.map { "\(enc($0.0))=\(enc($0.1))" }.joined(separator: "&").utf8)
    }

    /// First capture group of `pattern` in `text`, if any.
    static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    static func allMatches(_ pattern: String, in text: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return re.matches(in: text, range: range).map { match in
            (0..<match.numberOfRanges).map { i in
                Range(match.range(at: i), in: text).map { String(text[$0]) } ?? ""
            }
        }
    }

    /// Hidden `<input>` name/value pairs from an HTML form.
    static func hiddenInputs(in html: String) -> [String: String] {
        var result: [String: String] = [:]
        for input in allMatches("<input[^>]+>", in: html).map({ $0[0] }) {
            guard input.range(of: "type=[\"']hidden[\"']", options: [.regularExpression, .caseInsensitive]) != nil else { continue }
            guard let name = firstMatch("name=[\"']([^\"']+)[\"']", in: input) else { continue }
            let value = firstMatch("value=[\"']([^\"']*)[\"']", in: input) ?? ""
            result[name] = value
        }
        return result
    }
}
