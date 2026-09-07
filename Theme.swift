import SwiftUI
import UIKit

// MARK: - 高级设计系统
// 现代编辑体 + 暖纸质感 · 参考 Things 3 / Apple News / Linear
enum AppTheme {

    // MARK: - 主题定义
    enum Theme: String, CaseIterable, Identifiable {
        case warmOrange = "暖阳橙"
        case deepBlue = "深海蓝"
        case forestGreen = "森林绿"
        case duskPurple = "暮山紫"

        var id: String { rawValue }

        var accent: Color {
            switch self {
            case .warmOrange: return Color(red: 0.76, green: 0.25, blue: 0.05)   // #C2410C
            case .deepBlue: return Color(red: 0.13, green: 0.38, blue: 0.65)      // #1D4ED8 偏深
            case .forestGreen: return Color(red: 0.10, green: 0.45, blue: 0.28)   // #166534
            case .duskPurple: return Color(red: 0.42, green: 0.24, blue: 0.58)    // #6B21A8
            }
        }

        var accentSoft: Color {
            switch self {
            case .warmOrange: return Color(red: 1.0, green: 0.97, blue: 0.93)
            case .deepBlue: return Color(red: 0.93, green: 0.96, blue: 1.0)
            case .forestGreen: return Color(red: 0.93, green: 0.98, blue: 0.95)
            case .duskPurple: return Color(red: 0.97, green: 0.94, blue: 1.0)
            }
        }

