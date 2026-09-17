import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DiagnosticsView: View {
    @Environment(AppState.self) private var app

    @State private var results: [DiagnosticResult] = []
    @State private var running = false
    @State private var copied = false

    var body: some View {
        List {
            Section {
                Button {
                    Task { await runChecks() }
                } label: {
                    HStack {
                        Label("Uruchom test połączenia", systemImage: "stethoscope")
                        Spacer()
                        if running { ProgressView() }
                    }
                }
                .disabled(running)
            } footer: {
                Text("Sprawdza każdy endpoint Librusa osobno. Skopiuj raport i wyślij go, jeśli coś nie działa.")
            }

            Section {
                RawDumpButton(
                    title: "Kopiuj surowy JSON planu lekcji",
                    fetch: { await Diagnostics(session: app.session).rawTimetableJSON() }
                )
                RawDumpButton(
                    title: "Kopiuj surowy JSON ocen",
                    fetch: { await Diagnostics(session: app.session).rawGradesJSON() }
                )
            } footer: {
                Text("Pełna, niesformatowana odpowiedź Librusa dla wybranego modułu — przydatne przy zgłaszaniu błędów (plan lekcji: ubiegły/bieżący/przyszły tydzień; oceny: Grades + Categories + Comments). Zawiera imiona i nazwiska nauczycieli.")
            }

            if !results.isEmpty {
                Section {
                    ForEach(results) { r in
                        HStack(alignment: .top, spacing: Theme.Space.md) {
                            Image(systemName: r.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .font(.body)
                                .foregroundStyle(r.ok ? Color.positive : Color.negative)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).font(.callout.weight(.medium))
                                Text(r.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                } header: {
                    let bad = results.filter { !$0.ok }.count
                    Text(bad == 0 ? "Wszystko OK (\(results.count))" : "\(bad) z \(results.count) nie działa")
                        .textCase(nil)
                }

                Section {
                    Button {
                        // The report can contain teacher names and a message
                        // snippet — keep it on this device (no Universal Clipboard)
                        // and let it expire so it doesn't linger.
                        UIPasteboard.general.setItems(
                            [[UTType.utf8PlainText.identifier: Diagnostics.report(results)]],
                            options: [.localOnly: true,
                                      .expirationDate: Date().addingTimeInterval(10 * 60)]
                        )
                        Haptics.success()
                        withAnimation(Theme.Motion.quick) { copied = true }
                    } label: {
                        Label(copied ? "Skopiowano" : "Kopiuj raport", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appGroupedBackground.ignoresSafeArea())
        .navigationTitle("Diagnostyka")
        .navigationBarTitleDisplayMode(.inline)
        .animation(Theme.Motion.standard, value: results.count)
    }

    private func runChecks() async {
        Haptics.tap()
        running = true
        copied = false
        results = []
        defer { running = false }
        results = await Diagnostics(session: app.session).run()
    }
}

/// A button that fetches a raw diagnostic dump on demand and copies it to the
/// clipboard — local-only and time-limited, same privacy handling as the
/// connection-test report above.
private struct RawDumpButton: View {
    let title: String
    let fetch: () async -> String

    @State private var running = false
    @State private var copied = false

    var body: some View {
        Button {
            Task { await run() }
        } label: {
            HStack {
                Label(copied ? "Skopiowano" : title, systemImage: copied ? "checkmark" : "doc.on.doc")
                Spacer()
                if running { ProgressView() }
            }
        }
        .disabled(running)
    }

    private func run() async {
        Haptics.tap()
        running = true
        copied = false
        defer { running = false }
        let text = await fetch()
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: text]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(10 * 60)]
        )
        Haptics.success()
        withAnimation(Theme.Motion.quick) { copied = true }
    }
}
