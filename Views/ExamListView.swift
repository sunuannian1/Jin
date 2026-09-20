import SwiftUI
import UniformTypeIdentifiers

// 成绩管理 — 高级排版版
struct ExamListView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingAdd = false
    @State private var showingImport = false
    @State private var showingSemesterPanel = false
    @State private var typeFilter: Exam.ExamType?

    private var sortedExams: [Exam] {
        viewModel.exams.sorted { $0.date > $1.date }
    }

    private var filteredExams: [Exam] {
        var result = sortedExams
        // 按当前学期筛选
        if let currentSemesterId = viewModel.currentSemesterId {
            result = result.filter { $0.semesterId == currentSemesterId || $0.semesterId == nil }
        }
        // 按类型筛选
        if let type = typeFilter {
            result = result.filter { $0.type == type }
        }
        return result
    }

    var body: some View {
        Group {
            if viewModel.exams.isEmpty {
                EmptyStateView(
                    systemImage: "doc.text",
                    title: "还没有考试",
                    message: "点击右上角 + 新建考试，然后录入成绩"
                )
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        // 学期切换 + 统计
                        headerBar

                        // 类型筛选
                        typeFilterBar

                        // 考试卡片列表
                        if filteredExams.isEmpty {
                            Text("当前学期暂无考试")
                                .font(AppTheme.Fonts.footnote)
                                .foregroundColor(AppTheme.Colors.tertiaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(Array(filteredExams.enumerated()), id: \.element.id) { index, exam in
                                NavigationLink {
                                    ScoreDetailView(exam: exam)
                                } label: {
                                    ExamCard(exam: exam)
                                }
                                .buttonStyle(PressableButtonStyle())
                                .staggeredAppear(index: index)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation(AppTheme.Motion.smooth) {
                                            viewModel.deleteExam(exam)
                                        }
                                    } label: {
                                        Label("删除考试", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                    .animation(AppTheme.Motion.smooth, value: typeFilter)
                    .animation(AppTheme.Motion.smooth, value: viewModel.currentSemesterId)
                }
                .background(AppTheme.Colors.background)
            }
        }
        .navigationTitle("成绩管理")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.Colors.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("新建考试", systemImage: "plus")
                    }
                    Button {
                        showingImport = true
                    } label: {
                        Label("导入成绩 (CSV)", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                ExamFormView()
            }
        }
        .sheet(isPresented: $showingImport) {
            NavigationStack {
                ScoreCSVImportView()
            }
        }
        .sheet(isPresented: $showingSemesterPanel) {
            NavigationStack {
                SemesterManagerView()
            }
        }
    }

    // 顶部学期切换 + 统计
    private var headerBar: some View {
        HStack(spacing: 12) {
            // 学期切换按钮
            Button {
                showingSemesterPanel = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                    Text(viewModel.currentSemester?.shortName ?? "选择学期")
                        .font(AppTheme.Fonts.caption.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(AppTheme.Colors.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(AppTheme.Colors.separator, lineWidth: 0.5)
                )
                .rdShadow(AppTheme.Shadows.sm)
            }
            .buttonStyle(.plain)

            Spacer()

            // 统计
            HStack(spacing: 16) {
                statMini(value: "\(filteredExams.count)", label: "考试")
                statMini(value: "\(viewModel.scoreRecords.filter { record in filteredExams.contains(where: { exam in exam.id == record.examId }) }.count)", label: "成绩")
            }
        }
        .padding(.top, 12)
    }

    private func statMini(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundColor(AppTheme.Colors.accent)
            Text(label)
                .font(AppTheme.Fonts.caption2)
                .foregroundColor(AppTheme.Colors.tertiaryText)
        }
    }

    // 类型筛选
    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "全部", isActive: typeFilter == nil) {
                    typeFilter = nil
                }
                ForEach(Exam.ExamType.allCases, id: \.self) { type in
                    FilterChip(title: type.rawValue, isActive: typeFilter == type) {
                        typeFilter = type
                    }
                }
            }
        }
    }
}

// 考试卡片
struct ExamCard: View {
    let exam: Exam

    var body: some View {
        HStack(spacing: 14) {
            // 类型图标
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ExamTypeIcon.color(for: exam.type).opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: ExamTypeIcon.symbol(for: exam.type))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(ExamTypeIcon.color(for: exam.type))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(exam.name)
                    .font(AppTheme.Fonts.headline)
                    .foregroundColor(AppTheme.Colors.primaryText)
                HStack(spacing: 8) {
                    PillTag(title: exam.type.rawValue, color: ExamTypeIcon.color(for: exam.type))
                    Text("\(exam.subjects.count) 科")
                        .font(AppTheme.Fonts.caption2)
                        .foregroundColor(AppTheme.Colors.tertiaryText)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(exam.date.formatted(.dateTime.month().day()))
                    .font(AppTheme.Fonts.caption.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.secondaryText)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.tertiaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                .stroke(AppTheme.Colors.separator, lineWidth: 0.5)
        )
        .rdShadow(AppTheme.Shadows.sm)
    }
}