        var accentGradient: LinearGradient {
            switch self {
            case .warmOrange:
                return LinearGradient(colors: [Color(red: 0.76, green: 0.25, blue: 0.05),
                                                Color(red: 0.92, green: 0.35, blue: 0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
            case .deepBlue:
                return LinearGradient(colors: [Color(red: 0.13, green: 0.38, blue: 0.65),
                                                Color(red: 0.20, green: 0.48, blue: 0.78)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
            case .forestGreen:
                return LinearGradient(colors: [Color(red: 0.10, green: 0.45, blue: 0.28),
                                                Color(red: 0.15, green: 0.55, blue: 0.35)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
            case .duskPurple:
                return LinearGradient(colors: [Color(red: 0.42, green: 0.24, blue: 0.58),
                                                Color(red: 0.52, green: 0.30, blue: 0.70)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    // MARK: - 当前主题（从 UserDefaults 读取，默认暖阳橙）
    static var currentTheme: Theme {
        get {
            let saved = UserDefaults.standard.string(forKey: "appTheme") ?? ""
            return Theme(rawValue: saved) ?? .warmOrange
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "appTheme")
        }
    }

    // MARK: - 动态颜色辅助
    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }

    // MARK: - 颜色
    enum Colors {
        // 背景层（动态深色模式）
        static let background = dynamicColor(
            light: UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1),       // #F5F2ED 暖纸
            dark: UIColor(red: 0.11, green: 0.10, blue: 0.09, alpha: 1)         // #1C1917 深暖棕
        )
        static let cardBackground = dynamicColor(
            light: .white,
            dark: UIColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 1)         // #292524
        )
        static let subtleBackground = dynamicColor(
            light: UIColor(red: 0.93, green: 0.91, blue: 0.89, alpha: 1),       // #EDE9E2
            dark: UIColor(red: 0.23, green: 0.21, blue: 0.20, alpha: 1)         // #3A3634
        )
        static let groupedBackground = dynamicColor(
            light: UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1),
            dark: UIColor(red: 0.11, green: 0.10, blue: 0.09, alpha: 1)
        )
        static let secondaryGroupedBackground = dynamicColor(
            light: .white,
            dark: UIColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 1)
        )
        static let tertiaryGroupedBackground = dynamicColor(
            light: UIColor(red: 0.93, green: 0.91, blue: 0.89, alpha: 1),
            dark: UIColor(red: 0.23, green: 0.21, blue: 0.20, alpha: 1)
        )

        // 文字层（三级字阶，动态）
        static let primaryText = dynamicColor(
            light: UIColor(red: 0.11, green: 0.10, blue: 0.09, alpha: 1),        // #1C1917
            dark: UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1)          // #FAFAF9
        )
        static let secondaryText = dynamicColor(
            light: UIColor(red: 0.34, green: 0.33, blue: 0.31, alpha: 1),        // #57534E
            dark: UIColor(red: 0.66, green: 0.64, blue: 0.62, alpha: 1)          // #A8A29E
        )
        static let tertiaryText = dynamicColor(
            light: UIColor(red: 0.66, green: 0.64, blue: 0.62, alpha: 1),        // #A8A29E
            dark: UIColor(red: 0.47, green: 0.44, blue: 0.42, alpha: 1)          // #78716C
        )

        // 分割线（动态）
        static let separator = dynamicColor(
            light: UIColor.black.withAlphaComponent(0.08),
            dark: UIColor.white.withAlphaComponent(0.10)
        )
        static let opaqueSeparator = dynamicColor(
            light: UIColor.black.withAlphaComponent(0.12),
            dark: UIColor.white.withAlphaComponent(0.15)
        )

        // 强调色（动态主题，深色模式下提亮）
        static var accent: Color {
            dynamicColor(
                light: UIColor(currentTheme.accent),
                dark: UIColor(currentTheme.accent).adjustedBrightness(by: 0.15)
            )
        }
        static var accentSoft: Color {
            dynamicColor(
                light: UIColor(currentTheme.accentSoft),
                dark: UIColor(currentTheme.accent).withAlphaComponent(0.15)
            )
        }
        static var accentGradient: LinearGradient { currentTheme.accentGradient }

        // 功能色（深色模式下微调）
        static let blue = dynamicColor(
            light: UIColor(red: 0.21, green: 0.44, blue: 0.87, alpha: 1),
            dark: UIColor(red: 0.40, green: 0.60, blue: 0.95, alpha: 1)
        )
        static let green = dynamicColor(
            light: UIColor(red: 0.13, green: 0.55, blue: 0.33, alpha: 1),
            dark: UIColor(red: 0.30, green: 0.70, blue: 0.45, alpha: 1)
        )
        static let orange = dynamicColor(
            light: UIColor(red: 0.90, green: 0.42, blue: 0.10, alpha: 1),
            dark: UIColor(red: 0.95, green: 0.55, blue: 0.20, alpha: 1)
        )
        static let red = dynamicColor(
            light: UIColor(red: 0.85, green: 0.20, blue: 0.18, alpha: 1),
            dark: UIColor(red: 0.95, green: 0.35, blue: 0.30, alpha: 1)
        )
        static let purple = dynamicColor(
            light: UIColor(red: 0.55, green: 0.30, blue: 0.75, alpha: 1),
            dark: UIColor(red: 0.70, green: 0.45, blue: 0.85, alpha: 1)
        )
        static let pink = dynamicColor(
            light: UIColor(red: 0.85, green: 0.30, blue: 0.50, alpha: 1),
            dark: UIColor(red: 0.95, green: 0.45, blue: 0.65, alpha: 1)
        )
        static let yellow = dynamicColor(
            light: UIColor(red: 0.90, green: 0.72, blue: 0.10, alpha: 1),
            dark: UIColor(red: 0.95, green: 0.80, blue: 0.25, alpha: 1)
        )
        static let mint = dynamicColor(
            light: UIColor(red: 0.20, green: 0.65, blue: 0.60, alpha: 1),
            dark: UIColor(red: 0.35, green: 0.75, blue: 0.70, alpha: 1)
        )
        static let teal = Color(red: 0.10, green: 0.55, blue: 0.55)
        static let indigo = Color(red: 0.30, green: 0.30, blue: 0.70)
        static let brown = Color(red: 0.55, green: 0.38, blue: 0.25)
        static let gray = Color(red: 0.55, green: 0.55, blue: 0.57)
        static let gray2 = Color(red: 0.65, green: 0.65, blue: 0.67)
        static let gray3 = Color(red: 0.75, green: 0.75, blue: 0.77)
        static let gray4 = Color(red: 0.82, green: 0.82, blue: 0.84)
        static let gray5 = Color(red: 0.90, green: 0.90, blue: 0.92)
        static let gray6 = Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    // MARK: - 字阶（建立断崖）
    enum Fonts {
        static let display = Font.system(size: 34, weight: .heavy)
        static let largeTitle = Font.system(size: 28, weight: .heavy)
        static let title = Font.system(size: 22, weight: .bold)
        static let title2 = Font.system(size: 17, weight: .semibold)
        static let title3 = Font.system(size: 15, weight: .semibold)
        static let headline = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 15, weight: .regular)
        static let callout = Font.system(size: 14, weight: .regular)
        static let subheadline = Font.system(size: 13, weight: .regular)
        static let footnote = Font.system(size: 12, weight: .regular)
        static let caption = Font.system(size: 11, weight: .regular)
        static let caption2 = Font.system(size: 10, weight: .regular)

        // 数字专用（等宽数字）
        static let statNumber = Font.system(size: 36, weight: .heavy).monospacedDigit()
        static let statNumberSmall = Font.system(size: 24, weight: .bold).monospacedDigit()
    }

    // MARK: - 间距
    enum Spacing {
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let large: CGFloat = 18
        static let xLarge: CGFloat = 22
        static let xxLarge: CGFloat = 28
        static let xxxLarge: CGFloat = 36
    }

    // MARK: - 圆角（角色分工）
    enum CornerRadius {
        static let card: CGFloat = 22          // 大卡片
        static let element: CGFloat = 14       // 中元素
        static let button: CGFloat = 10        // 按钮
        static let small: CGFloat = 8          // 小元素
        static let pill: CGFloat = 999         // 胶囊
    }

    // MARK: - 阴影（柔和多层）
    enum Shadows {
        static let sm = Shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        static let md = Shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 2)
        static let lg = Shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 4)
        static let accent = Shadow(color: currentTheme.accent.opacity(0.28), radius: 12, x: 0, y: 4)
    }

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - View 扩展：便捷应用阴影
extension View {
    func rdShadow(_ shadow: AppTheme.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - 通用卡片容器
struct Card<Content: View>: View {
    var padding: CGFloat = AppTheme.Spacing.large
    var onClick: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if let onClick = onClick {
                Button(action: onClick) { contentBody }
                    .buttonStyle(.plain)
            } else {
                contentBody
            }
        }
    }

    private var contentBody: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .stroke(AppTheme.Colors.separator, lineWidth: 0.5)
            )
            .rdShadow(AppTheme.Shadows.sm)
    }
}

// MARK: - 区块标题
struct SectionHeader: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xSmall) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accent)
            }
            Text(title)
                .font(AppTheme.Fonts.title2)
                .foregroundColor(AppTheme.Colors.primaryText)
                .tracking(-0.3)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.top, AppTheme.Spacing.large)
        .padding(.bottom, AppTheme.Spacing.small)
    }
}

