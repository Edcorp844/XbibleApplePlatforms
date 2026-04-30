import SwiftUI

struct TimelineFeatureView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var selectedEvent: TimelineEvent?
    
    // Track horizontal scroll sync
    @State private var horizontalOffset: CGFloat = 0
    
    // Layout Constants
    let timelineStart: Int = -4100
    let timelineEnd: Int = 2100
    let pixelsPerYear: CGFloat = 1.2
    let currentYear: Int = 2026

    private var scrollViewWidth: CGFloat {
        CGFloat(abs(timelineStart - timelineEnd)) * pixelsPerYear
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. THE STICKY YEAR BAR
            // Using a simple horizontal ScrollView that we will sync later
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    yearLabelsLayer
                    currentYearBubble
                }
                .frame(width: scrollViewWidth, height: 40)
                // This offset trick keeps it in sync if you use a sync method,
                // but the cleanest Mac way is nesting. See "The Sync Fix" below.
            }
            .background(Color(.windowBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            // 2. THE MAIN CONTENT
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    TimelineBackgroundGrid(startYear: timelineStart, pixelsPerYear: pixelsPerYear)
                        .frame(width: scrollViewWidth)
                    
                    currentYearLine
                    
                    if viewModel.isLoading {
                        ProgressView().position(x: 500, y: 100)
                    } else {
                        contentLayer
                    }
                }
                // Height should be dynamic based on your row count,
                // but 1500 is a safe start.
                .frame(width: scrollViewWidth, height: 1500)
            }
        }
        .navigationTitle("Bible Timeline")
        .sheet(item: $selectedEvent) { event in
            eventDetailView(for: event)
        }
        .task {
            await viewModel.loadEvents()
        }
    }

    // MARK: - Fixed Year Labels Layer
    private var yearLabelsLayer: some View {
        // FIX: Convert stride to Array to satisfy ForEach
        let years = Array(stride(from: timelineStart, to: timelineEnd, by: 100))
        
        return ZStack(alignment: .topLeading) {
            ForEach(years, id: \.self) { year in
                Text(TimelineUtils.calculateLabel(start: year, end: year))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .position(
                        x: CGFloat(year - timelineStart) * pixelsPerYear,
                        y: 20
                    )
            }
        }
    }

    private var currentYearBubble: some View {
        let xPos = CGFloat(currentYear - timelineStart) * pixelsPerYear
        return Text("\(currentYear)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.red))
            .position(x: xPos, y: 20)
    }

    private var currentYearLine: some View {
        let xPos = CGFloat(currentYear - timelineStart) * pixelsPerYear
        return Rectangle()
            .fill(Color.red)
            .frame(width: 2)
            .frame(maxHeight: .infinity)
            .offset(x: xPos)
    }

    @ViewBuilder
    private var contentLayer: some View {
        ForEach(viewModel.sections) { section in
            let sectionColor = Color(hex: section.color)
            ForEach(section.events) { event in
                let startX = CGFloat(event.start - timelineStart) * pixelsPerYear
                let endX = CGFloat(event.end - timelineStart) * pixelsPerYear
                let rawWidth = endX - startX
                let calculatedWidth = rawWidth < 200 ? 200 : rawWidth

                TimelineItemView(event: event, sectionColor: sectionColor, width: calculatedWidth) { ev in
                    self.selectedEvent = ev
                }
                .offset(x: startX, y: TimelineUtils.rowToPx(row: CGFloat(event.row)))
            }
        }
    }

    @ViewBuilder
    private func eventDetailView(for event: TimelineEvent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text(event.title).font(.title2).bold()
                    Text(TimelineUtils.calculateLabel(start: event.start, end: event.end))
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button { selectedEvent = nil } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2)
                }.buttonStyle(.plain)
            }
            .padding()
            Divider()
            ScrollView {
                Text(event.slug).padding()
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}
