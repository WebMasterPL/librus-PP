import Foundation

struct DiagnosticResult: Identifiable {
    let id = UUID()
    let name: String
    let ok: Bool
    let detail: String
}

/// Hits every endpoint independently and reports OK / error text.
/// Useful for remote debugging: the user can copy the report and send it over.
struct Diagnostics {
    let session: LibrusSession

    func run() async -> [DiagnosticResult] {
        let checks: [(String, String)] = [
            ("Me", Librus.Path.me),
            ("Subjects", Librus.Path.subjects),
            ("Users", Librus.Path.users),
            ("Classes", Librus.Path.classes),
            ("Classrooms", Librus.Path.classrooms),
            ("Grades", Librus.Path.grades),
            ("Grades/Categories", Librus.Path.gradeCategories),
            ("Timetables", Librus.Path.timetable(weekStart: LibrusDate.ymdString(LibrusDate.weekStart()))),
            ("Attendances", Librus.Path.attendances),
            ("Attendances/Types", Librus.Path.attendanceTypes),
            ("Lessons", Librus.Path.lessons),
            ("Schools (dzwonki)", Librus.Path.schools),
            ("SchoolNotices", Librus.Path.schoolNotices),
            ("HomeWorks (terminarz)", Librus.Path.events),
            ("Notes", Librus.Path.notes),
        ]

        var results: [DiagnosticResult] = [await checkLogin()]

        // If login itself failed, the rest will all fail the same way — skip them.
        if results[0].ok {
            for (name, path) in checks {
                results.append(await check(name: name, path: path))
            }
            results.append(await checkMessages())
        }
        return results
    }

    private func checkLogin() async -> DiagnosticResult {
        do {
            let token = try await session.validAccessToken()
            return DiagnosticResult(name: "Logowanie (Portal → Synergia)", ok: !token.isEmpty,
                                    detail: token.isEmpty ? "pusty token" : "token OK (\(token.prefix(6))…)")
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            return DiagnosticResult(name: "Logowanie (Portal → Synergia)", ok: false, detail: msg)
        }
    }

    private func check(name: String, path: String) async -> DiagnosticResult {
        do {
            let data = try await session.authorizedData(path: path)
            let bytes = data.count
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let keys = obj.keys.sorted().prefix(3).joined(separator: ", ")
                return DiagnosticResult(name: name, ok: true, detail: "\(bytes) B · klucze: \(keys)")
            }
            return DiagnosticResult(name: name, ok: true, detail: "\(bytes) B")
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            return DiagnosticResult(name: name, ok: false, detail: msg)
        }
    }

    private func checkMessages() async -> DiagnosticResult {
        let client = MessagesClient(session: session)
        do {
            let list = try await client.inbox()
            return DiagnosticResult(name: "Wiadomości (mostek)", ok: true,
                                    detail: "\(list.count) wiadomości w skrzynce")
        } catch {
            // Deep probe: try every candidate inbox endpoint and report what each
            // returns, so we can see which API the current Librus serves.
            let report = await client.probe()
            return DiagnosticResult(name: "Wiadomości (mostek)", ok: false, detail: report)
        }
    }

    static func report(_ results: [DiagnosticResult]) -> String {
        var lines = ["Mój Librus — diagnostyka \(Date().formattedPL("yyyy-MM-dd HH:mm"))"]
        for r in results {
            lines.append("\(r.ok ? "OK  " : "BŁĄD") \(r.name) — \(r.detail)")
        }
        return lines.joined(separator: "\n")
    }
}
