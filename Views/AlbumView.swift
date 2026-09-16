import SwiftUI
import PhotosUI
import UIKit

// MARK: - 班级相册主页（按分类分组 · 对齐网页相册 v2）
struct AlbumListView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var formMode: AlbumFormMode?

    // 置顶优先，其次名称；再按分类聚合（预设分类顺序，自定义分类追加）
    private var groupedFolders: [(String, [AlbumFolder])] {
        let sorted = viewModel.albumFolders.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
            return a.name < b.name
        }
        var order = AlbumCategory.all
        for folder in sorted where !order.contains(folder.category) { order.append(folder.category) }
        return order.compactMap { category in
            let items = sorted.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    private var totalPhotos: Int { viewModel.albumPhotos.count }
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        Group {
            if viewModel.albumFolders.isEmpty {
                EmptyStateView(
                    systemImage: "photo.on.rectangle.angled",
                    title: "还没有相册",
                    message: "点击右上角 + 新建相册，记录班级点滴",
                    buttonTitle: "新建相册"
                ) { formMode = .add }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 统计条
                        HStack(spacing: 6) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(viewModel.albumFolders.count) 个相册 · \(totalPhotos) 张照片")
                                .font(AppTheme.Fonts.footnote)
                            Spacer()
                        }
                        .foregroundColor(AppTheme.Colors.tertiaryText)
                        .padding(.horizontal, 4)

                        ForEach(groupedFolders, id: \.0) { category, folders in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill(AppTheme.Colors.accent)
                                        .frame(width: 4, height: 14)
                                    Text(category)
                                        .font(AppTheme.Fonts.title3)
                                        .foregroundColor(AppTheme.Colors.primaryText)
                                    Text("\(folders.count)")
                                        .font(AppTheme.Fonts.caption)
                                        .foregroundColor(AppTheme.Colors.tertiaryText)
                                    Spacer()
                                }
                                .padding(.horizontal, 4)

                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                                        NavigationLink {
                                            AlbumDetailView(folderId: folder.id)
                                        } label: {
                                            AlbumCard(folder: folder)
                                        }
                                        .buttonStyle(PressableButtonStyle(scale: 0.96))
                                        .contextMenu { albumMenu(for: folder) }
                                        .staggeredAppear(index: index, step: 0.05)
                                    }
                                }
                            }
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 32)
                }
                .background(AppTheme.Colors.background)
            }
        }
        .navigationTitle("班级相册")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { formMode = .add } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $formMode) { mode in
            NavigationStack { AlbumFormView(mode: mode) }
        }
    }

    @ViewBuilder
    private func albumMenu(for folder: AlbumFolder) -> some View {
        Button {
            viewModel.toggleAlbumPin(folder)
        } label: {
            Label(folder.isPinned ? "取消置顶" : "置顶相册",
                  systemImage: folder.isPinned ? "pin.slash" : "pin")
        }
        Button { formMode = .edit(folder) } label: { Label("编辑相册", systemImage: "pencil") }
        Button(role: .destructive) { viewModel.deleteAlbum(folder) } label: {
            Label("删除相册", systemImage: "trash")
        }
    }
}

// MARK: - 相册卡片（真实封面优先，无照片用稳定渐变）
struct AlbumCard: View {
    @EnvironmentObject var viewModel: AppViewModel
    let folder: AlbumFolder

