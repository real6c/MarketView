import AppKit
import SwiftUI
import Charts

// MARK: - Theme (expanded view follows system appearance; dark = existing look)

struct ChartTheme {
    let background: Color
    let panel: Color
    let gridLine: Color
    let axisLabel: Color
    let baseline: Color
    let up: Color
    let down: Color
    let priceText: Color
    let secondaryText: Color
    /// Fills the inner ring of point markers; matches plot background
    let plotBackground: Color
    let pressedShade: Color

    static func forScheme(_ scheme: ColorScheme) -> ChartTheme {
        switch scheme {
        case .light:
            return ChartTheme(
                background: Color(nsColor: .windowBackgroundColor),
                panel: Color(nsColor: .controlBackgroundColor),
                gridLine: Color.black.opacity(0.1),
                axisLabel: Color.primary.opacity(0.55),
                baseline: Color.black.opacity(0.22),
                up: Color(red: 0.10, green: 0.62, blue: 0.38),
                down: Color(red: 0.90, green: 0.22, blue: 0.26),
                priceText: Color.primary,
                secondaryText: Color.secondary,
                plotBackground: Color(nsColor: .windowBackgroundColor),
                pressedShade: Color.black.opacity(0.06)
            )
        case .dark:
            fallthrough
        @unknown default:
            return ChartTheme(
                background: Color(red: 0.07, green: 0.08, blue: 0.10),
                panel: Color(red: 0.08, green: 0.09, blue: 0.11),
                gridLine: Color.white.opacity(0.05),
                axisLabel: Color.white.opacity(0.45),
                baseline: Color.white.opacity(0.18),
                up: Color(red: 0.20, green: 0.82, blue: 0.51),
                down: Color(red: 1.00, green: 0.32, blue: 0.37),
                priceText: .white,
                secondaryText: Color.white.opacity(0.55),
                plotBackground: Color(red: 0.07, green: 0.08, blue: 0.10),
                pressedShade: Color.white.opacity(0.05)
            )
        }
    }
}

// MARK: - Root popover view

struct ChartView: View {
    @ObservedObject var service: StockService
    @Environment(\.colorScheme) private var colorScheme

    @State private var hoveredIndex: Int?
    @State private var dragStartIndex: Int?
    @State private var dragCurrentIndex: Int?

    @State private var showingSearch = false

    private var theme: ChartTheme { ChartTheme.forScheme(colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            header
            chartArea
            periodBar
        }
        .frame(width: 520, height: 360)
        .background(theme.background)
        .task { await service.loadDefault() }
        .popover(isPresented: $showingSearch) {
            SearchTickerView(service: service)
        }
    }

    // MARK: Hover & Drag Helpers

    private var isDragging: Bool {
        dragStartIndex != nil && dragCurrentIndex != nil
    }

    private var activeStartPoint: PricePoint? {
        if let idx = dragStartIndex, idx >= 0, idx < service.points.count {
            return service.points[idx]
        }
        return nil
    }

    private var activeEndPoint: PricePoint? {
        if let idx = dragCurrentIndex, idx >= 0, idx < service.points.count {
            return service.points[idx]
        }
        if let idx = hoveredIndex, idx >= 0, idx < service.points.count {
            return service.points[idx]
        }
        return service.points.last
    }

    private var displayPrice: Double? {
        if isDragging { return activeEndPoint?.close }
        if hoveredIndex != nil { return activeEndPoint?.close }
        return service.currentPrice
    }

    private var displayChange: Double? {
        if isDragging, let start = activeStartPoint?.close, let end = activeEndPoint?.close {
            return end - start
        }
        if hoveredIndex != nil {
            guard let price = activeEndPoint?.close, let open = service.openPrice else { return nil }
            return price - open
        }
        return service.change
    }

    private var displayChangePct: Double? {
        if isDragging, let start = activeStartPoint?.close, let ch = displayChange, start != 0 {
            return ch / start * 100
        }
        if hoveredIndex != nil {
            guard let ch = displayChange, let open = service.openPrice, open != 0 else { return nil }
            return ch / open * 100
        }
        return service.changePct
    }

    private var displayIsPositive: Bool {
        (displayChange ?? 0) >= 0
    }