// 类型图标工具
enum ExamTypeIcon {
    static func symbol(for type: Exam.ExamType) -> String {
        switch type {
        case .unitTest: return "square.grid.2x2"
        case .monthly: return "calendar"
        case .midterm: return "book.closed"
        case .final: return "graduationcap"
        }
    }
    static func color(for type: Exam.ExamType) -> Color {
        switch type {
        case .unitTest: return .blue
        case .monthly: return AppTheme.Colors.accent
        case .midterm: return .purple
        case .final: return .green
        }
    }
}

// 新建考试表单
struct ExamFormView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: Exam.ExamType = .monthly
    @State private var date = Date()
    @State private var selectedSubjects: Set<String> = []

    private var allSubjects: [String] {
        viewModel.classInfo.subjects
    }

    var body: some View {
        Form {
            Section("考试信息") {
                TextField("考试名称", text: $name, prompt: Text("如：第一次月考"))
                Picker("类型", selection: $type) {
                    ForEach(Exam.ExamType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                DatePicker("日期", selection: $date, displayedComponents: .date)
            }
            Section("选择科目") {
                if allSubjects.isEmpty {
                    Text("请先在「班级设置」中添加科目")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(allSubjects, id: \.self) { subject in
                        Toggle(subject, isOn: Binding(
                            get: { selectedSubjects.contains(subject) },
                            set: { isOn in
                                if isOn {
                                    selectedSubjects.insert(subject)
                                } else {
                                    selectedSubjects.remove(subject)
                                }
                            }
                        ))
                    }
                }
            }
        }
        .navigationTitle("新建考试")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("创建") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !selectedSubjects.isEmpty else { return }
                    viewModel.addExam(name: trimmed, type: type, subjects: Array(selectedSubjects))
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedSubjects.isEmpty)
            }
        }
    }
}

// 学期管理页面
struct SemesterManagerView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdd = false

    var body: some View {
        Group {
            if viewModel.semesters.isEmpty {
                EmptyStateView(
                    systemImage: "calendar",
                    title: "还没有学期",
                    message: "点击右上角 + 添加学期"
                )
            } else {
                List {
                    ForEach(viewModel.semesters.sorted { $0.startDate > $1.startDate }) { semester in
                        Button {
                            viewModel.setCurrentSemester(semester)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(semester.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("\(semester.startDate.formatted(.dateTime.year().month())) - \(semester.endDate.formatted(.dateTime.year().month()))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if viewModel.currentSemesterId == semester.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteSemester(semester)
                            } label: {
                                Label("删除学期", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("选择学期")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { SemesterFormView() }
        }
    }
}

// MARK: - 新建学期（名称 + 起止日期，对齐网页新建学期弹窗）
struct SemesterFormView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var startDate: Date
    @State private var endDate: Date

    init() {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let fallStart = calendar.date(from: DateComponents(year: year, month: 9, day: 1)) ?? Date()
        let winterEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 31)) ?? Date()
        _startDate = State(initialValue: fallStart)
        _endDate = State(initialValue: winterEnd)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        Form {
            Section("学期名称") {
                TextField("如：2025-2026学年第一学期", text: $name)
            }
            Section("学期时间") {
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
            }
            Section {
                Button("使用第一学期（9月-1月）") { applyPreset(first: true) }
                Button("使用第二学期（2月-7月）") { applyPreset(first: false) }
            } header: {
                Text("快速填充")
            } footer: {
                Text("新建后将自动切换到该学期，成绩数据按学期隔离。")
            }
        }
        .navigationTitle("新建学期")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("创建") { save() }
                    .fontWeight(.semibold)
                    .disabled(trimmedName.isEmpty)
            }
        }
    }

    private func applyPreset(first: Bool) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: startDate)
        if first {
            startDate = calendar.date(from: DateComponents(year: year, month: 9, day: 1)) ?? startDate
            endDate = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 31)) ?? endDate
            if name.isEmpty { name = "\(year)-\(year + 1)学年第一学期" }
        } else {
            startDate = calendar.date(from: DateComponents(year: year, month: 2, day: 1)) ?? startDate
            endDate = calendar.date(from: DateComponents(year: year, month: 7, day: 31)) ?? endDate
            if name.isEmpty { name = "\(year - 1)-\(year)学年第二学期" }
        }
    }

    private func save() {
        let semester = Semester(name: trimmedName, shortName: trimmedName,
                                startDate: startDate, endDate: endDate, isCurrent: true)
        viewModel.addSemester(semester)
        viewModel.setCurrentSemester(semester)
        dismiss()
    }
}

