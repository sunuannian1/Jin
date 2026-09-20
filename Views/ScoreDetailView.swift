import SwiftUI
import Charts

// 成绩录入详情 — 完整成绩可视化 + 丝滑动效
struct ScoreDetailView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let exam: Exam

    @State private var selectedSubject: String
    @State private var showingRanking = false
    // 图表生长动画因子（0 → 1）
    @State private var reveal: Double = 0
    // 点选的分数段
    @State private var selectedBar: String?

    init(exam: Exam) {
        self.exam = exam
        _selectedSubject = State(initialValue: exam.subjects.first ?? "")
    }

    private var subjectBinding: Binding<String> {
        Binding(
            get: {
                if exam.subjects.contains(selectedSubject) { return selectedSubject }
                return exam.subjects.first ?? ""
            },
            set: { newValue in
                withAnimation(AppTheme.Motion.smooth) { selectedSubject = newValue }
                replayChart()
            }
        )
    }

    private var records: [ScoreRecord] {
        guard !selectedSubject.isEmpty else { return [] }
        return viewModel.scores(for: exam.id, subject: selectedSubject)
    }

    // MARK: - 统计量
    // 整页只算一次：body 顶部取 records / stats 各一份再往下传。
    // 原先 7 个统计属性各自全表过滤一遍（其中最高/最低/中位还要各排一次序），
    // 一次 body 求值要把成绩表扫十几遍，而这一页可以边打字边改。
    private var stats: AppViewModel.SubjectStats {
        viewModel.stats(examId: exam.id, subject: selectedSubject)
    }
    private var trendDelta: Double? { viewModel.averageTrendDelta(examId: exam.id, subject: selectedSubject) }

    // 分数分布（原始）
    private func scoreDistribution(_ records: [ScoreRecord]) -> [ScoreBucket] {
        let buckets = [
            ScoreBucket(range: "0-59", label: "不及格", min: 0, max: 59.99),
            ScoreBucket(range: "60-69", label: "及格", min: 60, max: 69.99),
            ScoreBucket(range: "70-79", label: "中等", min: 70, max: 79.99),
            ScoreBucket(range: "80-89", label: "良好", min: 80, max: 89.99),
            ScoreBucket(range: "90-100", label: "优秀", min: 90, max: 1000)
        ]
        return buckets.map { bucket in
            var b = bucket
            b.count = records.filter { $0.score >= bucket.min && $0.score <= bucket.max }.count
            return b
        }
    }

    // 带动画因子的柱状数据
    private func distributionBars(_ records: [ScoreRecord]) -> [DistributionBar] {
        scoreDistribution(records).map { b in
            DistributionBar(
                label: b.label,
                tier: b.range,
                count: b.count,
                animatedValue: Double(b.count) * reveal,
                ratio: records.isEmpty ? 0 : Double(b.count) / Double(records.count)
            )
        }
    }

    // 班级均分趋势（同科目历次考试）
    private var averageTrend: [TrendPoint] {
        viewModel.exams
            .filter { $0.subjects.contains(selectedSubject) }
            .sorted { $0.date < $1.date }
            .map { TrendPoint(examName: $0.name, date: $0.date,
                              average: viewModel.averageScore(examId: $0.id, subject: selectedSubject)) }
    }

    var body: some View {
        // 整页求值一次，往下传（见上方统计量注释）
        let records = self.records
        let stats = self.stats
        let scoreTexts = Dictionary(uniqueKeysWithValues:
            records.map { ($0.studentId, Self.scoreText($0.score)) })

        ScrollView {
            VStack(spacing: 14) {
                if exam.subjects.count > 1 {
                    Picker("科目", selection: subjectBinding) {
                        ForEach(exam.subjects, id: \.self) { subject in
                            Text(subject).tag(subject)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                }

                // MARK: 核心统计
                heroStats(stats)
                    .padding(.horizontal, 18)
                    .id("hero-\(selectedSubject)")
                    .transition(.opacity.combined(with: .move(edge: .top)))

                // MARK: 次级指标条
                if !records.isEmpty {
                    metricStrip(stats)
                        .padding(.horizontal, 18)
                        .id("strip-\(selectedSubject)")
                        .transition(.opacity)
                }

                // MARK: 分数分布
                if !records.isEmpty {
                    distributionCard(records)
                        .padding(.horizontal, 18)
                }

                // MARK: 均分趋势
                if averageTrend.count >= 2 {
                    trendCard
                        .padding(.horizontal, 18)
                }

                // MARK: 成绩录入
                if viewModel.students.isEmpty {
                    EmptyStateView(systemImage: "person.2", title: "还没有学生",
                                   message: "请先在「学生名册」中添加学生")
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(viewModel.students.enumerated()), id: \.element.id) { index, student in
                            ScoreInputRow(student: student, examId: exam.id, subject: selectedSubject,
                                          initialScore: scoreTexts[student.id] ?? "")
                                .staggeredAppear(index: index, step: 0.03)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                    .id(selectedSubject)
                    .transition(.opacity)
                }
            }
            .animation(AppTheme.Motion.smooth, value: selectedSubject)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(exam.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showingRanking = true } label: { Label("总分排名", systemImage: "list.number") }
                    Button { printScores() } label: { Label("打印成绩单", systemImage: "printer") }
                        .disabled(records.isEmpty)
                } label: { Image(systemName: "ellipsis.circle") }
                .disabled(viewModel.students.isEmpty)
            }
        }
        .sheet(isPresented: $showingRanking) {
            NavigationStack { RankingView(exam: exam) }
        }
        .onAppear { replayChart() }
    }

    // 重新播放图表生长动画
    private func replayChart() {
        reveal = 0
        selectedBar = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(AppTheme.Motion.chart) { reveal = 1 }
        }
    }

    private func printScores() {
        let students = viewModel.students.map { student -> (name: String, number: String, scores: [Double?]) in
            let scores = exam.subjects.map { subject -> Double? in
                viewModel.scores(for: exam.id, subject: subject)
                    .first(where: { $0.studentId == student.id })?.score
            }
            return (student.name, student.studentNumber, scores)
        }
        PrintService.shared.printScores(examName: exam.name, className: viewModel.classInfo.className,
                                       subjects: exam.subjects, students: students)
    }

    // 分数显示：整数值不带小数点
    private static func scoreText(_ score: Double) -> String {
        score.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(score)) : String(score)
    }

    // MARK: - 核心统计（平均分主卡 + 及格率/优秀率）
    private func heroStats(_ stats: AppViewModel.SubjectStats) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // 平均分主卡
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "sum")
                        .font(.system(size: 12, weight: .semibold))
                    Text("平均分").font(AppTheme.Fonts.caption.weight(.medium))
                }
                .foregroundColor(.white.opacity(0.85))

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(stats.isEmpty ? "—" : String(format: "%.1f", stats.average))
                        .font(.system(size: 40, weight: .heavy).monospacedDigit())
                        .numericRoll()
                    if let delta = trendDelta, !stats.isEmpty {
                        TrendDeltaBadge(delta: delta)
                    }
                }
                .foregroundColor(.white)

                Text("\(stats.count)/\(viewModel.students.count) 人已录入")
                    .font(AppTheme.Fonts.caption2)
                    .foregroundColor(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.Colors.accentGradient)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
            .rdShadow(AppTheme.Shadows.accent)

            // 及格率 / 优秀率
            VStack(spacing: 10) {
                rateSubCard(title: "及格率", value: stats.passRate, systemImage: "checkmark.seal",
                            color: AppTheme.Colors.green, hasData: !stats.isEmpty)
                rateSubCard(title: "优秀率", value: stats.excellentRate, systemImage: "star",
                            color: AppTheme.Colors.yellow, hasData: !stats.isEmpty)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 132)
    }

    private func rateSubCard(title: String, value: Double, systemImage: String, color: Color, hasData: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
                Text(title).font(AppTheme.Fonts.caption)
            }
            .foregroundColor(color)
            Text(hasData ? String(format: "%.0f%%", value) : "—")
                .font(.system(size: 22, weight: .heavy).monospacedDigit())
                .foregroundColor(AppTheme.Colors.primaryText)
                .numericRoll()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous)
            .stroke(AppTheme.Colors.separator, lineWidth: 0.5))
        .rdShadow(AppTheme.Shadows.sm)
    }

    // MARK: - 次级指标条（最高/最低/中位/标准差）
    private func metricStrip(_ stats: AppViewModel.SubjectStats) -> some View {
        HStack(spacing: 8) {
            metricCell(title: "最高", value: String(format: "%.0f", stats.highest), color: AppTheme.Colors.green)
            metricCell(title: "最低", value: String(format: "%.0f", stats.lowest), color: AppTheme.Colors.red)
            metricCell(title: "中位", value: String(format: "%.0f", stats.median), color: AppTheme.Colors.blue)
            metricCell(title: "标准差", value: String(format: "%.1f", stats.stdDev), color: AppTheme.Colors.purple)
        }
    }

    private func metricCell(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold).monospacedDigit())
                .foregroundColor(color)
                .numericRoll()
            Text(title)
                .font(AppTheme.Fonts.caption2)
                .foregroundColor(AppTheme.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous)
            .stroke(AppTheme.Colors.separator, lineWidth: 0.5))
    }

    // MARK: - 分数分布卡片
    private func distributionCard(_ records: [ScoreRecord]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("分数分布").font(AppTheme.Fonts.title3).foregroundColor(AppTheme.Colors.primaryText)
                Spacer()
                Text("\(records.count) 人")
                    .font(AppTheme.Fonts.caption).foregroundColor(AppTheme.Colors.tertiaryText)
            }

            Chart(distributionBars(records)) { bar in
                BarMark(x: .value("分数段", bar.label), y: .value("人数", bar.animatedValue))
                    .cornerRadius(6)
                    .foregroundStyle(barColor(bar))
                    .annotation(position: .top) {
                        if bar.count > 0 && reveal > 0.6 {
                            Text("\(bar.count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppTheme.Colors.primaryText)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
            }
            .frame(height: 158)
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { location in
                            // iOS16 兼容的分类轴点选：再次点同一柱取消选中
                            if let label = proxy.value(atX: location.x, as: String.self) {
                                withAnimation(AppTheme.Motion.quick) {
                                    selectedBar = (selectedBar == label ? nil : label)
                                }
                            }
                        }
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { _ in
                    AxisGridLine().foregroundStyle(Color.clear)
                    AxisTick().foregroundStyle(Color.clear)
                    AxisValueLabel().font(.system(size: 10)).foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
            .chartYAxis(.hidden)
            .padding(.vertical, 8)

            // 选中段明细 / 占比提示
            Group {
                if let selected = selectedBar,
                   let bar = distributionBars(records).first(where: { $0.label == selected }) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill").font(.system(size: 11))
                        Text("\(bar.label)：\(bar.count) 人 · 占 \(Int(bar.ratio * 100))%")
                            .font(AppTheme.Fonts.caption.weight(.medium))
                    }
                    .foregroundColor(AppTheme.Colors.accent)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Text("轻点柱子查看各分数段占比")
                        .font(AppTheme.Fonts.caption2)
                        .foregroundColor(AppTheme.Colors.tertiaryText)
                }
            }
            .frame(height: 18)
            .animation(AppTheme.Motion.quick, value: selectedBar)
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
            .stroke(AppTheme.Colors.separator, lineWidth: 0.5))
        .rdShadow(AppTheme.Shadows.sm)
    }

    private func barColor(_ bar: DistributionBar) -> Color {
        let base: Color
        switch bar.tier {
        case "0-59": base = AppTheme.Colors.red
        case "60-69": base = AppTheme.Colors.orange
        case "70-79": base = AppTheme.Colors.yellow
        case "80-89": base = AppTheme.Colors.blue
        case "90-100": base = AppTheme.Colors.accent
        default: base = Color.gray
        }
        // 选中态：选中饱和，其余降透明；未选中时全部正常
        if let selectedBar, selectedBar != bar.label { return base.opacity(0.3) }
        return base
    }

    // MARK: - 均分趋势卡片
    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("班级均分趋势").font(AppTheme.Fonts.title3).foregroundColor(AppTheme.Colors.primaryText)
                Spacer()
                Text(selectedSubject).font(AppTheme.Fonts.caption).foregroundColor(AppTheme.Colors.tertiaryText)
            }

            Chart(averageTrend) { point in
                AreaMark(x: .value("考试", point.examName), y: .value("均分", point.average))
                    .foregroundStyle(
                        LinearGradient(colors: [AppTheme.Colors.accent.opacity(0.22), AppTheme.Colors.accent.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("考试", point.examName), y: .value("均分", point.average))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("考试", point.examName), y: .value("均分", point.average))
                    .foregroundStyle(.white)
                    .symbolSize(54)
                PointMark(x: .value("考试", point.examName), y: .value("均分", point.average))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .symbolSize(30)
            }
            .frame(height: 158)
            .chartXAxis {
                AxisMarks(position: .bottom) { _ in
                    AxisGridLine().foregroundStyle(Color.clear)
                    AxisTick().foregroundStyle(Color.clear)
                    AxisValueLabel().font(.system(size: 10)).foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(AppTheme.Colors.separator)
                    AxisTick().foregroundStyle(Color.clear)
                    AxisValueLabel().font(.system(size: 10)).foregroundStyle(AppTheme.Colors.tertiaryText)
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .padding(.vertical, 8)
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
            .stroke(AppTheme.Colors.separator, lineWidth: 0.5))
        .rdShadow(AppTheme.Shadows.sm)
    }
}

