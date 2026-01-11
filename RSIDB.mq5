//+------------------------------------------------------------------+
//|                                            DualRSIStrategyEA.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include files                                                    |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input double   LotSize         = 0.01;     // Lot size
input int      StopLoss        = 100;      // Stop Loss (points)
input int      TakeProfit      = 200;      // Take Profit (points)
input int      MagicNumber     = 789012;   // Magic Number
input int      Slippage        = 10;       // Slippage (points)

// RSI Parameters
input int      RSIPeriodFast   = 2;        // RSI Fast Period
input int      RSIPeriodSlow   = 14;       // RSI Slow Period
input int      OversoldLevel   = 20;       // Oversold Level

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
int handleRSIFast, handleRSISlow;
datetime lastTradeBarTime;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize RSI indicator handles
   handleRSIFast = iRSI(_Symbol, _Period, RSIPeriodFast, PRICE_CLOSE);
   handleRSISlow = iRSI(_Symbol, _Period, RSIPeriodSlow, PRICE_CLOSE);
   
   if(handleRSIFast == INVALID_HANDLE || handleRSISlow == INVALID_HANDLE)
   {
      Print("Error creating RSI indicator handles");
      return(INIT_FAILED);
   }
   
   // Configure CTrade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetAsyncMode(false); // Synchronous execution
   
   lastTradeBarTime = 0;
   Print("Dual RSI Strategy EA initialized successfully");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(handleRSIFast != INVALID_HANDLE) IndicatorRelease(handleRSIFast);
   if(handleRSISlow != INVALID_HANDLE) IndicatorRelease(handleRSISlow);
   
   Comment(""); // Clear chart comment
   Print("EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(lastBarTime == currentBarTime) return;
   lastBarTime = currentBarTime;
   
   // Wait for bar to close (we need to trade at next bar open)
   // We'll check conditions on bar close and trade on next tick
   CheckTradingConditions();
   
   // Display current values on chart
   DisplayIndicatorValues();
}

//+------------------------------------------------------------------+
//| Check trading conditions                                         |
//+------------------------------------------------------------------+
void CheckTradingConditions()
{
   // Check if we have an open position
   if(HasOpenPosition()) return;
   
   // Get RSI values from previous completed bar (index 1)
   double rsiFast = GetRSIValue(handleRSIFast, 1);  // Previous bar
   double rsiSlow = GetRSIValue(handleRSISlow, 1);  // Previous bar
   
   // Entry condition: RSI Fast <= Oversold Level AND RSI Slow > 50
   if(rsiFast <= OversoldLevel && rsiSlow > 50)
   {
      // Get current time for logging
      MqlDateTime tm;
      TimeCurrent(tm);
      
      string signalInfo = StringFormat("BUY SIGNAL Detected at %02d:%02d:%02d\n", 
                                       tm.hour, tm.min, tm.sec);
      signalInfo += StringFormat("RSI Fast (%d): %.2f <= %d (Oversold)\n", 
                                 RSIPeriodFast, rsiFast, OversoldLevel);
      signalInfo += StringFormat("RSI Slow (%d): %.2f > 50\n", 
                                 RSIPeriodSlow, rsiSlow);
      signalInfo += "Will open trade at next bar open";
      
      Print(signalInfo);
      
      // Set flag to open trade on next bar
      lastTradeBarTime = iTime(_Symbol, _Period, 1);
   }
   
   // Check if we should open a trade (on new bar after signal)
   if(lastTradeBarTime > 0 && lastTradeBarTime == iTime(_Symbol, _Period, 1))
   {
      OpenTradeAtNextBar();
      lastTradeBarTime = 0; // Reset flag
   }
}