    private func formatHoverDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        switch service.selectedPeriod {
        case .oneDay, .oneWeek:
            f.dateFormat = "MMM d, h:mm a"
        case .oneMonth, .threeMonths, .yearToDate, .oneYear:
            f.dateFormat = "MMM d, yyyy"
        case .fiveYears:
            f.dateFormat = "MMM d, yyyy"
        }
        return f.string(from: date)
    }

    // MARK: Header

    private var quitButton: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Image(systemName: "power")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(red: 0.92, green: 0.22, blue: 0.24))
                )
        }
        .buttonStyle(.plain)
        .help("Quit MarketView")
    }

    private var header: some View {
        let accent = displayIsPositive ? theme.up : theme.down
        // Reserve space so the first row does not run under the 30×30 control.
        let topRowTrailingGutter: CGFloat = 8 + 30

        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if isDragging, let pt1 = activeStartPoint, let pt2 = activeEndPoint {
                        Text("\(formatHoverDate(pt1.date))  →  \(formatHoverDate(pt2.date))")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(0.3)
                            .foregroundStyle(theme.secondaryText)
                    } else if hoveredIndex != nil, let pt = activeEndPoint {
                        Text(formatHoverDate(pt.date))
                            .font(.system(size: 11, weight: .medium))
                            .tracking(0.3)
                            .foregroundStyle(theme.secondaryText)
                    } else {
                        Menu {
                            Button(action: { showingSearch = true }) {
                                Label("Add Ticker…", systemImage: "plus")
                            }

                            Divider()

                            ForEach(service.savedTickers) { ticker in
                                Button(action: { service.selectTicker(ticker) }) {
                                    HStack {
                                        Text("\(ticker.name) (\(ticker.symbol))")
                                        if service.activeTicker.symbol == ticker.symbol {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }

                            if service.savedTickers.count > 1 {
                                Divider()
                                Button(role: .destructive, action: { service.removeTicker(service.activeTicker) }) {
                                    Label("Remove \(service.activeTicker.symbol)", systemImage: "trash")
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("\(service.activeTicker.name)  ·  \(service.activeTicker.symbol)")
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9))
                            }
                            .font(.system(size: 11, weight: .medium))
                            .tracking(0.3)
                            .foregroundStyle(theme.secondaryText)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize(horizontal: true, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, topRowTrailingGutter)
                .multilineTextAlignment(.leading)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if let price = displayPrice {
                        Text(price, format: .number.precision(.fractionLength(2)))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.priceText)
                            .monospacedDigit()
                    } else {
                        Text("—")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.priceText)
                    }

                    if let pct = displayChangePct, let ch = displayChange {
                        let sign = displayIsPositive ? "+" : "−"
                        Text("\(sign)\(String(format: "%.2f", abs(ch)))  (\(sign)\(String(format: "%.2f", abs(pct)))%)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(accent)
                            .monospacedDigit()
                    }

                    Spacer()

                    if service.isLoading {
                        ProgressView()
                            .scaleEffect(0.55)
                            .tint(theme.secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            quitButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: Chart area

    @ViewBuilder
    private var chartArea: some View {
        if let error = service.errorMessage {
            Text("Error: \(error)")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if service.points.isEmpty && !service.isLoading {
            Text("No data")
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            SPXChart(
                points: service.points,
                isPositive: service.isPositive,
                openPrice: service.openPrice,
                period: service.selectedPeriod,
                hoveredIndex: $hoveredIndex,
                dragStartIndex: $dragStartIndex,
                dragCurrentIndex: $dragCurrentIndex
            )
        }
    }

    // MARK: Period bar

    private var periodBar: some View {
        HStack(spacing: 2) {
            ForEach(Period.allCases) { period in
                Button(period.rawValue) {
                    Task { await service.load(period: period) }
                }
                .buttonStyle(PeriodButtonStyle(
                    selected: service.selectedPeriod == period,
                    accent: service.isPositive ? theme.up : theme.down,
                    theme: theme
                ))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.panel)
    }
}

// MARK: - SPX Chart

struct SPXChart: View {
    let points: [PricePoint]
    let isPositive: Bool
    let openPrice: Double?
    let period: Period
    @Binding var hoveredIndex: Int?
    @Binding var dragStartIndex: Int?
    @Binding var dragCurrentIndex: Int?

    @Environment(\.colorScheme) private var colorScheme
    private var theme: ChartTheme { ChartTheme.forScheme(colorScheme) }

    /// Tight Y domain with breathing room above and below.
    private var yDomain: ClosedRange<Double> {
        let closes = points.map(\.close)
        guard var lo = closes.min(), var hi = closes.max() else { return 0...1 }

        if let open = openPrice {
            lo = min(lo, open)
            hi = max(hi, open)
        }

        let span = hi - lo
        guard span > 0 else {
            let pad = hi * 0.01
            return (hi - pad)...(hi + pad)
        }
        let pad = span * 0.10
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        let base = openPrice ?? points.first?.close ?? 0
        let domain = yDomain

        // In SwiftUI Charts, when you apply a LinearGradient to a series (like a LineMark
        // or AreaMark), the gradient's coordinate space (0.0 to 1.0) maps exactly to the
        // bounding box of the *drawn marks*, NOT the full axis domain.
        // Therefore, we must calculate where the baseline sits relative to the min/max
        // of the actual data points (plus the baseline itself), rather than the padded domain.
        let closes = points.map(\.close)
        let maxPrice = max(closes.max() ?? base, base)
        let minPrice = min(closes.min() ?? base, base)

        let baseFrac: CGFloat = {
            let total = maxPrice - minPrice
            guard total > 0 else { return 0.5 }
            // 0.0 = top of the bounding box (maxPrice)
            // 1.0 = bottom of the bounding box (minPrice)
            let fraction = (maxPrice - base) / total
            return CGFloat(max(0, min(1, fraction)))
        }()

        Chart {
            // ── Area fill — split at baseline (green above, red below) ─────
            // When dragging, we only fill the area between start and current index.
            let dragMinIdx = min(dragStartIndex ?? -1, dragCurrentIndex ?? -1)
            let dragMaxIdx = max(dragStartIndex ?? -1, dragCurrentIndex ?? -1)
            let isDragging = dragMinIdx >= 0

            if isDragging {
                ForEach(Array(points.enumerated()), id: \.element.id) { i, pt in
                    if i >= dragMinIdx && i <= dragMaxIdx {
                        AreaMark(
                            x: .value("Index", i),
                            yStart: .value("Base", base),
                            yEnd: .value("Price", pt.close)
                        )
                    }
                }
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: theme.up.opacity(0.30),   location: 0.0),
                            .init(color: theme.up.opacity(0.00),   location: max(0, baseFrac - 0.001)),
                            .init(color: theme.down.opacity(0.00), location: min(1, baseFrac + 0.001)),
                            .init(color: theme.down.opacity(0.30), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            } else {
                ForEach(Array(points.enumerated()), id: \.element.id) { i, pt in
                    AreaMark(
                        x: .value("Index", i),
                        yStart: .value("Base", base),
                        yEnd: .value("Price", pt.close)
                    )
                }
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: theme.up.opacity(0.30),   location: 0.0),
                            .init(color: theme.up.opacity(0.00),   location: max(0, baseFrac - 0.001)),
                            .init(color: theme.down.opacity(0.00), location: min(1, baseFrac + 0.001)),
                            .init(color: theme.down.opacity(0.30), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }

            // ── Main line — same split, solid colors ───────────────────────
            ForEach(Array(points.enumerated()), id: \.element.id) { i, pt in
                LineMark(
                    x: .value("Index", i),
                    y: .value("Price", pt.close)
                )
            }
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: theme.up,   location: 0.0),
                        .init(color: theme.up,   location: max(0, baseFrac - 0.001)),
                        .init(color: theme.down, location: min(1, baseFrac + 0.001)),
                        .init(color: theme.down, location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

            // ── Baseline rule at opening price ─────────────────────────────
            RuleMark(y: .value("Open", base))
                .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                .foregroundStyle(theme.baseline)

            // ── Drag / Hover Indicators ────────────────────────────────────
            if let startIdx = dragStartIndex, let currIdx = dragCurrentIndex,
               startIdx >= 0, startIdx < points.count,
               currIdx >= 0, currIdx < points.count {
                
                let startPt = points[startIdx]
                let currPt = points[currIdx]
                let isDragPos = currPt.close >= startPt.close
                let dragColor = isDragPos ? theme.up : theme.down

                // Start Marker
                RuleMark(x: .value("Index", startIdx))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(theme.axisLabel.opacity(0.6))
                PointMark(
                    x: .value("Index", startIdx),
                    y: .value("Price", startPt.close)
                )
                .symbolSize(40)
                .foregroundStyle(theme.axisLabel)

                // Current Marker
                RuleMark(x: .value("Index", currIdx))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(theme.axisLabel.opacity(0.5))
                PointMark(
                    x: .value("Index", currIdx),
                    y: .value("Price", currPt.close)
                )
                .symbolSize(80)
                .foregroundStyle(dragColor)
                
                PointMark(
                    x: .value("Index", currIdx),
                    y: .value("Price", currPt.close)
                )
                .symbolSize(25)
                .foregroundStyle(theme.plotBackground)
                
            } else if let idx = hoveredIndex, idx >= 0, idx < points.count {
                let pt = points[idx]
                
                RuleMark(x: .value("Index", idx))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(theme.axisLabel.opacity(0.5))

                PointMark(
                    x: .value("Index", idx),
                    y: .value("Price", pt.close)
                )
                .symbolSize(80)
                .foregroundStyle(pt.close >= base ? theme.up : theme.down)
                
                PointMark(
                    x: .value("Index", idx),
                    y: .value("Price", pt.close)
                )
                .symbolSize(25)
                .foregroundStyle(theme.plotBackground)
                
            } else if let last = points.last {
                PointMark(
                    x: .value("Index", points.count - 1),
                    y: .value("Price", last.close)
                )
                .symbolSize(36)
                .foregroundStyle(last.close >= base ? theme.up : theme.down)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if let floatIndex: Double = proxy.value(atX: value.location.x) {
                                    let idx = max(0, min(points.count - 1, Int(round(floatIndex))))
                                    if dragStartIndex == nil {
                                        dragStartIndex = idx
                                    }
                                    dragCurrentIndex = idx
                                    hoveredIndex = nil
                                }
                            }
                            .onEnded { _ in
                                dragStartIndex = nil
                                dragCurrentIndex = nil
                            }
                    )
                    .onContinuousHover { phase in
                        guard dragStartIndex == nil else { return }
                        switch phase {
                        case .active(let location):
                            if let floatIndex: Double = proxy.value(atX: location.x) {
                                hoveredIndex = max(0, min(points.count - 1, Int(round(floatIndex))))
                            }
                        case .ended:
                            hoveredIndex = nil
                        }
                    }
            }
        }
        .chartYScale(domain: domain)
        .chartXScale(domain: 0...(points.count - 1))
        .chartXAxis {
            AxisMarks(values: tickIndices) { value in
                if let idx = value.as(Int.self), idx >= 0, idx < points.count {
                    AxisValueLabel {
                        Text(formatted(points[idx].date))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.axisLabel)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(theme.gridLine)
                AxisValueLabel(
                    format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
                )
                .foregroundStyle(theme.axisLabel)
                .font(.system(size: 10, weight: .medium))
            }
        }
        .chartPlotStyle { plot in
            plot.padding(.top, 8).padding(.bottom, 4)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
    }

    // MARK: - Tick dates

    private var tickIndices: [Int] {
        guard points.count >= 2 else { return [] }

        let target: Int
        switch period {
        case .oneDay:       target = 5
        case .oneWeek:      target = 5
        case .oneMonth:     target = 4
        case .threeMonths:  target = 4
        case .yearToDate:   target = 5
        case .oneYear:      target = 6
        case .fiveYears:    target = 5
        }

        let n = points.count
        guard n > target else { return Array(0..<n) }

        return (0 ..< target).map { i in
            i * (n - 1) / (target - 1)
        }
    }

    // MARK: - Date formatting

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        switch period {
        case .oneDay:       f.dateFormat = "h:mm a"
        case .oneWeek:      f.dateFormat = "EEE"
        case .oneMonth:     f.dateFormat = "MMM d"
        case .threeMonths:  f.dateFormat = "MMM d"
        case .yearToDate:   f.dateFormat = "MMM"
        case .oneYear:      f.dateFormat = "MMM"
        case .fiveYears:    f.dateFormat = "yyyy"
        }
        return f.string(from: date)
    }
}

// MARK: - Period button style

struct PeriodButtonStyle: ButtonStyle {
    let selected: Bool
    let accent: Color
    let theme: ChartTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(selected ? accent : theme.secondaryText)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        selected
                            ? accent.opacity(0.15)
                            : (configuration.isPressed ? theme.pressedShade : Color.clear)
                    )
            )
            .contentShape(Rectangle())
    }
}
