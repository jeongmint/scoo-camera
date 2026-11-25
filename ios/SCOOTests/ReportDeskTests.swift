import XCTest
@testable import SCOO

final class ReportDeskTests: XCTestCase {
    func testReportRowsFromTheServerDecode() throws {
        let json = #"""
        [{"id": 3, "created_at": "2026-11-25T03:00:00.123456+00:00", "reason": "욕을 했어요", "status": "suspended",
          "action_note": "욕설", "reviewed_at": "2026-11-25T04:00:00+00:00", "reporter_name": "신난 루나",
          "reported": "aaaaaaaa-0000-4000-8000-000000000001", "reported_name": "졸린 도도", "reported_total": 2,
          "suspended_until": "2099-01-01T00:00:00+00:00", "message_id": null, "body": "나쁜 말", "sticker": null,
          "photo": null, "letter_exists": false}]
        """#
        let rows = try SupabaseClient.decoder.decode([ReportDesk.Report].self, from: Data(json.utf8))
        XCTAssertEqual(rows.first?.statusTitle, "편지 지우고 보내기 정지")
        XCTAssertEqual(rows.first?.isSuspended(), true)
        XCTAssertEqual(rows.first?.body, "나쁜 말")
    }

    func testSuspendedSendersReadWhenTheyCanWriteAgain() {
        let error = SupabaseClient.ServerError.http(400, #"{"code":"P0001","message":"suspended until 2026-12-02"}"#)
        XCTAssertEqual(error.errorDescription, "운영 규칙을 어긴 편지가 있어서 2026-12-02까지 편지와 친구 요청을 보낼 수 없어요.")
        XCTAssertEqual(SupabaseClient.ServerError.http(403, "operators only").errorDescription, "운영자만 할 수 있어요.")
    }
}
