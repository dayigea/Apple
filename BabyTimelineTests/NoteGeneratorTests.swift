import XCTest
@testable import BabyTimeline

final class NoteGeneratorTests: XCTestCase {

    private func makeBaby(birthday: Date = Date(timeIntervalSince1970: 0)) -> Baby {
        Baby(name: "测试", birthday: birthday)
    }

    private func makePhoto(
        creationDate: Date,
        autoTags: [String] = [],
        placeName: String? = nil
    ) -> PhotoEntry {
        let p = PhotoEntry(assetLocalId: UUID().uuidString, creationDate: creationDate)
        p.autoTags = autoTags
        p.placeName = placeName
        return p
    }

    // MARK: - 场景模板命中

    func testBirthdayCakeScene() {
        let baby = makeBaby(birthday: Date(timeIntervalSince1970: 0))
        let photo = makePhoto(
            creationDate: Date(timeIntervalSince1970: 365 * 86400),
            autoTags: ["生日蛋糕", "蛋糕", "微笑"]
        )
        let note = NoteGenerator.generate(for: photo, baby: baby)
        XCTAssertTrue(note.contains("生日"), "Birthday scene should mention 生日: \(note)")
    }

    func testDogParkScene() {
        let baby = makeBaby(birthday: Date(timeIntervalSince1970: 0))
        let photo = makePhoto(
            creationDate: Date(timeIntervalSince1970: 200 * 86400),
            autoTags: ["狗", "公园"],
            placeName: "朝阳公园"
        )
        let note = NoteGenerator.generate(for: photo, baby: baby)
        XCTAssertTrue(note.contains("狗"), "Dog+park scene should mention 狗: \(note)")
        XCTAssertTrue(note.contains("朝阳公园"), "Should include place: \(note)")
    }

    func testSnowScene() {
        let baby = makeBaby(birthday: Date(timeIntervalSince1970: 0))
        let photo = makePhoto(
            creationDate: Date(timeIntervalSince1970: 400 * 86400),
            autoTags: ["雪"]
        )
        let note = NoteGenerator.generate(for: photo, baby: baby)
        XCTAssertTrue(note.contains("雪"), "Snow scene should mention 雪: \(note)")
    }

    func testWalkingSceneForYoungBaby() {
        let baby = makeBaby(birthday: Date(timeIntervalSince1970: 0))
        let photo = makePhoto(
            creationDate: Date(timeIntervalSince1970: 365 * 86400),
            autoTags: ["走路"]
        )
        let note = NoteGenerator.generate(for: photo, baby: baby)
        XCTAssertFalse(note.isEmpty)
    }

    // MARK: - 通用模板

    func testGenericNoteForYoungBaby() {
        let baby = makeBaby(birthday: Date(timeIntervalSince1970: 0))
        let photo = makePhoto(
            creationDate: Date(timeIntervalSince1970: 90 * 86400),
            autoTags: ["椅子", "玩具"],
            placeName: "家里"
        )
        let note = NoteGenerator.generate(for: photo, baby: baby)
        XCTAssertFalse(note.isEmpty, "Should produce a non-empty note")
        XCTAssertTrue(note.contains("家里"), "Should include place: \(note)")
    }

    func testGenericNoteFiltersBoringTags() {
        let baby = makeBaby(birthday: Date(timeIntervalSince1970: 0))
        let photo = makePhoto(
            creationDate: Date(timeIntervalSince1970: 600 * 86400),
            autoTags: ["宝宝", "室内", "家具", "玩具"]
        )
        let note = NoteGenerator.generate(for: photo, baby: baby)
        XCTAssertFalse(note.contains("宝宝"), "Should filter '宝宝': \(note)")
        XCTAssertFalse(note.contains("室内"), "Should filter '室内': \(note)")
    }

    // MARK: - 年龄语气

    func testSoftToneForNewborn() {
        let baby = makeBaby(birthday: Date(timeIntervalSince1970: 0))
        let photo = makePhoto(
            creationDate: Date(timeIntervalSince1970: 60 * 86400),
            autoTags: ["毯子"]
        )
        let note = NoteGenerator.generate(for: photo, baby: baby)
        XCTAssertFalse(note.isEmpty)
    }

    func testStorytellingToneForOlderChild() {
        let baby = makeBaby(birthday: Date(timeIntervalSince1970: 0))
        let photo = makePhoto(
            creationDate: Date(timeIntervalSince1970: 730 * 86400),
            autoTags: ["玩具", "积木"]
        )
        let note = NoteGenerator.generate(for: photo, baby: baby)
        XCTAssertFalse(note.isEmpty)
    }

    // MARK: - 边界

    func testEmptyTags() {
        let baby = makeBaby(birthday: Date(timeIntervalSince1970: 0))
        let photo = makePhoto(
            creationDate: Date(timeIntervalSince1970: 300 * 86400),
            autoTags: []
        )
        let note = NoteGenerator.generate(for: photo, baby: baby)
        XCTAssertFalse(note.isEmpty, "Should still produce a note with no tags")
    }

    func testNoteNeverEmpty() {
        let baby = makeBaby(birthday: Date(timeIntervalSince1970: 0))
        for days in stride(from: 30, through: 900, by: 90) {
            let photo = makePhoto(
                creationDate: Date(timeIntervalSince1970: Double(days) * 86400),
                autoTags: ["花", "阳光"]
            )
            let note = NoteGenerator.generate(for: photo, baby: baby)
            XCTAssertFalse(note.isEmpty, "Note should never be empty at day \(days)")
        }
    }
}
