import XCTest
@testable import MojLibrus

final class PortalAuthTests: XCTestCase {
    func testFormBodyEncoding() {
        let body = HTTP.formBody(["grant_type": "authorization_code", "redirect_uri": "app://librus", "code": "a b+c"])
        let s = String(data: body, encoding: .utf8)!
        XCTAssertTrue(s.contains("grant_type=authorization_code"))
        XCTAssertTrue(s.contains("redirect_uri=app%3A%2F%2Flibrus"))
        XCTAssertTrue(s.contains("code=a+b%2Bc"))
    }

    func testFirstMatch() {
        let html = #"<meta name="csrf-token" content="ABC123xyz">"#
        XCTAssertEqual(HTTP.firstMatch(#"name="csrf-token"\s+content="([^"]+)""#, in: html), "ABC123xyz")
        XCTAssertNil(HTTP.firstMatch(#"name="nope" content="([^"]+)""#, in: html))
    }

    func testHiddenInputs() {
        let html = """
        <form>
          <input type="hidden" name="_token" value="tok123" autocomplete="off">
          <input type="hidden" name="redirectTo" value="/konto-librus/redirect/dru">
          <input type="hidden" name="redirectCrc" value="abcdef">
          <input type="email" name="email" value="">
        </form>
        """
        let fields = HTTP.hiddenInputs(in: html)
        XCTAssertEqual(fields["_token"], "tok123")
        XCTAssertEqual(fields["redirectTo"], "/konto-librus/redirect/dru")
        XCTAssertEqual(fields["redirectCrc"], "abcdef")
        XCTAssertNil(fields["email"]) // not hidden
    }

    func testDecodeSynergiaAccounts() throws {
        let json = """
        { "lastModification": 1725000000, "accounts": [
          { "id": 111, "login": "1234567u", "accessToken": "SYN-TOKEN",
            "studentName": "Jan Kowalski", "group": "student", "state": "active" }
        ] }
        """
        struct Wrapper: Decodable { let accounts: [SynergiaAccount] }
        let w = try JSONDecoder().decode(Wrapper.self, from: Data(json.utf8))
        XCTAssertEqual(w.accounts.count, 1)
        XCTAssertEqual(w.accounts[0].login, "1234567u")
        XCTAssertEqual(w.accounts[0].accessToken, "SYN-TOKEN")
        XCTAssertEqual(w.accounts[0].studentName, "Jan Kowalski")
    }
}
