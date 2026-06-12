import SwiftUI

struct BibleTimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var selectedEvent: TimelineEvent?
    @State private var activeYear: Int = -4100
    
    let pixelsPerYear: CGFloat = 1.5
    let rowHeight: CGFloat = 110.0
    let timelineStartYear = -4100
    let timelineEndYear = 2100
    
    private let timelineSpace = "TimelineCenterSpace"

    private var totalWidth: CGFloat {
        CGFloat(timelineEndYear - timelineStartYear) * pixelsPerYear
    }

    var body: some View {
        NavigationStack {
            GeometryReader { areaGeo in
                let centerX = areaGeo.size.width / 2
                
                ZStack {
                    ScrollView(.horizontal, showsIndicators: true) {
                        // This ZStack contains EVERYTHING that moves
                        ZStack(alignment: .topLeading) {
                            
                            // 1. THE TRACKER
                            GeometryReader { scrollGeo in
                                Color.clear
                                    .onChange(of: scrollGeo.frame(in: .named(timelineSpace)).minX) { _ in
                                        updateYear(scrollGeo, centerX: centerX)
                                    }
                            }
                            .frame(height: 1)

                            // 2. THE CONTENT (Shifted to start at the Red Line)
                            VStack(alignment: .leading, spacing: 0) {
                                // Year Labels
                                yearLabelsHeader
                                    .frame(width: totalWidth, height: 50)
                                    .border(.secondary.opacity(0.4), width: 1)
                                    .padding(.leading, centerX) // SHIFTED RIGHT

                                // Events Vertical Scroll
                                ScrollView(.vertical, showsIndicators: true) {
                                    ZStack(alignment: .topLeading) {
                                        TimelineBackgroundGrid(startYear: timelineStartYear, pixelsPerYear: pixelsPerYear)
                                        
                                        if viewModel.isLoading {
                                            ProgressView().frame(width: areaGeo.size.width)
                                        } else {
                                            renderEvents()
                                        }
                                    }
                                    .frame(width: totalWidth, height: 2500)
                                    .padding(.leading, centerX) // SHIFTED RIGHT
                                }
                            }
                        }
                        // Important: Make the total scrollable area wide enough to
                        // let the end of the timeline reach the center
                        .frame(width: totalWidth + (centerX * 2))
                    }
                    .coordinateSpace(name: timelineSpace)

                    // 3. THE RED SCRUBBER (Fixed in the absolute center)
                    VStack(spacing: 0) {
                        Text(TimelineUtils.calculateLabel(start: activeYear, end: activeYear))
                            .font(.system(size: 12).monospaced())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.red))
                            .offset(y: 10)
                        
                        centerScrubberLine
                    }
                    .zIndex(2)
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("Bible Timeline")
            .task { await viewModel.loadEvents() }
        }
    }

    private func updateYear(_ proxy: GeometryProxy, centerX: CGFloat) {
        let scrollOffset = proxy.frame(in: .named(timelineSpace)).minX
        
        // Since we padded the content by centerX, the math is now:
        let relativeX = -scrollOffset
        let yearsPassed = Int(relativeX / pixelsPerYear)
        
        var newYear = timelineStartYear + yearsPassed
        if newYear >= 0 { newYear += 1 }
        
        let clampedYear = min(max(newYear, timelineStartYear), timelineEndYear)
        if activeYear != clampedYear {
            activeYear = clampedYear
        }
    }

    private var centerScrubberLine: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrowtriangle.down.fill")
                .foregroundColor(.red)
                .offset(y: 4)
            Rectangle()
                .fill(.red)
                .frame(width: 0.5)
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    

    private var yearLabelsHeader: some View {
        let years = Array(stride(from: timelineStartYear, to: timelineEndYear, by: 100))
        return ZStack(alignment: .topLeading) {
            ForEach(years, id: \.self) { year in
                Text(TimelineUtils.calculateLabel(start: year, end: year))
                    .font(.system(size: 12).monospaced())
                    .foregroundColor(.secondary)
                    .position(
                        x: CGFloat(year - timelineStartYear) * pixelsPerYear,
                        y: 25
                    )
            }
        }
    }
    
    @ViewBuilder
    private func renderEvents() -> some View {
        ForEach(viewModel.sections) { section in
            let sectionColor = Color(hex: section.color)
            ForEach(section.events) { event in
                let duration = CGFloat(event.end - event.start)
                let calculatedWidth = max(duration * pixelsPerYear, 20)
                
                TimelineItemView(event: event, sectionColor: sectionColor, width: calculatedWidth) { ev in
                    self.selectedEvent = ev
                }
                .frame(width: calculatedWidth, height: rowHeight - 10)
                .position(
                    x: (CGFloat(event.start - timelineStartYear) * pixelsPerYear) + (calculatedWidth / 2),
                    y: (CGFloat(event.row) * rowHeight) + 60
                )
            }
        }
    }
}
