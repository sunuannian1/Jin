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

    // 叶县默认坐标（解析失败时兜底）
    private let yexianCoordinate = CLLocationCoordinate2D(latitude: 33.87, longitude: 113.36)

    // 地址预处理：去掉横杠，加上中国前缀，提高中文地址解析率
    private func normalizedAddress(_ raw: String) -> String {
        var addr = raw.replacingOccurrences(of: "-", with: "")
        addr = addr.replacingOccurrences(of: "  ", with: " ")
        if !addr.hasPrefix("中国") {
            addr = "中国" + addr
        }
        return addr
    }

    // CLGeocoder 需逐个串行请求，加间隔防限流，失败用叶县坐标兜底
    private func geocodeAll() async {
        guard pins.isEmpty, !isGeocoding, !studentsWithAddress.isEmpty else { return }
        await MainActor.run { isGeocoding = true }
        let geocoder = CLGeocoder()
        var resolved: [AddressPin] = []
        var failures: [String] = []

        for (index, student) in studentsWithAddress.enumerated() {
            let address = student.address
            let normalized = normalizedAddress(address)
            do {
                let placemarks = try await geocoder.geocodeAddressString(normalized)
                if let location = placemarks.first?.location {
                    resolved.append(AddressPin(name: student.name, address: address, coordinate: location.coordinate))
                } else {
                    // 解析不到精确地址，用叶县坐标兜底，仍标注学生
                    resolved.append(AddressPin(name: student.name, address: address, coordinate: yexianCoordinate))
                    failures.append(address)
                }
            } catch {
                resolved.append(AddressPin(name: student.name, address: address, coordinate: yexianCoordinate))
                failures.append(address)
            }
            // 每 5 个请求后暂停 1 秒，防 CLGeocoder 限流
            if (index + 1) % 5 == 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
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