// MARK: - CSV 成绩导入视图
struct ScoreCSVImportView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingFilePicker = false
    @State private var parsedRows: [[String]] = []
    @State private var headers: [String] = []
    @State private var selectedExamId: UUID?
    @State private var importResult: (success: Int, failed: Int, notFound: [String])?
    @State private var fileName = ""

    private var sortedExams: [Exam] {
        viewModel.exams.sorted { $0.date > $1.date }
    }

    // 学号列 / 姓名列按表头认，不再假设"前两列固定是学号+姓名"
    // （教师表格常见 序号/学号/考号 混用，位置假设会让整表匹配不到学生）
    private var numberColumnIndex: Int? {
        headers.firstIndex { $0.contains("学号") || $0.contains("考号") || $0.contains("序号") }
    }
    private var nameColumnIndex: Int? {
        headers.firstIndex { $0.contains("姓名") }
    }

    // 非科目表头：总分/排名/座位之类的列，不能被当成科目导进去
    private static let nonSubjectHeaders = ["总分", "合计", "排名", "名次", "座位", "学号", "考号",
                                           "序号", "姓名", "备注", "组", "宿舍", "均分", "平均分", "班级"]

    private var subjectColumnIndices: [Int] {
        let idIdx = numberColumnIndex
        let nameIdx = nameColumnIndex
        return headers.indices.filter { i in
            let header = headers[i]
            if header.isEmpty { return false }
            if i == idIdx || i == nameIdx { return false }
            return !Self.nonSubjectHeaders.contains { header.contains($0) }
        }
    }

    private var subjectColumns: [String] {
        subjectColumnIndices.map { headers[$0] }
    }

    var body: some View {
        Group {
            if parsedRows.isEmpty {
                initialView
            } else if importResult == nil {
                previewView
            } else {
                importResultView
            }
        }
        .navigationTitle("导入成绩")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.commaSeparatedText, .text]) { result in
            switch result {
            case .success(let url):
                parseCSV(url: url)
            case .failure:
                break
            }
        }
    }
    @ViewBuilder
    private var initialView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.Colors.accent.opacity(0.1))
                    .frame(width: 96, height: 96)
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accent)
            }
            VStack(spacing: 8) {
                Text("导入 CSV 成绩")
                    .font(AppTheme.Fonts.title2)
                    .foregroundColor(AppTheme.Colors.primaryText)
                Text("CSV 格式：学号,姓名,科目1,科目2,...\n第一行为表头")
                    .font(AppTheme.Fonts.footnote)
                    .foregroundColor(AppTheme.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            Button {
                showingFilePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("选择 CSV 文件")
                        .font(AppTheme.Fonts.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.Colors.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous))
                .rdShadow(AppTheme.Shadows.accent)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            Spacer()
        }
        .background(AppTheme.Colors.background)
    }

    @ViewBuilder
    private var previewView: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(AppTheme.Colors.accent)
                    Text(fileName)
                        .font(AppTheme.Fonts.subheadline.weight(.medium))
                        .foregroundColor(AppTheme.Colors.primaryText)
                    Spacer()
                    Text("\(parsedRows.count) 行")
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(AppTheme.Colors.tertiaryText)
                }
                .padding(14)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous))
                VStack(alignment: .leading, spacing: 10) {
                    Text("选择目标考试")
                        .font(AppTheme.Fonts.title3)
                        .foregroundColor(AppTheme.Colors.primaryText)
                    if sortedExams.isEmpty {
                        Text("请先创建考试")
                            .font(AppTheme.Fonts.footnote)
                            .foregroundColor(AppTheme.Colors.tertiaryText)
                    } else {
                        ForEach(sortedExams) { exam in
                            ExamSelectRow(exam: exam, isSelected: selectedExamId == exam.id) {
                                selectedExamId = exam.id
                            }
                        }
                    }
                }
                if !subjectColumns.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("识别到 \(subjectColumns.count) 个科目列")
                            .font(AppTheme.Fonts.caption.weight(.semibold))
                            .foregroundColor(AppTheme.Colors.tertiaryText)
                        HStack(spacing: 6) {
                            ForEach(subjectColumns, id: \.self) { subject in
                                Text(subject)
                                    .font(AppTheme.Fonts.caption2)
                                    .foregroundColor(AppTheme.Colors.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.Colors.accentSoft)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("数据预览（前 3 行）")
                        .font(AppTheme.Fonts.caption.weight(.semibold))
                        .foregroundColor(AppTheme.Colors.tertiaryText)
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            ForEach(headers, id: \.self) { header in
                                Text(header)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.secondaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                        }
                        .background(AppTheme.Colors.subtleBackground)
                        ForEach(Array(parsedRows.prefix(3).enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 0) {
                                ForEach(0..<min(row.count, headers.count), id: \.self) { idx in
                                    csvPreviewCell(row: row, idx: idx)
                                }
                            }
                            Divider().background(AppTheme.Colors.separator)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppTheme.Colors.separator, lineWidth: 0.5)
                    )
                }
                Spacer(minLength: 20)
                Button {
                    performImport()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                        Text("确认导入")
                            .font(AppTheme.Fonts.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background {
                        if selectedExamId != nil {
                            AppTheme.Colors.accentGradient
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(selectedExamId == nil)
            }
            .padding(18)
        }
        .background(AppTheme.Colors.background)
    }
struct ExamSelectRow: View {
    let exam: Exam
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.tertiaryText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exam.name)
                        .font(AppTheme.Fonts.body.weight(.medium))
                        .foregroundColor(AppTheme.Colors.primaryText)
                    Text("\(exam.type.rawValue) · \(exam.subjects.count) 科")
                        .font(AppTheme.Fonts.caption2)
                        .foregroundColor(AppTheme.Colors.tertiaryText)
                }
                Spacer()
            }
            .padding(12)
            .background(isSelected ? AppTheme.Colors.accentSoft : AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous)
                    .stroke(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.separator, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private func examSubtitle(for exam: Exam) -> String {
        "\(exam.type.rawValue) · \(exam.subjects.count) 科"
    }

    private func csvPreviewCell(row: [String], idx: Int) -> some View {
        let text = row.indices.contains(idx) ? row[idx] : ""
        return Text(text)
            .font(.system(size: 10))
            .foregroundColor(AppTheme.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    // 解析 CSV
    private func parseCSV(url: URL) {
        guard let data = AppViewModel.readSecuredFile(url) else { return }
        // 统一交给 CSVParser.decodeText：认 UTF-16 BOM、回退 GBK，并剥掉开头 BOM
        let content = CSVParser.decodeText(data)

        fileName = url.lastPathComponent

        let lines = content.components(separatedBy: CharacterSet.newlines).filter { !$0.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty }
        guard !lines.isEmpty else { return }

        // 解析表头
        headers = parseCSVLine(lines[0]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        // 解析数据行
        parsedRows = Array(lines.dropFirst()).map { parseCSVLine($0) }
    }

    // 解析单行 CSV（处理引号）
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current.trimmingCharacters(in: .whitespaces))
        return result
    }

    // 执行导入
    private func performImport() {
        guard let examId = selectedExamId else { return }

        let idIdx = numberColumnIndex ?? 0
        var records: [(studentNumber: String, subject: String, score: Double)] = []
        let columnIndices = subjectColumnIndices

        for row in parsedRows {
            guard idIdx < row.count else { continue }
            let studentNumber = row[idIdx]
            guard !studentNumber.isEmpty else { continue }
            for i in columnIndices {
                guard i < row.count else { continue }
                if let score = Double(row[i]) {
                    records.append((studentNumber, headers[i], score))
                }
            }
        }

        importResult = viewModel.importScores(examId: examId, records: records)
    }

    // 导入结果视图
    private var importResultView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(.green)
            }

            VStack(spacing: 8) {
                Text("导入完成")
                    .font(AppTheme.Fonts.title)
                    .foregroundColor(AppTheme.Colors.primaryText)

                if let result = importResult {
                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("\(result.success)")
                                .font(.system(size: 28, weight: .heavy).monospacedDigit())
                                .foregroundColor(.green)
                            Text("成功")
                                .font(AppTheme.Fonts.caption)
                                .foregroundColor(AppTheme.Colors.tertiaryText)
                        }
                        VStack(spacing: 4) {
                            Text("\(result.failed)")
                                .font(.system(size: 28, weight: .heavy).monospacedDigit())
                                .foregroundColor(.red)
                            Text("失败")
                                .font(AppTheme.Fonts.caption)
                                .foregroundColor(AppTheme.Colors.tertiaryText)
                        }
                    }

                    if !result.notFound.isEmpty {
                        VStack(spacing: 6) {
                            Text("未找到的学号：")
                                .font(AppTheme.Fonts.caption.weight(.semibold))
                                .foregroundColor(AppTheme.Colors.secondaryText)
                            Text(result.notFound.joined(separator: "、"))
                                .font(AppTheme.Fonts.caption2)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                    }
                }
            }

            Button {
                dismiss()
            } label: {
                Text("完成")
                    .font(AppTheme.Fonts.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous))
                    .rdShadow(AppTheme.Shadows.accent)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)

            Spacer()
        }
        .background(AppTheme.Colors.background)
    }
}
