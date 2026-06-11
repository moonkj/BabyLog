import Foundation

/// 거래 대화를 사람이 읽을 수 있는 텍스트 사본으로 변환한다.
/// 사용자가 경찰·지원기관에 제출할 수 있도록 내보내기/신고에 사용.
enum ChatTranscript {
    static func text(itemTitle: String,
                     counterpart: String,
                     messages: [ChatMessage],
                     reason: String? = nil,
                     note: String? = nil) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ko_KR")
        df.dateFormat = "yyyy-MM-dd HH:mm"

        var lines: [String] = []
        lines.append("[베이비로그 거래 대화 사본]")
        lines.append("매물: \(itemTitle)")
        lines.append("상대: \(counterpart)")
        lines.append("내보낸 시각: \(df.string(from: Date()))")
        if let reason, !reason.isEmpty { lines.append("신고 사유: \(reason)") }
        if let note, !note.isEmpty { lines.append("메모: \(note)") }
        lines.append("메시지: \(messages.count)건")
        lines.append("────────────")
        if messages.isEmpty {
            lines.append("(대화 내용 없음)")
        } else {
            for m in messages {
                let who = m.mine ? "나" : counterpart
                lines.append("[\(df.string(from: m.date))] \(who): \(m.text)")
            }
        }
        lines.append("────────────")
        lines.append("※ 본 기록은 사용자 기기에 저장된 대화 사본입니다.")
        return lines.joined(separator: "\n")
    }
}
