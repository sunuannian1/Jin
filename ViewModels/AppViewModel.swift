import Foundation
import SwiftUI
import Combine

// 全局应用状态：真数据、本地持久化、无假数据
class AppViewModel: ObservableObject {
    // MARK: - 数据
    @Published var classInfo: ClassInfo
    @Published var students: [Student]
    @Published var semesters: [Semester]
    @Published var currentSemesterId: UUID?
    @Published var exams: [Exam]
    @Published var scoreRecords: [ScoreRecord]
    @Published var courses: [Course]
    @Published var dutyGroups: [DutyGroup]
    @Published var todos: [TodoItem]
    @Published var notifications: [NotificationItem]
    @Published var albumFolders: [AlbumFolder]
    @Published var albumPhotos: [AlbumPhoto]
    @Published var notificationTemplates: [NotificationTemplate]

    // 首页功能入口配置
    struct HomeFeature: Identifiable, Codable {
        let id: String
        let name: String
        let systemImage: String
        var isVisible: Bool
        var order: Int
    }

    @Published var homeFeatures: [HomeFeature] {
        didSet { saveHomeFeatures() }
    }

    // 默认功能列表
    static let defaultHomeFeatures: [HomeFeature] = [
        HomeFeature(id: "schedule", name: "课表", systemImage: "calendar", isVisible: true, order: 0),
        HomeFeature(id: "duty", name: "值日", systemImage: "paintbrush", isVisible: true, order: 1),
        HomeFeature(id: "seat", name: "座位", systemImage: "rectangle.grid.3x3", isVisible: true, order: 2),
        HomeFeature(id: "map", name: "班级地图", systemImage: "map", isVisible: true, order: 3),
        HomeFeature(id: "album", name: "相册", systemImage: "photo.on.rectangle", isVisible: true, order: 4),
        HomeFeature(id: "notification", name: "发通知", systemImage: "megaphone", isVisible: true, order: 5),
        HomeFeature(id: "ranking", name: "成绩排名", systemImage: "list.number", isVisible: true, order: 6),
        HomeFeature(id: "scoreImport", name: "导入成绩", systemImage: "square.and.arrow.down", isVisible: true, order: 7),
        HomeFeature(id: "templates", name: "通知模板", systemImage: "doc.text", isVisible: false, order: 8),
        HomeFeature(id: "settings", name: "设置", systemImage: "gearshape", isVisible: false, order: 9),
        HomeFeature(id: "print", name: "打印中心", systemImage: "printer", isVisible: false, order: 10)
    ]

    @Published var currentDutyIndex: Int {
        didSet { UserDefaults.standard.set(currentDutyIndex, forKey: "currentDutyIndex") }
    }

    private var cancellables = Set<AnyCancellable>()
    private let dataManager = DataManager.shared

    init() {
        if DataManager.shared.hasSavedData {
            self.classInfo = DataManager.shared.loadClassInfo() ?? .default
            self.students = DataManager.shared.loadStudents() ?? []
            self.semesters = DataManager.shared.loadSemesters() ?? []
            self.currentSemesterId = UserDefaults.standard.string(forKey: "currentSemesterId").flatMap(UUID.init(uuidString:))
            self.exams = DataManager.shared.loadExams() ?? []
            self.scoreRecords = DataManager.shared.loadScores() ?? []
            self.courses = DataManager.shared.loadCourses() ?? []
            self.dutyGroups = DataManager.shared.loadDutyGroups() ?? []
            self.todos = DataManager.shared.loadTodos() ?? []
            self.notifications = DataManager.shared.loadNotifications() ?? []
            self.albumFolders = DataManager.shared.loadAlbumFolders() ?? []
            self.albumPhotos = DataManager.shared.loadAlbumPhotos() ?? []
        } else {
            self.classInfo = .default
            self.students = []
            self.semesters = []
            self.currentSemesterId = nil
            self.exams = []
            self.scoreRecords = []
            self.courses = []
            self.dutyGroups = []
            self.todos = []
            self.notifications = []
            self.albumFolders = []
            self.albumPhotos = []
        }
        self.currentDutyIndex = UserDefaults.standard.integer(forKey: "currentDutyIndex")
        self.notificationTemplates = NotificationTemplate.builtinTemplates + (DataManager.shared.loadNotificationTemplates() ?? [])
        self.homeFeatures = AppViewModel.loadHomeFeatures()
        setupAutoSave()
        setupThemeObserver()
    }

