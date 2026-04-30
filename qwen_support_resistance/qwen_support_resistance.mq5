//+------------------------------------------------------------------+
//| Trend Reversal EA (MQL5 Version)                                |
//|                                                                 |
//| Detects potential trend reversals using support/resistance      |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      "https://yourwebsite.com"
#property version   "1.02"

// Input Parameters
input int    LookbackPeriod    = 50;       // Bars for S/R calculation
input double RiskRewardRatio   = 2.0;      // Risk-to-reward ratio
input double LotSize           = 0.1;      // Fixed lot size
input int    StopLossPips      = 50;       // Stop loss in pips
input int    TakeProfitPips    = 100;      // Take profit in pips
input bool   UseTrailingStop   = true;     // Enable trailing stop
input int    TrailingStopPips  = 30;       // Trailing stop distance
input ulong  MagicNumber       = 12345;    // EA identifier

// Global Variables
double SupportLevel, ResistanceLevel;
int PipAdjustment;
double PointMultiplier;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   PipAdjustment = GetPipAdjustment();
   PointMultiplier = Point() * PipAdjustment;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Calculate pip adjustment based on symbol digits                 |
//+------------------------------------------------------------------+
int GetPipAdjustment()
{
   long digits = SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   return (digits == 3 || digits == 5) ? 10 : 1;
}

//+------------------------------------------------------------------+
//| Calculate dynamic support/resistance levels                     |
//+------------------------------------------------------------------+
void CalculateSupportResistance()
{
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   
   // Copy historical data (MQL5 style)
   int copied = CopyHigh(Symbol(), Period(), 0, LookbackPeriod, highs);
   copied     = CopyLow(Symbol(), Period(), 0, LookbackPeriod, lows);
   
   if(copied > 0) {
      ResistanceLevel = highs[ArrayMaximum(highs, 0, LookbackPeriod)];
      SupportLevel    = lows[ArrayMinimum(lows, 0, LookbackPeriod)];
   }
}

//+------------------------------------------------------------------+
//| Check for existing positions                                     |
//+------------------------------------------------------------------+
bool PositionExists()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(PositionGetSymbol(i) == Symbol() && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   return false;
}

//+------------------------------------------------------------------+
//| Main tick handler                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   CalculateSupportResistance();
   CheckTradingSignals();
   if(UseTrailingStop) TrailingStopUpdate();
}

//+------------------------------------------------------------------+
//| Check for trading signals                                        |
//+------------------------------------------------------------------+
void CheckTradingSignals()
{
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   // Buy signal: Price breaks resistance
   if(ask > ResistanceLevel && !PositionExists())
      OpenPosition(ORDER_TYPE_BUY);
   
   // Sell signal: Price breaks support
   else if(bid < SupportLevel && !PositionExists())
      OpenPosition(ORDER_TYPE_SELL);
}

//+------------------------------------------------------------------+
//| Open market position                                             |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   double price = (orderType == ORDER_TYPE_BUY) ? 
                 SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                 SymbolInfoDouble(Symbol(), SYMBOL_BID);
                 
   double sl = CalculateStopLoss(orderType, price);
   double tp = CalculateTakeProfit(orderType, price);

   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = Symbol();
   request.volume   = LotSize;
   request.type     = orderType;
   request.price    = price;
   request.sl       = sl;
   request.tp       = tp;
   request.deviation= 5;
   request.magic    = MagicNumber;
   
   if(!OrderSend(request, result))
      Print("OrderSend error: ", GetLastError());
   else
      Print("Position opened at ", DoubleToString(price, Digits()));
}

//+------------------------------------------------------------------+
//| Calculate stop loss levels                                       |
//+------------------------------------------------------------------+
double CalculateStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   double stopLoss = 0;
   double points = StopLossPips * PointMultiplier;
   
   if(orderType == ORDER_TYPE_BUY)
      stopLoss = entryPrice - points;
   else if(orderType == ORDER_TYPE_SELL)
      stopLoss = entryPrice + points;
      
   return NormalizePrice(stopLoss);
}

//+------------------------------------------------------------------+
//| Calculate take profit levels                                     |
//+------------------------------------------------------------------+
double CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   double takeProfit = 0;
   double points = TakeProfitPips * PointMultiplier;
   
   if(orderType == ORDER_TYPE_BUY)
      takeProfit = entryPrice + points;
   else if(orderType == ORDER_TYPE_SELL)
      takeProfit = entryPrice - points;
      
   return NormalizePrice(takeProfit);
}

//+------------------------------------------------------------------+
//| Normalize price to proper format                                 |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//| Trailing stop management                                         |
//+------------------------------------------------------------------+
void TrailingStopUpdate()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && 
         PositionGetString(POSITION_SYMBOL) == Symbol() &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double currentSL = PositionGetDouble(POSITION_SL);
         double newSL = CalculateTrailingStop(posType, ticket);
         
         if((posType == POSITION_TYPE_BUY && newSL > currentSL) ||
            (posType == POSITION_TYPE_SELL && newSL < currentSL))
         {
            ModifyPositionSL(ticket, newSL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate trailing stop level                                    |
//+------------------------------------------------------------------+
double CalculateTrailingStop(ENUM_POSITION_TYPE posType, ulong ticket)
{
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                        SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                        SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   double distance = currentPrice - entryPrice;
   if(posType == POSITION_TYPE_SELL) distance *= -1;
   
   if(distance > TrailingStopPips * PointMultiplier)
   {
      double newSL = currentPrice - TrailingStopPips * PointMultiplier;
      if(posType == POSITION_TYPE_SELL) newSL = currentPrice + TrailingStopPips * PointMultiplier;
      return NormalizePrice(newSL);
   }
   return PositionGetDouble(POSITION_SL);
}

//+------------------------------------------------------------------+
//| Modify position's stop loss                                      |
//+------------------------------------------------------------------+
void ModifyPositionSL(ulong ticket, double newSL)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action    = TRADE_ACTION_SLTP;
   request.position  = ticket;
   request.symbol    = Symbol();
   request.sl        = newSL;
   request.magic     = MagicNumber;
   
   if(!OrderSend(request, result))
      Print("Modify SL error: ", GetLastError());
}