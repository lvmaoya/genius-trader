import SwiftUI

struct MarketRowView: View {
    let item: MarketItem
    let isSelected: Bool
    let isHovered: Bool
    let greenColor: Color
    let redColor: Color
    let selectedColor: Color

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .white : Color(hex: 0x333333))
                
                Text(item.code)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : Color(hex: 0x999999))
            }
            .frame(width: 90, alignment: .leading)

            Spacer()
            SimpleSparkline(data: item.trend, color: isSelected ? .white : (item.isRising ? redColor : greenColor))
                .frame(width: 40, height: 20)
            Text(formatPrice(item.price))
                .font(.system(size: 14, weight: .none))
                .foregroundStyle(isSelected ? .white : (item.isRising ? redColor : greenColor))
                .frame(width: 80, alignment: .trailing)

            Text(formatChange(item.changePercentage))
                .font(.system(size: 14, weight: .none))
                .foregroundStyle(isSelected ? .white : (item.isRising ? redColor : greenColor))
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? selectedColor : (isHovered ? Color(hex: 0x999999) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 6)
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "%.0f", price)
        }
        return String(format: "%.2f", price)
    }

    private func formatChange(_ change: Double) -> String {
        String(format: "%.2f%%", change)
    }
}
