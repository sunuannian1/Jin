import Foundation

// MARK: - 班级信息
struct ClassInfo: Codable {
    var className: String      // 班级名，如"高一（2）班"
    var grade: String          // 年级，如"高一"
    var headTeacher: String    // 班主任姓名
    var subjects: [String]     // 开设科目

    static let `default` = ClassInfo(
        className: "",
        grade: "",
        headTeacher: "",
        subjects: ["语文", "数学", "英语", "物理", "化学", "生物", "政治", "历史", "地理"]
    )
}

// MARK: - 学生
struct Student: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var studentNumber: String      // 学号
    var gender: Gender
    var phone: String              // 学生电话
    var fatherName: String         // 父亲姓名
    var fatherPhone: String        // 父亲电话
    var motherName: String         // 母亲姓名
    var motherPhone: String        // 母亲电话
    var ethnicity: String          // 民族
    var birthDate: String          // 出生年月
    var idCardNumber: String       // 身份证号
    var address: String            // 家庭住址
    var groupNumber: Int           // 小组编号（1-4）
    var seatRow: Int               // 座位行（0=未分配）
    var seatCol: Int               // 座位列（0=未分配）
    var dormitory: String          // 宿舍号
    var latitude: Double?          // 家庭住址纬度（解析后保存）
    var longitude: Double?         // 家庭住址经度（解析后保存）
    var notes: String              // 备注

    enum Gender: String, Codable, CaseIterable {
        case male = "男"
        case female = "女"
    }

    init(id: UUID = UUID(), name: String, studentNumber: String = "", gender: Gender = .male,
         phone: String = "", fatherName: String = "", fatherPhone: String = "",
         motherName: String = "", motherPhone: String = "",
         ethnicity: String = "汉", birthDate: String = "", idCardNumber: String = "",
         address: String = "", groupNumber: Int = 1, seatRow: Int = 0, seatCol: Int = 0,
         dormitory: String = "", latitude: Double? = nil, longitude: Double? = nil, notes: String = "") {
        self.id = id
        self.name = name
        self.studentNumber = studentNumber
        self.gender = gender
        self.phone = phone
        self.fatherName = fatherName
        self.fatherPhone = fatherPhone
        self.motherName = motherName
        self.motherPhone = motherPhone
        self.ethnicity = ethnicity
        self.birthDate = birthDate
        self.idCardNumber = idCardNumber
        self.address = address
        self.groupNumber = groupNumber
        self.seatRow = seatRow
        self.seatCol = seatCol
        self.dormitory = dormitory
        self.latitude = latitude
        self.longitude = longitude
        self.notes = notes
    }
}

// MARK: - 考试
struct Exam: Identifiable, Codable {
    let id: UUID
    var name: String              // 考试名称，如"第一次月考"
    var type: ExamType
    var date: Date
    var subjects: [String]        // 考试科目
    var semesterId: UUID?         // 关联学期

    enum ExamType: String, Codable, CaseIterable {
        case unitTest = "单元测"
        case monthly = "月考"
        case midterm = "期中考"
        case final = "期末考"
    }

    init(id: UUID = UUID(), name: String, type: ExamType, date: Date = Date(),
         subjects: [String] = [], semesterId: UUID? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.date = date
        self.subjects = subjects
        self.semesterId = semesterId
    }
}

// MARK: - 成绩记录
struct ScoreRecord: Identifiable, Codable {
    let id: UUID
    var studentId: UUID
    var subject: String
    var examId: UUID              // 关联考试
    var score: Double             // 分数
    var fullScore: Double         // 满分（默认100）

    init(id: UUID = UUID(), studentId: UUID, subject: String, examId: UUID,
         score: Double, fullScore: Double = 100) {
        self.id = id
        self.studentId = studentId
        self.subject = subject
        self.examId = examId
        self.score = score
        self.fullScore = fullScore
    }
}

// MARK: - 课程
struct Course: Identifiable, Codable {
    let id: UUID
    var subject: String
    var dayOfWeek: Int            // 1=周一 ... 7=周日
    var period: Int               // 第几节
    var classroom: String
    var teacher: String

    init(id: UUID = UUID(), subject: String, dayOfWeek: Int, period: Int,
         classroom: String = "", teacher: String = "") {
        self.id = id
        self.subject = subject
        self.dayOfWeek = dayOfWeek
        self.period = period
        self.classroom = classroom
        self.teacher = teacher
    }

    // 根据节次返回时间字符串
    var timeString: String {
        let times = [
            1: "08:00-08:45",
            2: "08:55-09:40",
            3: "10:00-10:45",
            4: "10:55-11:40",
            5: "14:00-14:45",
            6: "14:55-15:40",
            7: "16:00-16:45",
            8: "16:55-17:40"
        ]
        return times[period] ?? "第\(period)节"
    }
}

// MARK: - 值日组
struct DutyGroup: Identifiable, Codable {
    let id: UUID
    var groupNumber: Int          // 组号（1-6）
    var studentIds: [UUID]        // 成员

    init(id: UUID = UUID(), groupNumber: Int, studentIds: [UUID] = []) {
        self.id = id
        self.groupNumber = groupNumber
        self.studentIds = studentIds
    }
}

// MARK: - 待办事项
struct TodoItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var dueDate: Date?
    var createdAt: Date
    var completedAt: Date?

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, dueDate: Date? = nil, createdAt: Date = Date(), completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
