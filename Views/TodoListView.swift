import SwiftUI

// 待办事项列表（按日期分组，历史记录永久保存）
struct TodoListView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingAdd = false
    @State private var newTitle = ""
    @State private var newDueDate = Date()
    @State private var hasDueDate = false

    var body: some View {
        Group {
            if viewModel.todos.isEmpty {
                EmptyStateView(
                    systemImage: "checklist",
                    title: "还没有待办事项",
                    message: "点击右上角 + 添加待办"
                )
            } else {
                List {
                    ForEach(viewModel.todosByDate, id: \.date) { group in
                        Section {
                            ForEach(group.items) { todo in
                                todoRow(todo)
                            }
                        } header: {
                            HStack {
                                Text(dateTitle(group.date))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                let completed = group.items.filter { $0.isCompleted }.count
                                Text("\(completed)/\(group.items.count) 已完成")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("待办事项")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("添加待办", isPresented: $showingAdd) {
            TextField("待办内容", text: $newTitle)
            Toggle("设置截止日期", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker("截止日期", selection: $newDueDate, displayedComponents: .date)
            }
            Button("取消", role: .cancel) {
                newTitle = ""
                hasDueDate = false
            }
            Button("添加") {
                let title = newTitle.trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    viewModel.addTodo(title: title, dueDate: hasDueDate ? newDueDate : nil)
                }
                newTitle = ""
                hasDueDate = false
            }
        }
    }

    @ViewBuilder
    private func todoRow(_ todo: TodoItem) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    viewModel.toggleTodo(todo)
                }
            } label: {
                ZStack {
                    if todo.isCompleted {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppTheme.Colors.accent)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.body)
                    .foregroundColor(todo.isCompleted ? .secondary : .primary)
                    .strikethrough(todo.isCompleted, color: .secondary)
                HStack(spacing: 8) {
                    if let due = todo.dueDate {
                        Label(due.formatted(.dateTime.month().day()), systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(isOverdue(todo) ? .red : .secondary)
                    }
                    if let completedAt = todo.completedAt {
                        Label("完成于 \(completedAt.formatted(.dateTime.month().day().hour().minute()))", systemImage: "checkmark.circle")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            Spacer()
            Button(role: .destructive) {
                viewModel.deleteTodo(todo)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func dateTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.isDateInTomorrow(date) {
            return "明天"
        } else {
            return date.formatted(.dateTime.year().month().day().weekday(.wide))
        }
    }

    private func isOverdue(_ todo: TodoItem) -> Bool {
        guard !todo.isCompleted, let due = todo.dueDate else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }
}