// MARK: - 统计卡片（支持主卡/次卡）
struct StatCard: View {
    let value: String
    let label: String
    let systemImage: String
    var color: Color = AppTheme.Colors.accent
    var isPrimary: Bool = false

    var body: some View {
        Group {
            if isPrimary {
                primaryCard
            } else {
                secondaryCard
            }
        }
    }

    private var primaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            Spacer(minLength: 4)
            Text(value)
                .font(AppTheme.Fonts.statNumber)
                .foregroundColor(.white)
                .tracking(-1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(AppTheme.Fonts.footnote.weight(.medium))
                .foregroundColor(.white.opacity(0.78))
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.Colors.accentGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
        .rdShadow(AppTheme.Shadows.accent)
    }

    private var secondaryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Spacer(minLength: 2)
            Text(value)
                .font(AppTheme.Fonts.statNumberSmall)
                .foregroundColor(AppTheme.Colors.primaryText)
                .tracking(-0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(AppTheme.Fonts.caption.weight(.medium))
                .foregroundColor(AppTheme.Colors.tertiaryText)
                .tracking(0.2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.medium)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                .stroke(AppTheme.Colors.separator, lineWidth: 0.5)
        )
        .rdShadow(AppTheme.Shadows.sm)
    }
}

// MARK: - 功能入口按钮
struct FeatureButton: View {
    let title: String
    let systemImage: String
    let color: Color
    var onClick: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onClick = onClick {
                Button(action: onClick) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.element, style: .continuous))
            Text(title)
                .font(AppTheme.Fonts.caption.weight(.medium))
                .foregroundColor(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.small)
        .contentShape(Rectangle())
    }
}

