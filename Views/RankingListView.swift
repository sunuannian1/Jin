import SwiftUI

// 总分排名：选择考试 → 前三名 + 完整排名（丝滑动效版）
struct RankingListView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedExamId: UUID?
    @State private var podiumReveal = false

    private var sortedExams: [Exam] {
        viewModel.exams.sorted { $0.date > $1.date }
    }

    private var selectedExam: Exam? {
        guard let id = selectedExamId else { return nil }
        return viewModel.exams.first { $0.id == id }
    }

    var body: some View {
        Group {
            if viewModel.exams.isEmpty {
                EmptyStateView(systemImage: "chart.bar", title: "还没有考试",
                               message: "先在「成绩管理」中新建考试并录入成绩")
            } else {
                VStack(spacing: 0) {
                    Picker("考试", selection: examSelection) {
                        ForEach(sortedExams) { exam in
                            Text(exam.name).tag(Optional(exam.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.vertical, 6)

                    if let exam = selectedExam {
                        rankingBody(for: exam)
                            .id(exam.id)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .animation(AppTheme.Motion.smooth, value: selectedExamId)
            }
        }
        .navigationTitle("总分排名")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.Colors.background)
        .onAppear {
            if selectedExamId == nil { selectedExamId = sortedExams.first?.id }
            replayPodium()
        }
    }

    // 选择考试时重播领奖台动画
    private var examSelection: Binding<UUID?> {
        Binding(
            get: { selectedExamId },
            set: { newValue in
                withAnimation(AppTheme.Motion.smooth) { selectedExamId = newValue }
                podiumReveal = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(AppTheme.Motion.bouncy) { podiumReveal = true }
                }
            }
        )
    }

    private func replayPodium() {
        podiumReveal = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(AppTheme.Motion.bouncy) { podiumReveal = true }
        }
    }

    @ViewBuilder
    private func rankingBody(for exam: Exam) -> some View {
        let ranking = viewModel.totalRanking(for: exam.id)
        if ranking.isEmpty {
            EmptyStateView(systemImage: "list.number", title: "暂无成绩",
                           message: "这场考试还没有录入成绩")
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    if ranking.count >= 3 {
                        podium(of: Array(ranking.prefix(3)))
                    } else {
                        Text("有成绩的学生不足 3 人，直接查看下方排名")
                            .font(AppTheme.Fonts.footnote)
                            .foregroundColor(AppTheme.Colors.tertiaryText)
                    }
                    fullList(of: ranking)
                }
                .padding(18)
                .padding(.bottom, 32)
            }
            .background(AppTheme.Colors.background)
        }
    }

    private struct PodiumEntry: Identifiable {
        let rank: Int
        let student: Student
        let total: Double
        var id: Int { rank }
    }

    // 前三名领奖台（弹入动画）
    private func podium(of top3: [(student: Student, total: Double)]) -> some View {
        let entries: [PodiumEntry] = [
            PodiumEntry(rank: 2, student: top3[1].student, total: top3[1].total),
            PodiumEntry(rank: 1, student: top3[0].student, total: top3[0].total),
            PodiumEntry(rank: 3, student: top3[2].student, total: top3[2].total),
        ]
        let barHeight: [Int: CGFloat] = [1: 56, 2: 34, 3: 16]
        let colors: [Int: Color] = [1: Color(red: 0.95, green: 0.75, blue: 0.15),
                                    2: Color(red: 0.65, green: 0.65, blue: 0.67),
                                    3: Color(red: 0.80, green: 0.50, blue: 0.20)]

        return HStack(alignment: .bottom, spacing: 12) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill((colors[entry.rank] ?? AppTheme.Colors.gray).opacity(0.2))
                            .frame(width: 56, height: 56)
                        StudentAvatar(name: entry.student.name, size: 44)
                        Text("\(entry.rank)")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(colors[entry.rank] ?? AppTheme.Colors.gray))
                            .offset(x: 20, y: -20)
                    }
                    .scaleEffect(podiumReveal ? 1 : 0.2)
                    .opacity(podiumReveal ? 1 : 0)

                    Text(entry.student.name)
                        .font(AppTheme.Fonts.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.Colors.primaryText)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(String(format: "%.0f 分", entry.total))
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(AppTheme.Colors.secondaryText)
                    Rectangle()
                        .fill((colors[entry.rank] ?? AppTheme.Colors.gray).opacity(0.3))
                        .frame(height: podiumReveal ? (barHeight[entry.rank] ?? 12) : 0)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous)
                    .stroke(AppTheme.Colors.separator, lineWidth: 0.5))
                .animation(AppTheme.Motion.bouncy.delay(Double(index) * 0.12), value: podiumReveal)
            }
        }
    }

    // 完整排名列表（依次入场）
    private func fullList(of ranking: [(student: Student, total: Double)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("完整排名（\(ranking.count) 人）")
                .font(AppTheme.Fonts.title3)
                .foregroundColor(AppTheme.Colors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(ranking.enumerated()), id: \.element.student.id) { index, item in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 15, weight: .heavy).monospacedDigit())
                            .foregroundColor(index < 3 ? AppTheme.Colors.accent : AppTheme.Colors.tertiaryText)
                            .frame(width: 30, alignment: .center)
                        StudentAvatar(name: item.student.name, size: 34)
                        Text(item.student.name)
                            .font(AppTheme.Fonts.body.weight(.medium))
                            .foregroundColor(AppTheme.Colors.primaryText)
                        Spacer()
                        Text(String(format: "%.0f", item.total))
                            .font(.system(size: 16, weight: .heavy).monospacedDigit())
                            .foregroundColor(AppTheme.Colors.accent)
                        Text("分")
                            .font(AppTheme.Fonts.caption)
                            .foregroundColor(AppTheme.Colors.tertiaryText)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .staggeredAppear(index: index, step: 0.035)
                    if index < ranking.count - 1 {
                        Divider().background(AppTheme.Colors.separator).padding(.leading, 60)
                    }
                }
            }
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                .stroke(AppTheme.Colors.separator, lineWidth: 0.5))
            .rdShadow(AppTheme.Shadows.sm)
        }
    }
}
