import SwiftUI

struct AnimatedCustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    @State private var isInteracting = false
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
                    .frame(height: isInteracting ? 24 : 8) // Made slightly taller to fit text nicely
                
                // Active Progress Fill
                Capsule()
                    .fill(.white)
                    .frame(width: CGFloat(currentPercentage) * width, height: isInteracting ? 24 : 8)
                
                // Embedded Timestamp Text (Only visible during expand/hold)
                if isInteracting {
                    Text(formatTime(value))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.black) // Reads cleanly against the white fill
                        .colorInvert() // Inverts if your master system theme changes it
                        .padding(.leading, 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { gesture in
                        // Forces immediate visual expansion on initial mouse down click
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
                        // Shrinks back down cleanly structural the instant mouse button releases
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isInteracting = false
                        }
                    }
            )
        }
        .frame(height: 24)
    }
    
    // Helper to format raw doubles (seconds) into a clean digital readout
    private func formatTime(_ timeInSeconds: Double) -> String {
        let totalSeconds = Int(timeInSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
