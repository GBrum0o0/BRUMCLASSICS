import XCTest
@testable import BRUMCLASSICSMobile

final class MobileExperienceTests: XCTestCase {
    func testOfflineStateExplainsCacheAndPendingChanges() {
        let value = MobileSyncSummary.make(connection: .offline, paired: true, cachedGames: 42, pending: 3, lastSuccess: Date())
        XCTAssertEqual(value.title, "Dados salvos no aparelho")
        XCTAssertTrue(value.detail.contains("3 alterações"))
        XCTAssertEqual(value.action, "Reconexão automática ativa")
    }

    func testConnectedStateCannotBeMisread() {
        let value = MobileSyncSummary.make(connection: .online, paired: true, cachedGames: 12, pending: 0, lastSuccess: Date())
        XCTAssertEqual(value.title, "Tudo sincronizado")
        XCTAssertTrue(value.isHealthy)
    }
}