    private var gradient: LinearGradient {
        let palette: [(Color, Color)] = [
            (.blue, .purple), (.orange, .pink), (.green, .mint),
            (.purple, .indigo), (.pink, .red), (.teal, .blue), (.yellow, .orange)
        ]
        var hash = 0
        for scalar in folder.name.unicodeScalars { hash = (hash &* 31 &+ Int(scalar.value)) & 0x7fffffff }
        let pair = palette[hash % palette.count]
        return LinearGradient(colors: [pair.0, pair.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var coverId: UUID? { viewModel.coverPhotoId(of: folder) }
    private var photoCount: Int { folder.photoIds.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let coverId {
                    PhotoThumbView(photoId: coverId)
                        .id(coverId)
                        .scaledToFill()
                } else {
                    gradient.overlay(
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundColor(.white.opacity(0.72))
                    )
                }
            }
            .frame(height: 104)
            .clipped()
            .overlay(alignment: .topTrailing) {
                if folder.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Circle().fill(.black.opacity(0.35)))
                        .padding(8)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Text("\(photoCount)")
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(.black.opacity(0.35)))
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                    .font(AppTheme.Fonts.headline)
                    .foregroundColor(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                Text(folder.desc?.isEmpty == false ? folder.desc! : folder.category)
                    .font(AppTheme.Fonts.caption2)
                    .foregroundColor(AppTheme.Colors.tertiaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous)
            .stroke(AppTheme.Colors.separator, lineWidth: 0.5))
        .rdShadow(AppTheme.Shadows.sm)
    }
}

// MARK: - 新建 / 编辑相册
enum AlbumFormMode: Identifiable {
    case add
    case edit(AlbumFolder)
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let f): return f.id.uuidString
        }
    }
}

struct AlbumFormView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let mode: AlbumFormMode

    @State private var name = ""
    @State private var category = AlbumCategory.all[0]
    @State private var desc = ""
    @State private var isPinned = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        Form {
            Section("相册信息") {
                TextField("相册名称（如：秋季运动会）", text: $name)
                Toggle("置顶该相册", isOn: $isPinned)
            }
            Section("相册分类") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AlbumCategory.all, id: \.self) { cat in
                            let active = cat == category
                            Button {
                                withAnimation(AppTheme.Motion.snappy) { category = cat }
                            } label: {
                                Text(cat)
                                    .font(AppTheme.Fonts.caption.weight(.semibold))
                                    .foregroundColor(active ? .white : AppTheme.Colors.secondaryText)
                                    .padding(.horizontal, 13).padding(.vertical, 7)
                                    .background(active ? AnyShapeStyle(AppTheme.Colors.accentGradient) : AnyShapeStyle(AppTheme.Colors.tertiaryGroupedBackground))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.93))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section {
                TextField("补充一句描述（可选）", text: $desc, axis: .vertical)
                    .lineLimit(2...5)
            } header: {
                Text("相册描述")
            } footer: {
                Text("创建后可在相册内添加照片、设置封面。")
            }
        }
        .navigationTitle(isEditing ? "编辑相册" : "新建相册")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if case .edit(let folder) = mode {
                name = folder.name
                category = AlbumCategory.all.contains(folder.category) ? folder.category : (AlbumCategory.all.first ?? category)
                desc = folder.desc ?? ""
                isPinned = folder.isPinned
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDesc = desc.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        switch mode {
        case .add:
            viewModel.addAlbum(name: trimmedName, category: category,
                               desc: trimmedDesc.isEmpty ? nil : trimmedDesc, isPinned: isPinned)
        case .edit(let folder):
            var updated = folder
            updated.name = trimmedName
            updated.category = category
            updated.desc = trimmedDesc.isEmpty ? nil : trimmedDesc
            updated.isPinned = isPinned
            viewModel.updateAlbum(updated)
        }
        dismiss()
    }
}