// MARK: - 涨跌徽标
struct TrendDeltaBadge: View {
    let delta: Double
    private var isUp: Bool { delta >= 0 }
    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .heavy))
            Text(String(format: "%.1f", abs(delta)))
                .font(.system(size: 11, weight: .bold).monospacedDigit())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.22))
        .clipShape(Capsule())
    }
}

// MARK: - 图表数据模型
struct ScoreBucket {
    var range: String
    var label: String
    var min: Double
    var max: Double
    var count: Int = 0
}

struct DistributionBar: Identifiable {
    // 稳定身份：生长动画逐帧重算时不能用随机 UUID，否则柱子会闪烁
    var id: String { tier }
    var label: String
    var tier: String
    var count: Int
    var animatedValue: Double
    var ratio: Double
}

struct TrendPoint: Identifiable {
    let id = UUID()
    var examName: String
    var date: Date
    var average: Double
}

// MARK: - 单个学生成绩输入行
struct ScoreInputRow: View {
    @EnvironmentObject var viewModel: AppViewModel
    let student: Student
    let examId: UUID
    let subject: String
    let initialScore: String

    @State private var text: String
    @State private var isEditing = false

    init(student: Student, examId: UUID, subject: String, initialScore: String) {
        self.student = student
        self.examId = examId
        self.subject = subject
        self.initialScore = initialScore
        _text = State(initialValue: initialScore)
    }