    // MARK: - 首页功能配置
    private static func loadHomeFeatures() -> [HomeFeature] {
        guard let data = UserDefaults.standard.data(forKey: "homeFeatures"),
              let features = try? JSONDecoder().decode([HomeFeature].self, from: data) else {
            return defaultHomeFeatures
        }
        // 合并：用户配置 + 默认新增的功能
        var merged = features
        for defaultFeature in defaultHomeFeatures {
            if !merged.contains(where: { $0.id == defaultFeature.id }) {
                merged.append(defaultFeature)
            }
        }
        return merged.sorted { $0.order < $1.order }
    }

    private func saveHomeFeatures() {
        if let data = try? JSONEncoder().encode(homeFeatures) {
            UserDefaults.standard.set(data, forKey: "homeFeatures")
        }
    }

    var visibleHomeFeatures: [HomeFeature] {
        homeFeatures.filter { $0.isVisible }.sorted { $0.order < $1.order }
    }

    func toggleFeature(_ feature: HomeFeature) {
        if let i = homeFeatures.firstIndex(where: { $0.id == feature.id }) {
            homeFeatures[i].isVisible.toggle()
        }
    }

    func moveFeature(from source: IndexSet, to destination: Int) {
        var visible = visibleHomeFeatures
        visible.move(fromOffsets: source, toOffset: destination)
        // 更新 order
        for (idx, feature) in visible.enumerated() {
            if let i = homeFeatures.firstIndex(where: { $0.id == feature.id }) {
                homeFeatures[i].order = idx
            }
        }
    }

    func resetHomeFeatures() {
        homeFeatures = AppViewModel.defaultHomeFeatures
    }