// MARK: - 相册内页（按日期分组照片流 + 选择模式）
struct AlbumDetailView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let folderId: UUID

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isAdding = false
    @State private var selectionMode = false
    @State private var selected: Set<UUID> = []
    @State private var browser: BrowserStart?
    @State private var formMode: AlbumFormMode?
    @State private var showMoveSheet = false
    @State private var confirmDelete = false

    private var folder: AlbumFolder? { viewModel.albumFolders.first { $0.id == folderId } }
    private var dateSections: [(date: Date, photos: [AlbumPhoto])] {
        guard let folder else { return [] }
        return viewModel.photosByDate(in: folder)
    }
    // 与网格一致的扁平顺序，供大图浏览
    private var orderedPhotos: [AlbumPhoto] { dateSections.flatMap { $0.photos } }
    private let gridColumns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]

    var body: some View {
        Group {
            if let folder {
                content(for: folder)
            } else {
                EmptyStateView(systemImage: "photo.on.rectangle.angled", title: "相册不存在", message: "该相册可能已被删除")
            }
        }
        .navigationTitle(folder?.name ?? "相册")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !selectionMode, folder != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { selectionMode = true } label: { Label("选择照片", systemImage: "checkmark.circle") }
                        Button { formMode = .edit(folder!) } label: { Label("编辑相册", systemImage: "pencil") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .sheet(item: $formMode) { mode in NavigationStack { AlbumFormView(mode: mode) } }
        .sheet(isPresented: $showMoveSheet) {
            NavigationStack { MovePhotosView(currentFolderId: folderId, photoIds: Array(selected)) { afterMove in
                if afterMove { selected.removeAll(); selectionMode = false }
            } }
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $browser) { start in
            PhotoBrowserView(photos: start.photos, initialId: start.initialId, folderId: start.folderId)
        }
        .confirmationDialog("确认删除选中的 \(selected.count) 张照片？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除 \(selected.count) 张", role: .destructive) { deleteSelected() }
            Button("取消", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func content(for folder: AlbumFolder) -> some View {
        let photos = orderedPhotos
        Group {
            if photos.isEmpty {
                EmptyStateView(
                    systemImage: "photo.badge.plus",
                    title: "相册还是空的",
                    message: "点击右下角 + 从相册选择照片",
                    buttonTitle: nil, buttonAction: nil
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                        albumHeader(for: folder)
                        ForEach(dateSections, id: \.date) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                dateHeader(section)
                                LazyVGrid(columns: gridColumns, spacing: 3) {
                                    ForEach(Array(section.photos.enumerated()), id: \.element.id) { index, photo in
                                        photoCell(photo, index: index)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, selectionMode ? 96 : 100)
                }
            }
        }
        .background(AppTheme.Colors.background)
        // 选择模式顶部条
        .safeAreaInset(edge: .top, spacing: 0) {
            if selectionMode { selectionTopBar }
        }
        // 选择模式底部操作条
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectionMode { selectionBottomBar }
        }
        // 浮动添加按钮（非选择模式）
        .overlay(alignment: .bottomTrailing) {
            if !selectionMode {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 54, height: 54)
                        .background(AppTheme.Colors.accentGradient)
                        .clipShape(Circle())
                        .rdShadow(AppTheme.Shadows.lg)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.9))
                .padding(20)
                .disabled(isAdding)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(AppTheme.Motion.smooth, value: selectionMode)
        .onChange(of: pickerItems) { items in
            guard !items.isEmpty else { return }
            isAdding = true
            let targetId = folder.id
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run { viewModel.addPhoto(data: data, folderId: targetId) }
                    }
                }
                await MainActor.run { pickerItems = []; isAdding = false }
            }
        }
    }

    // 相册头部横幅：全宽出血封面 + 整幅压暗 + 毛玻璃信息条（与下方照片墙同一条左右基准线）
    private func albumHeader(for folder: AlbumFolder) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let coverId = viewModel.coverPhotoId(of: folder) {
                PhotoThumbView(photoId: coverId)
                    .id(coverId)
            } else {
                LinearGradient(colors: [AppTheme.Colors.accent, AppTheme.Colors.accent.opacity(0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            // 整幅压暗：顶部轻、底部重，压住任何封面图的细节
            LinearGradient(colors: [.black.opacity(0.16), .black.opacity(0.42), .black.opacity(0.74)],
                           startPoint: .top, endPoint: .bottom)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(folder.name)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(orderedPhotos.count) 张照片")
                        .font(AppTheme.Fonts.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.82))
                }
                Spacer()
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(.ultraThinMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 0.5))
            .padding(14)
        }
        .frame(height: 170)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func dateHeader(_ section: (date: Date, photos: [AlbumPhoto])) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.Colors.accent)
            Text(albumSectionFmt.string(from: section.date))
                .font(AppTheme.Fonts.caption.weight(.semibold))
                .foregroundColor(AppTheme.Colors.primaryText)
            Spacer()
            Text("\(section.photos.count) 张")
                .font(AppTheme.Fonts.caption2.weight(.medium))
                .foregroundColor(AppTheme.Colors.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(AppTheme.Colors.cardBackground.opacity(0.9)))
    }

    private func photoCell(_ photo: AlbumPhoto, index: Int) -> some View {
        let isSelected = selected.contains(photo.id)
        return Button {
            if selectionMode {
                withAnimation(AppTheme.Motion.snappy) {
                    if isSelected { selected.remove(photo.id) } else { selected.insert(photo.id) }
                }
            } else {
                browser = BrowserStart(photos: orderedPhotos, initialId: photo.id, folderId: folderId)
            }
        } label: {
            ZStack {
                // 方形骨架：Color 配合 aspectRatio 稳定锁定 1:1 尺寸，
                // 图片作为 overlay 填充、不参与格子尺寸协商，竖图/横图都绝不会撑高或撑宽格子。
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(PhotoThumbView(photoId: photo.id))
                    .clipped()
                if selectionMode {
                    ZStack {
                        Circle().fill(.black.opacity(isSelected ? 0 : 0.25)).frame(maxWidth: .infinity, maxHeight: .infinity)
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isSelected ? AppTheme.Colors.accent : .white)
                            .background(Circle().fill(.white.opacity(isSelected ? 1 : 0)).frame(width: 22, height: 22))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(6)
                    }
                    .transition(.opacity)
                }
            }
            .clipped()
            .overlay(
                Rectangle()
                    .stroke(AppTheme.Colors.accent, lineWidth: isSelected ? 2.5 : 0)
            )
            .scaleEffect(isSelected ? 0.94 : 1)
            .animation(AppTheme.Motion.snappy, value: isSelected)
        }
        .buttonStyle(.plain)
        .staggeredAppear(index: index, step: 0.02)
    }

    // 选择模式顶栏
    private var selectionTopBar: some View {
        HStack {
            Button("取消") {
                withAnimation(AppTheme.Motion.smooth) { selected.removeAll(); selectionMode = false }
            }
            .foregroundColor(AppTheme.Colors.secondaryText)
            Spacer()
            Text(selected.isEmpty ? "选择照片" : "已选 \(selected.count) 张")
                .font(AppTheme.Fonts.headline)
                .foregroundColor(AppTheme.Colors.primaryText)
            Spacer()
            Button(selected.count == orderedPhotos.count ? "取消全选" : "全选") {
                withAnimation(AppTheme.Motion.snappy) {
                    if selected.count == orderedPhotos.count { selected.removeAll() }
                    else { selected = Set(orderedPhotos.map { $0.id }) }
                }
            }
            .foregroundColor(AppTheme.Colors.accent)
        }
        .font(AppTheme.Fonts.callout)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // 选择模式底栏
    private var selectionBottomBar: some View {
        HStack(spacing: 10) {
            selectionAction(icon: "folder", title: "移动", enabled: !selected.isEmpty) { showMoveSheet = true }
            selectionAction(icon: "square.and.arrow.down", title: "保存", enabled: !selected.isEmpty) { saveSelected() }
            selectionAction(icon: "trash", title: "删除", isDestructive: true, enabled: !selected.isEmpty) { confirmDelete = true }
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 20)
        .background(.ultraThinMaterial)
    }

    private func selectionAction(icon: String, title: String, isDestructive: Bool = false, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title).font(AppTheme.Fonts.caption2.weight(.medium))
            }
            .foregroundColor(!enabled ? AppTheme.Colors.tertiaryText : (isDestructive ? AppTheme.Colors.red : AppTheme.Colors.primaryText))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .disabled(!enabled)
        .buttonStyle(PressableButtonStyle(scale: 0.94))
    }

    private func saveSelected() {
        let images = selected.compactMap { id in viewModel.photoData(id: id).flatMap(UIImage.init(data:)) }
        guard !images.isEmpty else { return }
        let group = DispatchGroup()
        for image in images {
            group.enter()
            ImageSaver.shared.save(image) { _ in group.leave() }
        }
        group.notify(queue: .main) {
            withAnimation(AppTheme.Motion.smooth) { selected.removeAll(); selectionMode = false }
        }
    }

    private func deleteSelected() {
        let targets = orderedPhotos.filter { selected.contains($0.id) }
        viewModel.deletePhotos(targets)
        selected.removeAll()
        selectionMode = false
    }
}

