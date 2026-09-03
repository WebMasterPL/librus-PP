import SwiftUI

struct BellScheduleView: View {
    @Environment(DataRepository.self) private var repo

    private var nowMinutes: Int { LibrusDate.nowMinutesOfDay }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.lg) {
                if repo.bellSchedule.isEmpty {
                    EmptyStateView(systemImage: "bell.slash", title: "Brak rozkładu dzwonków",
                                   message: "Pociągnij w dół, aby odświeżyć.")
                        .padding(.top, Theme.Space.xxl)
                } else {
                    if let school = repo.schoolName, !school.isEmpty {
                        Text(school)
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Card(padding: Theme.Space.md) {
                        VStack(spacing: 0) {
                            ForEach(Array(repo.bellSchedule.enumerated()), id: \.element.id) { idx, period in
                                periodRow(period)
                                if idx < repo.bellSchedule.count - 1 {
                                    Divider().padding(.leading, 40).opacity(0.4)
                                }
                            }
                        }
                    }
                }
            }
            .padding(Theme.Space.lg)
        }
        .screenBackground()
        .navigationTitle("Rozkład dzwonków")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await repo.refreshCore() }
    }

    private func periodRow(_ p: BellPeriod) -> some View {
        let now = isNow(p)
        return HStack(spacing: Theme.Space.md) {
            Text("\(p.number)")
                .font(.headline.weight(.bold))
                .fontDesign(.rounded)
                .frame(width: 26)
                .foregroundStyle(now ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(p.start) – \(p.end)")
                    .font(.callout.monospacedDigit())
                    .fontWeight(now ? .semibold : .regular)
                if let len = length(p) {
                    Text("\(len) min").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if now {
                Text("teraz")
                    .font(.caption2.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, Theme.Space.sm).padding(.vertical, 2)
                    .background(.tint, in: Capsule())
            }
        }
        .padding(.vertical, Theme.Space.sm)
    }

    private func isNow(_ p: BellPeriod) -> Bool {
        guard let s = LibrusDate.minutesOfDay(p.start), let e = LibrusDate.minutesOfDay(p.end) else { return false }
        return nowMinutes >= s && nowMinutes < e
    }

    private func length(_ p: BellPeriod) -> Int? {
        guard let s = LibrusDate.minutesOfDay(p.start), let e = LibrusDate.minutesOfDay(p.end), e > s else { return nil }
        return e - s
    }
}
