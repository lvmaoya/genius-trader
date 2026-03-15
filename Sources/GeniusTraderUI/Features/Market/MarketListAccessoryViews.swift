import SwiftUI

/// 底部菜单行。视觉上与币种列表分开，但交互方式保持一致：hover 高亮、点击触发动作。
struct MenuRowView: View {
    let item: MenuItem
    let isSelected: Bool
    let selectedColor: Color

    var body: some View {
        HStack {
            Text(item.title)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? .white : Color(hex: 0x333333))
            Spacer()
            Text(item.code)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? .white : Color(hex: 0x999999))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isSelected ? selectedColor : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 3)
    }
}

/// 自选为空时的占位视图。
struct EmptyWatchlistView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("在上方搜索币种后，点击添加")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: 0x9CA3AF))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}
