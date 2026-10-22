import Foundation

/// Plain text with its web links and e-mail addresses made tappable — `Text`
/// renders the `.link` runs in the accent colour and the system opens them
/// (Safari, Mail). "www.example.pl" without a scheme counts as a link too.
enum LinkedText {
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func attributed(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        guard let detector else { return result }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let url = match.url,
                  let stringRange = Range(match.range, in: text),
                  let range = Range(stringRange, in: result) else { continue }
            result[range].link = url
        }
        return result
    }
}
