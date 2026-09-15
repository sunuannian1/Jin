import SwiftUI
import UniformTypeIdentifiers

// 我的页面 — 高级排版版
struct ProfileView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingClearConfirm = false
    @State private var showingRestoreConfirm = false
    @State private var showingAbout = false
    @State private var showingImport = false
    @State private var exportURL: URL?
    @State private var importResultMessage: String?
    @State private var showingImportResult = false
    @State private var showingThemePicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 用户信息卡（深色渐变）
                userCard
                    .padding(.top, 16)

                // 数据统计
                statsSection

                // 教学管理
                settingsGroup(title: "教学管理", icon: "graduationcap.fill") {
                    settingsRow(icon: "book.fill", title: "科目管理", color: .blue) {
                        SettingsView()
                    }
                    settingsRow(icon: "person.2.fill", title: "学生名册管理", color: AppTheme.Colors.accent) {
                        StudentListView()
                    }
                }

                // 通知管理
                settingsGroup(title: "通知管理", icon: "bell.fill") {
                    settingsRow(icon: "doc.text.fill", title: "通知模板管理", color: .purple) {
                        NotificationTemplateView()
                    }
                    settingsRow(icon: "clock.arrow.circlepath", title: "通知发布记录", color: .green) {
                        NotificationListView()
                    }
                }

                // 个性化设置
                settingsGroup(title: "个性化设置", icon: "paintbrush.fill") {
                    // 主题切换
                    Button {
                        showingThemePicker = true
                    } label: {
                        HStack(spacing: 12) {
                            settingsIcon(icon: "paintbrush.fill", color: .pink)
                            Text("主题配色")
                                .font(AppTheme.Fonts.body)
                                .foregroundColor(AppTheme.Colors.primaryText)
                            Spacer()
                            // 当前主题预览
                            HStack(spacing: 4) {
                                ForEach(AppTheme.Theme.allCases.prefix(4), id: \.self) { theme in
                                    Circle()
                                        .fill(theme.accent)
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            Circle()
                                                .stroke(theme == AppTheme.currentTheme ? AppTheme.Colors.primaryText : .clear, lineWidth: 2)
                                        )
                                }
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.tertiaryText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .background(AppTheme.Colors.separator)
                        .padding(.leading, 52)

                    settingsRow(icon: "square.grid.2x2.fill", title: "首页布局设置", color: .teal) {
                        HomeFeatureManagerView()
                    }
                    Divider()
                        .background(AppTheme.Colors.separator)
                        .padding(.leading, 52)
                    settingsRow(icon: "star.fill", title: "常用功能管理", color: .yellow) {
                        HomeFeatureManagerView()
                    }
                }

                // 数据管理
                settingsGroup(title: "数据管理", icon: "externaldrive.fill") {
                    // 导出
                    Button {
                        if let url = exportURL {
                            // 触发分享
                            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootVC = windowScene.windows.first?.rootViewController {
                                rootVC.present(av, animated: true)
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            settingsIcon(icon: "square.and.arrow.up.fill", color: .blue)
                            Text("导出全部数据")
                                .font(AppTheme.Fonts.body)
                                .foregroundColor(AppTheme.Colors.primaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.tertiaryText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .background(AppTheme.Colors.separator)
                        .padding(.leading, 52)

                    Button {
                        showingImport = true
                    } label: {
                        HStack(spacing: 12) {
                            settingsIcon(icon: "square.and.arrow.down.fill", color: .green)
                            Text("导入数据恢复")
                                .font(AppTheme.Fonts.body)
                                .foregroundColor(AppTheme.Colors.primaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.tertiaryText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .background(AppTheme.Colors.separator)
                        .padding(.leading, 52)

                    Button(role: .destructive) {
                        showingClearConfirm = true
                    } label: {
                        HStack(spacing: 12) {
                            settingsIcon(icon: "trash.fill", color: .red)
                            Text("清空所有数据")
                                .font(AppTheme.Fonts.body)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // 关于
                Button {
                    showingAbout = true
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon(icon: "info.circle.fill", color: .gray)
                        Text("关于")
                            .font(AppTheme.Fonts.body)
                            .foregroundColor(AppTheme.Colors.primaryText)
                        Spacer()
                        Text("v1.0.0")
                            .font(AppTheme.Fonts.caption)
                            .foregroundColor(AppTheme.Colors.tertiaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                            .stroke(AppTheme.Colors.separator, lineWidth: 0.5)
                    )
                    .rdShadow(AppTheme.Shadows.sm)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 18)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            prepareExportFile()
        }
        .fileImporter(isPresented: $showingImport, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let ok = viewModel.importBackup(from: url)
                importResultMessage = ok ? "导入成功，数据已恢复。" : "导入失败：文件格式不正确。"
                showingImportResult = true
                prepareExportFile()
            case .failure:
                break
            }
        }
        .alert("清空所有数据？", isPresented: $showingClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认清除", role: .destructive) {
                viewModel.clearAllData()
                prepareExportFile()
            }
        } message: {
            Text("将删除全部学生、成绩、课表、值日、通知、相册、待办数据，且无法恢复。")
        }
        .confirmationDialog("恢复示例数据？", isPresented: $showingRestoreConfirm, titleVisibility: .visible) {
            Button("恢复示例数据", role: .destructive) {
                viewModel.restoreSampleData()
                prepareExportFile()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将用一套完整的示例班级数据覆盖当前全部数据。")
        }
        .alert("导入结果", isPresented: $showingImportResult) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(importResultMessage ?? "")
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingThemePicker) {
            ThemePickerView()
        }
    }

    // MARK: - 用户信息卡
    private var userCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.Colors.accentGradient)
                    .frame(width: 64, height: 64)
                Text(String(viewModel.classInfo.headTeacher.isEmpty ? "班" : String(viewModel.classInfo.headTeacher.prefix(1))))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.classInfo.headTeacher.isEmpty ? "未设置班主任" : viewModel.classInfo.headTeacher)
                    .font(AppTheme.Fonts.title2)
                    .foregroundColor(.white)
                Text(viewModel.classInfo.className.isEmpty ? "未设置班级" : viewModel.classInfo.className)
                    .font(AppTheme.Fonts.footnote)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [AppTheme.Colors.primaryText, Color(red: 0.20, green: 0.18, blue: 0.16)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
        .rdShadow(AppTheme.Shadows.md)
    }

    // MARK: - 数据统计
    private var statsSection: some View {
        HStack(spacing: 10) {
            statCard(value: "\(viewModel.students.count)", label: "学生", icon: "person.2.fill", color: .blue)
            statCard(value: "\(viewModel.exams.count)", label: "考试", icon: "doc.text.fill", color: AppTheme.Colors.accent)
            statCard(value: "\(viewModel.scoreRecords.count)", label: "成绩", icon: "chart.bar.fill", color: .green)
            statCard(value: "\(viewModel.notifications.count)", label: "通知", icon: "bell.fill", color: .purple)
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .bold).monospacedDigit())
                .foregroundColor(AppTheme.Colors.primaryText)
            Text(label)
                .font(AppTheme.Fonts.caption2)
                .foregroundColor(AppTheme.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous)
                .stroke(AppTheme.Colors.separator, lineWidth: 0.5)
        )
    }

    // MARK: - 设置分组
    private func settingsGroup<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.tertiaryText)
                Text(title.uppercased())
                    .font(AppTheme.Fonts.caption2.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.tertiaryText)
                    .tracking(1.0)
                Spacer()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .stroke(AppTheme.Colors.separator, lineWidth: 0.5)
            )
            .rdShadow(AppTheme.Shadows.sm)
        }
    }

    // 设置行（带跳转）
    private func settingsRow<Destination: View>(icon: String, title: String, color: Color, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                settingsIcon(icon: icon, color: color)
                Text(title)
                    .font(AppTheme.Fonts.body)
                    .foregroundColor(AppTheme.Colors.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsIcon(icon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
        }
    }

    // 把备份写到临时文件供分享
    private func prepareExportFile() {
        if let data = viewModel.makeBackupData() {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClassTeacherApp-backup.json")
            do {
                try data.write(to: url, options: .atomic)
                exportURL = url
            } catch {
                exportURL = nil
            }
        } else {
            exportURL = nil
        }
    }
}