// MARK: - 学生头像
struct StudentAvatar: View {
    let name: String
    var size: CGFloat = 44
    var color: Color? = nil

    private var avatarColor: Color {
        if let color = color { return color }
        // 按姓名稳定生成颜色
        let palette: [Color] = [
            AppTheme.Colors.accent, .blue, .green, .purple, .pink, .teal, .indigo, .orange
        ]
        var hash = 0
        for scalar in name.unicodeScalars {
            hash = (hash &* 31 &+ Int(scalar.value)) & 0x7fffffff
        }
        return palette[hash % palette.count]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.accent.opacity(0.15))
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(AppTheme.Colors.accent)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 空状态
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.subtleBackground)
                    .frame(width: 96, height: 96)
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(AppTheme.Colors.tertiaryText)
            }
            VStack(spacing: AppTheme.Spacing.xSmall) {
                Text(title)
                    .font(AppTheme.Fonts.title2)
                    .foregroundColor(AppTheme.Colors.primaryText)
                    .tracking(-0.3)
                Text(message)
                    .font(AppTheme.Fonts.footnote)
                    .foregroundColor(AppTheme.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xxLarge)
            }
            if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                Button(action: buttonAction) {
                    Label(buttonTitle, systemImage: "plus.circle.fill")
                        .font(AppTheme.Fonts.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppTheme.Spacing.large)
                        .padding(.vertical, AppTheme.Spacing.medium)
                        .background(AppTheme.Colors.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous))
                        .rdShadow(AppTheme.Shadows.accent)
                }
                .padding(.top, AppTheme.Spacing.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}

// MARK: - 胶囊标签
struct PillTag: View {
    let title: String
    var color: Color = AppTheme.Colors.accent

    var body: some View {
        Text(title)
            .font(AppTheme.Fonts.caption2.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, AppTheme.Spacing.small)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - 主按钮
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 6) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(AppTheme.Fonts.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.medium)
            .background(AppTheme.Colors.accentGradient)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous))
            .rdShadow(AppTheme.Shadows.accent)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 次按钮
struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 6) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(title)
                    .font(AppTheme.Fonts.callout.weight(.medium))
            }
            .foregroundColor(AppTheme.Colors.secondaryText)
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.vertical, AppTheme.Spacing.small)
            .background(AppTheme.Colors.subtleBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 全局外观设置（在 App 入口调用）
extension AppTheme {
    static func applyGlobalAppearance() {
        // 导航栏
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.Colors.primaryText),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.Colors.primaryText),
            .font: UIFont.systemFont(ofSize: 28, weight: .heavy)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        // TabBar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // TableView
        UITableView.appearance().backgroundColor = UIColor(AppTheme.Colors.background)
        UITableViewCell.appearance().backgroundColor = UIColor(AppTheme.Colors.cardBackground)

        // 全局 tint
        UIWindow.appearance().tintColor = UIColor(AppTheme.Colors.accent)
    }
}

// MARK: - UIColor 亮度调整扩展
extension UIColor {
    func adjustedBrightness(by amount: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue,
                           saturation: saturation,
                           brightness: min(max(brightness + amount, 0), 1),
                           alpha: alpha)
        }
        return self
    }
}
