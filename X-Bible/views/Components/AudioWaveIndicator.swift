import SwiftUI

struct AudioWaveIndicator: View {
    let currentVolume: CGFloat
    private let multipliers: [CGFloat] = [0.3,0.7, 0.8, 0.6, 0.2]
    
    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
                    .frame(width: 2, height: max(2.0, min(16.0, 3.0 + (currentVolume * 13.0 * multipliers[index]))))
                    .animation(.spring(response: 0.2, dampingFraction: 0.65), value: currentVolume)
            }
        }
        .frame(width: 24, height: 16)
    }
}
