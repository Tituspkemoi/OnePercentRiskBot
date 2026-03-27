//+------------------------------------------------------------------+
//|                                              OnePercentRiskBot   |
//|                                  Copyright 2026, User            |
//|      Features: 1% Risk, ATR, Trailing SL, Time & Equity Guards   |
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
input double            InpRewardRatio    = 3.0;      // Take Profit (Ratio to Risk)

input group             "Time Filter"
input int               InpStartHour      = 9;        // Start Trading Hour (Broker Time)
input int               InpEndHour        = 21;       // End Trading Hour (Broker Time)
input bool              InpTradeFriday    = false;    // Trade on Fridays?

input group             "Strategy Settings"
input int               InpATRPeriod      = 14;       // ATR Period for Volatility
input int               InpMAPeriod       = 50;       // Trend Filter (Moving Average)
input int               InpMagicNumber    = 888111;   // Unique Bot ID
input int               InpTrailingStop   = 300;      // Trailing Stop in Points (30 Pips)

//--- GLOBAL VARIABLES
CTrade      trade;
int         handleATR;
int         handleMA;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize Indicators
   handleATR = iATR(_Symbol, _Period, InpATRPeriod);
   handleMA  = iMA(_Symbol, _Period, InpMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   
   if(handleATR == INVALID_HANDLE || handleMA == INVALID_HANDLE)
   {
      Print("Error initializing indicators");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   Print("OnePercentRiskBot V3.0 Online. Monitoring USDCHF...");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Main Trading Logic                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. EQUITY GUARD: Protect the $94k balance
   if(IsEquityBreached()) 
   {
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

   // Get Indicator Data
   double atr[], ma[], close[];
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(ma, true);
   ArraySetAsSeries(close, true);

   if(CopyBuffer(handleATR, 0, 0, 1, atr) <= 0) return;
   if(CopyBuffer(handleMA, 0, 0, 1, ma) <= 0) return;
   if(CopyClose(_Symbol, _Period, 0, 1, close) <= 0) return;

   // Logic: Buy if price is above Moving Average
   if(close[0] > ma[0]) 
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl_distance_price = atr[0] * InpATRMultiplier;
      
      // Calculate Lot Size based on 1% Equity Risk
      double lot = CalculateLotSize(sl_distance_price);
      
      if(lot > 0)
      {
         double sl = ask - sl_distance_price;
         double tp = ask + (sl_distance_price * InpRewardRatio);
         
         if(trade.Buy(lot, _Symbol, ask, sl, tp, "V3.0 ATR Entry"))
         {
            Print("Order Placed. Lot: ", lot, " | Risk: ", InpRiskPercent, "%");
         }
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
   
   if(balance <= 0) return false;
   
   double drawdown = ((balance - equity) / balance) * 100.0;
   
   if(drawdown >= InpMaxDrawdown) 
   {
      Print("CRITICAL: Max Drawdown (", InpMaxDrawdown, "%) reached! Protecting Account.");
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
   
   if(!InpTradeFriday && dt.day_of_week == 5) return false;
   if(dt.hour >= InpStartHour && dt.hour < InpEndHour) return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| MODULE: Dynamic Lot Size Calculation                             |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_distance_price)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_amount = equity * (InpRiskPercent / 100.0);
   
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(sl_distance_price <= 0 || tick_value <= 0) return 0;

   double lot_size = risk_amount / (sl_distance_price * (tick_value / tick_size));
   
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot_size = MathFloor(lot_size / step) * step;
   
   if(lot_size < min_lot) lot_size = min_lot;
   if(lot_size > max_lot) lot_size = max_lot;
   
   return lot_size;
}

//+------------------------------------------------------------------+
//| MODULE: Trailing Stop Management                                 |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_sl = PositionGetDouble(POSITION_SL);
            
            if(bid - open_price > InpTrailingStop * _Point)
            {
               double new_sl = bid - (InpTrailingStop * _Point);
               if(new_sl > current_sl) 
               {
                  trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| MODULE: Emergency Close                                          |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) 
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
//| MODULE: Position Selection Helper                                |
//+------------------------------------------------------------------+
bool PositionSelectByMagic(long magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == magic) return true;
      }
   }
   return false;
}