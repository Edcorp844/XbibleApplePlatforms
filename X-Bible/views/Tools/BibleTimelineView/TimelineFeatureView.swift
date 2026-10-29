import SwiftUI
import XbibleEngine


struct TimelineFeatureView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var selectedEvent: Event?

    // Zoom
    @State private var scale: CGFloat = 1.0

    // Scroll position (for scrubber)
    @State private var horizontalOffset: CGFloat = 0
    @State private var centerYear: Int64 = 0

    // Era capsule
    @State private var isPeriodExpanded: Bool = false

    // Base metrics
    private let basePixelsPerYear: CGFloat = 1.2
    private let rowHeight: CGFloat = 52
    private let topPadding: CGFloat = 60
    private let bottomPadding: CGFloat = 80

    // MARK: - Derived from viewModel.periods (no hard-coding)

    private var timelineStart: Int64 {
        viewModel.periods.map(\.startYear).min() ?? -4100
    }
    private var timelineEnd: Int64 {
        viewModel.periods.map(\.endYear).max() ?? 2100
    }
    private var totalYears: Int64 { max(1, timelineEnd - timelineStart) }
    private var pixelsPerYear: CGFloat { basePixelsPerYear * scale }
    private var scrollViewWidth: CGFloat { CGFloat(totalYears) * pixelsPerYear }

    /// Pack events so they never overlap horizontally.
    private var eventRows: [UInt64: Int] {
        let all = viewModel.periods
            .flatMap { $0.events }
            .sorted { $0.start < $1.start }

        var rowEnds: [CGFloat] = []
        var rows: [UInt64: Int] = [:]

        for event in all {
            let startX = CGFloat(event.start - timelineStart) * pixelsPerYear
            let visualWidth = CGFloat(max(0, event.end - event.start)) * pixelsPerYear
            let labelWidth = CGFloat(event.title.count) * 6.5
            let totalWidth = max(visualWidth, labelWidth) + 30
            let endX = startX + totalWidth

            if let idx = rowEnds.firstIndex(where: { startX >= $0 }) {
                rowEnds[idx] = endX
                rows[event.id] = idx
            } else {
                rowEnds.append(endX)
                rows[event.id] = rowEnds.count - 1
            }
        }
        return rows
    }

    private var maxRow: Int { eventRows.values.max() ?? 0 }
    private var totalContentHeight: CGFloat {
        topPadding + CGFloat(maxRow + 1) * rowHeight + bottomPadding
    }

    private var currentPeriod: Period? {
        viewModel.periods.first {
            centerYear >= $0.startYear && centerYear <= $0.endYear
        }
    }
    private var prevPeriod: Period? {
        viewModel.periods
            .filter { $0.startYear < centerYear - 2 }
            .max(by: { $0.startYear < $1.startYear })
    }
    private var nextPeriod: Period? {
        viewModel.periods
            .filter { $0.startYear > centerYear + 2 }
            .min(by: { $0.startYear < $1.startYear })
    }

    // MARK: - Body (layout preserved)

    var body: some View {
        GeometryReader { geo in
            let halfWidth = geo.size.width / 2

            ZStack(alignment: .bottom) {
                // ── Sticky year header + main canvas
                VStack(spacing: 0) {
                    // Year header — offsets with scroll for sync
                    ScrollView(.horizontal, showsIndicators: false) {
                        ZStack(alignment: .topLeading) {
                            yearLabelsLayer
                                .offset(x: -horizontalOffset)
                        }
                        .frame(width: scrollViewWidth, height: 40)
                    }
                    #if os(macOS)
                    .background(Color(.windowBackgroundColor))
                    #else
                    .background(.clear)
                    #endif
                    .overlay(Divider(), alignment: .bottom)

                    // Main content
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            TimelineBackgroundGrid(
                                startYear: Int(timelineStart),
                                pixelsPerYear: pixelsPerYear
                            )
                            .frame(width: scrollViewWidth)

                            // Current-year red line
                            currentYearLine

                            if viewModel.isLoading {
                                ProgressView()
                                    .position(x: halfWidth, y: 100)
                            } else {
                                contentLayer
                            }
                        }
                        .frame(width: scrollViewWidth, height: totalContentHeight)
                    }
                    .safeAreaPadding(.horizontal, halfWidth)
                    .coordinateSpace(name: "timeline")
                    .onScrollGeometryChange(for: CGFloat.self) { g in
                        g.contentOffset.x
                    } action: { _, newValue in
                        horizontalOffset = newValue
                        updateCenterYear(halfWidth: halfWidth)
                        // Collapse era capsule on scroll
                        if isPeriodExpanded {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isPeriodExpanded = false
                            }
                        }
                    }
                }

                // ── Center red scrubber line
                Rectangle()
                    .fill(scrubberColor.opacity(0.4))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .allowsHitTesting(false)

                // ── Floating era header capsule
                eraCapsule
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                    .frame(maxHeight: .infinity, alignment: .top)

                // ── Bottom control bar
                bottomControls
            }
            .gesture(
                MagnifyGesture()
                    .onChanged { v in
                        scale = min(max(scale * v.magnification, 0.1), 10)
                    }
            )
        }
        .navigationTitle("Bible Timeline")
        .sheet(item: $selectedEvent) { event in
            eventDetailView(for: event)
        }
        .task {
            await viewModel.loadEvents()
            if centerYear == 0 { centerYear = timelineStart }
        }
    }

    // MARK: - Year header (unchanged look, Int64-safe)

    private var yearLabelsLayer: some View {
        let years = Array(stride(from: timelineStart, to: timelineEnd, by: 100))
        return ZStack(alignment: .topLeading) {
            ForEach(years, id: \.self) { year in
                Text(TimelineUtils.calculateLabel(start: Int(year), end: Int(year)))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .position(
                        x: CGFloat(year - timelineStart) * pixelsPerYear,
                        y: 20
                    )
            }
        }
    }

    private var currentYearLine: some View {
        let xPos = CGFloat(centerYear - timelineStart) * pixelsPerYear
        return Rectangle()
            .fill(Color.red)
            .frame(width: 2)
            .frame(maxHeight: .infinity)
            .offset(x: xPos)
    }

    // MARK: - Events (uses packing, period color from hex)

    @ViewBuilder
    private var contentLayer: some View {
        ForEach(viewModel.periods, id: \.id) { period in
            let periodColor = TimelineUtils.color(from: period.color)
            ForEach(period.events, id: \.id) { event in
                let row = eventRows[event.id] ?? Int(event.row)
                let startX = CGFloat(event.start - timelineStart) * pixelsPerYear
                let rawWidth = CGFloat(max(0, event.end - event.start)) * pixelsPerYear
                let labelWidth = CGFloat(event.title.count) * 6.5 + 30
                let calculatedWidth = max(rawWidth, labelWidth, 200)
                let y = topPadding + CGFloat(row) * rowHeight

                TimelineItemView(
                    event: event,
                    periodColor: periodColor,
                    width: calculatedWidth
                ) { ev in
                    self.selectedEvent = ev
                }
                .offset(x: startX, y: y)
            }
        }
    }

    // MARK: - Era capsule

    @ViewBuilder
    private var eraCapsule: some View {
        if let period = currentPeriod {
            let color = TimelineUtils.color(from: period.color)

            VStack(spacing: 0) {
                if isPeriodExpanded {
                    if !period.image.isEmpty,
                       let url = URL(string: period.image) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color.secondary.opacity(0.1)
                        }
                        .frame(height: 180)
                        .clipped()
                    }
                    VStack(spacing: 6) {
                        Text(period.title)
                            .font(.title3.weight(.black))
                            .foregroundColor(color)
                        if !period.subTitle.isEmpty {
                            Text(period.subTitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Text(period.description)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .padding(.horizontal)
                        Text(TimelineUtils.rangeLabel(start: period.startYear, end: period.endYear))
                            .font(.caption2.weight(.bold))
                            .foregroundColor(color)
                    }
                    .padding(16)
                } else {
                    HStack(spacing: 8) {
                        Circle().fill(color).frame(width: 8, height: 8)
                        Text(period.title)
                            .font(.caption.weight(.black))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
            .onTapGesture {
                withAnimation(.spring(duration: 0.3)) {
                    isPeriodExpanded.toggle()
                }
            }
            .onChange(of: currentPeriod?.id) { _, _ in
                withAnimation(.spring(duration: 0.25)) {
                    isPeriodExpanded = true
                }
            }
        }
    }

    // MARK: - Bottom bar

    private var scrubberColor: Color {
        guard let p = currentPeriod else { return .red }
        return TimelineUtils.color(from: p.color, fallback: .red)
    }

    private var prevColor: Color {
        guard let p = prevPeriod else { return .secondary }
        return TimelineUtils.color(from: p.color)
    }

    private var nextColor: Color {
        guard let p = nextPeriod else { return .secondary }
        return TimelineUtils.color(from: p.color)
    }

    private var progress: CGFloat {
        guard totalYears > 0 else { return 0 }
        let raw = CGFloat(centerYear - timelineStart) / CGFloat(totalYears)
        return min(max(raw, 0), 1)
    }

    private var bottomControls: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(scrubberColor)
                .frame(height: 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(x: progress, anchor: .leading)

            HStack {
                Button {
                    if let p = prevPeriod { scrollTo(year: p.startYear) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(prevColor)
                        .frame(width: 44, height: 44)
                }
                .disabled(prevPeriod == nil)

                Spacer()

                Text(TimelineUtils.yearLabel(centerYear))
                    .font(.callout.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 4).fill(scrubberColor))

                Spacer()

                Button {
                    if let p = nextPeriod { scrollTo(year: p.startYear) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(nextColor)
                        .frame(width: 44, height: 44)
                }
                .disabled(nextPeriod == nil)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 56)
        .background(.regularMaterial)
    }

    // MARK: - Adaptive ruler
    // (Only the interval changes; grid visuals untouched)

    private func adaptiveInterval() -> Int64 {
        if pixelsPerYear > 40 { return 1 }
        if pixelsPerYear > 15 { return 5 }
        if pixelsPerYear > 8  { return 10 }
        if scale > 2          { return 50 }
        if scale > 0.5        { return 100 }
        return 500
    }

    // MARK: - Sheet (kept simple; adapters for uniffi types)

    @ViewBuilder
    private func eventDetailView(for event: Event) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text(event.title).font(.title2).bold()
                    Text(TimelineUtils.rangeLabel(start: event.start, end: event.end))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button { selectedEvent = nil } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            Divider()
            ScrollView {
                Text(event.slug).padding()
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }

    // MARK: - Helpers

    private func updateCenterYear(halfWidth: CGFloat) {
        guard pixelsPerYear > 0 else { return }
        let years = (horizontalOffset - halfWidth) / pixelsPerYear
        var y = timelineStart + Int64(years)
        if y >= 0 { y += 1 }
        centerYear = min(max(y, timelineStart), timelineEnd)
    }

    private func scrollTo(year: Int64) {
        // Requires ScrollViewReader in production; this is a placeholder that
        // just re-centers the scrubber for now.
        centerYear = year
    }
}
