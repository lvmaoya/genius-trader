import SwiftUI
import AppKit

/// 市场列表页的主视图。
/// 这里主要负责页面级状态编排：
/// 搜索、自选列表、底部菜单、hover 浮窗，以及选中项恢复。
public struct MarketListView: View {
    @StateObject private var viewModel = MarketViewModel()
    /// 左侧系统 popover 的控制器。
    @StateObject private var hoverPreviewController = HoverPreviewPanelController()
    /// 用户点击后选中的币种，会被持久化并在下次启动时尝试恢复。
    @State private var selectedItemID: String?
    /// 底部菜单当前高亮项。
    @State private var selectedMenuItemID: UUID?
    /// 当前鼠标悬停的币种，仅用于临时高亮与左侧预览。
    @State private var hoveredProductID: String?
    /// 鼠标当前是否正在 popover 内容区域内。
    @State private var isHoveringPopover = false
    /// 用于给 popover 关闭增加一点缓冲，避免从列表行移向 popover 的过程中瞬间关闭。
    @State private var pendingPopoverHideWorkItem: DispatchWorkItem?
    /// 列表中每一行的 frame，供独立浮窗做定位。
    @State private var rowFrames: [String: CGRect] = [:]
    /// 当前 SwiftUI 对应的宿主 NSView。系统 popover 需要依附在真实 AppKit 视图上展示。
    @State private var hostView: NSView?
    @FocusState private var isSearchFieldFocused: Bool
    private let onQuit: (() -> Void)?

    private let textGreen = Color(red: 0.12, green: 0.62, blue: 0.24)
    private let textRed = Color(red: 0.9, green: 0.18, blue: 0.2)
    private let selectedColor = Color(hex: 0x4690fc)

    public init(onQuit: (() -> Void)? = nil) {
        self.onQuit = onQuit
    }

