import SwiftUI

// MARK: - Sparkline View
struct SparklineView: View {
    let values: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !values.isEmpty else { return }
                
                let width = geometry.size.width
                let height = geometry.size.height
                let maxValue = values.max() ?? 0
                let minValue = values.min() ?? 0
                let range = maxValue - minValue
                
                for (index, value) in values.enumerated() {
                    let x = CGFloat(index) / CGFloat(values.count - 1) * width
                    let y = height - (CGFloat(value - minValue) / CGFloat(range) * height)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        SparklineView(
            values: [10, 20, 15, 25, 30, 20, 35],
            color: .blue
        )
        .frame(height: 100)
        .padding()
    }
}
