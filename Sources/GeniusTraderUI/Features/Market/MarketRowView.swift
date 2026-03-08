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
            Text(item.name)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? .white : .black.opacity(0.8))
                .frame(width: 90, alignment: .leading)

            Spacer()

            SimpleSparkline(data: item.trend, color: isSelected ? .white : (item.isRising ? redColor : greenColor))
                .frame(width: 40, height: 20)

            Spacer()

            Text(formatPrice(item.price))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .white : (item.isRising ? redColor : greenColor))
                .frame(width: 80, alignment: .trailing)

            Text(formatChange(item.changePercentage))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .white : (item.isRising ? redColor : greenColor))
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? selectedColor : (isHovered ? Color.gray.opacity(0.1) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 8)
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
