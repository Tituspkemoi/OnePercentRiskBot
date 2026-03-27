# OnePercentRiskBot (V3.0)

An advanced Algorithmic Trading Expert Advisor (EA) built for MetaTrader 5 (MQL5). This bot is designed with a "Capital First" philosophy, prioritizing strict risk management and volatility-based entries.

## 🚀 Key Features
- **Dynamic 1% Risk Engine:** Automatically calculates lot sizes based on current account equity to ensure no single trade exceeds a 1% loss.
- **ATR Volatility Scaling:** Uses the Average True Range (ATR) to set dynamic Stop Loss and Take Profit levels that adapt to market conditions.
- **Equity Guard (Circuit Breaker):** Automatically closes all positions and halts trading if a pre-defined drawdown percentage is hit.
- **Time & Session Filtering:** Built-in logic to avoid high-spread periods and weekend gaps (Friday protection).
- **Trend Confirmation:** Employs a Moving Average filter to ensure trades are only taken in the direction of the dominant trend.

## 📈 Current Performance
The system is currently being live-tested on a high-equity account (~$95k), maintaining a healthy margin level of 3000%+ while navigating major currency breakouts (USDCHF).

## 🛠 Tech Stack
- **Language:** MQL5 (C++ based)
- **Platform:** MetaTrader 5
- **Version Control:** Git/GitHub

## 📁 Project Structure
- `Experts/OnePercentRiskBot.mq5`: The main source code.
- `.gitignore`: Configured to exclude compiled `.ex5` files and MetaQuotes logs.

## 📜 License
This project is licensed under the MIT License.