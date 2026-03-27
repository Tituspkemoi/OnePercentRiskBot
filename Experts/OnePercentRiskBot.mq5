//+------------------------------------------------------------------+
//|                                              OnePercentRiskBot   |
//|                                  Copyright 2026, User            |
//|               Features: 1% Risk, ATR, Trailing SL, Time & Equity |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, User"
#property version   "3.00"
#property strict

#include <Trade\Trade.mqh>

//--- INPUT PARAMETERS
input group             "Risk Management"
input double            InpRiskPercent    = 1.0;      // Risk % per Trade
input double            InpMaxDrawdown    = 5.0;      // Max Account Drawdown % (Equity Guard)
input double            InpATRMultiplier  = 2.0;      // SL Distance (ATR Multiplier)

input group             "Time Filter"
input int               InpStartHour      = 9;        // Start Trading Hour (EAT)
input int               InpEndHour        = 21;       // End Trading Hour (EAT)
input bool              InpTradeFriday    = false;    // Trade on Fridays?

input group             "Strategy Settings"
input int               InpATRPeriod      = 14;       
input int               InpMAPeriod       = 50;       
input int               InpMagicNumber    = 888111;   
input int               InpTrailingStop   = 300;      

//--- GLOBAL VARIABLES
CTrade      trade;
int         handleATR, handleMA;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   handleATR = iATR(_Symbol, _Period, InpATRPeriod);
   handleMA  = iMA(_Symbol, _Period, InpMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   Print("OnePercentRiskBot V3.0 Online. All Systems Nominal.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Main Trading Logic                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. EQUITY GUARD: Check if we've hit our max loss limit
   if(IsEquityBreached()) {
      CloseAllPositions();
      ExpertRemove(); // Shut down the bot for safety
      return;
   }

   // 2. TIME FILTER: Check if we are within allowed hours
   if(!IsTradingTime()) return;

   // 3. MANAGE EXISTING: Trailing Stop
   ManageExistingPositions();

   // 4. ENTRY LOGIC: Only look for new trades if none are open
   if(PositionSelectByMagic(InpMagicNumber)) return;

   double atr[], ma[], close[];
   CopyBuffer(handleATR, 0, 0, 1, atr);
   CopyBuffer(handleMA, 0, 0, 1, ma);
   CopyClose(_Symbol, _Period, 0, 1, close);

   if(close[0] > ma[0]) // Bullish Trend
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl_dist = atr[0] * InpATRMultiplier;
      double lot = CalculateLotSize(sl_dist);
      
      if(lot > 0) {
         double sl = ask - sl_dist;
         double tp = ask + (sl_dist * 3.0);
         trade.Buy(lot, _Symbol, ask, sl, tp, "V3.0 Entry");
      }
   }
}

//+------------------------------------------------------------------+
//| MODULE: Equity Guard Logic                                       |
//+------------------------------------------------------------------+
bool IsEquityBreached()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown = ((balance - equity) / balance) * 100.0;
   
   if(drawdown >= InpMaxDrawdown) {
      Print("CRITICAL: Max Drawdown reached! Protecting $", balance);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| MODULE: Time Filter Logic                                        |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   
   // Don't trade if Friday is disabled (prevents weekend gaps)
   if(!InpTradeFriday && dt.day_of_week == 5) return false;
   
   if(dt.hour >= InpStartHour && dt.hour < InpEndHour) return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| MODULE: Emergency Close                                          |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) trade.PositionClose(ticket);
   }
}

//--- (Include CalculateLotSize, ManageExistingPositions, and PositionSelectByMagic from V2)