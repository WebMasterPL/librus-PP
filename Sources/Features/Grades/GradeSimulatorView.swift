import SwiftUI

struct GradeSimulatorView: View {
    let subjectName: String
    let realGrades: [GradeItem]

    @Environment(\.dismiss) private var dismiss
    @State private var hypotheticals: [GradeMath.HypotheticalGrade] = []
    @State private var newValue = 5.0
    @State private var newWeight = 1.0

    private var currentAverage: Double? { GradeMath.weightedAverage(realGrades) }
    private var projected: Double? {
        GradeMath.projectedAverage(real: realGrades, adding: hypotheticals)
    }

    private var delta: Double? {
        guard let a = currentAverage, let b = projected else { return nil }
        return b - a
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    resultRow(title: "Średnia teraz", value: currentAverage, prominent: false)
                    resultRow(title: "Średnia po zmianach", value: projected, prominent: true)
                    if let delta, abs(delta) >= 0.005 {
                        HStack {
                            Text("Zmiana").foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%+.2f", delta))
                                .font(.subheadline.weight(.semibold))
                                .fontDesign(.rounded)
                                .foregroundStyle(delta >= 0 ? Color.positive : Color.negative)
                        }
                    }
                }

                Section("Dodaj hipotetyczną ocenę") {
                    Stepper(value: $newValue, in: 1...6, step: 0.25) {
                        HStack {
                            Text("Ocena")
                            Spacer()
                            Text(String(format: "%.2f", newValue))
                                .fontDesign(.rounded)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $newWeight, in: 1...10, step: 1) {
                        HStack {
                            Text("Waga")
                            Spacer()
                            Text(String(format: "%.0f", newWeight))
                                .fontDesign(.rounded)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        Haptics.tap()
                        hypotheticals.append(.init(value: newValue, weight: newWeight))
                    } label: {
                        Label("Dodaj ocenę", systemImage: "plus.circle.fill")
                    }
                }

                if !hypotheticals.isEmpty {
                    Section("Hipotetyczne oceny") {
                        ForEach(hypotheticals) { h in
                            HStack(spacing: Theme.Space.md) {
                                Pill(text: String(format: "%.2f", h.value), color: gradeColor(for: h.value))
                                Text("waga \(String(format: "%.0f", h.weight))")
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        .onDelete { hypotheticals.remove(atOffsets: $0) }
                        Button("Wyczyść wszystkie", role: .destructive) {
                            Haptics.warning()
                            hypotheticals.removeAll()
                        }
                    }
                }

                Section {
                    ForEach([Double(5), 4.5, 4, 3.5, 3], id: \.self) { target in
                        if let needed = GradeMath.neededGrade(real: realGrades, weight: newWeight, target: target) {
                            HStack {
                                Text("Na średnią \(String(format: "%.1f", target))")
                                Spacer()
                                Pill(text: String(format: "%.2f", needed),
                                     color: gradeColor(for: needed), prominent: false)
                            }
                        }
                    }
                } header: {
                    Text("Ile potrzebuję?").textCase(nil)
                } footer: {
                    Text("Przy jednej ocenie o wadze \(String(format: "%.0f", newWeight)).")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appGroupedBackground.ignoresSafeArea())
            .navigationTitle(subjectName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { dismiss() }
                }
            }
        }
    }

    private func resultRow(title: String, value: Double?, prominent: Bool) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(GradeMath.format(value))
                .font(prominent ? .title3.weight(.bold) : .body.weight(.medium))
                .fontDesign(.rounded)
                .foregroundStyle(gradeColor(for: value))
                .contentTransition(.numericText())
        }
    }
}
