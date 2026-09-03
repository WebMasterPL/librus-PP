import SwiftUI
import UIKit

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
                        UIPasteboard.general.string = Diagnostics.report(results)
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
