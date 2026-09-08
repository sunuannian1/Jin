import SwiftUI
import MapKit
import CoreLocation

// 地图标注
struct StudentPin: Identifiable {
    let id: UUID
    let name: String
    let gender: Student.Gender
    let address: String
    let coordinate: CLLocationCoordinate2D
}

// 学生住址分布地图
struct ClassMapView: View {
    @EnvironmentObject var viewModel: AppViewModel

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.87, longitude: 113.36),
        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
    )
    @State private var isGeocoding = false
    @State private var selectedStudent: Student?
    @State private var panelExpanded = false  // 抽屉是否展开，默认收起

    // 有坐标的学生
    private var studentsWithCoord: [Student] {
        viewModel.students.filter { $0.latitude != nil && $0.longitude != nil }
    }

    // 有地址但没坐标的学生（需要解析）
    private var studentsNeedGeocode: [Student] {
        viewModel.students.filter {
            !$0.address.trimmingCharacters(in: .whitespaces).isEmpty
            && ($0.latitude == nil || $0.longitude == nil)
        }
    }

    // 地图标注
    private var pins: [StudentPin] {
        studentsWithCoord.map { stu in
            StudentPin(
                id: stu.id,
                name: stu.name,
                gender: stu.gender,
                address: stu.address,
                coordinate: CLLocationCoordinate2D(latitude: stu.latitude!, longitude: stu.longitude!)
            )
        }
    }

    var body: some View {
        Group {
            if viewModel.students.isEmpty {
                EmptyStateView(
                    systemImage: "map",
                    title: "没有学生数据",
                    message: "请先添加学生或导入数据"
                )
            } else {
                ZStack(alignment: .bottom) {
                    // 全屏地图
                    Map(coordinateRegion: $region, annotationItems: pins) { pin in
                        MapAnnotation(coordinate: pin.coordinate) {
                            Button {
                                selectedStudent = viewModel.students.first { $0.id == pin.id }
                                panelExpanded = true
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(pin.gender == .female ? .pink : .blue)
                                    Text(pin.name)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)

                    // 顶部统计条
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                Text("\(studentsWithCoord.count)")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(AppTheme.Colors.accent)
                                Text("位学生 ·")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(areaCount)")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.blue)
                                Text("个小区")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            Spacer()
                        }
                        .padding(.top, 12)
                        Spacer()
                    }

                    // 图例（粉蓝区分男女）
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("男")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.pink)
                                        .font(.caption)
                                    Text("女")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.trailing, 16)
                            .padding(.bottom, panelExpanded ? 320 : 70)
                        }
                    }

                    // 底部可收起抽屉
                    bottomPanel
                }
            }
        }
        .navigationTitle("分布地图")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !studentsNeedGeocode.isEmpty {
                    Button {
                        Task { await geocodeAll() }
                    } label: {
                        if isGeocoding {
                            ProgressView()
                        } else {
                            Label("解析地址", systemImage: "location.magnifyingglass")
                        }
                    }
                    .disabled(isGeocoding)
                }
            }
        }
        .onAppear { fitRegion() }
        .sheet(item: $selectedStudent) { student in
            StudentDetailView(studentId: student.id)
        }
    }

    // 统计不同小区/村庄数量
    private var areaCount: Int {
        let areas = Set(studentsWithCoord.map { stu -> String in
            let addr = stu.address
            let parts = addr.split(separator: "-")
            if parts.count >= 3 {
                return String(parts[2])
            }
            return addr
        })
        return areas.count
    }

    // 底部抽屉面板（可收起）
    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // 顶部拖拽条 + 标题（始终可见，点击切换展开）
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    panelExpanded.toggle()
                }
            } label: {
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)

                    HStack {
                        Text("学生列表")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        if !studentsNeedGeocode.isEmpty && !isGeocoding {
                            Text("\(studentsNeedGeocode.count) 位未解析")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        Image(systemName: panelExpanded ? "chevron.down" : "chevron.up")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
            }
            .buttonStyle(.plain)

            // 展开时显示内容
            if panelExpanded {
                // 选中学生的导航按钮
                if let selected = selectedStudent,
                   let lat = selected.latitude, let lon = selected.longitude {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.name)
                                .font(.subheadline.weight(.semibold))
                            Text(selected.address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            openNavigation(for: selected)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                Text("导航")
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.Colors.accent)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    Divider()
                }

                // 学生列表
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.students) { student in
                            Button {
                                if student.latitude != nil && student.longitude != nil {
                                    selectedStudent = student
                                    // 移动地图到该学生
                                    withAnimation {
                                        region = MKCoordinateRegion(
                                            center: CLLocationCoordinate2D(latitude: student.latitude!, longitude: student.longitude!),
                                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                        )
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    StudentAvatar(name: student.name, size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(student.name)
                                                .font(.body.weight(.medium))
                                                .foregroundColor(.primary)
                                            Circle()
                                                .fill(student.gender == .female ? Color.pink : Color.blue)
                                                .frame(width: 6, height: 6)
                                        }
                                        Text(student.address.isEmpty ? "未填写地址" : student.address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if student.latitude != nil && student.longitude != nil {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(student.gender == .female ? .pink : .blue)
                                    } else if !student.address.isEmpty {
                                        Image(systemName: "clock")
                                            .foregroundColor(.orange)
                                    } else {
                                        Image(systemName: "minus.circle")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
    }

    // 打开系统地图导航
    private func openNavigation(for student: Student) {
        guard let lat = student.latitude, let lon = student.longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = student.name + "的家"
        mapItem.openMaps(with: [mapItem], launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    // 调整地图区域以显示所有标注
    private func fitRegion() {
        guard !pins.isEmpty else { return }
        let lats = pins.map { $0.coordinate.latitude }
        let lons = pins.map { $0.coordinate.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.8, 0.05),
            longitudeDelta: max((maxLon - minLon) * 1.8, 0.05)
        )
        region = MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - 地理编码（高德优先，精准定位）

    private let amapApiKey = "e0177c72e585f5718b4cdbc052918ecf"
    private let geocoder = CLGeocoder()

    // 地址预处理：确保完整地址格式
    private func normalizedAddress(_ raw: String) -> String {
        var addr = raw.replacingOccurrences(of: "-", with: "")
        addr = addr.replacingOccurrences(of: "  ", with: " ")
        addr = addr.trimmingCharacters(in: .whitespaces)
        // 如果地址不含"河南省"，补上
        if !addr.contains("河南") && !addr.contains("平顶山") {
            addr = "河南省平顶山市" + addr
        } else if !addr.contains("河南") && addr.contains("平顶山") {
            addr = "河南省" + addr
        }
        return addr
    }

    // 高德地图 API 解析（优先，精准）
    private func geocodeWithAMap(_ address: String) async -> CLLocationCoordinate2D? {
        guard !amapApiKey.isEmpty else { return nil }
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        let urlStr = "https://restapi.amap.com/v3/geocode/geo?key=\(amapApiKey)&address=\(encoded)&city=平顶山&citylimit=true"
        guard let url = URL(string: urlStr) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String, status == "1",
               let geocodes = json["geocodes"] as? [[String: Any]],
               let first = geocodes.first,
               let location = first["location"] as? String,
               let level = first["level"] as? String {
                let parts = location.split(separator: ",")
                if parts.count == 2,
                   let lon = Double(parts[0]),
                   let lat = Double(parts[1]) {
                    // 优先使用门牌号/POI级别的精准结果
                    if level.contains("门牌号") || level.contains("POI") || level.contains("兴趣点") {
                        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    }
                    // 乡镇级别也接受
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    // iOS 原生 CLGeocoder 兜底
    private func geocodeWithApple(_ address: String) async -> CLLocationCoordinate2D? {
        return await withCheckedContinuation { continuation in
            geocoder.geocodeAddressString(address) { placemarks, error in
                if let location = placemarks?.first?.location {
                    continuation.resume(returning: location.coordinate)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // 批量解析所有未解析的学生地址（高德优先）
    private func geocodeAll() async {
        guard !isGeocoding, !studentsNeedGeocode.isEmpty else { return }
        await MainActor.run { isGeocoding = true }

        for student in studentsNeedGeocode {
            let address = normalizedAddress(student.address)
            var coord: CLLocationCoordinate2D?

            // 优先用高德（中国大陆精准）
            coord = await geocodeWithAMap(address)

            // 高德失败则用 Apple 兜底
            if coord == nil {
                coord = await geocodeWithApple(address)
            }

            // 解析成功，保存坐标到学生数据
            if let coord = coord {
                if let index = viewModel.students.firstIndex(where: { $0.id == student.id }) {
                    viewModel.students[index].latitude = coord.latitude
                    viewModel.students[index].longitude = coord.longitude
                }
            }

            // 防限流，每个请求间隔 0.4 秒
            try? await Task.sleep(nanoseconds: 400_000_000)
        }

        await MainActor.run {
            isGeocoding = false
            fitRegion()
        }
    }
}

// 圆角扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
