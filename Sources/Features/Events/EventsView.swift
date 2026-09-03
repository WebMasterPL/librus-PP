import SwiftUI

struct EventsView: View {
    @Environment(DataRepository.self) private var repo
    @State private var showPast = false

    private var visible: [CalendarEvent] {
        showPast ? repo.events : repo.events.filter { !$0.isPast }
    }

    private var grouped: [(key: String, items: [CalendarEvent])] {
        let buckets: [String: [CalendarEvent]] = Dictionary(grouping: visible) { event in
            event.date?.dayMonthYear ?? "Bez daty"
        }
        var rows: [(key: String, items: [CalendarEvent])] = []
        for (key, items) in buckets {
            rows.append((key: key, items: items))
        }
        rows.sort { lhs, rhs in
            let l = lhs.items.first?.date ?? .distantFuture
            let r = rhs.items.first?.date ?? .distantFuture
            return l < r
        }
        return rows
    }

    var body: some View {
        List {
            if repo.events.isEmpty {
                EmptyStateView(systemImage: "calendar.badge.clock", title: "Brak wpisów w terminarzu")
            }
            if !repo.events.isEmpty {
                Toggle("Pokaż minione", isOn: $showPast.animation(Theme.Motion.quick))
            }

            ForEach(grouped, id: \.key) { group in
                Section {
                    ForEach(group.items) { ev in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: Theme.Space.sm) {
                                if let category = ev.category { Chip(text: category, tint: .accentColor) }
                                if let subject = ev.subject {
                                    Text(subject).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if let time = ev.time {
                                    Text(time).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                } else if let no = ev.lessonNo {
                                    Text("lekcja \(no)").font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            Text(ev.content.isEmpty ? "(bez opisu)" : ev.content).font(.callout)
                            if let teacher = ev.teacher {
                                Text(teacher).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text(group.key).textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appGroupedBackground.ignoresSafeArea())
        .navigationTitle("Terminarz")
        .refreshable { await repo.refreshCore() }
    }
}
