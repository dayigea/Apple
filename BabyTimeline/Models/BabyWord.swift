import Foundation
import SwiftData

/// 宝宝词典：宝宝说过的萌句 / 口头禅，可附录音。
@Model
final class BabyWord {
    /// 句子或词，例如「妈妈抱」
    var text: String
    /// 父母补充的上下文备注
    var note: String?
    /// 宝宝说出来的日期（不是入库时间）
    var dateSaid: Date
    var createdAt: Date

    /// 录音原始数据。SwiftData 用 `.externalStorage` 自动转外部文件，
    /// 避免 SQLite 体积膨胀。
    @Attribute(.externalStorage) var audioData: Data?
    /// 录音时长（秒），方便 UI 不解码就能展示
    var audioDuration: Double?

    init(
        text: String,
        note: String? = nil,
        dateSaid: Date = .now,
        audioData: Data? = nil,
        audioDuration: Double? = nil,
        createdAt: Date = .now
    ) {
        self.text = text
        self.note = note
        self.dateSaid = dateSaid
        self.audioData = audioData
        self.audioDuration = audioDuration
        self.createdAt = createdAt
    }
}
