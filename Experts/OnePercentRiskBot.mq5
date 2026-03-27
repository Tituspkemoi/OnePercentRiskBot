//+------------------------------------------------------------------+
//|                                              OnePercentRiskBot   |
//|                                  Copyright 2026, User            |
//|                            Strategy: ATR Breakout + Trailing Stop|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, User"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

//--- INPUT PARAMETERS
input group             "Risk Management"
input double            InpRiskPercent    = 1.0;      // Risk % per Trade
input double            InpATRMultiplier  = 2.0;      // SL Distance (ATR Multiplier)
input double            InpRewardRatio    = 3.0;      // Take Profit (Ratio to Risk)

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
   Print("OnePercentRiskBot V2.0 Online. Monitoring USDCHF...");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Main Trading Logic                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Manage existing positions (Trailing Stop)
   ManageExistingPositions();

   // 2. Check if a position is already open
   if(PositionSelectByMagic(InpMagicNumber)) return;

   // 3. Get Indicator Data
   double atr[], ma[], close[];
   CopyBuffer(handleATR, 0, 0, 1, atr);
   CopyBuffer(handleMA, 0, 0, 1, ma);
   CopyClose(_Symbol, _Period, 0, 1, close);

   double current_atr = atr[0];
   double current_ma  = ma[0];
   double current_price = close[0];

   // 4. Entry Conditions (Breakout + Trend Filter)
   // Buy if: Price is above Moving Average AND current bar is bullish
   if(current_price > current_ma)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl_distance = current_atr * InpATRMultiplier;
      
      // Calculate Lot Size based on 1% Equity Risk
      double lot = CalculateLotSize(sl_distance);
      
      if(lot > 0)
      {
         double sl = ask - sl_distance;
         double tp = ask + (sl_distance * InpRewardRatio);
         
         if(trade.Buy(lot, _Symbol, ask, sl, tp, "ATR Breakout"))
         {
            Print("Order Placed. Lot: ", lot, " | Risk: ", InpRiskPercent, "%");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk Amount                          |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_distance_price)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_amount = equity * (InpRiskPercent / 100.0);
   
   // Get Tick Value (Value of price change in account currency)
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(sl_distance_price <= 0 || tick_value <= 0) return 0;

   // Formula: Risk / (Price Distance * (TickValue / TickSize))
   double lot_size = risk_amount / (sl_distance_price * (tick_value / tick_size));
   
   // Normalize to broker specifications
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot_size = MathFloor(lot_size / step) * step;
   
   if(lot_size < min_lot) lot_size = min_lot;
   if(lot_size > max_lot) lot_size = max_lot;
   
   return lot_size;
}

//+------------------------------------------------------------------+
//| Trailing Stop Logic to Lock in Profit                            |
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
            
            // If price moves in favor by 'TrailingStop' points
            if(bid - open_price > InpTrailingStop * _Point)
            {
               double new_sl = bid - (InpTrailingStop * _Point);
               // Only move SL up, never down
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
//| Check for open positions by Magic Number                         |
//+------------------------------------------------------------------+
bool PositionSelectByMagic(long magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0)
      {
         if(PositionGetInteger(POSITION_MAGIC) == magic) return true;
      }
   }
   return false;
}