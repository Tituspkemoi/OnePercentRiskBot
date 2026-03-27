//+------------------------------------------------------------------+
//|                                         OnePercentRiskBot_Hybrid |
//|                                  Copyright 2026, User            |
//|      Features: Trend Following + Mean Reversion + Equity Guard   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, User"
#property version   "4.00"
#property strict

#include <Trade\Trade.mqh>

//--- INPUTS
input group             "Risk & Guard"
input double            InpRiskPercent    = 1.0;      // Risk % per trade
input double            InpMaxDrawdown    = 5.0;      // Max % Drawdown to stop bot
input double            InpATRMultiplier  = 2.0;      // SL distance

input group             "Strategy 1: Trend (MA)"
input bool              InpUseTrend       = true;     // Enable Trend Following
input int               InpMAPeriod       = 50;       // Period for Trend Filter

input group             "Strategy 2: Reversion (Bands)"
input bool              InpUseReversion   = true;     // Enable Mean Reversion
input int               InpBandsPeriod    = 20;       // Bollinger Period
input double            InpBandsDev       = 2.0;      // Standard Deviations

input int               InpMagicNumber    = 888111;

//--- GLOBALS
CTrade      trade;
int         handleMA, handleBands, handleATR;

//+------------------------------------------------------------------+
int OnInit() {
   handleMA    = iMA(_Symbol, _Period, InpMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   handleBands = iBands(_Symbol, _Period, InpBandsPeriod, 0, InpBandsDev, PRICE_CLOSE);
   handleATR   = iATR(_Symbol, _Period, 14);
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   Print("Hybrid Bot V4.0 Initialized.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick() {
   if(IsEquityBreached()) { 
      CloseAllPositions(); 
      ExpertRemove(); 
      return; 
   }
   
   if(PositionSelectByMagic(InpMagicNumber)) return;

   double ma[], upper[], lower[], close[], atr[];
   ArraySetAsSeries(ma, true); ArraySetAsSeries(upper, true); 
   ArraySetAsSeries(lower, true); ArraySetAsSeries(close, true);
   ArraySetAsSeries(atr, true);

   if(CopyBuffer(handleMA, 0, 0, 1, ma) <= 0) return;
   if(CopyBuffer(handleBands, 1, 0, 1, upper) <= 0) return;
   if(CopyBuffer(handleBands, 2, 0, 1, lower) <= 0) return;
   if(CopyClose(_Symbol, _Period, 0, 1, close) <= 0) return;
   if(CopyBuffer(handleATR, 0, 0, 1, atr) <= 0) return;

   // --- STRATEGY 1: TREND FOLLOWING (Buy when price > MA) ---
   if(InpUseTrend && close[0] > ma[0]) {
      double sl_dist = atr[0] * InpATRMultiplier;
      ExecuteTrade(ORDER_TYPE_BUY, sl_dist, "Trend_Buy");
      return;
   }

   // --- STRATEGY 2: MEAN REVERSION (Buy at lower band / Sell at upper) ---
   if(InpUseReversion) {
      double sl_dist = atr[0] * InpATRMultiplier;
      if(close[0] < lower[0]) { 
         ExecuteTrade(ORDER_TYPE_BUY, sl_dist, "Reversion_Buy");
      }
      else if(close[0] > upper[0]) { 
         ExecuteTrade(ORDER_TYPE_SELL, sl_dist, "Reversion_Sell");
      }
   }
}

//+------------------------------------------------------------------+
//| MODULE: Core Logic Functions                                     |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE type, double sl_dist, string comment) {
   double lot = CalculateLotSize(sl_dist);
   if(lot <= 0) return;

   if(type == ORDER_TYPE_BUY) {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      trade.Buy(lot, _Symbol, ask, ask-sl_dist, ask+(sl_dist*2), comment);
   } else {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      trade.Sell(lot, _Symbol, bid, bid+sl_dist, bid-(sl_dist*2), comment);
   }
}

bool IsEquityBreached() {
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   return (bal > 0 && ((bal - eq) / bal) * 100.0 >= InpMaxDrawdown);
}

void CloseAllPositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(PositionSelectByTicket(t)) trade.PositionClose(t);
   }
}

double CalculateLotSize(double sl_dist) {
   double risk = AccountInfoDouble(ACCOUNT_EQUITY) * (InpRiskPercent / 100.0);
   double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(sl_dist <= 0 || tick_val <= 0) return 0;
   double lot = risk / (sl_dist * (tick_val / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE)));
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   return MathFloor(lot / step) * step;
}

bool PositionSelectByMagic(long magic) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionSelectByTicket(PositionGetTicket(i))) {
         if(PositionGetInteger(POSITION_MAGIC) == magic) return true;
      }
   }
   return false;
}