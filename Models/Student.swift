import Foundation

// MARK: - 班级信息
struct ClassInfo: Codable {
    var className: String
    var grade: String
    var headTeacher: String
    var subjects: [String]

    static let `default` = ClassInfo(
        className: "",
        grade: "",
        headTeacher: "",
        subjects: ["语文", "数学", "英语", "物理", "化学", "生物", "政治", "历史", "地理"]
    )
}

// MARK: - 监护人
struct Guardian: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var relation: String
    var name: String
    var phone: String
    init(id: UUID = UUID(), relation: String, name: String, phone: String) {
        self.id = id; self.relation = relation; self.name = name; self.phone = phone
    }
}

// MARK: - 学生
struct Student: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var studentNumber: String
    var gender: Gender
    var phone: String
    var fatherName: String
    var fatherPhone: String
    var motherName: String
    var motherPhone: String
    var guardians: [Guardian]
    var ethnicity: String
    var birthDate: String
    var idCardNumber: String
    var address: String
    var groupNumber: Int
    var seatRow: Int
    var seatCol: Int
    var dormitory: String
    var latitude: Double?
    var longitude: Double?
    var notes: String

    enum Gender: String, Codable, CaseIterable {
        case male = "男"
        case female = "女"
    }

    init(id: UUID = UUID(), name: String, studentNumber: String = "", gender: Gender = .male,
         phone: String = "", fatherName: String = "", fatherPhone: String = "",
         motherName: String = "", motherPhone: String = "",
         guardians: [Guardian] = [],
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
        self.guardians = guardians
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

    enum CodingKeys: String, CodingKey {
        case id, name, studentNumber, gender, phone, fatherName, fatherPhone,
             motherName, motherPhone, guardians, ethnicity, birthDate, idCardNumber,
             address, groupNumber, seatRow, seatCol, dormitory, latitude, longitude, notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        studentNumber = try c.decodeIfPresent(String.self, forKey: .studentNumber) ?? ""
        gender = try c.decodeIfPresent(Gender.self, forKey: .gender) ?? .male
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        fatherName = try c.decodeIfPresent(String.self, forKey: .fatherName) ?? ""
        fatherPhone = try c.decodeIfPresent(String.self, forKey: .fatherPhone) ?? ""
        motherName = try c.decodeIfPresent(String.self, forKey: .motherName) ?? ""
        motherPhone = try c.decodeIfPresent(String.self, forKey: .motherPhone) ?? ""
        if let g = try c.decodeIfPresent([Guardian].self, forKey: .guardians), !g.isEmpty {
            guardians = g
        } else {
            var gs: [Guardian] = []
            if !fatherName.isEmpty || !fatherPhone.isEmpty {
                gs.append(Guardian(relation: "爸爸", name: fatherName, phone: fatherPhone))
            }
            if !motherName.isEmpty || !motherPhone.isEmpty {
                gs.append(Guardian(relation: "妈妈", name: motherName, phone: motherPhone))
            }
            guardians = gs
        }
        ethnicity = try c.decodeIfPresent(String.self, forKey: .ethnicity) ?? "汉"
        birthDate = try c.decodeIfPresent(String.self, forKey: .birthDate) ?? ""
        idCardNumber = try c.decodeIfPresent(String.self, forKey: .idCardNumber) ?? ""
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        groupNumber = try c.decodeIfPresent(Int.self, forKey: .groupNumber) ?? 1
        seatRow = try c.decodeIfPresent(Int.self, forKey: .seatRow) ?? 0
        seatCol = try c.decodeIfPresent(Int.self, forKey: .seatCol) ?? 0
        dormitory = try c.decodeIfPresent(String.self, forKey: .dormitory) ?? ""
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

// MARK: - 考试
struct Exam: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: ExamType
    var date: Date
    var subjects: [String]
    var semesterId: UUID?

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
    var examId: UUID
    var score: Double
    var fullScore: Double

    init(id: UUID = UUID(), studentId: UUID, subject: String, examId: UUID,
         score: Double, fullScore: Double = 100) {
        self.id = id
        self.studentId = studentId
        self.subject = subject
        self.examId = examId
        self.score = score
        self.fullScore = fullScore
    }

    // 成绩唯一键：学生 + 考试 + 科目
    static func key(studentId: UUID, examId: UUID, subject: String) -> String {
        "\(studentId.uuidString)|\(examId.uuidString)|\(subject)"
    }
}

// MARK: - 课程
struct Course: Identifiable, Codable {
    let id: UUID
    var subject: String
    var dayOfWeek: Int
    var period: Int
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
    var groupNumber: Int
    var studentIds: [UUID]

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
