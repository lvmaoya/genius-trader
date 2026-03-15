import SwiftUI
import AppKit

/// 收集“币种 productID -> 该行 frame”映射关系的 PreferenceKey。
/// 页面会借助它把列表行位置从子视图上传到父视图。
struct MarketRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// 把当前 SwiftUI 视图对应的宿主 NSView 暴露出来。
/// 这是 SwiftUI 与 AppKit 之间的桥，系统 popover 需要依附在真实的 AppKit 视图上显示。
struct HostViewAccessor: NSViewRepresentable {
    let onViewChange: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // NSView 初次加入窗口层级通常发生在下一个 runloop，因此这里异步回传 view。
        DispatchQueue.main.async {
            if view.window != nil {
                onViewChange(view)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if nsView.window != nil {
                onViewChange(nsView)
            }
        }
    }
}
