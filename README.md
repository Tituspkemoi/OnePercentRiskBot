# OnePercentRiskBot_Hybrid (V4.0)

A high-performance "Dual-Engine" Expert Advisor (EA) for MetaTrader 5. This version integrates two distinct trading philosophies into a single, modular system.

## 🧠 System Architecture: The Hybrid Engine
The bot operates using a **Logic Controller** that monitors market regimes and switches between two primary strategies:

1. **Trend Following Engine (MA):**
   - **Logic:** Identifies momentum when price action holds above the 50-period Moving Average.
   - **Goal:** To "ride" long-term directional moves in currency pairs like USDCHF.

2. **Mean Reversion Engine (Bollinger Bands):**
   - **Logic:** Detects "overextended" prices using 2.0 Standard Deviation bands.
   - **Goal:** To profit from price "snaps" back to the average during sideways or ranging markets.

## 🛡️ Enterprise-Grade Risk Controls
- **1% Equity Protection:** Dynamic lot sizing ensures a fixed risk percentage of total equity per trade.
- **Global Equity Guard:** An account-level circuit breaker that halts all activity if a 5% drawdown is reached.
- **ATR Volatility Scaling:** Stop Loss and Take Profit levels are automatically adjusted based on current market noise (ATR).

## 💻 Technical Implementation
- **Modular Codebase:** Functions are separated into logical modules (Execution, Calculation, Protection) for easy maintenance.
- **Low Latency:** Optimized indicator handles and buffer copying to ensure rapid execution on tick arrival.
- **Git Versioning:** Developed using an iterative approach, documented through clear commit history.

## 🚀 How to Use
1. Clone the repository to your MT5 `MQL5/Experts` folder.
2. Compile the source code in MetaEditor.
3. Attach to any H1 chart (Optimized for USDCHF).
4. Configure Strategy toggles in the Input tab.