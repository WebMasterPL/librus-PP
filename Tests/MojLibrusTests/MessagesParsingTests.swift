import XCTest
@testable import MojLibrus

final class MessagesParsingTests: XCTestCase {
    func testParsesBasicRow() {
        let html = """
        <table class="decorated stretch"><tbody>
        <tr>
          <td><input type="checkbox"></td>
          <td></td>
          <td><a href="/wiadomosci/1/5/555/f0">Anna Nowak</a></td>
          <td><a href="/wiadomosci/1/5/555/f0">Wycieczka</a></td>
          <td>2026-09-07 12:00:00</td>
        </tr>
        </tbody></table>
        """
        let items = MessagesClient.parseMessageList(html)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, 555)
        XCTAssertEqual(items.first?.correspondent, "Anna Nowak")
        XCTAssertEqual(items.first?.subject, "Wycieczka")
        XCTAssertFalse(items.first?.isUnread ?? true) // no inline style → read
    }

    func testStripsRoleWordAppendedToSender() {
        let html = """
        <table class="decorated stretch"><tbody>
        <tr>
          <td><input type="checkbox"></td>
          <td></td>
          <td style="font-weight:bold"><a href="/wiadomosci/1/5/12345/f0">Jan Kowalski nadawca</a></td>
          <td><a href="/wiadomosci/1/5/12345/f0">Zebranie z rodzicami</a></td>
          <td>2026-09-08 09:15:00</td>
        </tr>
        </tbody></table>
        """
        let items = MessagesClient.parseMessageList(html)
        XCTAssertEqual(items.first?.correspondent, "Jan Kowalski")
        XCTAssertTrue(items.first?.isUnread ?? false) // inline style → unread
    }

    /// Regression: a sortable column-header row ("Nadawca"/"Temat"/"Data") is a
    /// plain `<tr>` in this table, and its sort links reuse the message-row URL
    /// pattern with id=0 — this used to leak in as a fake "Librus" / "Temat" message.
    func testSkipsHeaderRow() {
        let html = """
        <table class="decorated stretch"><tbody>
        <tr>
          <td><input type="checkbox"></td>
          <td></td>
          <td><a href="/wiadomosci/1/5/0/sort_from">Nadawca</a></td>
          <td><a href="/wiadomosci/1/5/0/sort_subject">Temat</a></td>
          <td><a href="/wiadomosci/1/5/0/sort_date">Data</a></td>
        </tr>
        <tr>
          <td><input type="checkbox"></td>
          <td></td>
          <td><a href="/wiadomosci/1/5/123/f0">Jan Kowalski</a></td>
          <td><a href="/wiadomosci/1/5/123/f0">Zebranie</a></td>
          <td>2026-09-20 08:00:00</td>
        </tr>
        </tbody></table>
        """
        let items = MessagesClient.parseMessageList(html)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, 123)
        XCTAssertEqual(items.first?.correspondent, "Jan Kowalski")
        XCTAssertEqual(items.first?.subject, "Zebranie")
    }

    /// Same leak, but the header's sort link happens to carry a non-zero id —
    /// the subject-is-a-bare-header-word guard catches it instead.
    func testSkipsHeaderRowWithNonZeroId() {
        let html = """
        <table class="decorated stretch"><tbody>
        <tr>
          <td><input type="checkbox"></td>
          <td></td>
          <td></td>
          <td><a href="/wiadomosci/1/5/999/f0">Temat</a></td>
          <td></td>
        </tr>
        <tr>
          <td><input type="checkbox"></td>
          <td></td>
          <td><a href="/wiadomosci/1/5/123/f0">Jan Kowalski</a></td>
          <td><a href="/wiadomosci/1/5/123/f0">Zebranie</a></td>
          <td>2026-09-20 08:00:00</td>
        </tr>
        </tbody></table>
        """
        let items = MessagesClient.parseMessageList(html)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, 123)
    }

    /// Markup shape of the Terminarz calendar (names made up) —
    /// each day is a `kalendarz-numer-dnia` marker followed by a nested table of
    /// colour-coded rows; only the pink "Nieobecność" ones are teacher absences.
    func testParsesTerminarzAbsences() {
        let html = """
        <td class="center"><div class="kalendarz-dzien"><div class="kalendarz-numer-dnia">11</div><table><tbody>\
        <tr><td class="no-border-left no-border-right" style="background-color: rgb(255, 120, 120); color: rgb(49, 51, 50);" onclick="location.href='/terminarz/szczegoly_wolne/1001'">Nieobecność:<br>Nauczyciel: Kowalska Anna<br>Godziny: 11:30 do 12:15 </td></tr>\
        <tr><td class="no-border-left no-border-right" style="background-color: rgb(255, 120, 120); color: rgb(49, 51, 50);" onclick="location.href='/terminarz/szczegoly_wolne/1002'">Nieobecność:<br>Nauczyciel: Nowak Piotr</td></tr>\
        <tr><td class="no-border-right no-border-left" style="background-color: rgb(106, 150, 4); color: rgb(255, 255, 255);">Zastępstwo z Maria Zielińska na lekcji nr: 5 (Wychowanie fizyczne)</td></tr>\
        </tbody></table></div></td>
        <td class="center weekend"><div class="kalendarz-dzien"><div class="kalendarz-numer-dnia">12</div></div></td>
        <td class="center"><div class="kalendarz-dzien"><div class="kalendarz-numer-dnia">13</div><table><tbody>\
        <tr><td class="no-border-left no-border-right" style="background-color: rgb(255, 120, 120); color: rgb(49, 51, 50);" onclick="location.href='/terminarz/szczegoly_wolne/1003'">Nieobecność:<br>Nauczyciel: Wiśniewska Ewa</td></tr>\
        </tbody></table></div></td>
        """
        let items = MessagesClient.parseTerminarzAbsences(html)
        XCTAssertEqual(items.count, 3)

        let day11 = items.filter { $0.dayOfMonth == 11 }
        XCTAssertEqual(day11.count, 2)
        XCTAssertEqual(day11.first?.teacherName, "Kowalska Anna")
        XCTAssertEqual(day11.first?.timeFrom, "11:30")
        XCTAssertEqual(day11.first?.timeTo, "12:15")
        XCTAssertEqual(day11.last?.teacherName, "Nowak Piotr")
        XCTAssertNil(day11.last?.timeFrom)

        XCTAssertTrue(items.contains { $0.dayOfMonth == 12 } == false)

        let day13 = items.filter { $0.dayOfMonth == 13 }
        XCTAssertEqual(day13.count, 1)
        XCTAssertEqual(day13.first?.teacherName, "Wiśniewska Ewa")
    }

    /// Regression: a real `POST /terminarz` response (confirmed live
    /// 2026-09-30) renders self-closing `<br />`, not the bare `<br>` the first
    /// capture above used — the old pattern matched zero rows against this,
    /// silently (no error), which is why the summary stayed empty. The day-1
    /// excerpt (names and ids made up) also carries "Odwołane zajęcia" and a homework entry in
    /// the same cell, to confirm those still get skipped.
    func testParsesTerminarzAbsencesWithSelfClosingBr() {
        let html = """
        <td class="center today " ><div class="kalendarz-dzien"><div class="kalendarz-numer-dnia">1</div><table><tbody>\
        <tr><td class="no-border-left no-border-right" style="background-color: #FF7878; " onclick="location.href='/terminarz/szczegoly_wolne/1004'" >Nieobecność:<br />Nauczyciel: Wiśniewska Ewa</td></tr>\
        <tr><td class="no-border-left no-border-right" style="background-color: #FF7878; " onclick="location.href='/terminarz/szczegoly_wolne/1005'" >Nieobecność:<br />Nauczyciel: Wójcik Tomasz<br />Godziny: 11:30 do 12:15 </td></tr>\
        <tr><td style="background-color: #6A9604; " >
                            Odwołane zajęcia <br>Tomasz Lewandowski na lekcji nr: 0 (Fizyka)
                            </td></tr>\
        <tr><td class="no-border-left no-border-right" style="background-color: #32CD32; cursor: pointer;" title="Nauczyciel: Kaczmarek Jan" onclick="location.href='/terminarz/szczegoly/2001'">Nr lekcji: 5<br /><span class="przedmiot">Historia</span>, sprawdzian<br />2a<br/>Sala:&nbsp;12</td></tr>\
        </tbody></table></div></td>
        """
        let items = MessagesClient.parseTerminarzAbsences(html)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].teacherName, "Wiśniewska Ewa")
        XCTAssertNil(items[0].timeFrom)
        XCTAssertEqual(items[1].teacherName, "Wójcik Tomasz")
        XCTAssertEqual(items[1].timeFrom, "11:30")
        XCTAssertEqual(items[1].timeTo, "12:15")
    }

    func testTerminarzShownMonth() {
        let html = """
        <select name="miesiac"  class="ListaWyboru" onChange="this.form.submit();"><option value="1">Styczeń</option><option value="9">Wrzesień</option><option value="10" selected="selected" >Październik</option><option value="11">Listopad</option></select>&nbsp;<select name="rok" class="ListaWyboru"><option value="2026" selected="selected" > 2026</option></select>
        """
        XCTAssertEqual(MessagesClient.terminarzShownMonth(html), 10)
        XCTAssertNil(MessagesClient.terminarzShownMonth("<html>login</html>"))
    }

    func testTeacherNameKeyIgnoresWordOrder() {
        XCTAssertEqual(TimetableView.nameKey("Lewandowski Tomasz"), TimetableView.nameKey("Tomasz Lewandowski"))
        XCTAssertEqual(TimetableView.nameKey("Kamińska-Dąbrowska Joanna"),
                       TimetableView.nameKey("Joanna  Kamińska-Dąbrowska"))
        XCTAssertNotEqual(TimetableView.nameKey("Lewandowski Tomasz"), TimetableView.nameKey("Wójcik Tomasz"))
    }

    /// A link hidden behind a label keeps its address in the plain text.
    func testInlineLinksKeepTheAddress() {
        XCTAssertEqual(
            MessagesClient.inlineLinks(#"Formularz: <a href="https://example.com/form?a=1&amp;b=2" target="_blank">kliknij tutaj</a>."#),
            "Formularz: kliknij tutaj (https://example.com/form?a=1&b=2).")
        XCTAssertEqual(MessagesClient.inlineLinks(#"<a href="https://example.com/">example.com</a>"#),
                       "https://example.com/")
        XCTAssertEqual(MessagesClient.inlineLinks(#"<A HREF='mailto:sekretariat@example.com'>sekretariat@example.com</A>"#),
                       "sekretariat@example.com")
        XCTAssertEqual(MessagesClient.inlineLinks(#"<a href="/wiadomosci/1/5/123/f0">Odpowiedz</a>"#), "Odpowiedz")
    }

    func testLinkedTextMarksLinks() throws {
        let text = "Plan na www.example.com/plan, pytania: info@example.com, sala 12."
        let attributed = LinkedText.attributed(text)
        let links = attributed.runs.compactMap { run in run.link.map { (String(attributed[run.range].characters), $0) } }
        XCTAssertEqual(links.map(\.0), ["www.example.com/plan", "info@example.com"])
        XCTAssertEqual(links.first?.1.host, "www.example.com")
        XCTAssertEqual(links.last?.1.scheme, "mailto")
        XCTAssertEqual(String(attributed.characters), text)
    }

    func testRecoversWhenSenderCellIsAHeaderLabel() {
        // Shifted layout: cell[2] parsed out as the literal column header.
        let html = """
        <table class="decorated stretch"><tbody>
        <tr>
          <td><input type="checkbox"></td>
          <td>Anna Nowak</td>
          <td>Nadawca</td>
          <td><a href="/wiadomosci/1/5/777/f0">Wywiadówka</a></td>
          <td>2026-09-07 12:00:00</td>
        </tr>
        </tbody></table>
        """
        let items = MessagesClient.parseMessageList(html)
        XCTAssertEqual(items.first?.correspondent, "Anna Nowak")
        XCTAssertEqual(items.first?.subject, "Wywiadówka")
    }
}