// 大图浏览启动参数
struct BrowserStart: Identifiable {
    let id = UUID()
    let photos: [AlbumPhoto]
    let initialId: UUID
    let folderId: UUID
}

private let albumSectionFmt: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy年M月d日 EEEE"; return f
}()

// MARK: - 照片缩略图（从本地存储加载，带缓存）
// 注意：内部禁止使用 maxHeight: .infinity —— 在 LazyVGrid 中会让竖长图按原始比例
// 撑高、溢出方形格子，导致照片互相重叠；裁切与对齐一律交给外层 aspectRatio + clipped。
struct PhotoThumbView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let photoId: UUID
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle()
                    .fill(AppTheme.Colors.subtleBackground)
                    .overlay(ProgressView().scaleEffect(0.8))
            }
        }
        .onAppear {
            if image == nil {
                image = viewModel.photoData(id: photoId).flatMap(UIImage.init(data:))
            }
        }
    }
}

// MARK: - 全屏大图浏览（左右滑动 + 双击/捏合缩放 + 描述/分享/封面/删除）
struct PhotoBrowserView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let photos: [AlbumPhoto]
    let initialId: UUID
    let folderId: UUID

    @State private var localPhotos: [AlbumPhoto]
    @State private var currentId: UUID?
    @State private var chromeHidden = false
    @State private var editingCaption = false
    @State private var captionDraft = ""
    @State private var showInfo = false
    @State private var toast: String?

    init(photos: [AlbumPhoto], initialId: UUID, folderId: UUID) {
        self.photos = photos
        self.initialId = initialId
        self.folderId = folderId
        _localPhotos = State(initialValue: photos)
        _currentId = State(initialValue: initialId)
    }

    private var current: AlbumPhoto? { localPhotos.first { $0.id == currentId } }
    private var currentIndex: Int { localPhotos.firstIndex { $0.id == currentId } ?? 0 }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentId) {
                ForEach(localPhotos) { photo in
                    ZoomablePhoto(photoId: photo.id) {
                        withAnimation(AppTheme.Motion.quick) { chromeHidden.toggle() }
                    }
                    .tag(Optional(photo.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // 顶部栏
            VStack {
                topBar
                Spacer()
                bottomBar
            }
            .opacity(chromeHidden ? 0 : 1)
            .animation(AppTheme.Motion.quick, value: chromeHidden)

            // 轻提示
            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(AppTheme.Fonts.footnote)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Capsule().fill(.black.opacity(0.72)))
                        .padding(.bottom, 110)
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true)
        .alert("编辑描述", isPresented: $editingCaption) {
            TextField("为这张照片写点什么…", text: $captionDraft)
            Button("取消", role: .cancel) {}
            Button("保存") { saveCaption() }
        }
        .sheet(isPresented: $showInfo) {
            if let current { NavigationStack { PhotoInfoSheet(photo: current) } }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.black.opacity(0.4)))
            }
            Spacer()
            if localPhotos.count > 1 {
                Text("\(currentIndex + 1) / \(localPhotos.count)")
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(.black.opacity(0.4)))
            }
            Spacer()
            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.black.opacity(0.4)))
            }
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if let current {
                Text(current.note.isEmpty ? "添加描述…" : current.note)
                    .font(AppTheme.Fonts.footnote)
                    .foregroundColor(current.note.isEmpty ? .white.opacity(0.6) : .white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.black.opacity(0.4)))
                    .onTapGesture { captionDraft = current.note; editingCaption = true }
            }

            HStack(spacing: 0) {
                toolItem(icon: "square.and.arrow.up", title: "分享") { shareCurrent() }
                toolItem(icon: "square.and.arrow.down", title: "保存") { saveCurrent() }
                toolItem(icon: "photo.on.rectangle", title: "封面") { setCover() }
                toolItem(icon: "trash", title: "删除", isDestructive: true) { deleteCurrent() }
            }
            .background(Capsule().fill(.black.opacity(0.4)))
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
    }

    private func toolItem(icon: String, title: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 18, weight: .regular))
                Text(title).font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isDestructive ? Color(red: 1, green: 0.45, blue: 0.45) : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func currentImage() -> UIImage? {
        guard let current else { return nil }
        return viewModel.photoData(id: current.id).flatMap(UIImage.init(data:))
    }

    private func shareCurrent() {
        guard let image = currentImage() else { return }
        presentShare([image])
    }

    private func saveCurrent() {
        guard let image = currentImage() else { return }
        ImageSaver.shared.save(image) { ok in
            showToast(ok ? "已保存到手机相册" : "保存失败")
        }
    }

    private func setCover() {
        guard let current else { return }
        viewModel.setAlbumCover(folderId: folderId, photoId: current.id)
        showToast("已设为相册封面")
    }

    private func saveCaption() {
        guard let current else { return }
        var updated = current
        updated.note = captionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.updatePhoto(updated)
        if let i = localPhotos.firstIndex(where: { $0.id == current.id }) { localPhotos[i] = updated }
    }

    private func deleteCurrent() {
        guard let current else { return }
        viewModel.deletePhoto(current)
        guard let idx = localPhotos.firstIndex(where: { $0.id == current.id }) else { return }
        localPhotos.remove(at: idx)
        if localPhotos.isEmpty {
            dismiss()
        } else {
            currentId = localPhotos[min(idx, localPhotos.count - 1)].id
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { toast = nil }
        }
    }
}

