import SwiftUI

// 工作台首页 — 高级排版版
struct HomeView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingAddTodo = false
    @State private var newTodoTitle = ""
    @State private var showingCompose = false

    // 4 列功能入口
    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    // 统计卡片布局：主卡 1.4，次卡各 1
    private let statColumns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 10),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 10),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 10)
    ]

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let teacherName = viewModel.classInfo.headTeacher
        let surname = teacherName.isEmpty ? "老师" : "\(teacherName.prefix(1))老师"
        switch hour {
        case 5..<12: return "早上好，\(surname)"
        case 12..<14: return "中午好，\(surname)"
        case 14..<18: return "下午好，\(surname)"
        default: return "夜深了，\(surname)"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                statCards.staggeredAppear(index: 0)
                functionGrid.staggeredAppear(index: 1)
                dutySection.staggeredAppear(index: 2)
                coursesSection.staggeredAppear(index: 3)
                todoSection.staggeredAppear(index: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.bottom, 32)
        }
        .background(AppTheme.Colors.background)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .alert("添加待办", isPresented: $showingAddTodo) {
            TextField("待办事项", text: $newTodoTitle)
            Button("取消", role: .cancel) {}
            Button("添加") {
                let title = newTodoTitle.trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    viewModel.addTodo(title: title)
                }
                newTodoTitle = ""
            }
        }
        .sheet(isPresented: $showingCompose) {
            NavigationStack {
                NotificationComposeView()
            }
        }
    }

    // MARK: - 顶部大标题头部
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(AppTheme.Fonts.footnote.weight(.medium))
                .foregroundColor(AppTheme.Colors.tertiaryText)

            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.classInfo.className.isEmpty ? "我的班级" : viewModel.classInfo.className)
                    .font(AppTheme.Fonts.largeTitle)
                    .foregroundColor(AppTheme.Colors.primaryText)
                    .tracking(-0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.accent)
                        Text(viewModel.todayString)
                            .font(AppTheme.Fonts.callout.weight(.semibold))
                            .foregroundColor(AppTheme.Colors.primaryText)
                    }
                    Text(viewModel.weekdayString)
                        .font(AppTheme.Fonts.caption2)
                        .foregroundColor(AppTheme.Colors.tertiaryText)
                }
                .frame(minWidth: 82, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 64)
        .padding(.bottom, 8)
    }

    // MARK: - 数据概览（主卡 + 次卡）
    private var statCards: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(viewModel.students.count)", label: "班级学生",
                     systemImage: "person.2.fill", color: AppTheme.Colors.accent)
                .frame(maxWidth: .infinity)
            StatCard(value: "\(viewModel.pendingScoreCount)", label: "待录成绩",
                     systemImage: "pencil.line", color: .orange)
                .frame(maxWidth: .infinity)
            StatCard(value: "\(viewModel.classInfo.subjects.count)", label: "开设科目",
                     systemImage: "book.fill", color: .blue)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 100)
    }

    // MARK: - 功能入口（4 列紧凑网格，用户可自定义）
    private var functionGrid: some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("常用功能")
                        .font(AppTheme.Fonts.title2)
                        .foregroundColor(AppTheme.Colors.primaryText)
                        .tracking(-0.3)
                    Spacer()
                    NavigationLink {
                        HomeFeatureManagerView()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11, weight: .semibold))
                            Text("管理")
                                .font(AppTheme.Fonts.caption.weight(.semibold))
                        }
                        .foregroundColor(AppTheme.Colors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.Colors.accentSoft)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(viewModel.visibleHomeFeatures) { feature in
                        featureButton(for: feature)
                    }
                }
            }
        }
    }

    // 功能入口主题色
    private func featureColor(for id: String) -> Color {
        switch id {
        case "schedule": return .purple
        case "duty": return .green
        case "seat": return .teal
        case "map": return .brown
        case "album": return .cyan
        case "notification": return .red
        case "ranking": return .pink
        case "scoreImport": return .orange
        case "templates": return .indigo
        case "settings": return .gray
        case "print": return .blue
        default: return .gray
        }
    }

    // 根据功能配置渲染对应按钮（统一丝滑按压手感）
    @ViewBuilder
    private func featureButton(for feature: AppViewModel.HomeFeature) -> some View {
        let label = FeatureButton(title: feature.name, systemImage: feature.systemImage,
                                  color: featureColor(for: feature.id))
        switch feature.id {
        case "notification":
            Button { withAnimation(AppTheme.Motion.quick) { showingCompose = true } } label: { label }
                .buttonStyle(PressableButtonStyle(scale: 0.86))
        case "print":
            Button {
                PrintService.shared.printSchedule(
                    className: viewModel.classInfo.className,
                    weekDays: ["周一","周二","周三","周四","周五","周六","周日"],
                    periods: Array(1...8),
                    schedule: []
                )
            } label: { label }
                .buttonStyle(PressableButtonStyle(scale: 0.86))
        default:
            NavigationLink { featureDestination(for: feature.id) } label: { label }
                .buttonStyle(PressableButtonStyle(scale: 0.86))
        }
    }

    @ViewBuilder
    private func featureDestination(for id: String) -> some View {
        switch id {
        case "schedule": ScheduleView()
        case "duty": DutyView()
        case "seat": SeatView()
        case "map": ClassMapView()
        case "album": AlbumListView()
        case "ranking": RankingListView()
        case "scoreImport": ExamListView()
        case "templates": NotificationTemplateView()
        case "settings": SettingsView()
        default: EmptyView()
        }
    }

    // MARK: - 值日安排
    @ViewBuilder
    private var dutySection: some View {
        if let duty = viewModel.currentDutyGroup {
            Card(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("今日值日")
                            .font(AppTheme.Fonts.title2)
                            .foregroundColor(AppTheme.Colors.primaryText)
                            .tracking(-0.3)
                        Spacer()
                        Button {
                            withAnimation(AppTheme.Motion.snappy) {
                                viewModel.nextDutyGroup()
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text("下一组")
                                    .font(AppTheme.Fonts.caption.weight(.semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.Colors.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.Colors.accentSoft)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        Text("第\(duty.groupNumber)组")
                            .font(AppTheme.Fonts.headline.weight(.semibold))
                            .foregroundColor(.green)
                        Text("·")
                            .foregroundColor(AppTheme.Colors.tertiaryText)
                        Text(viewModel.dutyStudentNames(of: duty).isEmpty ? "未安排成员" : viewModel.dutyStudentNames(of: duty))
                            .font(AppTheme.Fonts.body)
                            .foregroundColor(AppTheme.Colors.primaryText)
                            .lineLimit(2)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - 今日课程
    private var coursesSection: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("今日课程")
                        .font(AppTheme.Fonts.title2)
                        .foregroundColor(AppTheme.Colors.primaryText)
                        .tracking(-0.3)
                    Spacer()
                    NavigationLink {
                        ScheduleView()
                    } label: {
                        HStack(spacing: 2) {
                            Text("课表")
                                .font(AppTheme.Fonts.caption.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.Colors.accent)
                    }
                }

                let todayCourses = viewModel.todayCourses()
                if todayCourses.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.Colors.tertiaryText)
                            Text("今天没有排课")
                                .font(AppTheme.Fonts.footnote)
                                .foregroundColor(AppTheme.Colors.tertiaryText)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(todayCourses.enumerated()), id: \.element.id) { index, course in
                            HStack(spacing: 10) {
                                Text(course.timeString)
                                    .font(AppTheme.Fonts.caption.weight(.semibold))
                                    .foregroundColor(AppTheme.Colors.accent)
                                    .frame(width: 72, alignment: .leading)
                                Text(course.subject)
                                    .font(AppTheme.Fonts.body.weight(.medium))
                                    .foregroundColor(AppTheme.Colors.primaryText)
                                Spacer()
                                Text("第\(course.period)节")
                                    .font(AppTheme.Fonts.caption2)
                                    .foregroundColor(AppTheme.Colors.tertiaryText)
                            }
                            .padding(.vertical, 10)
                            .staggeredAppear(index: index, step: 0.06)
                            if index < todayCourses.count - 1 {
                                Divider()
                                    .background(AppTheme.Colors.separator)
                                    .padding(.leading, 64)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 今日待办
    private var todoSection: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("今日待办")
                        .font(AppTheme.Fonts.title2)
                        .foregroundColor(AppTheme.Colors.primaryText)
                        .tracking(-0.3)
                    Spacer()
                    NavigationLink {
                        TodoListView()
                    } label: {
                        Text("全部")
                            .font(AppTheme.Fonts.footnote.weight(.semibold))
                            .foregroundColor(AppTheme.Colors.accent)
                    }
                    .buttonStyle(.plain)
                    Button {
                        showingAddTodo = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }

                let todayTodos = viewModel.todayTodos
                if todayTodos.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.Colors.tertiaryText)
                            Text("没有待办事项")
                                .font(AppTheme.Fonts.footnote)
                                .foregroundColor(AppTheme.Colors.tertiaryText)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(todayTodos.enumerated()), id: \.element.id) { index, todo in
                            HStack(spacing: 12) {
                                Button {
                                    withAnimation(AppTheme.Motion.bouncy) {
                                        viewModel.toggleTodo(todo)
                                    }
                                } label: {
                                    ZStack {
                                        if todo.isCompleted {
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(AppTheme.Colors.accent)
                                                .frame(width: 22, height: 22)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                                .transition(.scale.combined(with: .opacity))
                                        } else {
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .stroke(AppTheme.Colors.tertiaryText, lineWidth: 1.5)
                                                .frame(width: 22, height: 22)
                                        }
                                    }
                                    .animation(AppTheme.Motion.bouncy, value: todo.isCompleted)
                                }
                                .buttonStyle(PressableButtonStyle(scale: 0.8))

                                Text(todo.title)
                                    .font(AppTheme.Fonts.body)
                                    .foregroundColor(todo.isCompleted ? AppTheme.Colors.tertiaryText : AppTheme.Colors.primaryText)
                                    .strikethrough(todo.isCompleted, color: AppTheme.Colors.tertiaryText)
                                Spacer()
                                Button {
                                    withAnimation(AppTheme.Motion.smooth) {
                                        viewModel.deleteTodo(todo)
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.tertiaryText)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(PressableButtonStyle(scale: 0.8))
                            }
                            .padding(.vertical, 10)
                            if index < todayTodos.count - 1 {
                                Divider()
                                    .background(AppTheme.Colors.separator)
                                    .padding(.leading, 34)
                            }
                        }
                    }
                }
            }
        }
    }
}