// 主题选择器
struct ThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTheme = AppTheme.currentTheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("选择一个你喜欢的主题配色，应用立即生效。")
                        .font(AppTheme.Fonts.footnote)
                        .foregroundColor(AppTheme.Colors.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    ForEach(AppTheme.Theme.allCases, id: \.self) { theme in
                        Button {
                            withAnimation(AppTheme.Motion.snappy) {
                                selectedTheme = theme
                                AppTheme.currentTheme = theme
                            }
                            // 发送通知让全局刷新
                            NotificationCenter.default.post(name: NSNotification.Name("ThemeChanged"), object: nil)
                        } label: {
                            HStack(spacing: 14) {
                                // 主题预览
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(theme.accentGradient)
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "paintbrush.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(theme.rawValue)
                                        .font(AppTheme.Fonts.headline)
                                        .foregroundColor(AppTheme.Colors.primaryText)
                                    Text(theme == selectedTheme ? "当前使用" : "点击切换")
                                        .font(AppTheme.Fonts.caption)
                                        .foregroundColor(theme == selectedTheme ? AppTheme.Colors.accent : AppTheme.Colors.tertiaryText)
                                }

                                Spacer()

                                if theme == selectedTheme {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(AppTheme.Colors.accent)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.Colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                                    .stroke(theme == selectedTheme ? AppTheme.Colors.accent : AppTheme.Colors.separator, lineWidth: theme == selectedTheme ? 1.5 : 0.5)
                            )
                            .animation(AppTheme.Motion.snappy, value: selectedTheme)
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.97))
                    }
                }
                .padding(18)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("主题配色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// 关于页面
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.Colors.accentGradient)
                        .frame(width: 80, height: 80)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.top, 48)

                Text("班主任工作台")
                    .font(AppTheme.Fonts.title)
                    .foregroundColor(AppTheme.Colors.primaryText)
                Text("版本 1.0.0")
                    .font(AppTheme.Fonts.footnote)
                    .foregroundColor(AppTheme.Colors.tertiaryText)
                Text("为班主任打造的日常管理工具：学生名册、成绩管理、课表、值日、座位与待办。所有数据仅保存在本机，不上传。")
                    .font(AppTheme.Fonts.body)
                    .foregroundColor(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// 通知模板管理
struct NotificationTemplateView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingAdd = false
    @State private var editingTemplate: NotificationTemplate?

    var body: some View {
        Group {
            if viewModel.notificationTemplates.isEmpty {
                EmptyStateView(
                    systemImage: "doc.text.fill",
                    title: "暂无模板",
                    message: "点击右上角 + 创建通知模板"
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        // 预设模板
                        if !viewModel.notificationTemplates.filter({ $0.isBuiltin }).isEmpty {
                            sectionHeader(title: "预设模板")
                            ForEach(viewModel.notificationTemplates.filter { $0.isBuiltin }) { template in
                                templateCard(template: template, isBuiltin: true)
                            }
                        }

                        // 自定义模板
                        if !viewModel.customTemplates.isEmpty {
                            sectionHeader(title: "我的模板")
                                .padding(.top, 8)
                            ForEach(viewModel.customTemplates) { template in
                                templateCard(template: template, isBuiltin: false)
                            }
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 32)
                }
                .background(AppTheme.Colors.background)
            }
        }
        .navigationTitle("通知模板")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.Colors.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                NotificationTemplateEditView(mode: .add)
            }
        }
        .sheet(item: $editingTemplate) { template in
            NavigationStack {
                NotificationTemplateEditView(mode: .edit(template))
            }
        }
    }

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Fonts.caption.weight(.semibold))
                .foregroundColor(AppTheme.Colors.tertiaryText)
                .tracking(1.0)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func templateCard(template: NotificationTemplate, isBuiltin: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(template.title)
                    .font(AppTheme.Fonts.headline)
                    .foregroundColor(AppTheme.Colors.primaryText)
                Spacer()
                PillTag(title: template.audience, color: isBuiltin ? .gray : AppTheme.Colors.accent)
            }

            Text(template.content)
                .font(AppTheme.Fonts.footnote)
                .foregroundColor(AppTheme.Colors.secondaryText)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                // 一键使用
                NavigationLink {
                    NotificationComposeView(preFillTitle: template.title, preFillContent: template.content, preFillAudience: template.audience)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("使用模板")
                            .font(AppTheme.Fonts.caption.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.accentGradient)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                if !isBuiltin {
                    Button {
                        editingTemplate = template
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.secondaryText)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.Colors.subtleBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        viewModel.deleteTemplate(template)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .frame(width: 30, height: 30)
                            .background(.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                .stroke(AppTheme.Colors.separator, lineWidth: 0.5)
        )
        .rdShadow(AppTheme.Shadows.sm)
    }
}

// 通知模板编辑视图
struct NotificationTemplateEditView: View {
    enum Mode {
        case add
        case edit(NotificationTemplate)
    }

    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let mode: Mode

    @State private var title = ""
    @State private var content = ""
    @State private var audience = "全班"

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        Form {
            Section("模板信息") {
                TextField("模板名称", text: $title, prompt: Text("如：考试通知"))
                Picker("接收范围", selection: $audience) {
                    ForEach(NotificationItem.audiences, id: \.self) { a in
                        Text(a).tag(a)
                    }
                }
            }
            Section("通知内容") {
                TextField("通知正文", text: $content, axis: .vertical)
                    .lineLimit(6...12)
            }
        }
        .navigationTitle(isEditing ? "编辑模板" : "新建模板")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || content.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if case .edit(let template) = mode {
                title = template.title
                content = template.content
                audience = template.audience
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else { return }

        switch mode {
        case .add:
            viewModel.addTemplate(NotificationTemplate(title: trimmedTitle, content: trimmedContent, audience: audience))
        case .edit(let template):
            var updated = template
            updated.title = trimmedTitle
            updated.content = trimmedContent
            updated.audience = audience
            viewModel.updateTemplate(updated)
        }
        dismiss()
    }
}
