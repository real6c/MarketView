import Foundation

// MARK: - Domain models

struct PricePoint: Identifiable {
    let id = UUID()
    let date: Date
    let close: Double
}

enum Period: String, CaseIterable, Identifiable {
    case oneDay      = "1D"
    case oneWeek     = "1W"
    case oneMonth    = "1M"
    case threeMonths = "3M"
    case yearToDate  = "YTD"
    case oneYear     = "1Y"
    case fiveYears   = "5Y"

    var id: String { rawValue }

    var range: String {
        switch self {
        case .oneDay:       return "1d"
        case .oneWeek:      return "5d"
        case .oneMonth:     return "1mo"
        case .threeMonths:  return "3mo"
        case .yearToDate:   return "ytd"
        case .oneYear:      return "1y"
        case .fiveYears:    return "5y"
        }
    }

    var interval: String {
        switch self {
        case .oneDay:       return "5m"
        case .oneWeek:      return "30m"
        case .oneMonth:     return "1d"
        case .threeMonths:  return "1d"
        case .yearToDate:   return "1d"
        case .oneYear:      return "1d"
        case .fiveYears:    return "1wk"
        }
    }
}

// MARK: - Yahoo Finance API response

struct YFResponse: Decodable {
    let chart: YFChart
}

struct YFChart: Decodable {
    let result: [YFResult]?
}

struct YFResult: Decodable {
    let meta: YFMeta
    let timestamp: [Int]?
    let indicators: YFIndicators
}

struct YFMeta: Decodable {
    let regularMarketPrice: Double
    let chartPreviousClose: Double?
    let previousClose: Double?

    var openPrice: Double {
        chartPreviousClose ?? previousClose ?? regularMarketPrice
    }
}

struct YFIndicators: Decodable {
    let quote: [YFQuote]
}

struct YFQuote: Decodable {
    let close: [Double?]?
}

// MARK: - Yahoo Finance Search API response

struct YFSearchResponse: Decodable {
    let quotes: [YFSearchQuote]
}

struct YFSearchQuote: Decodable, Identifiable, Hashable {
    let symbol: String
    let shortname: String?
    let longname: String?
    let exchange: String?
    let quoteType: String?

    var id: String { symbol }
    
    var displayName: String {
        shortname ?? longname ?? symbol
    }
}

// MARK: - App Data

struct SavedTicker: Codable, Identifiable, Hashable {
    let symbol: String
    let name: String

    var id: String { symbol }
    
    static let defaultTicker = SavedTicker(symbol: "^GSPC", name: "S&P 500")
}
