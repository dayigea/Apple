import SwiftData
import SwiftUI

/// 新增 / 编辑一条宝宝词典记录。
struct BabyDictionaryEditView: View {

    let word: BabyWord?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var note: String = ""
    @State private var dateSaid: Date = .now
    @State private var audioData: Data?
    @State private var audioDuration: Double?
    @State private var hasInitialized = false

    @State private var recorder = AudioRecorderService()
    @State private var showPermissionAlert = false

    var body: some View {
        Form {
            Section("宝宝说的话") {
                TextField("例如：「妈妈抱」", text: $text, axis: .vertical)
                    .lineLimit(1...3)
                DatePicker(
                    "日期",
                    selection: $dateSaid,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "zh_CN"))
            }

            Section("录音（可选）") {
                recorderControls
            }

            Section("备注（可选）") {
                TextField("当时在干什么、谁在场...", text: $note, axis: .vertical)
                    .lineLimit(2...6)
            }

            if word != nil {
                Section {
                    Button(role: .destructive) {
                        deleteWord()
                    } label: {
                        Label("删除这条记录", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(word == nil ? "新记录" : "编辑")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    recorder.stopAll()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear { initializeIfNeeded() }
        .onDisappear { recorder.stopAll() }
        .alert("需要麦克风权限", isPresented: $showPermissionAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请到「设置 → 苹果长大了 → 麦克风」打开权限。")
        }
    }

    // MARK: - Recorder UI

    @ViewBuilder
    private var recorderControls: some View {
        switch recorder.state {
        case .idle:
            if audioData != nil {
                playbackBar
                HStack {
                    Button {
                        Task { await startRecording() }
                    } label: {
                        Label("重录", systemImage: "arrow.clockwise")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        audioData = nil
                        audioDuration = nil
                    } label: {
                        Label("删除录音", systemImage: "trash")
                    }
                }
                .font(.subheadline)
            } else {
                Button {
                    Task { await startRecording() }
                } label: {
                    Label("开始录音", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            }
        case .recording(let elapsed):
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .opacity(elapsed.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.3)
                    Text("正在录音 \(formatTime(elapsed))")
                        .font(.subheadline)
                        .monospacedDigit()
                    Spacer()
                }
                Button {
                    recorder.stopRecording()
                    if case .finishedRecording(let data, let duration) = recorder.state {
                        audioData = data
                        audioDuration = duration
                        recorder.stopAll()
                    }
                } label: {
                    Label("停止", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        case .playing(let progress):
            VStack(spacing: 6) {
                ProgressView(value: progress)
                HStack {
                    Text("正在播放…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("停止") { recorder.stopPlaying() }
                        .font(.caption)
                }
            }
        case .failed(let msg):
            Text(msg)
                .font(.caption)
                .foregroundStyle(.red)
        case .finishedRecording:
            EmptyView()  // 已经处理在 .recording 切到 .idle 之间
        }
    }

    private var playbackBar: some View {
        HStack {
            Button {
                guard let data = audioData else { return }
                recorder.play(data)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("已有录音")
                    .font(.subheadline)
                if let duration = audioDuration {
                    Text(formatTime(duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer()
        }
    }

    // MARK: - Actions

    private func startRecording() async {
        let granted = await recorder.requestPermission()
        guard granted else {
            showPermissionAlert = true
            return
        }
        recorder.startRecording()
    }

    private func initializeIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true
        guard let w = word else { return }
        text = w.text
        note = w.note ?? ""
        dateSaid = w.dateSaid
        audioData = w.audioData
        audioDuration = w.audioDuration
    }

    private func save() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        if let w = word {
            w.text = trimmedText
            w.note = trimmedNote.isEmpty ? nil : trimmedNote
            w.dateSaid = dateSaid
            w.audioData = audioData
            w.audioDuration = audioDuration
        } else {
            let new = BabyWord(
                text: trimmedText,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                dateSaid: dateSaid,
                audioData: audioData,
                audioDuration: audioDuration
            )
            context.insert(new)
        }
        try? context.save()
        recorder.stopAll()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        dismiss()
    }

    private func deleteWord() {
        guard let w = word else { return }
        context.delete(w)
        try? context.save()
        recorder.stopAll()
        dismiss()
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