    private var scoreValue: Double? {
        guard let v = Double(text), !text.isEmpty else { return nil }
        return v
    }

    private var scoreColor: Color {
        guard let v = scoreValue else { return AppTheme.Colors.tertiaryText }
        if v >= 90 { return AppTheme.Colors.green }
        if v >= 60 { return AppTheme.Colors.accent }
        return AppTheme.Colors.red
    }

    var body: some View {
        HStack(spacing: 12) {
            StudentAvatar(name: student.name, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(student.name).font(AppTheme.Fonts.body.weight(.medium)).foregroundColor(AppTheme.Colors.primaryText)
                Text("#\(student.studentNumber)").font(AppTheme.Fonts.caption2).foregroundColor(AppTheme.Colors.tertiaryText)
            }
            Spacer()
            TextField("分数", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isEditing ? AppTheme.Colors.accentSoft : AppTheme.Colors.subtleBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous)
                        .stroke(isEditing ? AppTheme.Colors.accent.opacity(0.5) : .clear, lineWidth: 1.5)
                )
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundColor(scoreColor)
                .animation(AppTheme.Motion.quick, value: isEditing)
                .onTapGesture { isEditing = true }
                .onChange(of: text) { newValue in
                    let cleaned = newValue.filter { "0123456789.".contains($0) }
                    if cleaned != newValue { text = cleaned }
                    if cleaned.isEmpty {
                        viewModel.removeScore(studentId: student.id, examId: examId, subject: subject)
                    } else {
                        saveIfValid(cleaned)
                    }
                }
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous)
            .stroke(AppTheme.Colors.separator, lineWidth: 0.5))
    }

    private func saveIfValid(_ value: String) {
        guard let score = Double(value), (0...1000).contains(score) else { return }
        viewModel.setScore(studentId: student.id, examId: examId, subject: subject, score: score)
    }
}

