import SwiftUI
import AppKit

@MainActor
/// 左侧 hover 详情弹层的控制器。
/// 这里改用系统 `NSPopover`，不再自己维护一套仿系统的独立 NSPanel 外观。
final class HoverPreviewPanelController: ObservableObject {
    private let popoverSize = NSSize(width: 360, height: 430)

    private let popover = NSPopover()
    private var hostingController: NSHostingController<AnyView>?
    private weak var attachedView: NSView?

    init() {
        popover.behavior = .applicationDefined
        popover.animates = false
    }

    /// 记录当前 SwiftUI 对应的宿主 NSView。
    /// `NSPopover` 需要依附在一个真实的 AppKit 视图上展示。
    func attach(to view: NSView) {
        attachedView = view
    }

    /// 显示或刷新左侧 popover。
    /// 当 hover 目标变化时，我们直接重建显示位置，保证箭头和行对齐。
    func show(
        snapshot: MarketHoverSnapshot,
        hostView: NSView,
        rowFrame: CGRect,
        greenColor: Color,
        redColor: Color,
        onPopoverHoverChange: @escaping (Bool) -> Void
    ) {
        attachedView = hostView

        let content = AnyView(
            MarketHoverDetailView(
                snapshot: snapshot,
                greenColor: greenColor,
                redColor: redColor,
                onHoverChange: onPopoverHoverChange
            )
            .frame(width: popoverSize.width, height: popoverSize.height)
        )

        if let hostingController {
            hostingController.rootView = content
            hostingController.view.frame.size = popoverSize
        } else {
            let hostingController = NSHostingController(rootView: content)
            hostingController.view.frame.size = popoverSize
            self.hostingController = hostingController
            popover.contentViewController = hostingController
            popover.contentSize = popoverSize
        }

        let anchorRect = popoverAnchorRect(for: rowFrame, in: hostView)

        if popover.isShown {
            popover.performClose(nil)
        }

        popover.show(relativeTo: anchorRect, of: hostView, preferredEdge: .minX)
    }

    /// 主界面消失或 hover 结束时关闭 popover。
    func hide() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    /// 把 SwiftUI 容器坐标系里的行 frame 转成 `NSPopover` 需要的 AppKit 锚点 rect。
    /// SwiftUI 这里拿到的是以左上为参考的列表坐标，而 AppKit 视图是左下原点，
    /// 所以需要把 y 轴翻转一次。
    private func popoverAnchorRect(for rowFrame: CGRect, in hostView: NSView) -> NSRect {
        NSRect(
            x: rowFrame.minX,
            y: hostView.bounds.height - rowFrame.maxY,
            width: rowFrame.width,
            height: rowFrame.height
        )
    }
}
