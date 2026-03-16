import SwiftUI

/// 左侧 hover 浮窗使用的展示快照。
/// 这是一个纯展示模型，目的是把页面级状态整理成浮窗真正需要的最小数据集。
struct MarketHoverSnapshot {
    let name: String
    let code: String
    let productID: String
    let priceText: String
    let moneyChangeText: String
    let changeText: String
    let high24hText: String
    let low24hText: String
    let volume24hText: String
    let turnover24hText: String
    let isRising: Bool
    let trend: [Double]
    let isInWatchlist: Bool
}

/// 左侧独立详情浮窗的内容视图。
/// 这里只关心“怎么展示”，不关心 hover 来源、窗口定位或持久化。
struct MarketHoverDetailView: View {
    let snapshot: MarketHoverSnapshot
    let greenColor: Color
    let redColor: Color
    let onHoverChange: ((Bool) -> Void)?

    /// 根据涨跌方向切换主强调色，与右侧列表保持一致。
    private var accentColor: Color {
        snapshot.isRising ? redColor : greenColor
    }

    private var secondaryAccentColor: Color {
        accentColor.opacity(0.7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            optionSection
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 外层系统面板样式由 NSVisualEffectView 提供，这里只保留内容排版。
        .background(Color.clear)
        .onHover { isHovered in
            onHoverChange?(isHovered)
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading) {
                Text(snapshot.priceText)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(accentColor)

                Text("\(snapshot.moneyChangeText)  \(snapshot.changeText)")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
            }
            .frame(width: 120, alignment: .leading)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 12) {
                metricGridRow(leftTitle: "24高", leftValue: snapshot.high24hText, rightTitle: "24低", rightValue: snapshot.low24hText)
                metricGridRow(leftTitle: "24量", leftValue: snapshot.volume24hText, rightTitle: "24额", rightValue: snapshot.turnover24hText)
            }
        }
    }

    private var optionSection: some View {
        HStack(spacing: 12) {
            optionPill(title: "分时", isSelected: true)
            optionPill(title: "五日")
            optionPill(title: "日K")
            optionPill(title: "周K")
            optionPill(title: "月K")
        }
    }

    private func metricGridRow(leftTitle: String, leftValue: String, rightTitle: String, rightValue: String) -> some View {
        HStack(spacing: 18) {
            metricCell(title: leftTitle, value: leftValue)
            metricCell(title: rightTitle, value: rightValue)
        }
    }

    private func metricCell(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: 0x999999))

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: 0x333333))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func optionPill(title: String, isSelected: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
        .foregroundStyle(isSelected ? Color.white : Color(hex: 0x444444))
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isSelected ? Color.black : Color.white.opacity(0.45))
        )
    }

}