// 可缩放的单张大图（UIScrollView 原生缩放：捏合缩放 + 双击切换 + 放大后平移回弹）
struct ZoomablePhoto: View {
    @EnvironmentObject var viewModel: AppViewModel
    let photoId: UUID
    var onTap: () -> Void = {}
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                PhotoZoomView(image: image, onSingleTap: onTap)
                    .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear {
            if image == nil { image = viewModel.photoData(id: photoId).flatMap(UIImage.init(data:)) }
        }
    }
}

// UIScrollView 包装：捏合缩放 / 双击切换 / 放大平移，丝滑回弹（机制参考 MIT 开源 Ceylo/Zoomable）
struct PhotoZoomView: UIViewControllerRepresentable {
    let image: UIImage
    var onSingleTap: () -> Void = {}

    func makeUIViewController(context: Context) -> PhotoZoomVC {
        PhotoZoomVC(image: image, onSingleTap: onSingleTap)
    }
    func updateUIViewController(_ ui: PhotoZoomVC, context: Context) {
        ui.onSingleTap = onSingleTap
    }
}

final class PhotoZoomVC: UIViewController, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var didInitialFit = false
    var onSingleTap: () -> Void = {}

    init(image: UIImage, onSingleTap: @escaping () -> Void) {
        self.onSingleTap = onSingleTap
        super.init(nibName: nil, bundle: nil)
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black

        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // 双击缩放；单击切换 chrome（单击需等待双击判定失败）
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(doubleTap)
        scrollView.addGestureRecognizer(singleTap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didInitialFit, scrollView.bounds.width > 0 {
            didInitialFit = true
            applyFit()
        }
        centerContent()
    }

    private func applyFit() {
        guard let size = imageView.image?.size, size.width > 0, size.height > 0 else { return }
        let fit = min(scrollView.bounds.width / size.width, scrollView.bounds.height / size.height)
        scrollView.minimumZoomScale = fit
        scrollView.maximumZoomScale = max(4, fit)
        scrollView.zoomScale = fit
        imageView.frame = CGRect(origin: .zero, size: CGSize(width: size.width * fit, height: size.height * fit))
        scrollView.contentSize = imageView.frame.size
        centerContent()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerContent() }

    private func centerContent() {
        let boundsSize = scrollView.bounds.size
        let contentSize = imageView.frame.size
        let offsetX = max((boundsSize.width - contentSize.width) * 0.5, 0)
        let offsetY = max((boundsSize.height - contentSize.height) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)
    }

    @objc private func handleSingleTap() { onSingleTap() }

    @objc private func handleDoubleTap() {
        let current = scrollView.zoomScale
        let target: CGFloat
        if current <= scrollView.minimumZoomScale * 1.01 {
            target = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2.5)
        } else {
            target = scrollView.minimumZoomScale
        }
        scrollView.setZoomScale(target, animated: true)
    }
}

