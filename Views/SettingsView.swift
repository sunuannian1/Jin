import SwiftUI

// 班级设置
struct SettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var className = ""
    @State private var grade = ""
    @State private var headTeacher = ""
    @State private var subjects: [String] = []
    @State private var newSubject = ""
    @State private var showImporter = false
    @State private var exportURL: URL?
    @State private var message: String?
    @State private var showMessage = false

    var body: some View {
        Form {
            Section("班级信息") {
                TextField("班级名（如：高一（2）班）", text: $className)
                TextField("年级（如：高一）", text: $grade)
                TextField("班主任姓名", text: $headTeacher)
            }
            Section("开设科目") {
                ForEach(subjects, id: \.self) { subject in
                    Text(subject)
                }
                .onDelete(perform: deleteSubject)

                HStack {
                    TextField("添加科目", text: $newSubject)
                    Button("添加") {
                        let trimmed = newSubject.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty && !subjects.contains(trimmed) {
                            subjects.append(trimmed)
                        }
                        newSubject = ""
                    }
                    .disabled(newSubject.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("分享备份文件", systemImage: "square.and.arrow.up")
                    }
                    Button("重新生成备份") { generateExport() }
                } else {
                    Button("导出备份", systemImage: "square.and.arrow.up") { generateExport() }
                }
                Button("导入备份", systemImage: "square.and.arrow.down") { showImporter = true }
            } header: {
                Text("数据备份")
            } footer: {
                Text("导出为一个压缩备份文件（含学生、成绩、相册及全部照片），可通过微信/邮件/文件 App 保存或转移。导入将整体覆盖当前数据。")
            }
            Section {
                Button("保存设置") {
                    viewModel.updateClassInfo(
                        className: className.trimmingCharacters(in: .whitespaces),
                        grade: grade.trimmingCharacters(in: .whitespaces),
                        headTeacher: headTeacher.trimmingCharacters(in: .whitespaces),
                        subjects: subjects
                    )
                    dismiss()
                }
                .disabled(className.trimmingCharacters(in: .whitespaces).isEmpty)
            } footer: {
                Text("科目将用于考试、课表等功能的选择。保存后立即生效并自动持久化。")
            }
        }
        .navigationTitle("班级设置")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data]) { result in
            switch result {
            case .success(let url):
                if viewModel.importBackup(from: url) { message = "导入成功" }
                else { message = "导入失败，请选择正确的备份文件" }
                showMessage = true
            case .failure:
                message = "未能读取文件"; showMessage = true
            }
        }
        .alert("提示", isPresented: $showMessage, presenting: message) { _ in
            Button("好", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
        .onAppear(perform: load)
    }

    private func generateExport() {
        guard let raw = viewModel.makeBackupData() else {
            message = "没有可导出的数据"; showMessage = true; return
        }
        let compressed = (raw as NSData).compressed(using: .zlib) ?? raw
        let fmt = DateFormatter(); fmt.locale = Locale(identifier: "zh_CN"); fmt.dateFormat = "yyyyMMdd-HHmm"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("班主任备份-\(fmt.string(from: Date())).backup")
        do {
            try compressed.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            message = "导出失败：\(error.localizedDescription)"; showMessage = true
        }
    }

    private func load() {
        className = viewModel.classInfo.className
        grade = viewModel.classInfo.grade
        headTeacher = viewModel.classInfo.headTeacher
        subjects = viewModel.classInfo.subjects
    }

    private func deleteSubject(at offsets: IndexSet) {
        subjects.remove(atOffsets: offsets)
    }
}
