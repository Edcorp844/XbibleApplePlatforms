import SwiftUI

struct BibleTimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var selectedEvent: TimelineEvent?
    
    // Tracking the current active year based on scroll
    @State private var activeYear: Int = -4100
    
    // Layout Constants
    let pixelsPerYear: CGFloat = 1.5
    let rowHeight: CGFloat = 110.0
    let timelineStartYear = -4100
    let timelineEndYear = 2100
    let horizontalPadding: CGFloat = 60.0

    private var totalWidth: CGFloat {
        (CGFloat(timelineEndYear - timelineStartYear) * pixelsPerYear) + (horizontalPadding * 2)
    }

    var body: some View {
        NavigationStack {
            // 1. This GeometryReader detects the VISIBLE area (shrinks when sidebar opens)
            GeometryReader { timelineAreaGeo in
                let visibleWidth = timelineAreaGeo.size.width
                let centerX = visibleWidth / 2
                
                ZStack {
                    // --- THE TIMELINE ---
                    ScrollView(.horizontal, showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            
                            // 2. This GeometryReader tracks the SCROLL position
                            GeometryReader { scrollGeo in
                                Color.clear
                                    .onAppear { updateYear(scrollGeo, centerX: centerX) }
                                    .onChange(of: scrollGeo.frame(in: .global).minX) { _ in
                                        updateYear(scrollGeo, centerX: centerX)
                                    }
                            }
                            .frame(height: 1)

                            VStack(alignment: .leading, spacing: 0) {
                                // 1. Sticky Year Bar
                                ZStack(alignment: .topLeading) {
                                    Color(.windowBackgroundColor).opacity(0.95)
                                    yearLabelsHeader
                                }
                                .frame(width: totalWidth, height: 50)
                                .overlay(Divider(), alignment: .bottom)
                                .zIndex(1)

                                // 2. Events
                                ScrollView(.vertical, showsIndicators: true) {
                                    ZStack(alignment: .topLeading) {
                                        TimelineBackgroundGrid(startYear: timelineStartYear, pixelsPerYear: pixelsPerYear)
                                            .offset(x: horizontalPadding)
                                        
                                        if viewModel.isLoading {
                                            ProgressView()
                                                .frame(width: visibleWidth)
                                                .padding(.top, 100)
                                        } else {
                                            renderEvents()
                                        }
                                    }
                                    .frame(width: totalWidth, height: 2500)
                                }
                            }
                        }
                    }

                    // --- CENTRAL FIXED SCRUBBER + ACTIVE YEAR LABEL ---
                    VStack(spacing: 0) {
                        Text(TimelineUtils.calculateLabel(start: activeYear, end: activeYear))
                            .font(.system(size: 14, weight: .black, design: .monospaced))
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
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event)
            }
            .task {
                await viewModel.loadEvents()
            }
        }
    }

    // MARK: - Logic to calculate year from scroll
    private func updateYear(_ proxy: GeometryProxy, centerX: CGFloat) {
        // We use .global to ensure we are measuring against the screen edge
        let scrollOffset = proxy.frame(in: .global).minX
        
        // Use the passed-in centerX which is relative to the current visible width
        let relativeX = centerX - scrollOffset - horizontalPadding
        let yearsPassed = Int(relativeX / pixelsPerYear)
        
        var newYear = timelineStartYear + yearsPassed
        
        // Handle Year 0 skip (1 BC to 1 AD)
        if newYear >= 0 { newYear += 1 }
        
        let clampedYear = min(max(newYear, timelineStartYear), timelineEndYear)
        
        if activeYear != clampedYear {
            activeYear = clampedYear
        }
    }

    // MARK: - Components
    
    private var centerScrubberLine: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 14))
                .foregroundColor(.red)
                .offset(y: 4)
            
            Rectangle()
                .fill(LinearGradient(colors: [.red, .red.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var yearLabelsHeader: some View {
        let years = Array(stride(from: timelineStartYear, to: timelineEndYear, by: 100))
        return ZStack(alignment: .topLeading) {
            ForEach(years, id: \.self) { year in
                Text(TimelineUtils.calculateLabel(start: year, end: year))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .position(
                        x: (CGFloat(year - timelineStartYear) * pixelsPerYear) + horizontalPadding,
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
                    x: (CGFloat(event.start - timelineStartYear) * pixelsPerYear) + horizontalPadding + (calculatedWidth / 2),
                    y: (CGFloat(event.row) * rowHeight) + 60
                )
            }
        }
    }
}
