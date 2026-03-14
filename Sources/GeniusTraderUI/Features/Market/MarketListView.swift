import SwiftUI

public struct MarketListView: View {
    @StateObject private var viewModel = MarketViewModel()
    @State private var selectedItemID: UUID?
    @State private var selectedMenuItemID: UUID?
    private let onQuit: (() -> Void)?

    private let textGreen = Color(red: 0.12, green: 0.62, blue: 0.24)
    private let textRed = Color(red: 0.9, green: 0.18, blue: 0.2)
    private let selectedColor = Color(hex: 0x4690fc)

    public init(onQuit: (() -> Void)? = nil) {
        self.onQuit = onQuit
    }

    @State private var hoveredItemID: UUID?
    @State private var isClearConfirmPresented = false

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Genider")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: 0x999999))
                
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: 0x999999))
                    
                    ZStack(alignment: .leading) {
                        if viewModel.searchText.isEmpty {
                            Text("搜索")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: 0x999999))
                        }
                        TextField("", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredItems) { item in
                        MarketRowView(
                            item: item,
                            isSelected: selectedItemID == item.id,
                            isHovered: false,
                            greenColor: textGreen,
                            redColor: textRed,
                            selectedColor: selectedColor
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItemID = item.id
                            selectedMenuItemID = nil
                        }
                        .onHover { isHovered in
                            if isHovered {
                                selectedItemID = item.id
                                selectedMenuItemID = nil
                            }
                        }
                        .tag(item.id)
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)

            Divider()
                .padding(.horizontal, 12)

            VStack(spacing: 0) {
                ForEach(viewModel.menuItems) { menuItem in
                    MenuRowView(
                        item: menuItem,
                        isSelected: selectedMenuItemID == menuItem.id,
                        selectedColor: selectedColor
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMenuItemID = menuItem.id
                        selectedItemID = nil
                        handleMenuAction(menuItem)
                    }
                    .onHover { isHovered in
                        if isHovered {
                            selectedMenuItemID = menuItem.id
                            selectedItemID = nil
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 4)
            .padding(.top, 4)
            .padding(.bottom, 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            if viewModel.items.count > 0 {
                selectedItemID = viewModel.items[0].id
            }
        }
        .alert("确认清空？", isPresented: $isClearConfirmPresented) {
            Button("取消", role: .cancel) {}
            Button("确认", role: .destructive) {
                viewModel.items.removeAll()
                selectedItemID = nil
            }
        } message: {
            Text("将移出全部自选项，无法撤销。")
        }
    }

    private var filteredItems: [MarketItem] {
        let keyword = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return viewModel.items }
        return viewModel.items.filter { $0.name.localizedCaseInsensitiveContains(keyword) }
    }

    private func handleMenuAction(_ menuItem: MenuItem) {
        if menuItem.title == "清空" {
            isClearConfirmPresented = true
            return
        }

        if menuItem.title == "退出" {
            onQuit?()
            return
        }
    }
}

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

#Preview {
    MarketListView()
        .frame(width: 380, height: 600)
}
