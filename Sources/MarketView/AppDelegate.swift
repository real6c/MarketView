import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let service = StockService()
    private var refreshTimer: Timer?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        observeService()
        scheduleRefresh()
        Task { await service.loadDefault() }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.title = "SPX…"
        button.action = #selector(handleButtonClick)
        button.target = self
    }

    @objc private func handleButtonClick() {
        popover.isShown ? closePopover() : openPopover()
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 500, height: 340)
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: ChartView(service: service)
        )

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover.isShown == true { self?.closePopover() }
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    // MARK: - Reactive updates

    /// Re-renders the status item whenever service data changes (period switch, refresh, etc.)
    private func observeService() {
        service.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // objectWillChange fires *before* the values change; defer by one run-loop pass
                DispatchQueue.main.async { self?.updateStatusItem() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Status item rendering

    @MainActor
    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        // ── sparkline — always reflects the current period's data ──────────
        let closes = service.points.map(\.close)
        if let sparkImage = SparklineRenderer.makeImage(values: closes, isPositive: service.isPositive) {
            button.image         = sparkImage
            button.imagePosition = .imageLeft
            button.imageScaling  = .scaleProportionallyDown
        }

        // ── label: ticker + percentage change ──────────────────────────────
        let tickerStr = service.activeTicker.symbol == "^GSPC" ? "SPX" : service.activeTicker.symbol

        guard let pct = service.changePct else {
            button.attributedTitle = NSAttributedString(string: " \(tickerStr) --")
            return
        }

        let sign  = pct >= 0 ? "+" : ""
        let label = " \(tickerStr) \(sign)\(String(format: "%.2f", pct))%"
        let color: NSColor = service.isPositive ? .systemGreen : .systemRed

        button.attributedTitle = NSAttributedString(string: label, attributes: [
            .foregroundColor: color,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
        ])
    }

    // MARK: - Periodic refresh

    private func scheduleRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.service.loadDefault() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
    }
}
