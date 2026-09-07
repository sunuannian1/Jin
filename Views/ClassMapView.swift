import SwiftUI
import MapKit
import CoreLocation

// 地图标注
struct AddressPin: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
}

// 学生住址分布地图：打开时逐个解析地址并落标记
struct ClassMapView: View {
    @EnvironmentObject var viewModel: AppViewModel

    @State private var pins: [AddressPin] = []
    @State private var failedAddresses: [String] = []
    @State private var isGeocoding = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.87, longitude: 113.36),
        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
    )

    private var studentsWithAddress: [Student] {
        viewModel.students.filter { !$0.address.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        Group {
            if studentsWithAddress.isEmpty {
                EmptyStateView(
                    systemImage: "map",
                    title: "没有可显示的住址",
                    message: "请先在学生资料中填写家庭住址"
                )
            } else {
                VStack(spacing: 0) {
                    mapSection
                    statusSection
                    addressList
                }
            }
        }
        .navigationTitle("分布地图")
        .navigationBarTitleDisplayMode(.inline)
        .task { await geocodeAll() }
    }

    private var mapSection: some View {
        Map(coordinateRegion: $region, annotationItems: pins) { pin in
            MapAnnotation(coordinate: pin.coordinate) {
                VStack(spacing: 2) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    Text(pin.name)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .frame(minHeight: 280)
    }

    @ViewBuilder
    private var statusSection: some View {
        HStack {
            if isGeocoding {
                ProgressView()
                    .padding(.trailing, 4)
                Text("正在解析学生住址…")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.footnote)
                Text("已标注 \(pins.count)/\(studentsWithAddress.count) 位学生住址")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                if !failedAddresses.isEmpty {
                    Text("（\(failedAddresses.count) 个地址无法解析）")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(AppTheme.Colors.cardBackground)
    }

    private var addressList: some View {
        List {
            ForEach(studentsWithAddress) { student in
                HStack(spacing: 12) {
                    StudentAvatar(name: student.name, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(student.name)
                            .font(.body.weight(.medium))
                        Text(student.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if pins.contains(where: { $0.name == student.name && $0.address == student.address }) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                    } else if failedAddresses.contains(student.address) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.secondary)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.insetGrouped)
    }

    // 高德地图 Web 服务 API Key（在 https://lbs.amap.com 申请，选"Web服务"类型）
    private let amapApiKey = "e0177c72e585f5718b4cdbc052918ecf"
    // 叶县默认坐标（解析失败时兜底）
    private let yexianCoordinate = CLLocationCoordinate2D(latitude: 33.87, longitude: 113.36)

    // 地址预处理：去掉横杠，整理为标准地址格式
    private func normalizedAddress(_ raw: String) -> String {
        var addr = raw.replacingOccurrences(of: "-", with: "")
        addr = addr.replacingOccurrences(of: "  ", with: " ")
        return addr.trimmingCharacters(in: .whitespaces)
    }

    // 调用高德地图地理编码 API，精准定位中国大陆地址
    private func geocodeWithAMap(_ address: String) async -> CLLocationCoordinate2D? {
        guard !amapApiKey.isEmpty, amapApiKey != "e0177c72e585f5718b4cdbc052918ecf" else { return nil }
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        let urlStr = "https://restapi.amap.com/v3/geocode/geo?key=\(amapApiKey)&address=\(encoded)&city=平顶山"
        guard let url = URL(string: urlStr) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
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

    // 逐个调用高德 API 解析地址，失败用叶县坐标兜底
    private func geocodeAll() async {
        guard pins.isEmpty, !isGeocoding, !studentsWithAddress.isEmpty else { return }
        await MainActor.run { isGeocoding = true }
        var resolved: [AddressPin] = []
        var failures: [String] = []

        for (index, student) in studentsWithAddress.enumerated() {
            let address = student.address
            let normalized = normalizedAddress(address)
            if let coord = await geocodeWithAMap(normalized) {
                resolved.append(AddressPin(name: student.name, address: address, coordinate: coord))
            } else {
                // 高德解析失败，用叶县坐标兜底
                resolved.append(AddressPin(name: student.name, address: address, coordinate: yexianCoordinate))
                failures.append(address)
            }
            // 高德 QPS 限制，每 5 个请求暂停 0.5 秒
            if (index + 1) % 5 == 0 {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        await MainActor.run {
            pins = resolved
            failedAddresses = Array(Set(failures))
            isGeocoding = false
            fitRegion(to: resolved)
        }
    }

    // 让所有标记尽量都落在可视范围内
    private func fitRegion(to pins: [AddressPin]) {
        guard !pins.isEmpty else { return }
        let lats = pins.map { $0.coordinate.latitude }
        let lons = pins.map { $0.coordinate.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        var span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.02),
            longitudeDelta: max((maxLon - minLon) * 1.6, 0.02)
        )
        // 防止跨度异常
        span.latitudeDelta = min(span.latitudeDelta, 90)
        span.longitudeDelta = min(span.longitudeDelta, 180)
        region = MKCoordinateRegion(center: center, span: span)
    }
}
