import AppKit
import SwiftUI

struct SearchTickerView: View {
    @ObservedObject var service: StockService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var query = ""
    @State private var results: [YFSearchQuote] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private var theme: ChartTheme { ChartTheme.forScheme(colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search symbol or company…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onChange(of: query) { _, newValue in
                        performSearch(for: newValue)
                    }

                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                } else if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(
                colorScheme == .light
                    ? Color.black.opacity(0.04)
                    : Color.white.opacity(0.05)
            )
            .cornerRadius(8)
            .padding(12)

            Divider()
                .overlay(
                    (colorScheme == .light ? Color.black : Color.white).opacity(0.12)
                )

            List {
                if query.isEmpty {
                    Text("Type a ticker symbol (e.g. AAPL, MSFT) or company name.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                        .listRowBackground(Color.clear)
                } else if results.isEmpty && !isSearching {
                    Text("No results found.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(results) { quote in
                        Button {
                            let ticker = SavedTicker(symbol: quote.symbol, name: quote.displayName)
                            service.addTicker(ticker)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(quote.symbol)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(colorScheme == .light ? Color.primary : Color.white)
                                    Text(quote.displayName)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if let type = quote.quoteType {
                                    Text(type)
                                        .font(.system(size: 9, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            (colorScheme == .light ? Color.black : Color.white)
                                                .opacity(0.1)
                                        )
                                        .cornerRadius(4)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 360, height: 400)
        .background(theme.panel)
    }

    private func performSearch(for text: String) {
        searchTask?.cancel()

        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            do {
                let fetched = try await service.search(query: text)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.results = fetched
                    self.isSearching = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.results = []
                    self.isSearching = false
                }
            }
        }
    }
}
