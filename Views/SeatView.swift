import SwiftUI
import UniformTypeIdentifiers

// 座位表（真实教室布局：黑板、讲台、中间过道、窗户）
struct SeatView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var draggedStudent: Student?

    // 每组列数（左右各一组）
    private let colsPerGroup = 4
    // 总列数 = 左组 + 过道 + 右组
    private var totalCols: Int { colsPerGroup * 2 + 1 } // +1 是过道

    // 动态行数
    private var rows: Int {
        guard !viewModel.students.isEmpty else { return 1 }
        return Int(ceil(Double(viewModel.students.count) / Double(colsPerGroup * 2)))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 教室顶部：窗户标注
                HStack {
                    Label("窗户", systemImage: "window.ceiling")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Label("门", systemImage: "door.left.hand.open")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

                // 黑板
                VStack(spacing: 4) {
                    Text("黑  板")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Text("———————————————")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(colors: [Color(red: 0.25, green: 0.45, blue: 0.32), Color(red: 0.2, green: 0.38, blue: 0.28)], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.horizontal, 24)

                // 讲台
                HStack {
                    Spacer()
                    Text("讲  台")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 100, height: 22)
                        .background(AppTheme.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Spacer()
                }
                .padding(.top, 6)
                .padding(.bottom, 12)

                // 提示信息
                HStack {
                    Text("共 \(viewModel.students.count) 人")
                    Text("·")
                    Text("\(rows)排 × 8座")
                    Text("·")
                    Text("长按拖动交换")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)

                // 座位区域（左右两组 + 中间过道）
                VStack(spacing: 6) {
                    ForEach(1...rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            // 左组座位
                            ForEach(1...colsPerGroup, id: \.self) { col in
                                seatCell(row: row, col: col, group: .left)
                            }

                            // 中间过道
                            Text("过\n道")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary.opacity(0.5))
                                .frame(width: 20, height: 52)
                                .background(Color.gray.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                            // 右组座位
                            ForEach(1...colsPerGroup, id: \.self) { col in
                                seatCell(row: row, col: col + colsPerGroup, group: .right)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)

                // 教室后部：窗户标注
                HStack {
                    Label("窗户", systemImage: "window.ceiling")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("后  门")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // 图例
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.accent.opacity(0.15))
                            .frame(width: 14, height: 14)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppTheme.Colors.accent.opacity(0.4), lineWidth: 1))
                        Text("男生")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.pink.opacity(0.12))
                            .frame(width: 14, height: 14)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.pink.opacity(0.5), lineWidth: 1))
                        Text("女生")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: 14, height: 14)
                        Text("空座")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 16)
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

    private enum SeatGroup { case left, right }

    // 获取指定座位的学生
    private func studentAt(row: Int, col: Int) -> Student? {
        viewModel.students.first { $0.seatRow == row && $0.seatCol == col }
    }

    // 座位格子
    @ViewBuilder
    private func seatCell(row: Int, col: Int, group: SeatGroup) -> some View {
        let student = studentAt(row: row, col: col)
        let isDragging = draggedStudent?.id == student?.id

        Group {
            if let student = student {
                VStack(spacing: 1) {
                    Text(student.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(row)排\(col)座")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(student.gender == .female ? Color.pink.opacity(0.12) : AppTheme.Colors.accent.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(student.gender == .female ? Color.pink.opacity(0.5) : AppTheme.Colors.accent.opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .scaleEffect(isDragging ? 1.15 : 1.0)
                .shadow(color: isDragging ? .black.opacity(0.25) : .clear, radius: isDragging ? 10 : 0)
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
                // 空座位
                VStack(spacing: 1) {
                    Image(systemName: "person")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("\(row)排\(col)座")
                        .font(.system(size: 7))
                        .foregroundColor(.gray.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.gray.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                )
                .onDrop(of: [UTType.text], delegate: SeatDropDelegate(
                    targetRow: row,
                    targetCol: col,
                    viewModel: viewModel,
                    draggedStudent: $draggedStudent
                ))
            }
        }
        .padding(.horizontal, 2)
    }

    // 自动排座：按学生顺序填满所有座位（S型排列更真实）
    private func autoAssign() {
        let sorted = viewModel.students.sorted { s1, s2 in
            if s1.seatRow != s2.seatRow { return s1.seatRow < s2.seatRow }
            if s1.seatCol != s2.seatCol { return s1.seatCol < s2.seatCol }
            return s1.name < s2.name
        }
        var index = 0
        for row in 1...rows {
            // 左组 1-4
            for col in 1...colsPerGroup {
                guard index < sorted.count else { return }
                if let i = viewModel.students.firstIndex(where: { $0.id == sorted[index].id }) {
                    viewModel.students[i].seatRow = row
                    viewModel.students[i].seatCol = col
                }
                index += 1
            }
            // 右组 5-8
            for col in (colsPerGroup + 1)...(colsPerGroup * 2) {
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
