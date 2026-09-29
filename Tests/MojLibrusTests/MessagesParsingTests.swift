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

    /// Real markup shape captured from the Terminarz calendar 2026-09-29 —
    /// each day is a `kalendarz-numer-dnia` marker followed by a nested table of
    /// colour-coded rows; only the pink "Nieobecność" ones are teacher absences.
    func testParsesTerminarzAbsences() {
        let html = """
        <td class="center"><div class="kalendarz-dzien"><div class="kalendarz-numer-dnia">11</div><table><tbody>\
        <tr><td class="no-border-left no-border-right" style="background-color: rgb(255, 120, 120); color: rgb(49, 51, 50);" onclick="location.href='/terminarz/szczegoly_wolne/3704850'">Nieobecność:<br>Nauczyciel: Pytel Renata<br>Godziny: 11:30 do 12:15 </td></tr>\
        <tr><td class="no-border-left no-border-right" style="background-color: rgb(255, 120, 120); color: rgb(49, 51, 50);" onclick="location.href='/terminarz/szczegoly_wolne/3695339'">Nieobecność:<br>Nauczyciel: Warchał Wojciech</td></tr>\
        <tr><td class="no-border-right no-border-left" style="background-color: rgb(106, 150, 4); color: rgb(255, 255, 255);">Zastępstwo z Katarzyna Chmiel na lekcji nr: 5 (Wychowanie fizyczne)</td></tr>\
        </tbody></table></div></td>
        <td class="center weekend"><div class="kalendarz-dzien"><div class="kalendarz-numer-dnia">12</div></div></td>
        <td class="center"><div class="kalendarz-dzien"><div class="kalendarz-numer-dnia">13</div><table><tbody>\
        <tr><td class="no-border-left no-border-right" style="background-color: rgb(255, 120, 120); color: rgb(49, 51, 50);" onclick="location.href='/terminarz/szczegoly_wolne/3695336'">Nieobecność:<br>Nauczyciel: Galant Krystyna</td></tr>\
        </tbody></table></div></td>
        """
        let items = MessagesClient.parseTerminarzAbsences(html)
        XCTAssertEqual(items.count, 3)

        let day11 = items.filter { $0.dayOfMonth == 11 }
        XCTAssertEqual(day11.count, 2)
        XCTAssertEqual(day11.first?.teacherName, "Pytel Renata")
        XCTAssertEqual(day11.first?.timeFrom, "11:30")
        XCTAssertEqual(day11.first?.timeTo, "12:15")
        XCTAssertEqual(day11.last?.teacherName, "Warchał Wojciech")
        XCTAssertNil(day11.last?.timeFrom)

        XCTAssertTrue(items.contains { $0.dayOfMonth == 12 } == false)

        let day13 = items.filter { $0.dayOfMonth == 13 }
        XCTAssertEqual(day13.count, 1)
        XCTAssertEqual(day13.first?.teacherName, "Galant Krystyna")
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
