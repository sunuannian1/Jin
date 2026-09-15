import Foundation

// MARK: - 学期
struct Semester: Identifiable, Codable {
    let id: UUID
    var name: String              // 如"2024-2025学年第一学期"
    var shortName: String         // 如"第1学期"
    var startDate: Date
    var endDate: Date
    var isCurrent: Bool

    init(id: UUID = UUID(), name: String, shortName: String = "",
         startDate: Date = Date(), endDate: Date = Date(), isCurrent: Bool = false) {
        self.id = id
        self.name = name
        self.shortName = shortName.isEmpty ? name : shortName
        self.startDate = startDate
        self.endDate = endDate
        self.isCurrent = isCurrent
    }
}

// MARK: - 通知
struct NotificationItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var date: Date
    var audience: String        // 接收范围：全班 / 家长 / 班干部
    var isPinned: Bool
    var isRead: Bool

    static let audiences = ["全班", "家长", "班干部"]

    init(id: UUID = UUID(), title: String, content: String, date: Date = Date(),
         audience: String = "全班", isPinned: Bool = false, isRead: Bool = false) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
        self.audience = audience
        self.isPinned = isPinned
        self.isRead = isRead
    }
}

// MARK: - 相册分类
struct AlbumFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: String        // 如：班级活动、运动会、日常
    var desc: String?           // 相册描述（v2，Optional 兼容旧数据）
    var isPinned: Bool
    var coverPhotoId: UUID?     // 指定封面；nil 时取第一张照片
    var photoIds: [UUID]

    init(id: UUID = UUID(), name: String, category: String = "班级活动",
         desc: String? = nil, isPinned: Bool = false, coverPhotoId: UUID? = nil, photoIds: [UUID] = []) {
        self.id = id
        self.name = name
        self.category = category
        self.desc = desc
        self.isPinned = isPinned
        self.coverPhotoId = coverPhotoId
        self.photoIds = photoIds
    }
}

// 相册分类（对齐网页 v2 分类网格）
enum AlbumCategory {
    static let all = ["班级活动", "运动会", "日常点滴", "学习成长", "荣誉表彰", "其他"]
}

// MARK: - 相册照片（图片二进制按 id 存 Documents/Photos 目录）
struct AlbumPhoto: Identifiable, Codable {
    let id: UUID
    var folderId: UUID
    var title: String
    var date: Date
    var note: String

    init(id: UUID = UUID(), folderId: UUID, title: String = "", date: Date = Date(), note: String = "") {
        self.id = id
        self.folderId = folderId
        self.title = title
        self.date = date
        self.note = note
    }
}

// MARK: - 通知模板
struct NotificationTemplate: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var audience: String
    var isBuiltin: Bool

    init(id: UUID = UUID(), title: String, content: String, audience: String = "全班", isBuiltin: Bool = false) {
        self.id = id
        self.title = title
        self.content = content
        self.audience = audience
        self.isBuiltin = isBuiltin
    }

    // 预设模板
    static let builtinTemplates: [NotificationTemplate] = [
        NotificationTemplate(
            title: "考试通知",
            content: "各位同学/家长：\n定于本周五进行本学期第一次月考，考试科目为语文、数学、英语。请同学们认真复习，家长协助督促。考试时间：上午8:00-12:00，下午14:00-16:00。\n谢谢配合！",
            audience: "全班",
            isBuiltin: true
        ),
        NotificationTemplate(
            title: "家长会通知",
            content: "尊敬的各位家长：\n兹定于本周五下午4:00在本班教室召开家长会，主要内容包括：本学期教学安排、学生在校表现反馈、家校沟通事项。请各位家长准时参加，如有特殊情况请提前与班主任联系。\n谢谢！",
            audience: "家长",
            isBuiltin: true
        ),
        NotificationTemplate(
            title: "放假通知",
            content: "各位同学/家长：\n根据学校安排，本周六、周日正常休息。请同学们合理安排作息，注意安全，按时完成作业。下周一早上7:30准时到校。\n祝大家周末愉快！",
            audience: "全班",
            isBuiltin: true
        ),
        NotificationTemplate(
            title: "成绩反馈",
            content: "各位家长：\n本次考试成绩已公布，整体情况良好。请各位家长查看孩子成绩单，与孩子一起分析错题，制定改进计划。如有疑问可随时与我沟通。\n感谢您的支持与配合！",
            audience: "家长",
            isBuiltin: true
        ),
        NotificationTemplate(
            title: "活动通知",
            content: "各位同学：\n本班将于下周三下午组织班级活动，地点待定。请同学们准时参加，穿校服，带好水杯。活动结束后正常放学。\n期待大家的参与！",
            audience: "全班",
            isBuiltin: true
        ),
        NotificationTemplate(
            title: "班干部通知",
            content: "各位班干部：\n请于今天下午放学后在教室召开简短会议，布置近期工作。请各位准时参加，带好笔记本。\n谢谢配合！",
            audience: "班干部",
            isBuiltin: true
        )
    ]
}

// MARK: - 全量备份（导出/导入用）
struct AllDataBackup: Codable {
    var classInfo: ClassInfo
    var students: [Student]
    var semesters: [Semester]
    var exams: [Exam]
    var scoreRecords: [ScoreRecord]
    var courses: [Course]
    var dutyGroups: [DutyGroup]
    var todos: [TodoItem]
    var notifications: [NotificationItem]
    var albumFolders: [AlbumFolder]
    var albumPhotos: [AlbumPhoto]
    var photoFiles: [String: Data]
}
