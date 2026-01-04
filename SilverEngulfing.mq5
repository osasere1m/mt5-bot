//+------------------------------------------------------------------+
//|                                               DailyHLStrategy.mq5|
//|                                 Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.01"

input ulong  MagicNumber = 3045;   // Magic Number
input double LotSize     = 0.01;     // Lot Size
input int    StopLoss    = 1000;     // Stop Loss (points)
input int    TakeProfit  = 2000;     // Take Profit (points)


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
  {
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Check for minimum number of bars
   if(Bars(_Symbol, PERIOD_D1) < 2)
     {
      Print("Not enough historical data");
      return;
     }

   // Check if already traded today
   string globalVarName = "LastTradeDate_" + string(MagicNumber) + "_" + Symbol();
   datetime lastTradeDate = GlobalVariableGet(globalVarName);
   datetime currentDate = TimeCurrent() / 86400 * 86400; // Get midnight of current day
   
   if(lastTradeDate >= currentDate)
     {
      Print("Already traded today. Skipping new trades.");
      return;
     }

  
   // Get candle data
   double firstCandleOpen = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double firstCandleClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   double firstCandleHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double firstCandleLow = iLow(_Symbol, PERIOD_CURRENT, 1);

   double secondCandleOpen = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double secondCandleClose = iClose(_Symbol, PERIOD_CURRENT, 2);
   double secondCandleHigh = iHigh(_Symbol, PERIOD_CURRENT, 2);
   double secondCandleLow = iLow(_Symbol, PERIOD_CURRENT, 2);

  
   // Check candle conditions
   bool isFirstCandleBullish = firstCandleClose > firstCandleOpen;
   
   // check buy condition
   
   bool checkbuybar = firstCandleClose > secondCandleClose && firstCandleLow < secondCandleLow && firstCandleHigh > secondCandleHigh;
   
   // Get current prices
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Check buy condition
   if(ask > firstCandleHigh && isFirstCandleBullish && checkbuybar && !HasOpenPosition())
     {
      if(OpenTrade(ORDER_TYPE_BUY, ask))
         GlobalVariableSet(globalVarName, currentDate);
     }

   // Check sell condition
   //if(bid < prevLow && !HasOpenPosition())
     {
      //if(OpenTrade(ORDER_TYPE_SELL, bid))
         //GlobalVariableSet(globalVarName, currentDate);
     }
  }

//+------------------------------------------------------------------+
//| Check if there's any open position                               |
//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
           {
            return true;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Execute trade order                                              |
//+------------------------------------------------------------------+
bool OpenTrade(const ENUM_ORDER_TYPE orderType, const double price)
  {
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.deviation = 5;
   request.magic = MagicNumber;

   // Calculate stop loss and take profit
   if(StopLoss > 0)
     {
      if(orderType == ORDER_TYPE_BUY)
         request.sl = NormalizeDouble(price - StopLoss * _Point, _Digits);
      else
         request.sl = NormalizeDouble(price + StopLoss * _Point, _Digits);
     }

   if(TakeProfit > 0)
     {
      if(orderType == ORDER_TYPE_BUY)
         request.tp = NormalizeDouble(price + TakeProfit * _Point, _Digits);
      else
         request.tp = NormalizeDouble(price - TakeProfit * _Point, _Digits);
     }

   // Send trade request
   if(!OrderSend(request, result))
     {
      Print("OrderSend failed: ", GetLastError());
      return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
