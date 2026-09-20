import SwiftUI
import UIKit
import Charts

// 学生名册 — 高级排版版
struct StudentListView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.openURL) private var openURL
    @State private var searchText = ""
    @State private var showingAdd = false
    @State private var showImporter = false
    @State private var importMessage = ""
    @State private var showImportAlert = false
    @State private var seatFilter: Int? = nil  // nil = 全部，0 = 未排座，1... = 第N排
    @State private var sortOption: SortOption = .bySeat
    @State private var showingSortMenu = false

    enum SortOption: String, CaseIterable {
        case bySeat = "按座位"
        case byName = "按姓名"
        case byNumber = "按学号"
        case byGroup = "按小组"
    }

    // 最大排数（用于筛选标签）
    private var maxSeatRow: Int {
        let maxRow = viewModel.students.map { $0.seatRow }.max() ?? 0
        return max(maxRow, 6)
    }

    private var filteredStudents: [Student] {
        var result = viewModel.students

        // 按排筛选
        if let seatFilter = seatFilter {
            if seatFilter == 0 {
                result = result.filter { $0.seatRow == 0 }
            } else {
                result = result.filter { $0.seatRow == seatFilter }
            }
        }

        // 排序
        switch sortOption {
        case .bySeat:
            result.sort { s1, s2 in
                if s1.seatRow != s2.seatRow { return s1.seatRow < s2.seatRow }
                if s1.seatCol != s2.seatCol { return s1.seatCol < s2.seatCol }
                return s1.name.localizedStandardCompare(s2.name) == .orderedAscending
            }
        case .byName:
            result.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .byNumber:
            result.sort { s1, s2 in
                if s1.studentNumber.isEmpty != s2.studentNumber.isEmpty {
                    return !s1.studentNumber.isEmpty
                }
                return s1.studentNumber.localizedStandardCompare(s2.studentNumber) == .orderedAscending
            }
        case .byGroup:
            result.sort { s1, s2 in
                if s1.groupNumber != s2.groupNumber { return s1.groupNumber < s2.groupNumber }
                return s1.name.localizedStandardCompare(s2.name) == .orderedAscending
            }
        }

        // 搜索
        guard !searchText.isEmpty else { return result }
        return result.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.studentNumber.localizedCaseInsensitiveContains(searchText)
                || $0.phone.contains(searchText)
                || $0.fatherPhone.contains(searchText)
        }
    }

    var body: some View {
        Group {
            if filteredStudents.isEmpty {
                EmptyStateView(
                    systemImage: "person.2",
                    title: searchText.isEmpty ? "还没有学生" : "未找到学生",
                    message: searchText.isEmpty ? "点击右上角 + 添加学生" : "换个关键词试试"
                )
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        // 统计
                        HStack {
                            Text("\(filteredStudents.count) 位学生")
                                .font(AppTheme.Fonts.caption.weight(.semibold))
                                .foregroundColor(AppTheme.Colors.tertiaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)

                        // 学生卡片列表
                        ForEach(Array(filteredStudents.enumerated()), id: \.element.id) { index, student in
                            NavigationLink {
                                StudentDetailView(studentId: student.id)
                            } label: {
                                StudentCard(student: student)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .staggeredAppear(index: index, step: 0.035)
                            .contextMenu {
                                if !student.phone.isEmpty, let url = telURL(student.phone) {
                                    Button {
                                        openURL(url)
                                    } label: {
                                        Label("拨打学生电话 \(student.phone)", systemImage: "phone.fill")
                                    }
                                }
                                if let gp = student.guardians.first(where: { !$0.phone.isEmpty }), let url = telURL(gp.phone) {
                                    Button {
                                        openURL(url)
                                    } label: {
                                        Label("拨打\(gp.relation)电话 \(gp.phone)", systemImage: "phone.arrow.right.left")
                                    }
                                }
                                Button(role: .destructive) {
                                    withAnimation(AppTheme.Motion.smooth) {
                                        viewModel.deleteStudent(student)
                                    }
                                } label: {
                                    Label("删除学生", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                    .animation(AppTheme.Motion.snappy, value: searchText)
                    .animation(AppTheme.Motion.smooth, value: seatFilter)
                    .animation(AppTheme.Motion.smooth, value: sortOption)
                }
                .background(AppTheme.Colors.background)
            }
        }
        .navigationTitle("学生名册")
        .searchable(text: $searchText, prompt: "搜索姓名/学号/电话")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            if sortOption == option {
                                Label(option.rawValue, systemImage: "checkmark")
                            } else {
                                Text(option.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                Button {
                    showImporter = true
                } label: {
                    Image(systemName: "tray.and.arrow.down")
                }
                Button {
                    printRoster()
                } label: {
                    Image(systemName: "printer")
                }
                .disabled(filteredStudents.isEmpty)
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                StudentFormView(mode: .add)
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data, .plainText, .commaSeparatedText]) { result in
            switch result {
            case .success(let url):
                let count = viewModel.importStudents(from: url)
                importMessage = count > 0 ? "成功导入 \(count) 名学生" : "未识别到有效数据，请确认是 UTF-8 的学生表 CSV"
                showImportAlert = true
            case .failure:
                importMessage = "未能读取文件"; showImportAlert = true
            }
        }
        .alert("导入学生表", isPresented: $showImportAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(importMessage)
        }
        // 按排筛选标签（放在搜索栏下方）
        .safeAreaInset(edge: .top) {
            if !viewModel.students.isEmpty {
                seatFilterBar
            }
        }
    }

    // 按排筛选横向滚动标签
    private var seatFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "全部", isActive: seatFilter == nil) {
                    seatFilter = nil
                }
                FilterChip(title: "未排座", isActive: seatFilter == 0) {
                    seatFilter = 0
                }
                ForEach(1...maxSeatRow, id: \.self) { row in
                    FilterChip(title: "第\(row)排", isActive: seatFilter == row) {
                        seatFilter = row
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .background(AppTheme.Colors.background.opacity(0.95))
        .background(.ultraThinMaterial)
    }

    private func telURL(_ phone: String) -> URL? {
        let digits = phone.filter { "0123456789+".contains($0) }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://" + digits)
    }

    // 真实打印：系统打印面板输出名册
    private func printRoster() {
        var rows = ""
        for student in filteredStudents {
            let seat = student.seatRow > 0 ? "第\(student.seatRow)排第\(student.seatCol)座" : "未分配"
            let phone = student.phone.isEmpty ? "—" : student.phone
            let parent = student.guardians.first(where: { !$0.phone.isEmpty })?.phone ?? "—"
            rows += "<tr><td>\(student.studentNumber)</td><td>\(student.name)</td><td>\(student.gender.rawValue)</td>"
            rows += "<td>\(phone)</td><td>\(parent)</td><td>第\(student.groupNumber)组</td><td>\(seat)</td></tr>"
        }
        let html = """
        <html><head><meta charset="utf-8"><style>
        body { font-family: -apple-system; font-size: 12px; }
        h2 { text-align: center; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #999; padding: 6px; text-align: center; }
        th { background-color: #eee; }
        </style></head><body>
        <h2>\(viewModel.classInfo.className) 学生名册</h2>
        <p style="text-align:center">共 \(filteredStudents.count) 人 · 打印日期 \(Date().formatted(.dateTime.year().month().day()))</p>
        <table>
        <tr><th>学号</th><th>姓名</th><th>性别</th><th>学生电话</th><th>家长电话</th><th>小组</th><th>座位</th></tr>
        \(rows)
        </table></body></html>
        """
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        formatter.perPageContentInsets = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
        let controller = UIPrintInteractionController.shared
        controller.printFormatter = formatter
        controller.present(animated: true)
    }
}

// 学生卡片（替代原来的 List Row）
struct StudentCard: View {
    let student: Student

    var body: some View {
        HStack(spacing: 14) {
            StudentAvatar(name: student.name, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(student.name)
                        .font(AppTheme.Fonts.headline)
                        .foregroundColor(AppTheme.Colors.primaryText)
                    Text("#\(student.studentNumber)")
                        .font(AppTheme.Fonts.caption2.weight(.medium))
                        .foregroundColor(AppTheme.Colors.accent)
                }

                HStack(spacing: 10) {
                    // 小组标签
                    HStack(spacing: 3) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 9))
                        Text("第\(student.groupNumber)组")
                            .font(AppTheme.Fonts.caption2)
                    }
                    .foregroundColor(AppTheme.Colors.secondaryText)

                    // 座位标签
                    if student.seatRow > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "chair.fill")
                                .font(.system(size: 9))
                            Text("\(student.seatRow)排\(student.seatCol)座")
                                .font(AppTheme.Fonts.caption2)
                        }
                        .foregroundColor(AppTheme.Colors.secondaryText)
                    }

                    // 电话图标
                    if !student.phone.isEmpty || !student.guardians.allSatisfy({ $0.phone.isEmpty }) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.Colors.tertiaryText)
        }
        .padding(14)
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