// MARK: - 总分排名（领奖台 + 完整榜单，带弹入动效）
struct RankingView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let exam: Exam

    @State private var podiumReveal = false

    var body: some View {
        let ranking = viewModel.totalRanking(for: exam.id)
        Group {
            if ranking.isEmpty {
                EmptyStateView(systemImage: "list.number", title: "暂无成绩", message: "录入成绩后才能查看排名")
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        if ranking.count >= 3 {
                            podiumView(of: Array(ranking.prefix(3)))
                                .padding(.top, 20)
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(ranking.enumerated()), id: \.element.student.id) { index, item in
                                rankRow(index: index, item: item)
                                if index < ranking.count - 1 {
                                    Divider().background(AppTheme.Colors.separator).padding(.leading, 64)
                                }
                            }
                        }
                        .background(AppTheme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                            .stroke(AppTheme.Colors.separator, lineWidth: 0.5))
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
                .background(AppTheme.Colors.background)
            }
        }
        .navigationTitle("总分排名")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
        }
        .onAppear {
            podiumReveal = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(AppTheme.Motion.bouncy) { podiumReveal = true }
            }
        }
    }

    private func rankRow(index: Int, item: (student: Student, total: Double)) -> some View {
        HStack(spacing: 12) {
            ZStack {
                if index < 3 {
                    Circle().fill(podiumColor(index: index)).frame(width: 32, height: 32)
                    Text("\(index + 1)").font(.system(size: 14, weight: .heavy)).foregroundColor(.white)
                } else {
                    Text("\(index + 1)").font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.Colors.tertiaryText).frame(width: 32)
                }
            }
            StudentAvatar(name: item.student.name, size: 36)
            Text(item.student.name).font(AppTheme.Fonts.body.weight(.medium)).foregroundColor(AppTheme.Colors.primaryText)
            Spacer()
            Text(String(format: "%.0f", item.total))
                .font(.system(size: 17, weight: .heavy).monospacedDigit())
                .foregroundColor(AppTheme.Colors.accent)
            Text("分").font(AppTheme.Fonts.caption).foregroundColor(AppTheme.Colors.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .staggeredAppear(index: index, step: 0.035)
    }

    private func podiumColor(index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.95, green: 0.75, blue: 0.15)
        case 1: return Color(red: 0.65, green: 0.65, blue: 0.67)
        case 2: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return .gray
        }
    }

    private func podiumView(of top3: [(student: Student, total: Double)]) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            podiumColumn(rank: 2, student: top3[1].student, total: top3[1].total, height: 80, delay: 0.15)
            podiumColumn(rank: 1, student: top3[0].student, total: top3[0].total, height: 110, delay: 0.0)
            podiumColumn(rank: 3, student: top3[2].student, total: top3[2].total, height: 60, delay: 0.30)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    private func podiumColumn(rank: Int, student: Student, total: Double, height: CGFloat, delay: Double) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(podiumColor(index: rank - 1).opacity(0.2)).frame(width: 52, height: 52)
                StudentAvatar(name: student.name, size: 44)
                Text("\(rank)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(podiumColor(index: rank - 1)))
                    .offset(x: 16, y: -16)
            }
            .scaleEffect(podiumReveal ? 1 : 0.3)
            .opacity(podiumReveal ? 1 : 0)

            Text(student.name)
                .font(AppTheme.Fonts.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.Colors.primaryText)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(String(format: "%.0f 分", total))
                .font(AppTheme.Fonts.caption).foregroundColor(AppTheme.Colors.secondaryText)
            Rectangle()
                .fill(podiumColor(index: rank - 1).opacity(0.3))
                .frame(height: podiumReveal ? height : 0)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .animation(AppTheme.Motion.bouncy.delay(delay), value: podiumReveal)
    }
}
