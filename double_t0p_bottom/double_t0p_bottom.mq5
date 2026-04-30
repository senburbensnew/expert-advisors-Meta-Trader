//+------------------------------------------------------------------+
//|                DoublePatternWithSLTP_EA.mq5                      |
//|  This EA detects Double Top and Double Bottom patterns, draws    |
//|  them on the chart, and opens positions with SL and TP.          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
CTrade trade;

//--- input parameters
input int    PivotLeft       = 3;       // Number of bars to the left for pivot test
input int    PivotRight      = 3;       // Number of bars to the right for pivot test
input double Tolerance       = 0.005;   // Maximum allowed relative difference between pivots (0.5%)
input double MinMove         = 0.01;    // Minimum required move between pivots and the intervening trough/peak (1%)
input double LotSize         = 0.1;     // Lot size for orders
input int    StopLossPips    = 20;      // Stop Loss in pips
input int    TakeProfitPips  = 40;      // Take Profit in pips

//--- Global variables
datetime lastBarTime = 0;
int      objCounter  = 0;            // used for unique object names

//+------------------------------------------------------------------+
//| Check if a bar is a pivot high                                  |
//+------------------------------------------------------------------+
bool IsPivotHigh(int index, int left, int right)
{
   // Ensure we have enough bars on each side
   if(index - left < 0 || index + right >= iBars(_Symbol,_Period))
      return false;
      
   double pivotPrice = iHigh(_Symbol,_Period,index);
   for(int i = index - left; i <= index + right; i++)
   {
      if(i == index)
         continue;
      if(iHigh(_Symbol,_Period,i) > pivotPrice)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check if a bar is a pivot low                                   |
//+------------------------------------------------------------------+
bool IsPivotLow(int index, int left, int right)
{
   if(index - left < 0 || index + right >= iBars(_Symbol,_Period))
      return false;
      
   double pivotPrice = iLow(_Symbol,_Period,index);
   for(int i = index - left; i <= index + right; i++)
   {
      if(i == index)
         continue;
      if(iLow(_Symbol,_Period,i) < pivotPrice)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check for a Double Top pattern                                  |
//| If found, returns true and sets pivotOld (older pivot) and        |
//| pivotRecent (more recent pivot)                                  |
//+------------------------------------------------------------------+
bool CheckDoubleTop(int &pivotOld, int &pivotRecent)
{
   int lookback = 50; // number of bars to search (adjust if needed)
   int count = 0;
   int pivots[10];         // to store pivot indices
   double pivotPrices[10]; // to store corresponding high prices

   // Loop through bars starting from index 2 (avoid incomplete bars)
   for(int i = 2; i < lookback && i < iBars(_Symbol,_Period); i++)
   {
      if(IsPivotHigh(i, PivotLeft, PivotRight))
      {
         pivots[count] = i;
         pivotPrices[count] = iHigh(_Symbol,_Period,i);
         count++;
         if(count >= 2)
            break; // only need the two most recent pivot highs
      }
   }
   if(count < 2)
      return false;
      
   // In MQL5 series, lower index = more recent bar.
   pivotRecent = pivots[0];  // most recent pivot high
   pivotOld    = pivots[1];  // previous pivot high

   // Ensure the two pivots are not adjacent (need at least one bar between)
   if(MathAbs(pivotOld - pivotRecent) < 2)
      return false;
      
   // Check that the two highs are similar (within Tolerance)
   double diff = MathAbs(pivotPrices[0] - pivotPrices[1]);
   double avg  = (pivotPrices[0] + pivotPrices[1]) / 2.0;
   if(diff / avg > Tolerance)
      return false;
      
   // Determine the time order between the two pivots
   int start = (pivotOld > pivotRecent ? pivotOld : pivotRecent);
   int end   = (pivotOld > pivotRecent ? pivotRecent : pivotOld);
   if(start - end < 2)
      return false;  // not enough bars between pivots
      
   // Find the lowest low (the trough) between the two pivot highs
   double minLow = iLow(_Symbol,_Period,start - 1);
   for(int i = start - 1; i > end; i--)
   {
      if(iLow(_Symbol,_Period,i) < minLow)
         minLow = iLow(_Symbol,_Period,i);
   }
   // Compare the trough to the lower of the two pivot highs
   double lowerPivot = (pivotPrices[0] < pivotPrices[1] ? pivotPrices[0] : pivotPrices[1]);
   if((lowerPivot - minLow) / lowerPivot < MinMove)
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Check for a Double Bottom pattern                               |
//| If found, returns true and sets pivotOld (older pivot) and        |
//| pivotRecent (more recent pivot)                                  |
//+------------------------------------------------------------------+
bool CheckDoubleBottom(int &pivotOld, int &pivotRecent)
{
   int lookback = 50;
   int count = 0;
   int pivots[10];         // to store pivot indices
   double pivotPrices[10]; // to store corresponding low prices

   for(int i = 2; i < lookback && i < iBars(_Symbol,_Period); i++)
   {
      if(IsPivotLow(i, PivotLeft, PivotRight))
      {
         pivots[count] = i;
         pivotPrices[count] = iLow(_Symbol,_Period,i);
         count++;
         if(count >= 2)
            break;
      }
   }
   if(count < 2)
      return false;
      
   pivotRecent = pivots[0];
   pivotOld    = pivots[1];
   
   if(MathAbs(pivotOld - pivotRecent) < 2)
      return false;
      
   // Check that the two pivot lows are similar (within Tolerance)
   double diff = MathAbs(pivotPrices[0] - pivotPrices[1]);
   double avg  = (pivotPrices[0] + pivotPrices[1]) / 2.0;
   if(diff / avg > Tolerance)
      return false;
      
   // Determine the time order between the two pivots
   int start = (pivotOld > pivotRecent ? pivotOld : pivotRecent);
   int end   = (pivotOld > pivotRecent ? pivotRecent : pivotOld);
   if(start - end < 2)
      return false;
      
   // Find the highest high (the peak) between the two pivot lows
   double maxHigh = iHigh(_Symbol,_Period,start - 1);
   for(int i = start - 1; i > end; i--)
   {
      if(iHigh(_Symbol,_Period,i) > maxHigh)
         maxHigh = iHigh(_Symbol,_Period,i);
   }
   // Compare the peak to the higher of the two pivot lows
   double higherPivot = (pivotPrices[0] > pivotPrices[1] ? pivotPrices[0] : pivotPrices[1]);
   if((maxHigh - higherPivot) / higherPivot < MinMove)
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Draw a Double Top pattern on the chart                           |
//+------------------------------------------------------------------+
void DrawDoubleTop(int pivotOld, int pivotRecent)
{
   objCounter++;
   string lineName  = "DoubleTopLine_" + IntegerToString(objCounter);
   string labelName = "DoubleTopLabel_" + IntegerToString(objCounter);
   
   // Get time and price from the pivot indices (most recent bars first)
   datetime time1 = iTime(_Symbol,_Period,pivotOld);
   datetime time2 = iTime(_Symbol,_Period,pivotRecent);
   double price1  = iHigh(_Symbol,_Period,pivotOld);
   double price2  = iHigh(_Symbol,_Period,pivotRecent);
   
   // Create a trend line connecting the two pivot highs.
   if(!ObjectCreate(0, lineName, OBJ_TREND, 0, time1, price1, time2, price2))
      Print("Failed to create Double Top trend line: ", lineName);
   else
   {
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
   }
   
   // Create a text label at the midpoint of the line.
   datetime midTime = time1 + (time2 - time1) / 2;
   double midPrice  = (price1 + price2) / 2.0;
   if(!ObjectCreate(0, labelName, OBJ_TEXT, 0, midTime, midPrice))
      Print("Failed to create Double Top label: ", labelName);
   else
   {
      ObjectSetString(0, labelName, OBJPROP_TEXT, "Double Top");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 12);
      // Optional: set the text alignment and background if desired
   }
}

//+------------------------------------------------------------------+
//| Draw a Double Bottom pattern on the chart                        |
//+------------------------------------------------------------------+
void DrawDoubleBottom(int pivotOld, int pivotRecent)
{
   objCounter++;
   string lineName  = "DoubleBottomLine_" + IntegerToString(objCounter);
   string labelName = "DoubleBottomLabel_" + IntegerToString(objCounter);
   
   datetime time1 = iTime(_Symbol,_Period,pivotOld);
   datetime time2 = iTime(_Symbol,_Period,pivotRecent);
   double price1  = iLow(_Symbol,_Period,pivotOld);
   double price2  = iLow(_Symbol,_Period,pivotRecent);
   
   if(!ObjectCreate(0, lineName, OBJ_TREND, 0, time1, price1, time2, price2))
      Print("Failed to create Double Bottom trend line: ", lineName);
   else
   {
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
   }
   
   datetime midTime = time1 + (time2 - time1) / 2;
   double midPrice  = (price1 + price2) / 2.0;
   if(!ObjectCreate(0, labelName, OBJ_TEXT, 0, midTime, midPrice))
      Print("Failed to create Double Bottom label: ", labelName);
   else
   {
      ObjectSetString(0, labelName, OBJPROP_TEXT, "Double Bottom");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 12);
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Double Pattern EA with SL/TP and chart objects initialized.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Optionally, you could remove drawn objects here.
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only act on a new closed bar.
   datetime currentBarTime = iTime(_Symbol, _Period, 1);
   if(currentBarTime == lastBarTime)
      return; // no new bar yet
   lastBarTime = currentBarTime;
   
   int pivotOld, pivotRecent;
   bool isDoubleTop    = CheckDoubleTop(pivotOld, pivotRecent);
   bool isDoubleBottom = CheckDoubleBottom(pivotOld, pivotRecent);
   
   // Only trade if there is no open position on the current symbol.
   if(PositionSelect(_Symbol))
      return;
   
   // Get symbol properties for price calculations.
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   // For symbols with 3 or 5 digits, one pip is typically 10 * point.
   double pip = point;
   if(digits == 3 || digits == 5)
      pip = point * 10;
      
   // If a double top is detected, take a SELL position.
   if(isDoubleTop)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      // For a sell order, SL is above the entry and TP is below.
      double sl = NormalizeDouble(bid + StopLossPips * pip, digits);
      double tp = NormalizeDouble(bid - TakeProfitPips * pip, digits);
      
      if(trade.Sell(LotSize, _Symbol, 0, sl, tp, "Double Top Pattern Sell"))
      {
         Print("Double Top detected. Sell order placed with SL=", sl, " TP=", tp);
         DrawDoubleTop(pivotOld, pivotRecent);
      }
      else
         Print("Sell order failed: ", trade.ResultRetcodeDescription());
   }
   // If a double bottom is detected, take a BUY position.
   else if(isDoubleBottom)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      // For a buy order, SL is below the entry and TP is above.
      double sl = NormalizeDouble(ask - StopLossPips * pip, digits);
      double tp = NormalizeDouble(ask + TakeProfitPips * pip, digits);
      
      if(trade.Buy(LotSize, _Symbol, 0, sl, tp, "Double Bottom Pattern Buy"))
      {
         Print("Double Bottom detected. Buy order placed with SL=", sl, " TP=", tp);
         DrawDoubleBottom(pivotOld, pivotRecent);
      }
      else
         Print("Buy order failed: ", trade.ResultRetcodeDescription());
   }
}
