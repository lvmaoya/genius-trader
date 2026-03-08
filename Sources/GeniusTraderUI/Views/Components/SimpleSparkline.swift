import SwiftUI

struct SimpleSparkline: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                guard data.count > 1 else { return }

                let stepX = width / CGFloat(data.count - 1)
                if let first = data.first {
                    path.move(to: CGPoint(x: 0, y: height * (1.0 - first)))
                }

                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height * (1.0 - value)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}
