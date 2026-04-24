import Foundation
import SwiftUI

final class StockService: ObservableObject {
    @Published var points: [PricePoint] = []
    @Published var currentPrice: Double?
    @Published var openPrice: Double?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPeriod: Period = .oneYear

    // Ticker management
    @AppStorage("savedTickers") private var savedTickersData: Data = Data()
    @AppStorage("activeTickerSymbol") private var activeTickerSymbol: String = SavedTicker.defaultTicker.symbol
    
    @Published var savedTickers: [SavedTicker] = [SavedTicker.defaultTicker]
    @Published var activeTicker: SavedTicker = SavedTicker.defaultTicker
    @Published var sparklineValues: [Double] = []

    var change: Double? {
        guard let c = currentPrice, let o = openPrice else { return nil }
        return c - o
    }
    var changePct: Double? {
        guard let ch = change, let o = openPrice, o != 0 else { return nil }
        return ch / o * 100
    }
    var isPositive: Bool { (change ?? 0) >= 0 }

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0"]
        return URLSession(configuration: cfg)
    }()

    init() {
        loadSavedTickers()
    }

    // MARK: - Ticker Management

    private func loadSavedTickers() {
        if let decoded = try? JSONDecoder().decode([SavedTicker].self, from: savedTickersData) {
            savedTickers = decoded
        }
        if savedTickers.isEmpty {
            savedTickers = [SavedTicker.defaultTicker]
        }
        
        if let active = savedTickers.first(where: { $0.symbol == activeTickerSymbol }) {
            activeTicker = active
        } else {
            activeTicker = savedTickers[0]
        }
    }

    private func saveTickers() {
        if let encoded = try? JSONEncoder().encode(savedTickers) {
            savedTickersData = encoded
        }
        activeTickerSymbol = activeTicker.symbol
    }

    func selectTicker(_ ticker: SavedTicker) {
        activeTicker = ticker
        saveTickers()
        Task { await load(period: selectedPeriod) }
    }

    func addTicker(_ ticker: SavedTicker) {
        if !savedTickers.contains(where: { $0.symbol == ticker.symbol }) {
            savedTickers.append(ticker)
            saveTickers()
        }
        selectTicker(ticker)
    }

    func removeTicker(_ ticker: SavedTicker) {
        savedTickers.removeAll { $0.symbol == ticker.symbol }
        if savedTickers.isEmpty {
            savedTickers = [SavedTicker.defaultTicker]
        }
        if activeTicker.symbol == ticker.symbol {
            activeTicker = savedTickers[0]
            Task { await load(period: selectedPeriod) }
        }
        saveTickers()
    }

    // MARK: - Data Fetching

    func load(period: Period) async {
        await MainActor.run {
            selectedPeriod = period
            isLoading = true
            errorMessage = nil
        }

        let symbol = activeTicker.symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? activeTicker.symbol
        let urlStr = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=\(period.interval)&range=\(period.range)"

        do {
            guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
            let (data, _) = try await session.data(from: url)
            let decoded = try JSONDecoder().decode(YFResponse.self, from: data)

            guard let result = decoded.chart.result?.first else {
                await MainActor.run { errorMessage = "No data returned" }
                return
            }

            let timestamps = result.timestamp ?? []
            let closes = result.indicators.quote.first?.close ?? []
            let newPoints = zip(timestamps, closes).compactMap { ts, close -> PricePoint? in
                guard let close else { return nil }
                return PricePoint(date: Date(timeIntervalSince1970: TimeInterval(ts)), close: close)
            }
            let newPrice = result.meta.regularMarketPrice
            let newOpen  = result.meta.openPrice

            await MainActor.run {
                points       = newPoints
                currentPrice = newPrice
                openPrice    = newOpen
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }

        await MainActor.run { isLoading = false }
    }

    func loadDefault() async {
        // Run both fetches concurrently
        async let mainFetch: Void  = load(period: selectedPeriod)
        async let sparkFetch: Void = loadSparkline()
        _ = await (mainFetch, sparkFetch)
    }

    /// Fetches 3-month daily data for the menu-bar sparkline (independent of selected period).
    func loadSparkline() async {
        let symbol = activeTicker.symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? activeTicker.symbol
        let urlStr = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=3mo"
        guard let url = URL(string: urlStr) else { return }
        do {
            let (data, _) = try await session.data(from: url)
            let decoded   = try JSONDecoder().decode(YFResponse.self, from: data)
            guard let result = decoded.chart.result?.first else { return }
            let timestamps = result.timestamp ?? []
            let closes     = result.indicators.quote.first?.close ?? []
            let values = zip(timestamps, closes).compactMap { _, close in close }
            await MainActor.run { sparklineValues = values }
        } catch {
            // Sparkline is best-effort; ignore errors silently
        }
    }

    // MARK: - Search

    func search(query: String) async throws -> [YFSearchQuote] {
        guard !query.isEmpty else { return [] }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlStr = "https://query1.finance.yahoo.com/v1/finance/search?q=\(encoded)&quotesCount=10&newsCount=0"
        guard let url = URL(string: urlStr) else { return [] }
        
        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(YFSearchResponse.self, from: data)
        
        // Filter out non-equity/index results if needed, or just return them
        return decoded.quotes.filter { $0.quoteType == "EQUITY" || $0.quoteType == "ETF" || $0.quoteType == "INDEX" || $0.quoteType == "CRYPTOCURRENCY" }
    }
}
