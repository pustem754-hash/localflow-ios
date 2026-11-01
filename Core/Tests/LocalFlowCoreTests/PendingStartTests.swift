import XCTest
import LocalFlowCore

/// Запуск из «Команд»: запись ждёт активной сцены, проверки моделей и конца загрузки модели.
final class PendingStartTests: XCTestCase {
    func testNoRequestNeverStarts() {
        var start = PendingStart()
        start.modelsCheckFinished()
        XCTAssertFalse(start.take(sceneActive: true, modelLoading: false))
    }

    func testWaitsForActiveSceneThenStartsOnce() {
        var start = PendingStart()
        start.request()
        start.modelsCheckFinished()
        XCTAssertFalse(start.take(sceneActive: false, modelLoading: false))
        XCTAssertTrue(start.isPending)
        XCTAssertTrue(start.take(sceneActive: true, modelLoading: false))
        XCTAssertFalse(start.isPending)
        XCTAssertFalse(start.take(sceneActive: true, modelLoading: false))
    }

    func testWaitsForModelsCheck() {
        var start = PendingStart()
        start.request()
        XCTAssertFalse(start.take(sceneActive: true, modelLoading: false))
        start.modelsCheckFinished()
        XCTAssertTrue(start.take(sceneActive: true, modelLoading: false))
    }

    func testWaitsWhileModelLoads() {
        var start = PendingStart()
        start.request()
        start.modelsCheckFinished()
        XCTAssertFalse(start.take(sceneActive: true, modelLoading: true))
        XCTAssertTrue(start.isPending)
        XCTAssertTrue(start.take(sceneActive: true, modelLoading: false))
    }

    func testButtonCancelsPendingRequest() {
        var start = PendingStart()
        start.request()
        start.cancel()
        start.modelsCheckFinished()
        XCTAssertFalse(start.take(sceneActive: true, modelLoading: false))
    }

    func testNewRequestChecksModelsAgain() {
        var start = PendingStart()
        start.request()
        start.modelsCheckFinished()
        XCTAssertTrue(start.take(sceneActive: true, modelLoading: false))
        start.request()
        XCTAssertFalse(start.modelsChecked)
        XCTAssertFalse(start.take(sceneActive: true, modelLoading: false))
    }
}
