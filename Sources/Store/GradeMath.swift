import Foundation

/// Grade string parsing + weighted averages.
///
/// Convention (matches the common Polish e-gradebook interpretation used by
/// szkolny.eu): a trailing `+` adds 0.5, a trailing `-` subtracts 0.25.
/// Non-numeric marks (`np`, `bz`, `nb`, bare `+`/`-`) have no numeric value and
/// do not count toward the average.
enum GradeMath {
    static func numericValue(of raw: String) -> Double? {
        let s = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !s.isEmpty else { return nil }

        let nonCounting: Set<String> = ["np", "bz", "nb", "+", "-", "-,-", "0"]
        if nonCounting.contains(s) { return nil }

        // e.g. "5", "4+", "3-", "2+", "6"
        var base = s
        var modifier = 0.0
        if let last = s.last {
            if last == "+" { modifier = 0.5; base = String(s.dropLast()) }
            else if last == "-" { modifier = -0.25; base = String(s.dropLast()) }
        }
        base = base.replacingOccurrences(of: ",", with: ".")
        guard let n = Double(base), (1...6).contains(n) else { return nil }
        return n + modifier
    }

    static func weightedAverage(_ grades: [GradeItem]) -> Double? {
        var weightSum = 0.0
        var valueSum = 0.0
        for g in grades {
            guard let v = g.value, g.weight > 0 else { continue }
            valueSum += v * g.weight
            weightSum += g.weight
        }
        guard weightSum > 0 else { return nil }
        return valueSum / weightSum
    }

    static func arithmeticAverage(_ grades: [GradeItem]) -> Double? {
        let values = grades.compactMap(\.value)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f", value)
    }

    struct HypotheticalGrade: Identifiable, Hashable {
        let id = UUID()
        var value: Double
        var weight: Double
    }

    /// Weighted average of the real grades plus a set of hypothetical ones.
    static func projectedAverage(
        real grades: [GradeItem], adding extra: [HypotheticalGrade]
    ) -> Double? {
        var weightSum = 0.0
        var valueSum = 0.0
        for g in grades {
            guard let v = g.value, g.weight > 0 else { continue }
            valueSum += v * g.weight
            weightSum += g.weight
        }
        for h in extra where h.weight > 0 {
            valueSum += h.value * h.weight
            weightSum += h.weight
        }
        guard weightSum > 0 else { return nil }
        return valueSum / weightSum
    }

    /// The single grade value (at `weight`) needed to reach `target`, given the real grades.
    /// Returns nil if unreachable within 1…6.
    static func neededGrade(
        real grades: [GradeItem], weight: Double, target: Double
    ) -> Double? {
        guard weight > 0 else { return nil }
        var weightSum = 0.0
        var valueSum = 0.0
        for g in grades {
            guard let v = g.value, g.weight > 0 else { continue }
            valueSum += v * g.weight
            weightSum += g.weight
        }
        let needed = (target * (weightSum + weight) - valueSum) / weight
        guard needed >= 1, needed <= 6 else { return nil }
        return needed
    }
}
