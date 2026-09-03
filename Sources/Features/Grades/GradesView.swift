import SwiftUI

struct GradesView: View {
    @Environment(DataRepository.self) private var repo
    @State private var filter: SemesterFilter = .current
    @State private var simulatorSubject: SubjectGrades?

    private var current: Int { repo.currentSemester }

    private var visibleSubjects: [SubjectGrades] {
        repo.subjectGrades.filter { !$0.filtered(filter, current: current).isEmpty }
    }

    private var overallAverage: Double? {
        let a = visibleSubjects.compactMap { $0.average(filter, current: current) }
        return a.isEmpty ? nil : a.reduce(0, +) / Double(a.count)
    }

    var body: some View {
        List {
            if let error = repo.lastError {
                Section { ErrorBanner(message: error) { Task { await repo.refreshCore() } } }
                    .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.lg, bottom: Theme.Space.sm, trailing: Theme.Space.lg))
                    .listRowBackground(Color.clear)
            }

            Section {
                Picker("Semestr", selection: $filter) {
                    ForEach(SemesterFilter.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: Theme.Space.xs, leading: 0, bottom: Theme.Space.sm, trailing: 0))
                .listRowBackground(Color.clear)

                if let avg = overallAverage {
                    HStack {
                        Text("Średnia ze średnich")
                            .font(.subheadline)
                        Spacer()
                        Text(GradeMath.format(avg))
                            .font(.title3.weight(.bold))
                            .fontDesign(.rounded)
                            .foregroundStyle(gradeColor(for: avg))
                    }
                }
            }

            if visibleSubjects.isEmpty {
                Section {
                    EmptyStateView(systemImage: "checkmark.seal", title: "Brak ocen",
                                   message: "Zmień semestr lub pociągnij w dół, aby odświeżyć.")
                }
            }

            ForEach(visibleSubjects) { subject in
                Section {
                    ForEach(subject.filtered(filter, current: current)) { grade in
                        NavigationLink {
                            GradeDetailView(grade: grade)
                        } label: {
                            GradeRow(grade: grade, isNew: repo.isGradeUnseen(grade))
                        }
                    }
                } header: {
                    HStack {
                        Text(subject.subjectName)
                        Spacer()
                        if let avg = subject.average(filter, current: current) {
                            Text(GradeMath.format(avg))
                                .fontDesign(.rounded)
                                .foregroundStyle(gradeColor(for: avg))
                        }
                        Button {
                            Haptics.tap()
                            simulatorSubject = subject
                        } label: {
                            Image(systemName: "function")
                                .font(.footnote.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Kalkulator średniej — \(subject.subjectName)")
                    }
                    .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appGroupedBackground.ignoresSafeArea())
        .navigationTitle("Oceny")
        .refreshable { await repo.refreshCore() }
        .onDisappear { repo.markGradesSeen() }
        .sheet(item: $simulatorSubject) { subject in
            GradeSimulatorView(subjectName: subject.subjectName,
                               realGrades: subject.normalGrades(filter, current: current))
        }
        .animation(Theme.Motion.quick, value: filter)
    }
}

struct GradeRow: View {
    let grade: GradeItem
    var isNew: Bool = false

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Pill(text: grade.raw, color: gradeColor(for: grade.value))
                .frame(minWidth: 42)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Theme.Space.sm) {
                    Text(grade.categoryName.isEmpty ? Self.label(for: grade.kind) : grade.categoryName)
                        .font(.callout)
                        .lineLimit(1)
                    if isNew {
                        Text("NOWE")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(.tint, in: Capsule())
                    }
                }
                HStack(spacing: Theme.Space.sm) {
                    if grade.weight > 0 { Text("waga \(GradeMath.format(grade.weight))") }
                    if let date = grade.date { Text(date.dayMonthShort) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    static func label(for kind: GradeKind) -> String {
        switch kind {
        case .normal: return "Ocena"
        case .semesterProposed: return "Propozycja śródroczna"
        case .semesterFinal: return "Ocena śródroczna"
        case .yearProposed: return "Propozycja roczna"
        case .yearFinal: return "Ocena roczna"
        }
    }
}

struct GradeDetailView: View {
    let grade: GradeItem

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Ocena").foregroundStyle(.secondary)
                    Spacer()
                    Pill(text: grade.raw, color: gradeColor(for: grade.value))
                        .scaleEffect(1.15)
                }
                if let value = grade.value { KeyValueRow(key: "Wartość", value: GradeMath.format(value)) }
                if grade.weight > 0 { KeyValueRow(key: "Waga", value: GradeMath.format(grade.weight)) }
                KeyValueRow(key: "Liczona do średniej", value: grade.countsToAverage ? "Tak" : "Nie")
                KeyValueRow(key: "Rodzaj", value: GradeRow.label(for: grade.kind))
            }
            Section {
                KeyValueRow(key: "Przedmiot", value: grade.subjectName)
                if !grade.categoryName.isEmpty { KeyValueRow(key: "Kategoria", value: grade.categoryName) }
                if !grade.teacherName.isEmpty { KeyValueRow(key: "Nauczyciel", value: grade.teacherName) }
                if let date = grade.date { KeyValueRow(key: "Data", value: date.dayMonthYear) }
                KeyValueRow(key: "Semestr", value: "\(grade.semester)")
            }
            if let comment = grade.comment {
                Section("Komentarz") { Text(comment) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appGroupedBackground.ignoresSafeArea())
        .navigationTitle("Szczegóły oceny")
        .navigationBarTitleDisplayMode(.inline)
    }
}