    // 监听主题变化，触发全局 UI 刷新
    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ThemeChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - 自动保存
    private func setupAutoSave() {
        $classInfo.dropFirst().debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.dataManager.saveClassInfo($0) }.store(in: &cancellables)
        $students.dropFirst().debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.dataManager.saveStudents($0) }.store(in: &cancellables)
        $semesters.dropFirst().debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.dataManager.saveSemesters($0) }.store(in: &cancellables)
        $currentSemesterId.dropFirst().debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .sink { [weak self] in UserDefaults.standard.set($0?.uuidString, forKey: "currentSemesterId") }.store(in: &cancellables)
        $exams.dropFirst().debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.dataManager.saveExams($0) }.store(in: &cancellables)
        $scoreRecords.dropFirst().debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.dataManager.saveScores($0) }.store(in: &cancellables)
        $courses.dropFirst().debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.dataManager.saveCourses($0) }.store(in: &cancellables)
        $dutyGroups.dropFirst().debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.dataManager.saveDutyGroups($0) }.store(in: &cancellables)
        $todos.dropFirst().debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.dataManager.saveTodos($0) }.store(in: &cancellables)
        $notifications.dropFirst().debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.dataManager.saveNotifications($0) }.store(in: &cancellables)
        $albumFolders.dropFirst().debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.dataManager.saveAlbumFolders($0) }.store(in: &cancellables)
        $albumPhotos.dropFirst().debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.dataManager.saveAlbumPhotos($0) }.store(in: &cancellables)
    }

    // MARK: - 班级
    func updateClassInfo(className: String, grade: String, headTeacher: String, subjects: [String]) {
        classInfo = ClassInfo(className: className, grade: grade, headTeacher: headTeacher, subjects: subjects.isEmpty ? classInfo.subjects : subjects)
    }

    // MARK: - 学生
    func addStudent(_ student: Student) { students.append(student) }
    func deleteStudent(_ student: Student) {
        students.removeAll { $0.id == student.id }
        scoreRecords.removeAll { $0.studentId == student.id }
        for i in dutyGroups.indices {
            dutyGroups[i].studentIds.removeAll { $0 == student.id }
        }
    }
    func updateStudent(_ student: Student) {
        if let i = students.firstIndex(where: { $0.id == student.id }) { students[i] = student }
    }
    func studentName(for id: UUID) -> String { students.first { $0.id == id }?.name ?? "未知" }
    func student(id: UUID) -> Student? { students.first { $0.id == id } }

    // MARK: - 学期
    var currentSemester: Semester? {
        guard let id = currentSemesterId else { return semesters.first }
        return semesters.first { $0.id == id } ?? semesters.first
    }
    func addSemester(_ semester: Semester) {
        semesters.append(semester)
        if currentSemesterId == nil { currentSemesterId = semester.id }
    }
    func updateSemester(_ semester: Semester) {
        if let i = semesters.firstIndex(where: { $0.id == semester.id }) { semesters[i] = semester }
    }
    func deleteSemester(_ semester: Semester) {
        semesters.removeAll { $0.id == semester.id }
        // 解除该学期下考试的关联
        for i in exams.indices where exams[i].semesterId == semester.id {
            exams[i].semesterId = nil
        }
        if currentSemesterId == semester.id { currentSemesterId = semesters.first?.id }
    }
    func setCurrentSemester(_ semester: Semester) {
        currentSemesterId = semester.id
    }

    // MARK: - 考试
    func addExam(name: String, type: Exam.ExamType, subjects: [String], semesterId: UUID? = nil) {
        exams.append(Exam(name: name, type: type, subjects: subjects, semesterId: semesterId ?? currentSemesterId))
    }

    // 批量导入成绩（CSV 解析后调用）
    // 返回 (成功导入条数, 失败条数, 未找到学生列表)
    @discardableResult
    func importScores(examId: UUID, records: [(studentNumber: String, subject: String, score: Double)]) -> (success: Int, failed: Int, notFound: [String]) {
        var success = 0
        var failed = 0
        var notFound: Set<String> = []

        for record in records {
            guard let student = students.first(where: { $0.studentNumber == record.studentNumber }) else {
                notFound.insert(record.studentNumber)
                failed += 1
                continue
            }
            guard record.score >= 0 && record.score <= 1000 else {
                failed += 1
                continue
            }
            setScore(studentId: student.id, examId: examId, subject: record.subject, score: record.score)
            success += 1
        }

        return (success, failed, Array(notFound))
    }
    func deleteExam(_ exam: Exam) {
        exams.removeAll { $0.id == exam.id }
        scoreRecords.removeAll { $0.examId == exam.id }
    }
    func examName(id: UUID) -> String { exams.first { $0.id == id }?.name ?? "未知考试" }

    // MARK: - 成绩
    // 某考试某科目的成绩（按学生顺序）
    func scores(for examId: UUID, subject: String) -> [ScoreRecord] {
        scoreRecords.filter { $0.examId == examId && $0.subject == subject }
    }
    // 保存/更新单个学生的成绩
    func setScore(studentId: UUID, examId: UUID, subject: String, score: Double) {
        if let i = scoreRecords.firstIndex(where: { $0.studentId == studentId && $0.examId == examId && $0.subject == subject }) {
            scoreRecords[i].score = score
        } else {
            scoreRecords.append(ScoreRecord(studentId: studentId, subject: subject, examId: examId, score: score))
        }
    }
    // 清除单个学生的某科成绩（输入框清空时）
    func removeScore(studentId: UUID, examId: UUID, subject: String) {
        scoreRecords.removeAll { $0.studentId == studentId && $0.examId == examId && $0.subject == subject }
    }
    // 某学生的总分
    func totalScore(of studentId: UUID, examId: UUID) -> Double {
        scoreRecords.filter { $0.studentId == studentId && $0.examId == examId }.reduce(0) { $0 + $1.score }
    }
    // 某科目平均分
    func averageScore(examId: UUID, subject: String) -> Double {
        let records = scores(for: examId, subject: subject)
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + $1.score } / Double(records.count)
    }
    // 某科目及格率（>=60 占比）
    func passRate(examId: UUID, subject: String) -> Double {
        let records = scores(for: examId, subject: subject)
        guard !records.isEmpty else { return 0 }
        let pass = records.filter { $0.score >= 60 }.count
        return Double(pass) / Double(records.count) * 100
    }
    // 总分排名
    func totalRanking(for examId: UUID) -> [(student: Student, total: Double)] {
        students
            .map { (student: $0, total: totalScore(of: $0.id, examId: examId)) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    // MARK: - 课程
    func courses(for dayOfWeek: Int) -> [Course] {
        courses.filter { $0.dayOfWeek == dayOfWeek }.sorted { $0.period < $1.period }
    }
    func addCourse(_ course: Course) { courses.append(course) }
    func updateCourse(_ course: Course) {
        if let i = courses.firstIndex(where: { $0.id == course.id }) { courses[i] = course }
    }
    func deleteCourse(_ course: Course) { courses.removeAll { $0.id == course.id } }
    // 今天星期几（1=周一 ... 7=周日）
    var todayDayOfWeek: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7 + 1
    }
    func todayCourses() -> [Course] { courses(for: todayDayOfWeek) }

    // MARK: - 值日
    var currentDutyGroup: DutyGroup? {
        guard !dutyGroups.isEmpty else { return nil }
        return dutyGroups[currentDutyIndex % dutyGroups.count]
    }
    func nextDutyGroup() {
        guard !dutyGroups.isEmpty else { return }
        currentDutyIndex = (currentDutyIndex + 1) % dutyGroups.count
    }
    func addDutyGroup(_ group: DutyGroup) { dutyGroups.append(group) }
    func updateDutyGroup(_ group: DutyGroup) {
        if let i = dutyGroups.firstIndex(where: { $0.id == group.id }) { dutyGroups[i] = group }
    }
    func deleteDutyGroup(_ group: DutyGroup) { dutyGroups.removeAll { $0.id == group.id } }
    func dutyStudentNames(of group: DutyGroup) -> String {
        group.studentIds.compactMap { student(id: $0)?.name }.joined(separator: "、")
    }

    // MARK: - 待办
    func addTodo(title: String) {
        todos.append(TodoItem(title: title))
    }
    func toggleTodo(_ todo: TodoItem) {
        if let i = todos.firstIndex(where: { $0.id == todo.id }) { todos[i].isCompleted.toggle() }
    }
    func deleteTodo(_ todo: TodoItem) { todos.removeAll { $0.id == todo.id } }
    var pendingTodos: [TodoItem] { todos.filter { !$0.isCompleted } }

    // MARK: - 通知
    func addNotification(title: String, content: String, audience: String) {
        notifications.insert(NotificationItem(title: title, content: content, audience: audience), at: 0)
    }
    func notification(id: UUID) -> NotificationItem? { notifications.first { $0.id == id } }
    func togglePinNotification(_ item: NotificationItem) {
        if let i = notifications.firstIndex(where: { $0.id == item.id }) { notifications[i].isPinned.toggle() }
    }
    func markNotificationRead(_ item: NotificationItem) {
        if let i = notifications.firstIndex(where: { $0.id == item.id }), !notifications[i].isRead {
            notifications[i].isRead = true
        }
    }
    func deleteNotification(_ item: NotificationItem) {
        notifications.removeAll { $0.id == item.id }
    }
    var unreadNotificationCount: Int { notifications.filter { !$0.isRead }.count }

    // MARK: - 通知模板
    var customTemplates: [NotificationTemplate] {
        notificationTemplates.filter { !$0.isBuiltin }
    }
    func addTemplate(_ template: NotificationTemplate) {
        notificationTemplates.append(template)
        saveCustomTemplates()
    }
    func updateTemplate(_ template: NotificationTemplate) {
        if let i = notificationTemplates.firstIndex(where: { $0.id == template.id }) {
            notificationTemplates[i] = template
            saveCustomTemplates()
        }
    }
    func deleteTemplate(_ template: NotificationTemplate) {
        notificationTemplates.removeAll { $0.id == template.id }
        saveCustomTemplates()
    }
    private func saveCustomTemplates() {
        dataManager.saveNotificationTemplates(customTemplates)
    }

    // MARK: - 相册
    @discardableResult
    func addAlbum(name: String, category: String) -> AlbumFolder {
        let folder = AlbumFolder(name: name, category: category)
        albumFolders.append(folder)
        return folder
    }
    func deleteAlbum(_ folder: AlbumFolder) {
        for photoId in folder.photoIds {
            dataManager.deletePhotoData(id: photoId)
        }
        albumPhotos.removeAll { $0.folderId == folder.id }
        albumFolders.removeAll { $0.id == folder.id }
    }
    @discardableResult
    func addPhoto(data: Data, folderId: UUID, title: String = "") -> AlbumPhoto? {
        guard albumFolders.contains(where: { $0.id == folderId }) else { return nil }
        let photo = AlbumPhoto(folderId: folderId, title: title)
        dataManager.savePhotoData(data, id: photo.id)
        albumPhotos.append(photo)
        if let i = albumFolders.firstIndex(where: { $0.id == folderId }) {
            albumFolders[i].photoIds.append(photo.id)
        }
        return photo
    }
    func updatePhoto(_ photo: AlbumPhoto) {
        if let i = albumPhotos.firstIndex(where: { $0.id == photo.id }) { albumPhotos[i] = photo }
    }
    func deletePhoto(_ photo: AlbumPhoto) {
        dataManager.deletePhotoData(id: photo.id)
        albumPhotos.removeAll { $0.id == photo.id }
        if let i = albumFolders.firstIndex(where: { $0.id == photo.folderId }) {
            albumFolders[i].photoIds.removeAll { $0 == photo.id }
        }
    }
    func photoData(id: UUID) -> Data? { dataManager.loadPhotoData(id: id) }
    func photos(in folder: AlbumFolder) -> [AlbumPhoto] {
        folder.photoIds.compactMap { id in albumPhotos.first { $0.id == id } }
    }

    // MARK: - 备份与恢复
    // 直接从内存状态导出，避免自动保存防抖导致导出滞后
    func makeBackupData() -> Data? {
        var photoFiles: [String: Data] = [:]
        for photo in albumPhotos {
            if let data = dataManager.loadPhotoData(id: photo.id) {
                photoFiles[photo.id.uuidString] = data
            }
        }
        let backup = AllDataBackup(
            classInfo: classInfo,
            students: students,
            semesters: semesters,
            exams: exams,
            scoreRecords: scoreRecords,
            courses: courses,
            dutyGroups: dutyGroups,
            todos: todos,
            notifications: notifications,
            albumFolders: albumFolders,
            albumPhotos: albumPhotos,
            photoFiles: photoFiles
        )
        return try? JSONEncoder().encode(backup)
    }

    @discardableResult
    func importBackup(from url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let backup = try? JSONDecoder().decode(AllDataBackup.self, from: data) else { return false }
        clearAllData()
        dataManager.importPhotoFiles(backup.photoFiles)
        classInfo = backup.classInfo
        students = backup.students
        semesters = backup.semesters
        currentSemesterId = backup.semesters.first?.id
        exams = backup.exams
        scoreRecords = backup.scoreRecords
        courses = backup.courses
        dutyGroups = backup.dutyGroups
        todos = backup.todos
        notifications = backup.notifications
        albumFolders = backup.albumFolders
        albumPhotos = backup.albumPhotos
        currentDutyIndex = 0
        return true
    }

    // 恢复示例数据（用户手动触发，方便快速体验全部功能）
    func restoreSampleData() {
        clearAllData()
        currentDutyIndex = 0

        classInfo = ClassInfo(
            className: "高一（2）班",
            grade: "高一",
            headTeacher: "王老师",
            subjects: ["语文", "数学", "英语", "物理", "化学"]
        )

        let names = ["张伟", "王芳", "李娜", "刘洋", "陈静", "杨帆", "赵磊", "黄丽", "周杰", "吴敏", "徐强", "孙婷"]
        var newStudents: [Student] = []
        for (index, name) in names.enumerated() {
            let gender: Student.Gender = index % 2 == 0 ? .male : .female
            newStudents.append(Student(
                name: name,
                studentNumber: String(format: "%02d", index + 1),
                gender: gender,
                phone: String(format: "1380000%04d", index + 1),
                fatherPhone: String(format: "1390000%04d", index + 1),
                address: ["北京市海淀区中关村大街1号", "北京市朝阳区建国路88号", "北京市西城区西长安街2号", "北京市东城区东直门大街5号"][index % 4],
                groupNumber: index % 4 + 1,
                dormitory: index < 6 ? "男生楼2-0\(index % 3 + 1)" : "女生楼3-0\(index % 3 + 1)",
                notes: ""
            ))
        }
        // 自动排座：前15个座位依次填入
        var seatIndex = 0
        for row in 1...3 {
            for col in 1...5 {
                guard seatIndex < newStudents.count else { break }
                newStudents[seatIndex].seatRow = row
                newStudents[seatIndex].seatCol = col
                seatIndex += 1
            }
        }
        students = newStudents

        // 学期示例数据
        let calendar = Calendar.current
        let semester1 = Semester(
            name: "2024-2025学年第一学期",
            shortName: "第1学期",
            startDate: calendar.date(from: DateComponents(year: 2024, month: 9, day: 1)) ?? Date(),
            endDate: calendar.date(from: DateComponents(year: 2025, month: 1, day: 31)) ?? Date(),
            isCurrent: true
        )
        let semester2 = Semester(
            name: "2024-2025学年第二学期",
            shortName: "第2学期",
            startDate: calendar.date(from: DateComponents(year: 2025, month: 2, day: 1)) ?? Date(),
            endDate: calendar.date(from: DateComponents(year: 2025, month: 7, day: 31)) ?? Date(),
            isCurrent: false
        )
        semesters = [semester1, semester2]
        currentSemesterId = semester1.id

        let examSubjects = ["语文", "数学", "英语"]
        let monthly = Exam(name: "9月月考", type: .monthly,
                           date: calendar.date(byAdding: .day, value: -20, to: Date()) ?? Date(),
                           subjects: examSubjects, semesterId: semester1.id)
        let midterm = Exam(name: "期中考试", type: .midterm,
                           date: calendar.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                           subjects: examSubjects, semesterId: semester1.id)
        exams = [monthly, midterm]

        // 稳定的伪随机成绩（55-95），不依赖随机数种子
        var newScores: [ScoreRecord] = []
        for exam in [monthly, midterm] {
            for (sIndex, student) in newStudents.enumerated() {
                for (subIndex, subject) in examSubjects.enumerated() {
                    let score = Double(((sIndex * 7 + subIndex * 13 + (exam.id == midterm.id ? 5 : 0)) % 41) + 55)
                    newScores.append(ScoreRecord(studentId: student.id, subject: subject, examId: exam.id, score: score))
                }
            }
        }
        scoreRecords = newScores

        var newCourses: [Course] = []
        let schedule: [[String]] = [
            ["语文", "数学", "英语", "物理", "化学", "语文"],
            ["数学", "语文", "化学", "英语", "物理", "数学"],
            ["英语", "物理", "数学", "语文", "化学", "英语"],
            ["物理", "化学", "语文", "数学", "英语", "物理"],
            ["化学", "英语", "物理", "化学", "语文", "数学"],
        ]
        for day in 1...5 {
            for period in 1...6 {
                let subject = schedule[day - 1][period - 1]
                newCourses.append(Course(subject: subject, dayOfWeek: day, period: period,
                                         classroom: "\(day)班教室", teacher: "\(subject)老师"))
            }
        }
        courses = newCourses

        var newGroups: [DutyGroup] = []
        for g in 1...4 {
            let members = newStudents.filter { $0.groupNumber == g }.map { $0.id }
            newGroups.append(DutyGroup(groupNumber: g, studentIds: members))
        }
        dutyGroups = newGroups

        todos = [
            TodoItem(title: "收周记作业"),
            TodoItem(title: "联系张伟家长沟通近期表现"),
            TodoItem(title: "准备周五班会课件"),
        ]

        notifications = [
            NotificationItem(title: "期中考试安排", content: "下周期中考试，范围为本学期前三章内容，请同学们认真复习。", audience: "全班"),
            NotificationItem(title: "家长会通知", content: "本周五下午4点在本班教室召开家长会，请各位家长准时参加。", audience: "家长"),
        ]

        addAlbum(name: "运动会", category: "班级活动")
        addAlbum(name: "日常点滴", category: "日常")
    }

    // MARK: - 数据管理
    func clearAllData() {
        dataManager.clearAllData()
        classInfo = .default
        students = []
        semesters = []
        currentSemesterId = nil
        exams = []
        scoreRecords = []
        courses = []
        dutyGroups = []
        todos = []
        notifications = []
        albumFolders = []
        albumPhotos = []
        currentDutyIndex = 0
    }

    // MARK: - 日期
    var todayString: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日"
        return f.string(from: Date())
    }
    var weekdayString: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "EEEE"
        return f.string(from: Date())
    }
}
