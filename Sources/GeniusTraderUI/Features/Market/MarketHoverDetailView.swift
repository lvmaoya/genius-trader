import SwiftUI

/// 左侧 hover 浮窗使用的展示快照。
/// 这是一个纯展示模型，目的是把页面级状态整理成浮窗真正需要的最小数据集。
struct MarketHoverSnapshot {
    let name: String
    let code: String
    let productID: String
    let priceText: String
    let changeText: String
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

    /// 根据涨跌方向切换主强调色，与右侧列表保持一致。
    private var accentColor: Color {
        snapshot.isRising ? redColor : greenColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(hex: 0x333333))

                    Text(snapshot.code)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: 0x999999))
                }

                Spacer()

                Text(snapshot.isInWatchlist ? "自选" : "搜索")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: 0x999999))
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.priceText)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(accentColor)

                Text(snapshot.changeText)
                    .font(.system(size: 12))
                    .foregroundStyle(accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            SimpleSparkline(data: snapshot.trend, color: accentColor)
                .frame(height: 48)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                hoverInfoRow(title: "产品", value: snapshot.productID)
                hoverInfoRow(
                    title: "状态",
                    value: snapshot.isInWatchlist ? "已在自选列表中" : "悬停预览，点击即可添加"
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 外层系统面板样式由 NSVisualEffectView 提供，这里只保留内容排版。
        .background(Color.clear)
    }

    /// 浮窗底部的说明行，用统一的小字号格式展示元信息。
    private func hoverInfoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: 0x999999))
                .frame(width: 28, alignment: .leading)

            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: 0x333333))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
    }
}