// 照片信息面板
struct PhotoInfoSheet: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let photo: AlbumPhoto

    private var imageSize: String {
        guard let data = viewModel.photoData(id: photo.id),
              let img = UIImage(data: data) else { return "—" }
        return "\(Int(img.size.width)) × \(Int(img.size.height))"
    }
    private var fileSize: String {
        guard let data = viewModel.photoData(id: photo.id) else { return "—" }
        let mb = Double(data.count) / 1024 / 1024
        return mb >= 1 ? String(format: "%.1f MB", mb) : "\(data.count / 1024) KB"
    }

    var body: some View {
        Form {
            Section("照片") {
                PhotoThumbView(photoId: photo.id)
                    .id(photo.id)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }
            Section("信息") {
                LabeledContent("添加时间", value: photo.date.formatted(.dateTime.year().month().day().hour().minute()))
                LabeledContent("分辨率", value: imageSize)
                LabeledContent("文件大小", value: fileSize)
                LabeledContent("描述", value: photo.note.isEmpty ? "无" : photo.note)
            }
        }
        .navigationTitle("照片信息")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
    }
}

// MARK: - 移动照片到其他相册
struct MovePhotosView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let currentFolderId: UUID
    let photoIds: [UUID]
    let completion: (Bool) -> Void

    private var targets: [AlbumFolder] {
        viewModel.albumFolders
            .filter { $0.id != currentFolderId }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        Group {
            if targets.isEmpty {
                EmptyStateView(systemImage: "folder.badge.questionmark", title: "没有其他相册",
                               message: "请先新建一个相册，再移动照片")
            } else {
                List {
                    Section("移动 \(photoIds.count) 张照片到") {
                        ForEach(targets) { folder in
                            Button {
                                viewModel.movePhotos(photoIds, to: folder.id)
                                completion(true)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(AppTheme.Colors.accent.opacity(0.12))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(AppTheme.Colors.accent)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(folder.name).font(AppTheme.Fonts.callout).foregroundColor(AppTheme.Colors.primaryText)
                                        Text(folder.category).font(AppTheme.Fonts.caption2).foregroundColor(AppTheme.Colors.tertiaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(AppTheme.Colors.tertiaryText)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("移动到相册")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { completion(false); dismiss() } } }
    }
}

// MARK: - 保存图片到系统相册
final class ImageSaver: NSObject {
    static let shared = ImageSaver()
    private var completion: ((Bool) -> Void)?

    func save(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        self.completion = completion
        UIImageWriteToSavedPhotosAlbum(image, self,
                                       #selector(saved(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc private func saved(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        DispatchQueue.main.async { self.completion?(error == nil); self.completion = nil }
    }
}

// MARK: - 系统分享
func presentShare(_ items: [Any]) {
    let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
    var top = root
    while let presented = top.presentedViewController { top = presented }
    top.present(activity, animated: true)
}
