# MarketView

Native macOS menu bar app for live stock prices and an interactive chart.  
Built with Swift, SwiftUI, Swift Charts, and AppKit.

## Showcase

# Interacting with chart and timespan:
<img width="400" height="266" alt="chart_interact" src="https://github.com/user-attachments/assets/3331a9dd-656a-41f8-a907-c729b4dae9e9" />

# Adding ticker:
<img width="400" height="488" alt="add_ticker" src="https://github.com/user-attachments/assets/8908c900-2db7-40b8-b5e3-37037da0a3fc" />

# Removing ticker:
<img width="400" height="272" alt="remove_ticker" src="https://github.com/user-attachments/assets/aa3f36ca-edaf-404f-ab0c-229885d40566" />

# Quit app:
<img width="400" height="270" alt="quit_app" src="https://github.com/user-attachments/assets/109125cd-2fdd-439c-af6c-67b0565c09d8" />

## Features

- **Menu bar** — selected ticker’s price with a colored **▲/▼** indicator and % change (sparkline in the item)
- **Popover** — Swift Charts **area** + gradient, opening-price baseline, **hover** and **drag** to inspect points
- **Tickers** — add symbols via **search**, switch between saved tickers from the header menu, remove when more than one is saved
- **Periods** — **1D · 1W · 1M · 3M · 1Y · 5Y**
- **Auto-refresh** about every 5 minutes
- **Appearance** — popover follows **system** light/dark
- **Quit** — red power control in the **top-right** of the popover
- **No Dock icon** — menu bar only (`LSUIElement`)

## App icon

`icon.png` is scaled to 1024×1024, run through `Scripts/round_icon.swift` (rounded rect, **transparent** outside the corners), then all standard `.iconset` sizes and `AppIcon.icns` are generated. **Corner radius** (in pixels on the 1024 master) is set by `ICON_CORNER_PX` in `package.sh`.

## Requirements

- macOS 14 Sonoma or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build

**Bundle the app (no launch):**

```bash
./package.sh
```

Produces `MarketView.app` next to the project (release build, icon, ad-hoc codesign, entitlements if present).

**Bundle and open:**

```bash
./build.sh
```

## Open in Xcode

```bash
open Package.swift
```

## Project layout

```
MarketView/
├── Sources/MarketView/
│   ├── main.swift
│   ├── AppDelegate.swift
│   ├── StockService.swift
│   ├── ChartView.swift
│   ├── SearchTickerView.swift
│   ├── SparklineRenderer.swift
│   └── Models.swift
├── Scripts/
│   └── round_icon.swift     # icon.png → rounded PNG (used by package.sh)
├── Package.swift
├── package.sh                # swift build -c release → .app + icon + sign
├── build.sh                 # package.sh, then open MarketView.app
├── icon.png                 # source for AppIcon
└── MarketView.entitlements  # e.g. network client
```