    /// 清空自选前的确认弹窗开关。
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
                            .focused($isSearchFieldFocused)
                            .onSubmit {
                                isSearchFieldFocused = false
                            }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Group {
                if viewModel.items.isEmpty && !viewModel.isSearching {
                    EmptyWatchlistView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if viewModel.isSearching {
                                ForEach(viewModel.searchResults) { item in
                                    if viewModel.isInWatchlist(item) {
                                        if let watchlistItem = viewModel.watchlistItem(for: item) {
                                            MarketRowView(
                                                item: watchlistItem,
                                                isSelected: selectedItemID == watchlistItem.id,
                                                isHovered: hoveredProductID == watchlistItem.productID,
                                                greenColor: textGreen,
                                                redColor: textRed,
                                                selectedColor: selectedColor
                                            )
                                            .contentShape(Rectangle())
                                            .background(rowFrameReader(for: watchlistItem.productID))
                                            .onTapGesture {
                                                selectItem(withID: watchlistItem.id)
                                                selectedMenuItemID = nil
                                            }
                                            .onHover { isHovered in
                                                handleHoverChange(
                                                    isHovered: isHovered,
                                                    productID: watchlistItem.productID,
                                                    selectedID: watchlistItem.id
                                                )
                                            }
                                        }
                                    } else {
                                        SearchResultRowView(
                                            item: item,
                                            onAdd: {
                                                viewModel.addToWatchlist(item)
                                            },
                                            selectedColor: selectedColor,
                                            isHovered: hoveredProductID == item.productID
                                        )
                                        .contentShape(Rectangle())
                                        .background(rowFrameReader(for: item.productID))
                                        .onHover { isHovered in
                                            handleHoverChange(
                                                isHovered: isHovered,
                                                productID: item.productID,
                                                selectedID: nil
                                            )
                                        }
                                    }
                                }
                            } else {
                                ForEach(viewModel.items) { item in
                                    MarketRowView(
                                        item: item,
                                        isSelected: selectedItemID == item.id,
                                        isHovered: hoveredProductID == item.productID,
                                        greenColor: textGreen,
                                        redColor: textRed,
                                        selectedColor: selectedColor
                                    )
                                    .contentShape(Rectangle())
                                    .background(rowFrameReader(for: item.productID))
                                    .onTapGesture {
                                        selectItem(withID: item.id)
                                        selectedMenuItemID = nil
                                    }
                                    .onHover { isHovered in
                                        handleHoverChange(
                                            isHovered: isHovered,
                                            productID: item.productID,
                                            selectedID: item.id
                                        )
                                    }
                                    .tag(item.id)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                        hoveredProductID = nil
                        handleMenuAction(menuItem)
                    }
                    .onHover { isHovered in
                        if isHovered {
                            cancelPendingPopoverHide()
                            isHoveringPopover = false
                            selectedMenuItemID = menuItem.id
                            selectedItemID = nil
                            hoveredProductID = nil
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 4)
            .padding(.top, 4)
            .padding(.bottom, 4)
        }
        // 用一个不可见的 AppKit 桥接视图取到当前 SwiftUI 对应的宿主 NSView。
        // `NSPopover` 不能直接挂在 SwiftUI View 上，需要一个真实的 AppKit 视图作为锚点。
        .background(HostViewAccessor { view in
            hostView = view
            hoverPreviewController.attach(to: view)
            updateHoverPreview()
        })
        // 给整个市场列表容器命名一个坐标系。
        // 后面每一行会上报自己相对于这个容器的 frame，供左侧独立浮窗定位。
        .coordinateSpace(name: "market-list-container")
        // 接收每一行通过 PreferenceKey 上报上来的 frame。
        // 一旦列表布局变化，就刷新缓存的位置字典，并同步更新左侧 hover 详情浮窗的位置。
        .onPreferenceChange(MarketRowFramePreferenceKey.self) { frames in
            rowFrames = frames
            updateHoverPreview()
        }
        // hover 目标改变时，立即刷新左侧系统 popover。
        .onChange(of: hoveredProductID) { _ in
            updateHoverPreview()
        }
        // 搜索条件变化后，列表内容会切换，因此也要刷新预览内容。
        .onChange(of: viewModel.searchText) { _ in
            updateHoverPreview()
        }
        // 行情数据返回后，预览里的价格/涨跌幅也要跟着更新。
        .onChange(of: viewModel.allItems) { _ in
            updateHoverPreview()
            restorePersistedSelectionIfNeeded()
        }
        .onAppear {
            // 恢复上次点击选中的币种，但只有它仍存在于自选列表时才会真正展示。
            selectedItemID = MarketSelectionStore.loadSelectedItemID()
            selectedMenuItemID = nil
            isSearchFieldFocused = false
            restorePersistedSelectionIfNeeded()
            updateHoverPreview()
        }
        .onDisappear {
            // 主界面关闭时，主动收起左侧 popover。
            cancelPendingPopoverHide()
            hoverPreviewController.hide()
        }
        .alert("确认清空？", isPresented: $isClearConfirmPresented) {
            Button("取消", role: .cancel) {}
            Button("确认", role: .destructive) {
                viewModel.clearWatchlist()
                MarketSelectionStore.clearSelectedItemID()
                selectedItemID = nil
                hoveredProductID = nil
            }
        } message: {
            Text("将移出全部自选项，无法撤销。")
        }
    }

    /// 通过透明的 GeometryReader 采集每一行的位置信息。
    /// 左侧 popover 依然不在当前 SwiftUI 树里，所以要靠这里把行位置传出去。
    private func rowFrameReader(for productID: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: MarketRowFramePreferenceKey.self,
                value: [productID: proxy.frame(in: .named("market-list-container"))]
            )
        }
    }

    /// 统一处理 hover 行为。
    /// hover 不会写入本地存储，但如果 hover 到的是自选项，会同步更新当前页面高亮。
    private func handleHoverChange(isHovered: Bool, productID: String, selectedID: String?) {
        if isHovered {
            cancelPendingPopoverHide()
            isHoveringPopover = false
            hoveredProductID = productID
        } else {
            schedulePopoverHide(for: productID)
        }

        if isHovered, let selectedID {
            selectedItemID = selectedID
            selectedMenuItemID = nil
        }
    }

    /// 底部菜单目前只有“清空”和“退出”有具体行为。
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

