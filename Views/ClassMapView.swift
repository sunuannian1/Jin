import SwiftUI
import MapKit
import CoreLocation

// 地图标注
struct StudentPin: Identifiable {
    let id: UUID
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
}

// 学生住址分布地图：优先用学生已保存的坐标，未解析的可批量解析
struct ClassMapView: View {
    @EnvironmentObject var viewModel: AppViewModel

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.87, longitude: 113.36),
        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
    )
    @State private var isGeocoding = false
    @State private var selectedStudent: Student?
    @State private var showBottomPanel = false

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
                                showBottomPanel = true
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.red)
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

                    // 底部操作/列表面板
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
            // 提取乡镇/小区名（取省市区后的第一段）
            let parts = addr.split(separator: "-")
            if parts.count >= 3 {
                return String(parts[2])
            }
            return addr
        })
        return areas.count
    }

    // 底部面板
    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // 拖拽指示条
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)

            if !studentsNeedGeocode.isEmpty && !isGeocoding {
                // 提示有未解析的地址
                Button {
                    Task { await geocodeAll() }
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(studentsNeedGeocode.count) 位学生地址未解析，点击解析")
                            .font(.footnote)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }

            // 学生列表
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.students) { student in
                        Button {
                            if student.latitude != nil && student.longitude != nil {
                                selectedStudent = student
                            }
                        } label: {
                            HStack(spacing: 12) {
                                StudentAvatar(name: student.name, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(student.name)
                                        .font(.body.weight(.medium))
                                        .foregroundColor(.primary)
                                    Text(student.address.isEmpty ? "未填写地址" : student.address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if student.latitude != nil && student.longitude != nil {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.red)
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
            .frame(maxHeight: 280)
            .background(AppTheme.Colors.cardBackground)
        }
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
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

    // MARK: - 地理编码（iOS 原生 CLGeocoder + 高德兜底）

    private let amapApiKey = "e0177c72e585f5718b4cdbc052918ecf"
    private let geocoder = CLGeocoder()

    // 地址预处理
    private func normalizedAddress(_ raw: String) -> String {
        var addr = raw.replacingOccurrences(of: "-", with: "")
        addr = addr.replacingOccurrences(of: "  ", with: " ")
        return addr.trimmingCharacters(in: .whitespaces)
    }

    // iOS 原生 CLGeocoder 解析
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

    // 高德地图 API 兜底解析
    private func geocodeWithAMap(_ address: String) async -> CLLocationCoordinate2D? {
        guard !amapApiKey.isEmpty else { return nil }
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        let urlStr = "https://restapi.amap.com/v3/geocode/geo?key=\(amapApiKey)&address=\(encoded)&city=平顶山"
        guard let url = URL(string: urlStr) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String, status == "1",
               let geocodes = json["geocodes"] as? [[String: Any]],
               let first = geocodes.first,
               let location = first["location"] as? String {
                let parts = location.split(separator: ",")
                if parts.count == 2,
                   let lon = Double(parts[0]),
                   let lat = Double(parts[1]) {
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    // 批量解析所有未解析的学生地址
    private func geocodeAll() async {
        guard !isGeocoding, !studentsNeedGeocode.isEmpty else { return }
        await MainActor.run { isGeocoding = true }

        for student in studentsNeedGeocode {
            let address = normalizedAddress(student.address)
            var coord: CLLocationCoordinate2D?

            // 先用 iOS 原生 CLGeocoder
            coord = await geocodeWithApple(address)

            // 失败则用高德兜底
            if coord == nil {
                coord = await geocodeWithAMap(address)
            }

            // 解析成功，保存坐标到学生数据
            if let coord = coord {
                if let index = viewModel.students.firstIndex(where: { $0.id == student.id }) {
                    viewModel.students[index].latitude = coord.latitude
                    viewModel.students[index].longitude = coord.longitude
                }
            }

            // 防限流，每个请求间隔 0.3 秒
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        await MainActor.run {
            isGeocoding = false
            viewModel.save()
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
