import SwiftUI

// 首页功能入口管理 — 显隐 + 排序
struct HomeFeatureManagerView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.editMode) private var editMode

    private var visibleFeatures: [AppViewModel.HomeFeature] {
        viewModel.visibleHomeFeatures
    }

    private var hiddenFeatures: [AppViewModel.HomeFeature] {
        viewModel.homeFeatures.filter { !$0.isVisible }.sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            Section {
                ForEach(visibleFeatures) { feature in
                    featureRow(feature: feature, isVisible: true)
                }
                .onMove { source, destination in
                    viewModel.moveFeature(from: source, to: destination)
                }
            } header: {
                HStack {
                    Text("已显示（\(visibleFeatures.count)）")
                    Spacer()
                    if visibleFeatures.count > 1 {
                        EditButton()
                            .font(.caption)
                    }
                }
            }

            if !hiddenFeatures.isEmpty {
                Section {
                    ForEach(hiddenFeatures) { feature in
                        featureRow(feature: feature, isVisible: false)
                    }
                } header: {
                    Text("已隐藏（\(hiddenFeatures.count)）")
                }
            }

            Section {
                Button(role: .destructive) {
                    viewModel.resetHomeFeatures()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("恢复默认布局")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("首页布局")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.Colors.background)
    }

    private func featureRow(feature: AppViewModel.HomeFeature, isVisible: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isVisible ? AppTheme.Colors.accent.opacity(0.15) : AppTheme.Colors.subtleBackground)
                    .frame(width: 36, height: 36)
                Image(systemName: feature.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isVisible ? AppTheme.Colors.accent : AppTheme.Colors.tertiaryText)
            }

            Text(feature.name)
                .font(AppTheme.Fonts.body)
                .foregroundColor(isVisible ? AppTheme.Colors.primaryText : AppTheme.Colors.tertiaryText)

            Spacer()

            Button {
                viewModel.toggleFeature(feature)
            } label: {
                Image(systemName: isVisible ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isVisible ? AppTheme.Colors.accent : AppTheme.Colors.tertiaryText)
                    .frame(width: 32, height: 32)
                    .background(isVisible ? AppTheme.Colors.accentSoft : AppTheme.Colors.subtleBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
