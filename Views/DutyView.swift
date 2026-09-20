import SwiftUI

// 值日表
struct DutyView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var editingGroup: DutyGroup?

    private var sortedGroups: [DutyGroup] {
        viewModel.dutyGroups.sorted { $0.groupNumber < $1.groupNumber }
    }

    var body: some View {
        Group {
            if viewModel.dutyGroups.isEmpty {
                EmptyStateView(
                    systemImage: "broom",
                    title: "还没有值日组",
                    message: "点击右上角 + 创建值日组并安排成员"
                )
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        currentDutyCard
                        groupsSection
                    }
                    .padding()
                }
                .background(AppTheme.Colors.background)
            }
        }
        .navigationTitle("值日表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        let maxGroup = viewModel.dutyGroups.map(\.groupNumber).max() ?? 0
                        viewModel.addDutyGroup(DutyGroup(groupNumber: maxGroup + 1))
                    } label: {
                        Label("新建值日组", systemImage: "plus")
                    }
                    Button {
                        printDuty()
                    } label: {
                        Label("打印值日表", systemImage: "printer")
                    }
                    .disabled(viewModel.dutyGroups.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editingGroup) { group in
            NavigationStack {
                DutyGroupEditView(group: group)
            }
        }
    }

    private func printDuty() {
        let groups = sortedGroups.map { group -> (name: String, members: [String]) in
            let members = group.studentIds.compactMap { id in
                viewModel.students.first(where: { $0.id == id })?.name
            }
            return ("第\(group.groupNumber)组", members)
        }
        let currentIndex = sortedGroups.firstIndex(where: { $0.id == viewModel.currentDutyGroup?.id }) ?? 0
        PrintService.shared.printDuty(
            className: viewModel.classInfo.className,
            groups: groups,
            currentGroupIndex: currentIndex
        )
    }

    // 当前值日组
    private var currentDutyCard: some View {
        let current = viewModel.currentDutyGroup
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("当前值日")
                    .font(.headline)
                Spacer()
                Button("换下一组") {
                    withAnimation { viewModel.nextDutyGroup() }
                }
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.accent)
            }

            if let current = current {
                HStack(spacing: 14) {
                    Text("\(current.groupNumber)")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(AppTheme.Colors.accent)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("第\(current.groupNumber)值日组")
                            .font(.title3.weight(.semibold))
                        Text(viewModel.dutyStudentNames(of: current))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    // 组列表
    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("值日组")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(sortedGroups.enumerated()), id: \.element.id) { index, group in
                    Button {
                        editingGroup = group
                    } label: {
                        HStack(spacing: 12) {
                            Text("第\(group.groupNumber)组")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                                .frame(width: 72, alignment: .leading)
                            Text(viewModel.dutyStudentNames(of: group).isEmpty ? "未安排成员" : viewModel.dutyStudentNames(of: group))
                                .font(.subheadline)
                                .foregroundColor(viewModel.dutyStudentNames(of: group).isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteDutyGroup(group)
                        } label: {
                            Label("删除第\(group.groupNumber)组", systemImage: "trash")
                        }
                    }
                    if index < sortedGroups.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// 值日组编辑（成员多选）
struct DutyGroupEditView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let group: DutyGroup

    @State private var selectedIds: Set<UUID> = []

    var body: some View {
        Form {
            Section("第\(group.groupNumber)组 · 选择成员") {
                ForEach(viewModel.students) { student in
                    Button {
                        if selectedIds.contains(student.id) {
                            selectedIds.remove(student.id)
                        } else {
                            selectedIds.insert(student.id)
                        }
                    } label: {
                        HStack {
                            Text(student.name)
                            Spacer()
                            if selectedIds.contains(student.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppTheme.Colors.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("第\(group.groupNumber)值日组")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    if let i = viewModel.dutyGroups.firstIndex(where: { $0.id == group.id }) {
                        viewModel.dutyGroups[i].studentIds = Array(selectedIds)
                    }
                    dismiss()
                }
            }
        }
        .onAppear {
            selectedIds = Set(group.studentIds)
        }
    }
}
