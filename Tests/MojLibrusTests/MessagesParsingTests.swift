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
