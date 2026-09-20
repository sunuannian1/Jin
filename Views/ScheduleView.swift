import SwiftUI

// 班级课表（规整网格：吸顶表头 + 固定时间列 + 统一行高）
struct ScheduleView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedSlot: ScheduleSlot?

    private let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    private let timeCol: CGFloat = 50
    private let rowHeight: CGFloat = 64

    // 真实作息时间表
    private struct PeriodInfo {
        let period: Int
        let label: String
        let time: String
        let section: String
    }

    private let periodInfos: [PeriodInfo] = [
        PeriodInfo(period: 0, label: "早读", time: "7:00-7:40", section: "早读"),
        PeriodInfo(period: 1, label: "第1节", time: "8:00-8:45", section: "上午"),
        PeriodInfo(period: 2, label: "第2节", time: "8:55-9:40", section: "上午"),
        PeriodInfo(period: 3, label: "第3节", time: "10:10-10:55", section: "上午"),
        PeriodInfo(period: 4, label: "第4节", time: "11:05-11:50", section: "上午"),
        PeriodInfo(period: 5, label: "第5节", time: "14:30-15:15", section: "下午"),
        PeriodInfo(period: 6, label: "第6节", time: "15:25-16:10", section: "下午"),
        PeriodInfo(period: 7, label: "第7节", time: "16:20-17:05", section: "下午"),
        PeriodInfo(period: 8, label: "第8节", time: "17:15-18:00", section: "下午"),
    ]

    // 当前节次（按传入时间判断）：原先是每次访问都 Date() + 新建节次表，
    // 一行一次、每帧十几次；改成静态表 + 显式传时间，由 TimelineView 每分钟驱动。
    private static let periodRanges: [(period: Int, start: Int, end: Int)] = [
        (0, 7 * 60, 7 * 60 + 40),
        (1, 8 * 60, 8 * 60 + 45),
        (2, 8 * 60 + 55, 9 * 60 + 40),
        (3, 10 * 60 + 10, 10 * 60 + 55),
        (4, 11 * 60 + 5, 11 * 60 + 50),
        (5, 14 * 60 + 30, 15 * 60 + 15),
        (6, 15 * 60 + 25, 16 * 60 + 10),
        (7, 16 * 60 + 20, 17 * 60 + 5),
        (8, 17 * 60 + 15, 18 * 60),
    ]

    private func currentPeriod(at date: Date) -> Int? {
        let calendar = Calendar.current
        let totalMinutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        for range in Self.periodRanges where totalMinutes >= range.start && totalMinutes <= range.end {
            return range.period
        }
        return nil
    }

    private func dayOfWeek(for date: Date) -> Int {
        (Calendar.current.component(.weekday, from: date) + 5) % 7 + 1
    }

    // 天 -> (节次 -> 课程)：格子直接查表，不再每格 filter+sort 一遍全量课程
    private func courseIndex() -> [Int: [Int: Course]] {
        var index: [Int: [Int: Course]] = [:]
        for course in viewModel.courses {
            index[course.dayOfWeek, default: [:]][course.period] = course
        }
        return index
    }

    var body: some View {
        // 每分钟推进一次：页面开着时"当前节次"高亮要跟着真实时间走
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let now = timeline.date
            let current = currentPeriod(at: now)
            let today = dayOfWeek(for: now)
            let coursesByDay = courseIndex()

            VStack(spacing: 0) {
                headerRow(today: today)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(periodInfos, id: \.period) { info in
                            periodRow(info, today: today, current: current, coursesByDay: coursesByDay)
                            if info.period == 2 { breakRow(label: "大课间 9:40-10:10") }
                            if info.period == 4 { breakRow(label: "午休 11:50-14:30") }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("班级课表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { printSchedule() } label: { Image(systemName: "printer") }
                    .accessibilityLabel("打印课表")
            }
        }
        .sheet(item: $selectedSlot) {
            CourseEditSheet(weekday: $0.weekday, period: $0.period)
        }
    }

    // 吸顶表头：时间列 + 周一~周日
    private func headerRow(today: Int) -> some View {
        HStack(spacing: 3) {
            Text("节次")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.Colors.tertiaryText)
                .frame(width: timeCol, height: 44)
            ForEach(1...7, id: \.self) { weekday in
                let isToday = weekday == today
                VStack(spacing: 1) {
                    Text(weekdays[weekday - 1])
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isToday ? .white : AppTheme.Colors.primaryText)
                    if isToday {
                        Text("今天")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isToday ? AppTheme.Colors.accent : AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    // 课间 / 午休整行通栏窄提示
    private func breakRow(label: String) -> some View {
        HStack(spacing: 3) {
            Color.clear.frame(width: timeCol)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppTheme.Colors.tertiaryText)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 20)
        .padding(.horizontal, 10)
    }

    // 一节课程行：时间列 + 7 天，严格对齐表头
    private func periodRow(_ info: PeriodInfo, today: Int, current: Int?,
                           coursesByDay: [Int: [Int: Course]]) -> some View {
        let isCurrent = current == info.period
        return HStack(spacing: 3) {
            VStack(spacing: 2) {
                Text(info.label)
                    .font(.system(size: 11, weight: isCurrent ? .bold : .semibold))
                    .foregroundColor(isCurrent ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
                Text(info.time)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(AppTheme.Colors.tertiaryText)
                    .lineLimit(1)
            }
            .frame(width: timeCol, height: rowHeight)
            .background(isCurrent ? AppTheme.Colors.accent.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            ForEach(1...7, id: \.self) { weekday in
                courseCell(weekday: weekday, period: info.period,
                           course: coursesByDay[weekday]?[info.period],
                           isToday: weekday == today, isCurrent: isCurrent)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 1.5)
    }

    // 课程格子：窄列只放科目 + 老师，去掉教室，避免拥挤换行
    @ViewBuilder
    private func courseCell(weekday: Int, period: Int, course: Course?, isToday: Bool, isCurrent: Bool) -> some View {
        Button {
            selectedSlot = ScheduleSlot(weekday: weekday, period: period)
        } label: {
            Group {
                if let course = course {
                    let tint = courseColor(course.subject)
                    VStack(spacing: 2) {
                        Text(course.subject)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if !course.teacher.isEmpty {
                            Text(course.teacher)
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundColor(AppTheme.Colors.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: rowHeight)
                    .background(tint.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(tint.opacity(isCurrent ? 0.85 : 0.45), lineWidth: isCurrent ? 2 : 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isToday ? AppTheme.Colors.accent.opacity(0.05)
                                      : AppTheme.Colors.subtleBackground.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(AppTheme.Colors.separator, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func courseColor(_ subject: String) -> Color {
        var hash = 0
        for scalar in subject.unicodeScalars {
            hash = (hash &* 31 &+ Int(scalar.value)) & 0x7fffffff
        }
        return Self.subjectPalette[hash % Self.subjectPalette.count]
    }

    // 科目配色：静态一次、全部走深色模式微调过的 token（原先每次调用都新建一份系统色数组）
    private static let subjectPalette: [Color] = [
        AppTheme.Colors.blue, AppTheme.Colors.orange, AppTheme.Colors.purple,
        AppTheme.Colors.green, AppTheme.Colors.pink, AppTheme.Colors.teal,
        AppTheme.Colors.indigo, AppTheme.Colors.brown, AppTheme.Colors.red,
        AppTheme.Colors.mint
    ]

    private func printSchedule() {
        let periods = Array(0...8)
        var schedule: [[String?]] = []
        for period in periods {
            var row: [String?] = []
            for weekday in 1...7 {
                let course = viewModel.courses(for: weekday).first { $0.period == period }
                row.append(course?.subject)
            }
            schedule.append(row)
        }
        PrintService.shared.printSchedule(
            className: viewModel.classInfo.className,
            weekDays: weekdays,
            periods: periods,
            schedule: schedule
        )
    }
}

// 可选的课表格
struct ScheduleSlot: Identifiable {
    let id = UUID()
    let weekday: Int
    let period: Int
}

// 课程添加/编辑弹窗
struct CourseEditSheet: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let weekday: Int
    let period: Int

    @State private var subject = ""
    @State private var classroom = ""
    @State private var teacher = ""

    private var existing: Course? {
        viewModel.courses(for: weekday).first { $0.period == period }
    }

    private var periodLabel: String {
        period == 0 ? "早读" : "第\(period)节"
    }

    var body: some View {
        NavigationStack {
            Form {
                if existing != nil {
                    Section("\(periodLabel) · 已有课程") {
                        Picker("科目", selection: $subject) {
                            ForEach(viewModel.classInfo.subjects, id: \.self) { s in
                                Text(s).tag(s)
                            }
                        }
                        TextField("教室", text: $classroom)
                        TextField("任课老师", text: $teacher)
                    }
                    Section {
                        Button(role: .destructive) {
                            if let course = existing {
                                viewModel.deleteCourse(course)
                            }
                            dismiss()
                        } label: {
                            Label("删除这节课", systemImage: "trash")
                        }
                    }
                } else {
                    Section("\(periodLabel) · 添加课程") {
                        Picker("科目", selection: $subject) {
                            ForEach(viewModel.classInfo.subjects, id: \.self) { s in
                                Text(s).tag(s)
                            }
                        }
                        TextField("教室（选填）", text: $classroom)
                        TextField("任课老师（选填）", text: $teacher)
                    }
                }
            }
            .navigationTitle("\(weekdayName(weekday)) \(periodLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let course = existing {
                            var updated = course
                            updated.subject = subject
                            updated.classroom = classroom
                            updated.teacher = teacher
                            viewModel.deleteCourse(course)
                            viewModel.addCourse(updated)
                        } else if !subject.isEmpty {
                            viewModel.addCourse(Course(subject: subject, dayOfWeek: weekday, period: period, classroom: classroom, teacher: teacher))
                        }
                        dismiss()
                    }
                    .disabled(subject.isEmpty)
                }
            }
            .onAppear {
                if let course = existing {
                    subject = course.subject
                    classroom = course.classroom
                    teacher = course.teacher
                } else if let first = viewModel.classInfo.subjects.first {
                    subject = first
                }
            }
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        ["周一", "周二", "周三", "周四", "周五", "周六", "周日"][weekday - 1]
    }
}
