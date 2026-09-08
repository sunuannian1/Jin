import SwiftUI
import UniformTypeIdentifiers

// 座位表（动态数量 + 拖拽调整）
struct SeatView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var draggedStudent: Student?

    // 动态列数，根据学生数量自适应
    private var cols: Int {
        let count = viewModel.students.count
        if count <= 30 { return 6 }
        if count <= 48 { return 7 }
        return 8
    }

    // 动态行数
    private var rows: Int {
        guard !viewModel.students.isEmpty else { return 1 }
        return Int(ceil(Double(viewModel.students.count) / Double(cols)))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // 讲台
                Text("讲台")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 260)
                    .padding(.vertical, 12)
                    .background(AppTheme.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.bottom, 8)

                // 提示
                Text("共 \(viewModel.students.count) 人 · \(rows)排\(cols)列 · 长按拖动可交换座位")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)

                // 座位网格
                VStack(spacing: 6) {
                    ForEach(1...rows, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(1...cols, id: \.self) { col in
                                if row * cols - cols + col <= viewModel.students.count || studentAt(row: row, col: col) != nil {
                                    seatCell(row: row, col: col)
                                } else {
                                    Color.clear
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 54)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("座位表")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("自动排座") {
                    autoAssign()
                }
                .disabled(viewModel.students.isEmpty)
            }
        }
    }

    // 获取指定座位的学生
    private func studentAt(row: Int, col: Int) -> Student? {
        viewModel.students.first { $0.seatRow == row && $0.seatCol == col }
    }

    // 座位格子
    @ViewBuilder
    private func seatCell(row: Int, col: Int) -> some View {
        let student = studentAt(row: row, col: col)
        let isDragging = draggedStudent?.id == student?.id

        Group {
            if let student = student {
                VStack(spacing: 2) {
                    Text(student.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("#\(student.studentNumber)")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(student.gender == .female ? Color.pink.opacity(0.12) : AppTheme.Colors.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(student.gender == .female ? Color.pink.opacity(0.5) : AppTheme.Colors.accent.opacity(0.4), lineWidth: 1)
                )
                .scaleEffect(isDragging ? 1.1 : 1.0)
                .shadow(color: isDragging ? .black.opacity(0.2) : .clear, radius: isDragging ? 8 : 0)
                .onDrag {
                    draggedStudent = student
                    return NSItemProvider(object: student.id.uuidString as NSString)
                }
                .onDrop(of: [UTType.text], delegate: SeatDropDelegate(
                    targetRow: row,
                    targetCol: col,
                    viewModel: viewModel,
                    draggedStudent: $draggedStudent
                ))
            } else {
                Rectangle()
                    .fill(AppTheme.Colors.cardBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
                    .onDrop(of: [UTType.text], delegate: SeatDropDelegate(
                        targetRow: row,
                        targetCol: col,
                        viewModel: viewModel,
                        draggedStudent: $draggedStudent
                    ))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // 自动排座：按学生顺序填满所有座位
    private func autoAssign() {
        let sorted = viewModel.students.sorted { s1, s2 in
            // 先按座位号排，没座位的排后面
            if s1.seatRow != s2.seatRow { return s1.seatRow < s2.seatRow }
            if s1.seatCol != s2.seatCol { return s1.seatCol < s2.seatCol }
            return s1.name < s2.name
        }
        var index = 0
        for row in 1...rows {
            for col in 1...cols {
                guard index < sorted.count else { return }
                if let i = viewModel.students.firstIndex(where: { $0.id == sorted[index].id }) {
                    viewModel.students[i].seatRow = row
                    viewModel.students[i].seatCol = col
                }
                index += 1
            }
        }
    }
}

// 拖拽接收代理
struct SeatDropDelegate: DropDelegate {
    let targetRow: Int
    let targetCol: Int
    let viewModel: AppViewModel
    @Binding var draggedStudent: Student?

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [UTType.text]).first else { return false }
        item.loadObject(ofClass: NSString.self) { provider, error in
            guard let idString = provider as? String,
                  let uuid = UUID(uuidString: idString),
                  let dragged = viewModel.students.first(where: { $0.id == uuid }) else {
                DispatchQueue.main.async { draggedStudent = nil }
                return
            }
            DispatchQueue.main.async {
                // 找到目标座位的学生
                if let target = viewModel.students.first(where: { $0.seatRow == targetRow && $0.seatCol == targetCol }) {
                    // 交换两个学生的座位
                    if let draggedIndex = viewModel.students.firstIndex(where: { $0.id == dragged.id }),
                       let targetIndex = viewModel.students.firstIndex(where: { $0.id == target.id }) {
                        let tempRow = viewModel.students[draggedIndex].seatRow
                        let tempCol = viewModel.students[draggedIndex].seatCol
                        viewModel.students[draggedIndex].seatRow = targetRow
                        viewModel.students[draggedIndex].seatCol = targetCol
                        viewModel.students[targetIndex].seatRow = tempRow
                        viewModel.students[targetIndex].seatCol = tempCol
                    }
                } else {
                    // 目标座位为空，直接移动
                    if let draggedIndex = viewModel.students.firstIndex(where: { $0.id == dragged.id }) {
                        viewModel.students[draggedIndex].seatRow = targetRow
                        viewModel.students[draggedIndex].seatCol = targetCol
                    }
                }
                draggedStudent = nil
            }
        }
        return true
    }

    func dropEntered(info: DropInfo) {}
    func dropExited(info: DropInfo) {}
}