// 学生详情（编辑后实时刷新）
struct StudentDetailView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let studentId: UUID
    @State private var editing = false
    @State private var noteDraft: String = ""
    @State private var noteLoaded = false

    private var student: Student? { viewModel.student(id: studentId) }

    var body: some View {
        Group {
            if let student = student {
                detailBody(student)
            } else {
                EmptyStateView(systemImage: "person.slash", title: "学生不存在", message: "该学生可能已被删除")
            }
        }
        .navigationTitle(student?.name ?? "学生详情")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.Colors.background)
        .sheet(isPresented: $editing) {
            if let student = student {
                NavigationStack {
                    StudentFormView(mode: .edit(student))
                }
            }
        }
    }

    @ViewBuilder
    private func detailBody(_ student: Student) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部大头像卡
                Card(padding: 20) {
                    VStack(spacing: 12) {
                        StudentAvatar(name: student.name, size: 72)
                        Text(student.name)
                            .font(AppTheme.Fonts.title)
                            .foregroundColor(AppTheme.Colors.primaryText)
                            .tracking(-0.5)
                        HStack(spacing: 12) {
                            PillTag(title: student.gender.rawValue, color: student.gender == .male ? .blue : .pink)
                            PillTag(title: "第\(student.groupNumber)组", color: AppTheme.Colors.accent)
                            if !student.studentNumber.isEmpty {
                                PillTag(title: "#\(student.studentNumber)", color: .gray)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)

                // 基本信息
                detailSection(title: "基本信息", systemImage: "person.text.rectangle") {
                    infoRow(icon: "person.2", label: "民族", value: student.ethnicity.isEmpty ? "—" : student.ethnicity)
                    infoRow(icon: "birthday.cake", label: "出生年月", value: student.birthDate.isEmpty ? "—" : student.birthDate)
                    infoRow(icon: "number", label: "身份证号", value: student.idCardNumber.isEmpty ? "—" : student.idCardNumber)
                }

                // 家长信息
                detailSection(title: "家长信息", systemImage: "person.2.fill") {
                    if student.guardians.isEmpty {
                        infoRow(icon: "person.fill", label: "监护人", value: "未填写")
                    }
                    ForEach(student.guardians) { g in
                        if !g.name.isEmpty {
                            infoRow(icon: "person.fill", label: g.relation.isEmpty ? "监护人" : g.relation, value: g.name)
                        }
                        if !g.phone.isEmpty {
                            contactRow(icon: "phone.fill", label: "\(g.relation.isEmpty ? "监护人" : g.relation)电话", value: g.phone, color: .blue) {
                                if let url = telURL(g.phone) { openURL(url) }
                            }
                        }
                    }
                }

                // 联系方式
                detailSection(title: "联系方式", systemImage: "phone.fill") {
                    if !student.phone.isEmpty {
                        contactRow(icon: "phone.fill", label: "学生电话", value: student.phone, color: .green) {
                            if let url = telURL(student.phone) { openURL(url) }
                        }
                    }
                    if !student.address.isEmpty {
                        infoRow(icon: "location.fill", label: "家庭住址", value: student.address)
                    }
                    if student.phone.isEmpty && student.address.isEmpty {
                        Text("暂无联系方式")
                            .font(AppTheme.Fonts.footnote)
                            .foregroundColor(AppTheme.Colors.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    }
                }

                // 座位与宿舍
                detailSection(title: "座位与宿舍", systemImage: "chair.fill") {
                    infoRow(icon: "chair.fill", label: "座位",
                            value: student.seatRow > 0 ? "第\(student.seatRow)排第\(student.seatCol)座" : "未分配")
                    infoRow(icon: "bed.double.fill", label: "宿舍",
                            value: student.dormitory.isEmpty ? "—" : student.dormitory)
                }

                // 成绩趋势 + 历次考试记录（对齐网页学生详情成绩模块）
                StudentScoreSection(studentId: student.id)
                    .padding(.horizontal, 18)

                // 私密备注（可直接编辑保存）
                noteSection(student: student)

                // 操作按钮
                VStack(spacing: 10) {
                    PrimaryButton(title: "编辑资料", systemImage: "pencil") {
                        editing = true
                    }
                    Button(role: .destructive) {
                        viewModel.deleteStudent(student)
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                            Text("删除学生")
                                .font(AppTheme.Fonts.headline)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.medium)
                        .background(.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
        }
        .background(AppTheme.Colors.background)
    }

    private func noteSection(student: Student) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accent)
                Text("私密备注")
                    .font(AppTheme.Fonts.title3)
                    .foregroundColor(AppTheme.Colors.primaryText)
                Spacer()
            }
            .padding(.horizontal, 22)

            Card(padding: 12) {
                VStack(spacing: 10) {
                    TextField("记录仅自己可见的信息，如性格、家庭情况、谈心记录…",
                              text: $noteDraft, axis: .vertical)
                        .font(AppTheme.Fonts.body)
                        .foregroundColor(AppTheme.Colors.primaryText)
                        .lineLimit(3...8)
                        .padding(10)
                        .background(AppTheme.Colors.subtleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
                        .onAppear {
                            if !noteLoaded { noteDraft = student.notes; noteLoaded = true }
                        }
                    HStack {
                        Spacer()
                        Button {
                            var updated = student
                            updated.notes = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            viewModel.updateStudent(updated)
                        } label: {
                            Label("保存备注", systemImage: "checkmark.circle.fill")
                                .font(AppTheme.Fonts.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(noteDraft == student.notes ? AnyShapeStyle(AppTheme.Colors.tertiaryText) : AnyShapeStyle(AppTheme.Colors.accentGradient))
                                .clipShape(Capsule())
                        }
                        .disabled(noteDraft == student.notes)
                        .buttonStyle(PressableButtonStyle(scale: 0.95))
                    }
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private func detailSection<Content: View>(title: String, systemImage: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accent)
                Text(title)
                    .font(AppTheme.Fonts.title3)
                    .foregroundColor(AppTheme.Colors.primaryText)
                Spacer()
            }
            .padding(.horizontal, 22)

            Card(padding: 4) {
                content()
            }
            .padding(.horizontal, 18)
        }
    }

    private func contactRow(icon: String, label: String, value: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(AppTheme.Fonts.caption2)
                        .foregroundColor(AppTheme.Colors.tertiaryText)
                    Text(value)
                        .font(AppTheme.Fonts.callout.weight(.medium))
                        .foregroundColor(AppTheme.Colors.primaryText)
                }
                Spacer()
                Image(systemName: "phone.fill")
                    .font(.system(size: 12))
                    .foregroundColor(color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.secondaryText)
                .frame(width: 32, height: 32)
                .background(AppTheme.Colors.subtleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTheme.Fonts.caption2)
                    .foregroundColor(AppTheme.Colors.tertiaryText)
                Text(value)
                    .font(AppTheme.Fonts.callout.weight(.medium))
                    .foregroundColor(AppTheme.Colors.primaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func telURL(_ phone: String) -> URL? {
        let digits = phone.filter { "0123456789+".contains($0) }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://" + digits)
    }
}

// 学生添加/编辑表单
struct StudentFormView: View {
    enum Mode {
        case add
        case edit(Student)
    }

    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let mode: Mode

    @State private var name = ""
    @State private var studentNumber = ""
    @State private var gender: Student.Gender = .male
    @State private var phone = ""
    @State private var guardians: [Guardian] = []
    @State private var ethnicity = "汉"
    @State private var birthDate = ""
    @State private var idCardNumber = ""
    @State private var address = ""
    @State private var groupNumber = 1
    @State private var dormitory = ""
    @State private var notes = ""
    @State private var seatRow = 0
    @State private var seatCol = 0

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("姓名", text: $name)
                TextField("学号", text: $studentNumber)
                Picker("性别", selection: $gender) {
                    ForEach(Student.Gender.allCases, id: \.self) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                TextField("民族", text: $ethnicity)
                TextField("出生年月", text: $birthDate)
                TextField("身份证号", text: $idCardNumber)
                Picker("小组", selection: $groupNumber) {
                    ForEach(1...6, id: \.self) { n in
                        Text("第\(n)组").tag(n)
                    }
                }
            }
            Section("家长信息") {
                ForEach(Array(guardians.enumerated()), id: \.element.id) { idx, g in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("称呼（爸爸/妈妈/爷爷…）", text: $guardians[idx].relation)
                                .textContentType(.givenName)
                            Button(role: .destructive) {
                                guardians.remove(at: idx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                        }
                        TextField("姓名", text: $guardians[idx].name)
                        TextField("电话", text: $guardians[idx].phone)
                            .keyboardType(.phonePad)
                    }
                }
                if guardians.count < 3 {
                    Button {
                        guardians.append(Guardian(relation: "", name: "", phone: ""))
                    } label: {
                        Label("添加监护人（最多3人）", systemImage: "plus")
                    }
                }
            }
            Section("联系方式") {
                TextField("学生电话", text: $phone)
                    .keyboardType(.phonePad)
                TextField("家庭住址", text: $address)
            }
            Section("座位") {
                Picker("排", selection: $seatRow) {
                    Text("未排座").tag(0)
                    ForEach(1...10, id: \.self) { Text("第\($0)排").tag($0) }
                }
                if seatRow > 0 {
                    Picker("列", selection: $seatCol) {
                        ForEach(1...8, id: \.self) { Text("第\($0)列").tag($0) }
                    }
                }
            }
            Section("宿舍") {
                TextField("宿舍号", text: $dormitory)
            }
            Section("备注") {
                TextField("备注（选填）", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle(isEditing ? "编辑学生" : "添加学生")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if case .edit(let student) = mode {
                name = student.name
                studentNumber = student.studentNumber
                gender = student.gender
                phone = student.phone
                guardians = student.guardians
                ethnicity = student.ethnicity
                birthDate = student.birthDate
                idCardNumber = student.idCardNumber
                address = student.address
                groupNumber = student.groupNumber
                dormitory = student.dormitory
                notes = student.notes
                seatRow = student.seatRow
                seatCol = student.seatCol
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        switch mode {
        case .add:
            viewModel.addStudent(Student(
                name: trimmed, studentNumber: studentNumber, gender: gender,
                phone: phone, guardians: guardians,
                ethnicity: ethnicity, birthDate: birthDate, idCardNumber: idCardNumber,
                address: address, groupNumber: groupNumber,
                seatRow: seatRow, seatCol: seatCol, dormitory: dormitory, notes: notes
            ))
        case .edit(let student):
            var updated = student
            updated.name = trimmed
            updated.studentNumber = studentNumber
            updated.gender = gender
            updated.phone = phone
            updated.guardians = guardians
            updated.ethnicity = ethnicity
            updated.birthDate = birthDate
            updated.idCardNumber = idCardNumber
            updated.address = address
            updated.groupNumber = groupNumber
            updated.dormitory = dormitory
            updated.notes = notes
            viewModel.updateStudent(updated)
        }
        dismiss()
    }
}

// MARK: - 学生详情：成绩趋势 + 考试记录（纯 SwiftUI/Charts 复刻网页版）
private let stuScoreDateFmt: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy/M/d"; return f
}()

struct StudentScoreSection: View {
    @EnvironmentObject var viewModel: AppViewModel
    let studentId: UUID

    @State private var selectedSubject: String?
    @State private var reveal: Double = 0
    @State private var expandedExams: Set<UUID> = []

    private var subjects: [String] { viewModel.subjectsTaken(by: studentId) }
    private var subject: String {
        if let selected = selectedSubject, subjects.contains(selected) { return selected }
        return subjects.first ?? ""
    }
    private var trend: [StudentTrendPoint] {
        subject.isEmpty ? [] : viewModel.studentTrend(studentId: studentId, subject: subject)
    }
    private var records: [StudentExamRecord] { viewModel.studentExamRecords(studentId: studentId) }
    private var maxFull: Double { trend.map { $0.fullScore }.max() ?? 100 }

    // 带动画因子的图表点（稳定身份，避免生长动画闪烁）
    private var chartPoints: [StuChartPoint] {
        trend.map { StuChartPoint(id: $0.id, examName: $0.examName, value: $0.score * reveal, real: $0.score) }
    }
    // 按考试类型分组，保持 单元测→月考→期中考→期末考 顺序
    private var groupedRecords: [(Exam.ExamType, [StudentExamRecord])] {
        Exam.ExamType.allCases.compactMap { type in
            let items = records.filter { $0.exam.type == type }
            return items.isEmpty ? nil : (type, items)
        }
    }

    var body: some View {
        if subjects.isEmpty {
            emptyCard
        } else {
            VStack(spacing: 16) {
                trendCard
                recordsCard
            }
            .onAppear { replay() }
        }
    }

    private func replay() {
        reveal = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(AppTheme.Motion.chart) { reveal = 1 }
        }
    }

    // 得分率配色（对齐网页：≥90 优 / ≥80 良 / ≥60 及格 / <60 待提升）
    private func ratioColor(_ r: Double) -> Color {
        if r >= 0.9 { return AppTheme.Colors.green }
        if r >= 0.8 { return AppTheme.Colors.blue }
        if r >= 0.6 { return AppTheme.Colors.accent }
        return AppTheme.Colors.red
    }

    private var emptyCard: some View {
        Card(padding: 18) {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(AppTheme.Colors.tertiaryText)
                VStack(alignment: .leading, spacing: 3) {
                    Text("暂无成绩记录").font(AppTheme.Fonts.headline).foregroundColor(AppTheme.Colors.primaryText)
                    Text("录入考试成绩后，这里会生成个人趋势分析").font(AppTheme.Fonts.caption).foregroundColor(AppTheme.Colors.tertiaryText)
                }
                Spacer()
            }
        }
    }

    // MARK: 成绩趋势卡
    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 13, weight: .semibold)).foregroundColor(AppTheme.Colors.accent)
                Text("成绩趋势").font(AppTheme.Fonts.title3).foregroundColor(AppTheme.Colors.primaryText)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(subjects, id: \.self) { subj in
                        let isActive = subj == subject
                        Button {
                            withAnimation(AppTheme.Motion.snappy) { selectedSubject = subj }
                            replay()
                        } label: {
                            Text(subj)
                                .font(AppTheme.Fonts.caption.weight(.semibold))
                                .foregroundColor(isActive ? .white : AppTheme.Colors.secondaryText)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(isActive ? AnyShapeStyle(AppTheme.Colors.accentGradient) : AnyShapeStyle(AppTheme.Colors.subtleBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.92))
                    }
                }
            }

            if trend.isEmpty {
                Text("\(subject) 还没有考试记录")
                    .font(AppTheme.Fonts.footnote).foregroundColor(AppTheme.Colors.tertiaryText)
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                Chart(chartPoints) { p in
                    AreaMark(x: .value("考试", p.examName), y: .value("分数", p.value))
                        .foregroundStyle(LinearGradient(colors: [AppTheme.Colors.accent.opacity(0.20), AppTheme.Colors.accent.opacity(0.02)],
                                                       startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("考试", p.examName), y: .value("分数", p.value))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("考试", p.examName), y: .value("分数", p.value))
                        .foregroundStyle(.white)
                        .symbolSize(50)
                    PointMark(x: .value("考试", p.examName), y: .value("分数", p.value))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .symbolSize(26)
                        .annotation(position: .top) {
                            if reveal > 0.7 {
                                Text(String(format: "%.0f", p.real))
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundColor(AppTheme.Colors.primaryText)
                                    .transition(.opacity)
                            }
                        }
                }
                .frame(height: 168)
                .chartYScale(domain: 0...maxFull)
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisGridLine().foregroundStyle(.clear)
                        AxisTick().foregroundStyle(.clear)
                        AxisValueLabel().font(.system(size: 9)).foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(AppTheme.Colors.separator)
                        AxisTick().foregroundStyle(.clear)
                        AxisValueLabel().font(.system(size: 9)).foregroundStyle(AppTheme.Colors.tertiaryText)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
            .stroke(AppTheme.Colors.separator, lineWidth: 0.5))
        .rdShadow(AppTheme.Shadows.sm)
        .id("stu-trend-\(subject)")
    }

    // MARK: 考试记录卡
    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "list.clipboard").font(.system(size: 13, weight: .semibold)).foregroundColor(AppTheme.Colors.accent)
                Text("考试记录").font(AppTheme.Fonts.title3).foregroundColor(AppTheme.Colors.primaryText)
                Spacer()
                Text("\(records.count) 场").font(AppTheme.Fonts.caption).foregroundColor(AppTheme.Colors.tertiaryText)
            }

            if records.isEmpty {
                Text("还没有考试分数")
                    .font(AppTheme.Fonts.footnote).foregroundColor(AppTheme.Colors.tertiaryText)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ForEach(groupedRecords, id: \.0) { type, items in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(type.rawValue)
                            .font(AppTheme.Fonts.caption.weight(.semibold))
                            .foregroundColor(AppTheme.Colors.tertiaryText).tracking(0.5)
                        ForEach(items) { rec in examRow(rec) }
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
            .stroke(AppTheme.Colors.separator, lineWidth: 0.5))
        .rdShadow(AppTheme.Shadows.sm)
    }

    private func examRow(_ rec: StudentExamRecord) -> some View {
        let isOpen = expandedExams.contains(rec.id)
        return VStack(spacing: 0) {
            Button {
                withAnimation(AppTheme.Motion.smooth) {
                    if isOpen { expandedExams.remove(rec.id) } else { expandedExams.insert(rec.id) }
                }
            } label: {
                HStack(spacing: 10) {
                    Circle().fill(ratioColor(rec.totalRatio)).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rec.exam.name).font(AppTheme.Fonts.callout.weight(.medium)).foregroundColor(AppTheme.Colors.primaryText)
                        Text(stuScoreDateFmt.string(from: rec.exam.date)).font(AppTheme.Fonts.caption2).foregroundColor(AppTheme.Colors.tertiaryText)
                    }
                    Spacer()
                    Text(String(format: "%.0f/%.0f", rec.total, rec.fullTotal))
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundColor(ratioColor(rec.totalRatio))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.tertiaryText)
                        .rotationEffect(.degrees(isOpen ? -180 : 0))
                }
                .padding(.horizontal, 12).padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(spacing: 0) {
                    Divider().background(AppTheme.Colors.separator)
                    ForEach(Array(rec.subjectScores.enumerated()), id: \.offset) { idx, item in
                        HStack(spacing: 10) {
                            Text(item.subject)
                                .font(AppTheme.Fonts.footnote).foregroundColor(AppTheme.Colors.secondaryText)
                                .frame(width: 48, alignment: .leading)
                            scoreRatioBar(ratio: item.full > 0 ? item.score / item.full : 0)
                            Spacer()
                            Text(String(format: "%.0f", item.score))
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundColor(ratioColor(item.full > 0 ? item.score / item.full : 0))
                                .frame(width: 44, alignment: .trailing)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        if idx < rec.subjectScores.count - 1 {
                            Divider().background(AppTheme.Colors.separator).padding(.leading, 12)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.Colors.subtleBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous))
    }

    // 迷你得分率条
    private func scoreRatioBar(ratio: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.Colors.separator).frame(height: 5)
                Capsule().fill(ratioColor(ratio))
                    .frame(width: max(4, geo.size.width * CGFloat(min(max(ratio, 0), 1))), height: 5)
            }
        }
        .frame(width: 76, height: 5)
    }
}

private struct StuChartPoint: Identifiable {
    let id: UUID
    let examName: String
    let value: Double
    let real: Double
}
