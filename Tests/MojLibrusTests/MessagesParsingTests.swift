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
