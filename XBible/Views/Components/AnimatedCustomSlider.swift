import SwiftUI

struct AnimatedCustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    @State private var isInteracting = false
    // 🌟 Added default value so parent views aren't forced to pass it if they don't want to
    var isActive: Bool = true
    @GestureState private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            
            let rangeLength = range.upperBound - range.lowerBound
            let currentPercentage = rangeLength > 0 ? (value - range.lowerBound) / rangeLength : 0.0
            
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: isInteracting ? 24 : 8)
                
                // Active Progress Fill
                Capsule()
                    .fill(isActive ? Color.white : Color.gray)
                    .frame(width: CGFloat(currentPercentage) * width, height: isInteracting ? 24 : 8)
                
                // Embedded Timestamp Text (Only visible during expand/hold)
                if isInteracting {
                    Text(formatTime(value))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .colorInvert()
                        .padding(.leading, 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .contentShape(Rectangle())
            // 🌟 FIX: Use standard conditional modifier evaluation rather than a broken inline "if" block
            .gesture(
                isActive ?
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { gesture in
                        if !isInteracting {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                isInteracting = true
                            }
                        }
                        
                        let locationX = gesture.location.x
                        let percentage = Double(locationX / width)
                        let clampedPercentage = min(max(percentage, 0.0), 1.0)
                        
                        self.value = range.lowerBound + (clampedPercentage * rangeLength)
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isInteracting = false
                        }
                    }
                : nil // Returns no gesture interaction when deactivated
            )
        }
        .frame(height: 24)
    }
    
    private func formatTime(_ timeInSeconds: Double) -> String {
        let totalSeconds = Int(timeInSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