    /// 用户真正点击选中某一项时，同时更新 UI 状态与本地持久化。
    private func selectItem(withID id: String) {
        selectedItemID = id
        MarketSelectionStore.saveSelectedItemID(id)
    }

    /// 根据当前 hover 的目标和该行的位置，刷新左侧系统 popover。
    /// 任一关键条件缺失时直接隐藏，避免展示过期内容。
    private func updateHoverPreview() {
        guard let hostView,
              let hoveredProductID,
              let snapshot = hoveredSnapshot,
              let rowFrame = rowFrames[hoveredProductID] else {
            hoverPreviewController.hide()
            return
        }

        hoverPreviewController.show(
            snapshot: snapshot,
            hostView: hostView,
            rowFrame: rowFrame,
            greenColor: textGreen,
            redColor: textRed,
            onPopoverHoverChange: handlePopoverHoverChange
        )
    }

    /// 把当前 hover 目标转换成给浮窗使用的展示快照。
    /// 这样详情浮窗不需要直接依赖页面上的复杂状态。
    private var hoveredSnapshot: MarketHoverSnapshot? {
        guard let hoveredProductID else { return nil }

        if let item = viewModel.items.first(where: { $0.productID == hoveredProductID }) {
            return MarketHoverSnapshot(
                name: item.name,
                code: item.code,
                productID: item.productID,
                priceText: formatPrice(item.price),
                changeText: formatChange(item.changePercentage),
                isRising: item.isRising,
                trend: item.trend,
                isInWatchlist: true
            )
        }

        if let searchItem = viewModel.searchResults.first(where: { $0.productID == hoveredProductID }) {
            return MarketHoverSnapshot(
                name: searchItem.name,
                code: searchItem.code,
                productID: searchItem.productID,
                priceText: "未添加",
                changeText: "搜索结果",
                isRising: true,
                trend: Array(repeating: 0.5, count: 12),
                isInWatchlist: false
            )
        }

        return nil
    }

    /// 与列表行保持一致的价格格式化规则，保证左右两边数字展示风格统一。
    private func formatPrice(_ price: Double) -> String {
        if price == 0 {
            return "--"
        }
        if price >= 1000 {
            return String(format: "%.0f", price)
        }
        if price >= 1 {
            return String(format: "%.2f", price)
        }
        if price >= 0.01 {
            return String(format: "%.4f", price)
        }
        return String(format: "%.6f", price)
    }

    private func formatChange(_ change: Double) -> String {
        String(format: "%@%.2f%%", change >= 0 ? "+" : "", change)
    }

    /// 恢复上次持久化的选中项。
    /// 如果本地保存的 ID 已经不在当前自选中，则顺手清理掉脏数据。
    private func restorePersistedSelectionIfNeeded() {
        guard let persistedSelectedItemID = MarketSelectionStore.loadSelectedItemID() else { return }

        if viewModel.items.contains(where: { $0.id == persistedSelectedItemID }) {
            if selectedItemID == nil {
                selectedItemID = persistedSelectedItemID
            }
        } else if !viewModel.isSearching {
            MarketSelectionStore.clearSelectedItemID()
            if selectedItemID == persistedSelectedItemID {
                selectedItemID = nil
            }
        }
    }

    /// 当鼠标进入 popover 时取消关闭；离开时延迟关闭，给用户留出一点移动和点击缓冲。
    private func handlePopoverHoverChange(_ isHovered: Bool) {
        isHoveringPopover = isHovered

        if isHovered {
            cancelPendingPopoverHide()
        } else if let hoveredProductID {
            schedulePopoverHide(for: hoveredProductID)
        }
    }

    /// 延迟关闭 popover，解决“鼠标刚离开列表行、正要进入 popover 时就被关掉”的问题。
    private func schedulePopoverHide(for productID: String) {
        cancelPendingPopoverHide()

        let workItem = DispatchWorkItem {
            guard !isHoveringPopover, hoveredProductID == productID else { return }
            hoveredProductID = nil
        }

        pendingPopoverHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    private func cancelPendingPopoverHide() {
        pendingPopoverHideWorkItem?.cancel()
        pendingPopoverHideWorkItem = nil
    }
}

#Preview {
    MarketListView()
        .frame(width: 360, height: 600)
}
