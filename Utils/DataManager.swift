import Foundation
import UIKit
import ImageIO

// 数据持久化管理：所有数据存 Documents 目录 JSON 文件
class DataManager {
    static let shared = DataManager()

    private let fileManager = FileManager.default

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func fileURL(_ name: String) -> URL {
        documentsURL.appendingPathComponent("\(name).json")
    }

    // MARK: - 通用读写
    private func load<T: Decodable>(_ name: String) -> T? {
        let url = fileURL(name)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: fileURL(name), options: .atomic)
    }

    // 是否已有保存数据（用于判断首次启动）
    var hasSavedData: Bool {
        fileManager.fileExists(atPath: fileURL("classInfo").path)
    }

    // MARK: - 各数据读写
    func loadClassInfo() -> ClassInfo? { load("classInfo") }
    func saveClassInfo(_ v: ClassInfo) { save(v, to: "classInfo") }

    func loadStudents() -> [Student]? { load("students") }
    func saveStudents(_ v: [Student]) { save(v, to: "students") }

    func loadSemesters() -> [Semester]? { load("semesters") }
    func saveSemesters(_ v: [Semester]) { save(v, to: "semesters") }

    func loadExams() -> [Exam]? { load("exams") }
    func saveExams(_ v: [Exam]) { save(v, to: "exams") }

    func loadScores() -> [ScoreRecord]? { load("scores") }
    func saveScores(_ v: [ScoreRecord]) { save(v, to: "scores") }

    func loadCourses() -> [Course]? { load("courses") }
    func saveCourses(_ v: [Course]) { save(v, to: "courses") }

    func loadDutyGroups() -> [DutyGroup]? { load("dutyGroups") }
    func saveDutyGroups(_ v: [DutyGroup]) { save(v, to: "dutyGroups") }

    func loadTodos() -> [TodoItem]? { load("todos") }
    func saveTodos(_ v: [TodoItem]) { save(v, to: "todos") }

    func loadNotifications() -> [NotificationItem]? { load("notifications") }
    func saveNotifications(_ v: [NotificationItem]) { save(v, to: "notifications") }

    func loadNotificationTemplates() -> [NotificationTemplate]? { load("notificationTemplates") }
    func saveNotificationTemplates(_ v: [NotificationTemplate]) { save(v, to: "notificationTemplates") }

    func loadAlbumFolders() -> [AlbumFolder]? { load("albumFolders") }
    func saveAlbumFolders(_ v: [AlbumFolder]) { save(v, to: "albumFolders") }

    func loadAlbumPhotos() -> [AlbumPhoto]? { load("albumPhotos") }
    func saveAlbumPhotos(_ v: [AlbumPhoto]) { save(v, to: "albumPhotos") }

    // MARK: - 照片二进制（单独存文件，避免 JSON 过大）
    private var photosDirectory: URL {
        documentsURL.appendingPathComponent("Photos", isDirectory: true)
    }

    func savePhotoData(_ data: Data, id: UUID) {
        let dir = photosDirectory
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try? data.write(to: dir.appendingPathComponent(id.uuidString), options: .atomic)
    }

    func loadPhotoData(id: UUID) -> Data? {
        try? Data(contentsOf: photosDirectory.appendingPathComponent(id.uuidString))
    }

    // MARK: - 图片解码（读盘 + 解码都不在主线程调用；缩略图带内存缓存）

    // 原先 PhotoThumbView 每次 onAppear 都在主线程解码全尺寸 JPEG（注释写了"带缓存"但并无实现），
    // 一张原图解码动辄几十毫秒，相册一屏十几张、回滚还会重解 —— 掉帧的主因。
    private static let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        return cache
    }()

    func loadThumbnail(id: UUID, maxPixelSize: CGFloat) -> UIImage? {
        let key = "\(id.uuidString)@\(Int(maxPixelSize))" as NSString
        if let cached = Self.thumbnailCache.object(forKey: key) { return cached }
        guard let data = try? Data(contentsOf: photosDirectory.appendingPathComponent(id.uuidString)) else { return nil }
        let sourceOptions: [AnyHashable: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData,
                                                       (sourceOptions as NSDictionary) as CFDictionary) else { return nil }
        let thumbnailOptions: [AnyHashable: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0,
                                                                (thumbnailOptions as NSDictionary) as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cgImage)
        Self.thumbnailCache.setObject(image, forKey: key)
        return image
    }

    // 原图：全屏缩放浏览需要保留分辨率，所以不降采样、也不进缓存（避免驻留大位图）
    func loadFullImage(id: UUID) -> UIImage? {
        guard let data = try? Data(contentsOf: photosDirectory.appendingPathComponent(id.uuidString)) else { return nil }
        return UIImage(data: data)
    }

    func clearThumbnailCache() {
        Self.thumbnailCache.removeAllObjects()
    }

    func deletePhotoData(id: UUID) {
        try? fileManager.removeItem(at: photosDirectory.appendingPathComponent(id.uuidString))
    }

    private func deleteAllPhotoFiles() {
        try? fileManager.removeItem(at: photosDirectory)
    }

    // MARK: - 数据管理
    // 导出全部数据为 JSON（用于备份/迁移，包含照片二进制）
    func exportAllData() -> Data? {
        var photoFiles: [String: Data] = [:]
        if let photos = loadAlbumPhotos() {
            for photo in photos {
                if let data = loadPhotoData(id: photo.id) {
                    photoFiles[photo.id.uuidString] = data
                }
            }
        }
        let classInfo = loadClassInfo() ?? .default
        let students = loadStudents() ?? []
        let exams = loadExams() ?? []
        let scoreRecords = loadScores() ?? []
        let courses = loadCourses() ?? []
        let dutyGroups = loadDutyGroups() ?? []
        let todos = loadTodos() ?? []
        let notifications = loadNotifications() ?? []
        let albumFolders = loadAlbumFolders() ?? []
        let albumPhotos = loadAlbumPhotos() ?? []
        let semesters = loadSemesters() ?? []
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

    // 导入备份：写回照片文件
    func importPhotoFiles(_ files: [String: Data]) {
        for (id, data) in files {
            guard let uuid = UUID(uuidString: id) else { continue }
            savePhotoData(data, id: uuid)
        }
        // 同 id 的原图已被备份覆盖，缓存里是旧像素
        clearThumbnailCache()
    }

    // 清空全部数据
    func clearAllData() {
        for name in ["classInfo", "students", "exams", "scores", "courses", "dutyGroups", "todos", "notifications", "albumFolders", "albumPhotos"] {
            try? fileManager.removeItem(at: fileURL(name))
        }
        deleteAllPhotoFiles()
        clearThumbnailCache()
    }
}
