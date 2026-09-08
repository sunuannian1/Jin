import SwiftUI
import UIKit

// 学生名册 — 高级排版版
struct StudentListView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.openURL) private var openURL
    @State private var searchText = ""
    @State private var showingAdd = false
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
                        ForEach(filteredStudents) { student in
                            NavigationLink {
                                StudentDetailView(studentId: student.id)
                            } label: {
                                StudentCard(student: student)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if !student.phone.isEmpty, let url = telURL(student.phone) {
                                    Button {
                                        openURL(url)
                                    } label: {
                                        Label("拨打学生电话 \(student.phone)", systemImage: "phone.fill")
                                    }
                                }
                                if !student.fatherPhone.isEmpty, let url = telURL(student.fatherPhone) {
                                    Button {
                                        openURL(url)
                                    } label: {
                                        Label("拨打家长电话 \(student.fatherPhone)", systemImage: "phone.arrow.right.left")
                                    }
                                }
                                Button(role: .destructive) {
                                    viewModel.deleteStudent(student)
                                } label: {
                                    Label("删除学生", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
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
                filterChip(title: "全部", isActive: seatFilter == nil) {
                    seatFilter = nil
                }
                filterChip(title: "未排座", isActive: seatFilter == 0) {
                    seatFilter = 0
                }
                ForEach(1...maxSeatRow, id: \.self) { row in
                    filterChip(title: "第\(row)排", isActive: seatFilter == row) {
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

    private func filterChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Fonts.caption.weight(.semibold))
                .foregroundColor(isActive ? .white : AppTheme.Colors.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Group {
                        if isActive {
                            AppTheme.Colors.primaryText
                        } else {
                            AppTheme.Colors.subtleBackground
                        }
                    }
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
            let parent = student.fatherPhone.isEmpty ? "—" : student.fatherPhone
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
                    if !student.phone.isEmpty || !student.fatherPhone.isEmpty {
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
                    if !student.fatherName.isEmpty {
                        infoRow(icon: "person.fill", label: "父亲", value: student.fatherName)
                    }
                    if !student.fatherPhone.isEmpty {
                        contactRow(icon: "phone.fill", label: "父亲电话", value: student.fatherPhone, color: .blue) {
                            if let url = telURL(student.fatherPhone) { openURL(url) }
                        }
                    }
                    if !student.motherName.isEmpty {
                        infoRow(icon: "person.fill", label: "母亲", value: student.motherName)
                    }
                    if !student.motherPhone.isEmpty {
                        contactRow(icon: "phone.fill", label: "母亲电话", value: student.motherPhone, color: .pink) {
                            if let url = telURL(student.motherPhone) { openURL(url) }
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

                // 备注
                if !student.notes.isEmpty {
                    detailSection(title: "备注", systemImage: "note.text") {
                        Text(student.notes)
                            .font(AppTheme.Fonts.body)
                            .foregroundColor(AppTheme.Colors.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

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
    @State private var fatherName = ""
    @State private var fatherPhone = ""
    @State private var motherName = ""
    @State private var motherPhone = ""
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
                TextField("父亲姓名", text: $fatherName)
                TextField("父亲电话", text: $fatherPhone)
                    .keyboardType(.phonePad)
                TextField("母亲姓名", text: $motherName)
                TextField("母亲电话", text: $motherPhone)
                    .keyboardType(.phonePad)
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
                fatherName = student.fatherName
                fatherPhone = student.fatherPhone
                motherName = student.motherName
                motherPhone = student.motherPhone
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
                phone: phone, fatherName: fatherName, fatherPhone: fatherPhone,
                motherName: motherName, motherPhone: motherPhone,
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
            updated.fatherName = fatherName
            updated.fatherPhone = fatherPhone
            updated.motherName = motherName
            updated.motherPhone = motherPhone
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
