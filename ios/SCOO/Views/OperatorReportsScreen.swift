import SwiftUI
import UIKit

/// 신고 처리 (운영자 모드): reported letters, newest first. For each one the operator sees what was sent and by whom,
/// how often that person was reported, and chooses: leave it, remove the letter, or remove it and stop the sender
/// for 7 days.
struct OperatorReportsScreen: View {
    @StateObject private var desk = ReportDesk()
    @State private var showOpen = true
    @State private var pending: (report: ReportDesk.Report, action: ReportDesk.Action)?
    @State private var note = ""

    var body: some View {
        Form {
            Section {
                Picker("보기", selection: $showOpen) {
                    Text("처리 전").tag(true)
                    Text("처리함").tag(false)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("신고한 사람이 누구인지는 신고받은 사람에게 알리지 않아요. 지운 편지도 신고 기록에는 글이 남아요.")
            }
            .listRowBackground(Color.clear)

            if desk.reports.isEmpty && !desk.loading {
                Section {
                    Text(showOpen ? "처리할 신고가 없어요." : "아직 처리한 신고가 없어요.")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Glass.row)
            }

            ForEach(desk.reports) { report in
                Section {
                    ReportCard(report: report, desk: desk)
                    if report.status == "open" {
                        ForEach(ReportDesk.Action.allCases, id: \.self) { action in
                            Button(action.title, role: action == .dismiss ? nil : .destructive) {
                                note = ""
                                pending = (report, action)
                            }
                        }
                    } else if report.isSuspended() {
                        Button("보내기 정지 풀기") { Task { await desk.lift(report, open: showOpen) } }
                    }
                }
                .listRowBackground(Glass.row)
            }
        }
        .glassSheet()
        .navigationTitle("신고 처리").navigationBarTitleDisplayMode(.inline)
        .overlay { if desk.loading && desk.reports.isEmpty { ProgressView() } }
        .task(id: showOpen) { await desk.load(open: showOpen) }
        .refreshable { await desk.load(open: showOpen) }
        .alert(pending?.action.title ?? "", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            TextField("메모 (선택, 처리 기록에만 남아요)", text: $note)
            Button(pending?.action.title ?? "확인", role: pending?.action == .dismiss ? nil : .destructive) {
                guard let pending else { return }
                let chosen = pending
                self.pending = nil
                Task { await desk.resolve(chosen.report, chosen.action, note: note, open: showOpen) }
            }
            Button("취소", role: .cancel) { pending = nil }
        } message: {
            Text(pending?.action.explanation ?? "")
        }
        .alert("처리하지 못했어요", isPresented: Binding(get: { desk.message != nil }, set: { if !$0 { desk.message = nil } })) {
            Button("확인", role: .cancel) { desk.message = nil }
        } message: { Text(desk.message ?? "") }
    }
}

/// One report: who reported whom, why, and the letter itself (words, sticker or photo).
private struct ReportCard: View {
    let report: ReportDesk.Report
    let desk: ReportDesk
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(report.created_at.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(report.statusTitle).font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((report.status == "open" ? Glass.clay : Glass.stone).opacity(0.5), in: Capsule())
            }
            Text("\(report.reporter_name ?? "지운 계정") → \(report.reported_name ?? "지운 계정")")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 6) {
                Text("이 사람이 받은 신고 \(report.reported_total)건").font(.caption)
                    .foregroundStyle(report.reported_total >= 3 ? Glass.clay : .secondary)
                if let until = report.suspended_until, report.isSuspended() {
                    Text("· \(until.formatted(date: .abbreviated, time: .omitted))까지 보내기 정지").font(.caption).foregroundStyle(Glass.clay)
                }
            }
            if let reason = report.reason, !reason.isEmpty {
                Text("신고 이유: \(reason)").font(.footnote)
            }
            VStack(alignment: .leading, spacing: 6) {
                if let body = report.body { Text(body).font(.callout) }
                if let sticker = report.sticker {
                    Text("스티커: \(Species.find(sticker)?.name ?? sticker)").font(.caption).foregroundStyle(.secondary)
                }
                if report.photo != nil {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel("신고된 편지 사진")
                    } else {
                        Text("사진 불러오는 중…").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !report.letter_exists {
                    Text("편지는 지워졌어요.").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            if let note = report.action_note, !note.isEmpty {
                Text("메모: \(note)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .task(id: report.photo) {
            guard let path = report.photo, image == nil, let data = await desk.photo(path) else { return }
            image = UIImage(data: data)
        }
    }
}
