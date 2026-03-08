import SwiftUI
import AppKit
import GeniusTraderUI

@main
struct GeniusTraderApp: App {
    var body: some Scene {
        MenuBarExtra {
            MarketListView(onQuit: {
                NSApplication.shared.terminate(nil)
            })
                .frame(minWidth: 320, minHeight: 900)
        } label: {
            if let image = menuBarIcon {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "bitcoinsign.circle")
                    .font(.system(size: 14, weight: .regular))
            }
        }
    }

    private var menuBarIcon: NSImage? {
        guard let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = true
        return image
    }
}