//+------------------------------------------------------------------+
//| Open trade at next bar open price                                |
//+------------------------------------------------------------------+
void OpenTradeAtNextBar()
{
   // Get current time for logging
   MqlDateTime tm;
   TimeCurrent(tm);
   
   // Get the open price of current bar (next bar after signal)
   double openPrice = iOpen(_Symbol, _Period, 0);
   
   // Calculate SL and TP
   double sl = (StopLoss > 0) ? openPrice - StopLoss * _Point : 0;
   double tp = (TakeProfit > 0) ? openPrice + TakeProfit * _Point : 0;
   
   // Get RSI values for display in comment
   double rsiFast = GetRSIValue(handleRSIFast, 1);
   double rsiSlow = GetRSIValue(handleRSISlow, 1);
   
   // Prepare trade comment
   string tradeComment = StringFormat("Dual RSI Strategy | RSI%d:%.2f<=%d & RSI%d:%.2f>50 | Time:%02d:%02d", 
                                      RSIPeriodFast, rsiFast, OversoldLevel, 
                                      RSIPeriodSlow, rsiSlow, 
                                      tm.hour, tm.min);
   
   // Use CTrade to open buy position at current bar open price
   if(trade.Buy(LotSize, _Symbol, openPrice, sl, tp, tradeComment))
   {
      PrintFormat("BUY position opened at next bar open");
      PrintFormat("Time: %02d:%02d:%02d | Open Price: %.5f", tm.hour, tm.min, tm.sec, openPrice);
      PrintFormat("SL: %.5f | TP: %.5f | Volume: %.2f", sl, tp, LotSize);
      PrintFormat("RSI Fast: %.2f | RSI Slow: %.2f", rsiFast, rsiSlow);
   }
   else
   {
      PrintFormat("Failed to open BUY position at %02d:%02d:%02d", tm.hour, tm.min, tm.sec);
      PrintFormat("Error: %d - %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Check if there's an open position with EA's magic number         |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get RSI value from specific bar index                            |
//+------------------------------------------------------------------+
double GetRSIValue(int handle, int shift)
{
   double RSIValues[];
   ArraySetAsSeries(RSIValues, true);
   
   // Get RSI value from specified bar
   if(CopyBuffer(handle, 0, shift, 1, RSIValues) < 1)
   {
      Print("Error getting RSI value for shift: ", shift);
      return 0;
   }
   
   return (RSIValues[0]);
}

//+------------------------------------------------------------------+
//| Display indicator values on chart                                |
//+------------------------------------------------------------------+
void DisplayIndicatorValues()
{
   // Get current time
   MqlDateTime tm;
   TimeCurrent(tm);
   
   // Get current RSI values (from completed bar index 1)
   double rsiFastCurrent = GetRSIValue(handleRSIFast, 1);
   double rsiSlowCurrent = GetRSIValue(handleRSISlow, 1);
   
   // Get RSI values from current bar (index 0) for display only
   double rsiFastLatest = GetRSIValue(handleRSIFast, 0);
   double rsiSlowLatest = GetRSIValue(handleRSISlow, 0);
   
   // Check if position is open
   bool hasPosition = HasOpenPosition();
   
   // Display values on chart
   string commentText = "";
   commentText += "=== DUAL RSI STRATEGY EA ===\n";
   commentText += "============================\n";
   commentText += StringFormat("Time: %02d:%02d:%02d\n", tm.hour, tm.min, tm.sec);
   commentText += "============================\n";
   commentText += StringFormat("RSI Fast (%d): %.2f\n", RSIPeriodFast, rsiFastLatest);
   commentText += StringFormat("RSI Slow (%d): %.2f\n", RSIPeriodSlow, rsiSlowLatest);
   commentText += StringFormat("Oversold Level: %d\n", OversoldLevel);
   commentText += "----------------------------\n";
   commentText += "ENTRY CONDITIONS:\n";
   commentText += StringFormat("1. RSI%d <= %d\n", RSIPeriodFast, OversoldLevel);
   commentText += "2. RSI14 > 50\n";
   commentText += StringFormat("Current: RSI%d=%.2f, RSI%d=%.2f\n", 
                               RSIPeriodFast, rsiFastCurrent, 
                               RSIPeriodSlow, rsiSlowCurrent);
   
   // Check if conditions are met
   bool condition1 = (rsiFastCurrent <= OversoldLevel);
   bool condition2 = (rsiSlowCurrent > 50);
   
   commentText += StringFormat("Condition 1: %s\n", condition1 ? "MET ✓" : "NOT MET ✗");
   commentText += StringFormat("Condition 2: %s\n", condition2 ? "MET ✓" : "NOT MET ✗");
   
   if(condition1 && condition2)
   {
      commentText += ">> ALL CONDITIONS MET - BUY SIGNAL <<\n";
      commentText += "Trade will open at next bar open\n";
   }
   
   commentText += "----------------------------\n";
   commentText += StringFormat("Position Open: %s\n", hasPosition ? "YES" : "NO");
   commentText += StringFormat("Lot Size: %.2f\n", LotSize);
   commentText += StringFormat("SL: %d points | TP: %d points\n", StopLoss, TakeProfit);
   commentText += "============================\n";
   commentText += StringFormat("Magic Number: %d", MagicNumber);
   
   Comment(commentText);
}

