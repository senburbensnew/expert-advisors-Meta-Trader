#include <Trade\Trade.mqh>

#property copyright "Your Name"
#property link      "https://www.example.com"
#property version   "1.00"
#property strict

// Add constants for object names
#define FAST_MA_OBJ "FastMA"
#define MIDDLE_MA_OBJ "MiddleMA"
#define SLOW_MA_OBJ "SlowMA"

input int      stochKPeriod = 14;       // Stochastic %K Period
input int      stochDPeriod = 3;        // Stochastic %D Period
input int      stochSlowing = 3;        // Stochastic Slowing
input double   riskPercentage = 1.0;    // Risk Percentage per Trade
input double   rrRatio = 5.0;           // Risk/Reward Ratio (e.g., 1:2)
input double   maxLotSize = 100.0;      // Maximum Lot Size
input int      stochOverbought = 80;    // Stochastic Overbought Level
input int      stochOversold = 20;      // Stochastic Oversold Level

input int      fastMaPeriod = 8;       // Fast MA Period (EMA)
input int      twentyoneMaPeriod = 21;    // Middle MA Period (EMA)
input int      middleMaPeriod = 55;    // Middle MA Period (EMA)
input int      slowMaPeriod = 200;     // Slow MA Period (SMA)

input long    minVolume = 100;        // Minimum volume to trigger trade
int stochasticOscillatorHandler;
int fastMaHandler, twentyoneMaHandler, middleMaHandler, slowMaHandler;
double pointValue;
double lastCurrentPrice = 0; // Variable to store the last current price
datetime lastCandleTime;
input int    TrendPeriod     = 5;     // Period for trend detection
input double TolerancePoints = 10;    // Points tolerance for matching highs/lows
input double MinShadowSize   = 0.0002;// Minimum shadow size (adjust for asset)
input color  TopColor        = clrRed;
input color  BottomColor     = clrBlue;
datetime lastPatternTime;

int maHandle;
datetime previousBarTime;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{  
   MqlRates rates[1];
   CopyRates(_Symbol, _Period, 1, 1, rates); // Get last CLOSED candle
   lastCandleTime = rates[0].time;
   
      // Create MA handle once
    maHandle = iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE);    
    // Initialize previous bar time
    previousBarTime = iTime(_Symbol, _Period, 0);

   // Create MA handles
   fastMaHandler = iMA(_Symbol, PERIOD_CURRENT, fastMaPeriod, 0, MODE_SMA, PRICE_CLOSE);
   twentyoneMaHandler = iMA(_Symbol, PERIOD_CURRENT, twentyoneMaPeriod, 0, MODE_SMA, PRICE_CLOSE);
   middleMaHandler = iMA(_Symbol, PERIOD_CURRENT, middleMaPeriod, 0, MODE_SMA, PRICE_CLOSE);
   slowMaHandler = iMA(_Symbol, PERIOD_CURRENT, slowMaPeriod, 0, MODE_SMA, PRICE_CLOSE);
   
   if(fastMaHandler == INVALID_HANDLE || middleMaHandler == INVALID_HANDLE || slowMaHandler == INVALID_HANDLE)
   {
      Print("Error creating MA handles");
      return(INIT_FAILED);
   }
   
       if(maHandle == INVALID_HANDLE)
    {
        Print("Error creating MA indicator");
        return INIT_FAILED;
    }
   
   // Initialize objects to draw MAs
   CreateMaObject(FAST_MA_OBJ, clrRed);    // Fast MA (Blue)
   CreateMaObject(MIDDLE_MA_OBJ, clrBlue); // Middle MA (Green)
   CreateMaObject(SLOW_MA_OBJ, clrWhite);     // Slow MA (Red)
   
   // Create Stochastic handle
   stochasticOscillatorHandler = iStochastic(_Symbol, PERIOD_CURRENT, stochKPeriod, stochDPeriod, stochSlowing, MODE_SMA, STO_LOWHIGH);
   
   if(stochasticOscillatorHandler == INVALID_HANDLE)
   {
      Print("Error creating Stochastic indicator handle");
      return(INIT_FAILED);
   }

   ChartIndicatorAdd(ChartID(), 0, fastMaHandler); 
   ChartIndicatorAdd(ChartID(), 0, twentyoneMaHandler); 
   // ChartIndicatorAdd(ChartID(), 1, stochasticOscillatorHandler); 

   pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / 
               (SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) / 
               SymbolInfoDouble(_Symbol, SYMBOL_POINT));
               
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Create a horizontal line object for an MA                        |
//+------------------------------------------------------------------+
void CreateMaObject(const string name, const color clr)
{
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, true); // Draw behind price chart
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    datetime currentBarTime = iTime(_Symbol, _Period, 0);
    
    // Check if a new bar has formed
    if(currentBarTime != previousBarTime)
    {
        priceCrosses50MovingAverageDetector(maHandle); // Call the detector
        previousBarTime = currentBarTime; // Update the bar time
    }
   
   MqlRates current[1];
   if(CopyRates(_Symbol, _Period, 0, 1, current) == 1) // Current forming candle
   {
      // Check if new candle started (previous candle closed)
      if(current[0].time > lastCandleTime)
      {
         lastCandleTime = current[0].time;
         runAllPatternDetectors(); // Your pattern functions
      }
   }  
   
   // Check for minimum volume
   long currentVolume = iVolume(_Symbol, _Period, 0);
   if(currentVolume < minVolume) return;
   
   if(BarsCalculated(fastMaHandler) < slowMaPeriod ||   
      BarsCalculated(middleMaHandler) < slowMaPeriod || 
      BarsCalculated(slowMaHandler) < slowMaPeriod)
      return;

   double fastMa[], middleMa[], slowMa[];
   CopyBuffer(fastMaHandler, 0, 0, 3, fastMa);
   CopyBuffer(middleMaHandler, 0, 0, 3, middleMa);
   CopyBuffer(slowMaHandler, 0, 0, 3, slowMa);
   
   ArraySetAsSeries(fastMa, true);
   ArraySetAsSeries(middleMa, true);
   ArraySetAsSeries(slowMa, true);

   // Update MA lines on the chart
   ObjectSetDouble(0, FAST_MA_OBJ, OBJPROP_PRICE, fastMa[0]);
   ObjectSetDouble(0, MIDDLE_MA_OBJ, OBJPROP_PRICE, middleMa[0]);
   ObjectSetDouble(0, SLOW_MA_OBJ, OBJPROP_PRICE, slowMa[0]);
  
                       
   // Simplified crossover detection (fastMA vs middleMA only)
   bool bullishCross = (fastMa[0] > middleMa[0]) && (fastMa[1] <= middleMa[1]);
   bool bearishCross = (fastMa[0] < middleMa[0]) && (fastMa[1] >= middleMa[1]);
   
   if(BarsCalculated(stochasticOscillatorHandler) < stochKPeriod + stochDPeriod + stochSlowing)
      return;
   
   double K[], D[];
   CopyBuffer(stochasticOscillatorHandler, 0, 0, 3, K); // %K values
   CopyBuffer(stochasticOscillatorHandler, 1, 0, 3, D); // %D values
   
   ArraySetAsSeries(K, true);
   ArraySetAsSeries(D, true);

   // Check for Stochastic crossover signals
   bool stochBuy = (K[0] > stochOversold && K[1] <= stochOversold);  // %K crosses above 20
   bool stochSell = (K[0] < stochOverbought && K[1] >= stochOverbought); // %K crosses below 80

   // Check existing positions
   bool positionExists = PositionSelect(_Symbol);

   // Calculate risk amount based on account equity
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * 0.01; // 1% of equity

   // Broker-specific constraints
   double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double minLotSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLotSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE) // Timeframe changed
   {
      lastCandleTime = 0; // Force reset
   }
}

void runAllPatternDetectors()
{
   deleteAllRectanglesAndMarkersWhenWeSwitchTimeframe();
   
   fvgCandlesPatternDetector();
   threeWhiteOrBlackSoldiersPatternDetector();
   engulfingCandlesPatternDetector();
   morningAndEveningStarCandlesPatternDetector();
   dojiAndDragonFlyDojiAndGravestoneDojiCandlesDetector();
   insideBarCandlesPatternDetector();
   haramiDetector();
   tweezersTopAndBottomDetector();
   pinBarCandlesPatternDetector();
   orderBlockCandlesPatternDetector();
   supplyAndDemandDetector();
   bos();
}

/* 
   void runAllPatternDetectors(int lookbackPeriod = 14) 
   {
      deleteAllRectanglesAndMarkersWhenWeSwitchTimeframe(); // Clear old objects
   
      // Run detectors with parameters (if needed)
      fvgCandlesPatternDetector(lookbackPeriod);
      threeWhiteOrBlackSoldiersPatternDetector();
      engulfingCandlesPatternDetector();
      morningAndEveningStarCandlesPatternDetector();
      dojiAndDragonFlyDojiAndGravestoneDojiCandlesDetector();
      insideBarCandlesPatternDetector();
      haramiDetector();
      tweezersTopAndBottomDetector();
      pinBarCandlesPatternDetector();
      orderBlockCandlesPatternDetector();
      supplyAndDemandDetector();
      bos(lookbackPeriod); // Pass parameters explicitly
   }
*/

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "Tweezer*");
   // Delete MA objects when EA is removed
   ObjectDelete(0, FAST_MA_OBJ);
   ObjectDelete(0, MIDDLE_MA_OBJ);
   ObjectDelete(0, SLOW_MA_OBJ);
   
   IndicatorRelease(fastMaHandler);
   IndicatorRelease(middleMaHandler);
   IndicatorRelease(slowMaHandler);
   IndicatorRelease(stochasticOscillatorHandler);
   
       if(maHandle != INVALID_HANDLE)
    {
        IndicatorRelease(maHandle); // Release the handle
    }
}

//+------------------------------------------------------------------+
//| Helper function to get current timeframe as a string            |
//+------------------------------------------------------------------+
string currentTimeFrame(){
    long period = Period();
    switch(period){
        case 1: return "M1";
        case 5: return "M5";
        case 15: return "M15";
        case 30: return "M30";
        case 60: return "H1";
        case 240: return "H4";
        case 1440: return "D1";
        case 10080: return "W1";
        case 43200: return "MN1";
        default: return "Unknown";
    }
}

//------------------------------------------------------------------
// price crosses 50 Moving Average Detector
//------------------------------------------------------------------
void priceCrosses50MovingAverageDetector(int maHandle)
{
    double maValues[2];
    ArraySetAsSeries(maValues, true); // Set series before copying
    if(CopyBuffer(maHandle, 0, 0, 2, maValues) != 2)
    {
        Print("Error copying MA values");
        return;
    }

    double closePrices[2];
    ArraySetAsSeries(closePrices, true); // Set series before copying
    if(CopyClose(_Symbol, _Period, 0, 2, closePrices) != 2)
    {
        Print("Error copying closing prices");
        return;
    }

    // Check for bullish cross (price crosses above MA)
    if(closePrices[1] < maValues[1] && closePrices[0] > maValues[0])
    {
        string timeframe = EnumToString(_Period);
        string message = StringFormat("%s %s Bullish crossover detected: Price crossed ABOVE 50-period SMA", _Symbol, timeframe);
        Alert(message);
        SendNotification(message);
    }
    
    // Check for bearish cross (price crosses below MA)
    if(closePrices[1] > maValues[1] && closePrices[0] < maValues[0])
    {
        string timeframe = EnumToString(_Period);
        string message = StringFormat("%s %s Bearish crossover detected: Price crossed BELOW 50-period SMA", _Symbol, timeframe);
        Alert(message);
        SendNotification(message);
    }
}

//------------------------------------------------------------------
// FVG patterns detection
//------------------------------------------------------------------
void fvgCandlesPatternDetector()
{
    string symbol = _Symbol;
    ENUM_TIMEFRAMES tf = _Period;
    int lookback = 5;
    MqlRates rates[];
    
    ArraySetAsSeries(rates, true);
    ArrayResize(rates, lookback); // MT5 requires explicit array sizing
    int copied = CopyRates(symbol, tf, 0, lookback, rates);
    
    if(copied < 3) return;

    static datetime lastBullishFVG = 0;
    static datetime lastBearishFVG = 0;

    // Process candles from OLDEST to NEWEST (MT5-specific)
    for(int i = copied-1; i >= 2; i--) // Key fix: reverse iteration
    {
        MqlRates c3 = rates[i];     // Oldest candle
        MqlRates c2 = rates[i-1];   // Middle candle
        MqlRates c1 = rates[i-2];   // Newest candle

        if(!isCandleClosed(i-2, rates)) continue; // Skip forming candles

        // Bullish FVG (Bearish c3 -> Bullish c1)
        if(c3.close < c3.open &&    // Bearish candle
           c1.close > c1.open &&    // Bullish candle
           c2.low > c3.high &&      // Gap between c3 and c2
           c1.low > c2.high)        // Gap remains unfilled
        {
            double fvgTop = c3.high;
            double fvgBottom = c2.low;
            
            if(isValidFVG(fvgTop, fvgBottom) && 
               lastBullishFVG != c3.time)
            {
                drawFVG(c3.time, c2.time, fvgTop, fvgBottom, clrDodgerBlue, "Bullish");
                sendFVGNotification("Bullish", fvgTop, fvgBottom, c3.time);
                lastBullishFVG = c3.time;
            }
        }

        // Bearish FVG (Bullish c3 -> Bearish c1)
        if(c3.close > c3.open &&    // Bullish candle
           c1.close < c1.open &&    // Bearish candle
           c2.high < c3.low &&      // Gap between c3 and c2
           c1.high < c2.low)        // Gap remains unfilled
        {
            double fvgTop = c2.high;
            double fvgBottom = c3.low;
            
            if(isValidFVG(fvgTop, fvgBottom) && 
               lastBearishFVG != c3.time)
            {
                drawFVG(c3.time, c2.time, fvgTop, fvgBottom, clrOrangeRed, "Bearish");
                sendFVGNotification("Bearish", fvgTop, fvgBottom, c3.time);
                lastBearishFVG = c3.time;
            }
        }
    }
}

bool isValidFVG(double top, double bottom)
{
    // Dynamic pip size calculation
    double pipSize = (_Digits == 3 || _Digits == 5) ? 10*_Point : _Point;
    double fvgSize = MathAbs(top - bottom);
    return (fvgSize >= 10*pipSize); // Minimum 10 pips
}

void drawFVG(datetime startTime, datetime endTime, double top, double bottom, color clr, string type)
{
    string objName = type + "FVG_" + TimeToString(startTime, TIME_DATE|TIME_MINUTES);
    
    if(ObjectFind(0, objName) >= 0) return; // Avoid duplicates

    color transparentClr = ColorToARGB(clr, 25); // 10% opacity
    
    ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, top, endTime, bottom);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, transparentClr);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, transparentClr);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    ObjectSetInteger(0, objName, OBJPROP_FILL, true);
}

void sendFVGNotification(string type, double top, double bottom, datetime time)
{
    string timeframe = EnumToString(_Period);
    double fvgSizePips = MathAbs(top - bottom) / ((_Digits == 3 || _Digits ==5) ? 0.001 : 0.0001);
    
    string message = StringFormat("%s FVG detected on %s %s\nTime: %s\nSize: %.1f pips",
                     type, _Symbol, timeframe, TimeToString(time), fvgSizePips);
    
    Alert(message);
    SendNotification(message); // Requires MT5 notifications enabled
}
//------------------------------------------------------------------
// Three White/Black Soldiers patterns detection
//------------------------------------------------------------------
void threeWhiteOrBlackSoldiersPatternDetector()
{
    // 1. Declare and load price data
    double closePrices[], openPrices[], highPrices[], lowPrices[];
    datetime timePrices[];
    ArraySetAsSeries(closePrices, true);
    ArraySetAsSeries(openPrices, true);
    ArraySetAsSeries(highPrices, true);
    ArraySetAsSeries(lowPrices, true);
    ArraySetAsSeries(timePrices, true);

    int barsNeeded = 5;
    CopyClose(_Symbol, _Period, 0, barsNeeded, closePrices);
    CopyOpen(_Symbol, _Period, 0, barsNeeded, openPrices);
    CopyHigh(_Symbol, _Period, 0, barsNeeded, highPrices);
    CopyLow(_Symbol, _Period, 0, barsNeeded, lowPrices);
    CopyTime(_Symbol, _Period, 0, barsNeeded, timePrices);

    // 2. Index mapping
    enum PatternBars {
        TREND_BAR = 4,   // Bar 4 (oldest)
        OLDEST = 3,      // Bar 3
        MIDDLE = 2,      // Bar 2
        NEWEST = 1       // Bar 1 (most recent closed)
    };

    bool whiteSoldiers = false;
    bool blackSoldiers = false;

    // 3. Bullish pattern check (Three White Soldiers)
    if(closePrices[NEWEST] > openPrices[NEWEST] &&
       closePrices[MIDDLE] > openPrices[MIDDLE] &&
       closePrices[OLDEST] > openPrices[OLDEST])
    {
        double body1 = (closePrices[OLDEST] - openPrices[OLDEST]) 
                      / (MathMax(_Point, highPrices[OLDEST] - lowPrices[OLDEST]));
        double body2 = (closePrices[MIDDLE] - openPrices[MIDDLE]) 
                      / (MathMax(_Point, highPrices[MIDDLE] - lowPrices[MIDDLE]));
        double body3 = (closePrices[NEWEST] - openPrices[NEWEST]) 
                      / (MathMax(_Point, highPrices[NEWEST] - lowPrices[NEWEST]));

        whiteSoldiers = body1 >= 0.6 && body2 >= 0.6 && body3 >= 0.6 &&
                       (openPrices[MIDDLE] > openPrices[OLDEST]) &&
                       (openPrices[MIDDLE] < closePrices[OLDEST]) &&
                       (openPrices[NEWEST] > openPrices[MIDDLE]) &&
                       (openPrices[NEWEST] < closePrices[MIDDLE]) &&
                       (closePrices[TREND_BAR] < closePrices[OLDEST]);
    }

    // 4. Bearish pattern check (Three Black Soldiers)
    if(closePrices[NEWEST] < openPrices[NEWEST] &&
       closePrices[MIDDLE] < openPrices[MIDDLE] &&
       closePrices[OLDEST] < openPrices[OLDEST])
    {
        double body1 = (openPrices[OLDEST] - closePrices[OLDEST]) 
                      / (MathMax(_Point, highPrices[OLDEST] - lowPrices[OLDEST]));
        double body2 = (openPrices[MIDDLE] - closePrices[MIDDLE]) 
                      / (MathMax(_Point, highPrices[MIDDLE] - lowPrices[MIDDLE]));
        double body3 = (openPrices[NEWEST] - closePrices[NEWEST]) 
                      / (MathMax(_Point, highPrices[NEWEST] - lowPrices[NEWEST]));

        blackSoldiers = body1 >= 0.6 && body2 >= 0.6 && body3 >= 0.6 &&
                       (openPrices[MIDDLE] < openPrices[OLDEST]) &&
                       (openPrices[MIDDLE] > closePrices[OLDEST]) &&
                       (openPrices[NEWEST] < openPrices[MIDDLE]) &&
                       (openPrices[NEWEST] > closePrices[MIDDLE]) &&
                       (closePrices[TREND_BAR] > closePrices[OLDEST]);
    }

    // 5. Draw boxes and alerts
    if(whiteSoldiers) 
    {
        datetime startTime = timePrices[OLDEST];
        datetime endTime = timePrices[NEWEST] + PeriodSeconds(_Period);
        DrawSoldiersPatternBox("TWS_Box", startTime, endTime, 
                      lowPrices[OLDEST], highPrices[NEWEST], clrLimeGreen);
        Alert("Three White Soldiers detected");
    }
    
    if(blackSoldiers) 
    {
        datetime startTime = timePrices[OLDEST];
        datetime endTime = timePrices[NEWEST] + PeriodSeconds(_Period);
        DrawSoldiersPatternBox("TBS_Box", startTime, endTime, 
                      lowPrices[NEWEST], highPrices[OLDEST], clrIndianRed);
        Alert("Three Black Soldiers detected");
    }
}

//------------------------------------------------------------------
// Box Drawing Function
//------------------------------------------------------------------
void DrawSoldiersPatternBox(string namePrefix, datetime startTime, datetime endTime, 
                    double price1, double price2, color clr)
{
    string objName = namePrefix + "_" + TimeToString(startTime);
    
    // Delete old object if exists
    if(ObjectFind(0, objName) >= 0)
        ObjectDelete(0, objName);

    // Create rectangle object
    if(!ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, price1, endTime, price2))
    {
        Print("Failed to create box: ", GetLastError());
        return;
    }

    // Style settings
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASHDOT);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    ObjectSetInteger(0, objName, OBJPROP_FILL, false);
    ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
}


//------------------------------------------------------------------
// Engulfing patterns detection
//------------------------------------------------------------------
void engulfingCandlesPatternDetector()
{
   int limit = 5; // Number of candles to analyze
   string symbol = _Symbol;
   ENUM_TIMEFRAMES tf = _Period;

   MqlRates rates[];
   ArraySetAsSeries(rates, true); // Newest data at index 0
   int copied = CopyRates(symbol, tf, 0, limit, rates);
   
   if(copied < 2) return; // Need at least 2 candles

   static datetime lastBullishTime = 0;
   static datetime lastBearishTime = 0;

   for(int i = 0; i < copied - 1; i++) // Compare current & next candle
   {
      int current = i;
      int previous = i + 1;

      // Skip if current candle is still forming (only check i=0)
      if(current == 0)
      {
         datetime currentCandleCloseTime = rates[current].time + PeriodSeconds();
         if(TimeCurrent() < currentCandleCloseTime)
            continue; // Skip unclosed current candle
      }

      double open1 = rates[current].open;
      double close1 = rates[current].close;
      double open2 = rates[previous].open;
      double close2 = rates[previous].close;

      // Skip invalid candles (no trading activity)
      if(open1 == 0 || close1 == 0 || open2 == 0 || close2 == 0) continue;

      datetime currentTime = rates[current].time;

      // Bullish Engulfing Pattern
      if(isBullishEngulfing(open1, close1, open2, close2))
      {
         if(lastBullishTime != currentTime)
         {
            drawEngulfingBox(rates[current], rates[previous], clrBlue, "Bullish");
            notifyEngulfing("Bullish", symbol, currentTime);
            lastBullishTime = currentTime;
         }
      }

      // Bearish Engulfing Pattern
      else if(isBearishEngulfing(open1, close1, open2, close2))
      {
         if(lastBearishTime != currentTime)
         {
            drawEngulfingBox(rates[current], rates[previous], clrRed, "Bearish");
            notifyEngulfing("Bearish", symbol, currentTime);
            lastBearishTime = currentTime;
         }
      }
   }
}

bool isBullishEngulfing(double o1, double c1, double o2, double c2)
{
   return (c2 < o2) &&          // Previous candle is bearish
          (c1 > o1) &&          // Current candle is bullish
          (c1 > o2) &&          // Current close > previous open
          (o1 < c2);            // Current open < previous close
}

bool isBearishEngulfing(double o1, double c1, double o2, double c2)
{
   return (c2 > o2) &&          // Previous candle is bullish
          (c1 < o1) &&          // Current candle is bearish
          (o1 > c2) &&          // Current open > previous close
          (c1 < o2);            // Current close < previous open
}

void drawEngulfingBox(const MqlRates &current, const MqlRates &previous, color clr, string patternType)
{
   string objName = patternType + "Engulfing" + IntegerToString(current.time);
   
   double upper = MathMax(current.high, previous.high);
   double lower = MathMin(current.low, previous.low);

   if(ObjectFind(0, objName) >= 0) 
      ObjectDelete(0, objName);

   if(!ObjectCreate(0, objName, OBJ_RECTANGLE, 0, previous.time, upper, current.time, lower))
   {
      Print("Failed to create rectangle: ", GetLastError());
      return;
   }

   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_FILL, false);
}

void notifyEngulfing(string patternType, string symbol, datetime dt)
{
   string timeframe = EnumToString(_Period);
   string message = StringFormat("%s Engulfing detected on %s %s %s at %s", 
                    patternType, symbol, timeframe, EnumToString(_Period), TimeToString(dt));
   
   Print(message);
   if(!MQL5InfoInteger(MQL5_TESTING)) // Send alerts only if not in tester
   {
      SendNotification(message);
      Alert(message);
   }
}

//------------------------------------------------------------------
// Morning and Eveming Star Detector
//------------------------------------------------------------------
void morningAndEveningStarCandlesPatternDetector() {
   int lookback = 5;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   ArrayResize(rates, lookback);
   int copied = CopyRates(_Symbol, _Period, 0, lookback, rates);
   
   if(copied < 3) return;
   
   static datetime lastStarTime = 0;

   for(int i = 0; i < copied - 2; i++) {
      if(!isCandleClosed(i, rates)) continue;
      
      MqlRates third = rates[i];    // Current candle
      MqlRates second = rates[i+1]; // Middle candle
      MqlRates first = rates[i+2];  // First candle

      double firstBodySize = bodySize(first);
      double secondBodySize = bodySize(second);
      double firstMid = (first.open + first.close) / 2.0;

      // Morning Star (Bullish)
      bool morningStar = first.close < first.open &&
                        secondBodySize < firstBodySize * 0.3 &&
                        second.open < first.close &&
                        third.open > second.close &&
                        third.close > third.open &&
                        third.close > firstMid;

      // Evening Star (Bearish)
      bool eveningStar = first.close > first.open &&
                        secondBodySize < firstBodySize * 0.3 &&
                        second.open > first.close &&
                        third.open < second.close &&
                        third.close < third.open &&
                        third.close < firstMid;

      if(morningStar || eveningStar) {
         string patternType = morningStar ? "Morning Star" : "Evening Star";
         color clr = morningStar ? clrDodgerBlue : clrOrangeRed;
         
         if(lastStarTime != third.time) {
            drawPatternBox(first.time, third.time,
                          MathMax(MathMax(first.high, second.high), third.high),
                          MathMin(MathMin(first.low, second.low), third.low),
                          clr, patternType);
            notifyPattern(patternType, third.time);
            lastStarTime = third.time;
         }
      }
   }
}

//------------------------------------------------------------------
// Doji, Dragonfly Doji, and Gravestone Doji Detector
//------------------------------------------------------------------
void dojiAndDragonFlyDojiAndGravestoneDojiCandlesDetector()
{
   int lookback = 5;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   ArrayResize(rates, lookback); // MT5 requires explicit array sizing
   int copied = CopyRates(_Symbol, _Period, 0, lookback, rates);
   
   if(copied < 1) return;
   
   static datetime lastDojiTime = 0;
   
   for(int i = 0; i < copied; i++) {
      if(!isCandleClosed(i, rates)) continue;
      
      MqlRates current = rates[i];
      double body = bodySize(current);
      double totalRange = current.high - current.low;
      
      if(totalRange == 0) continue;
      
      // Doji criteria (body < 10% of total range)
      if(body < totalRange * 0.1) {
         double lowerShade = lowerShadow(current);
         double upperShade = upperShadow(current);
         
         if(lowerShade > totalRange * 0.6 && upperShade < totalRange * 0.1) {
            drawPattern(current.time, "DragonflyDoji", clrLime);
            if(lastDojiTime != current.time) {
               notifyPattern("Dragonfly Doji", current.time);
               lastDojiTime = current.time;
            }
         }
         else if(upperShade > totalRange * 0.6 && lowerShade < totalRange * 0.1) {
            drawPattern(current.time, "GravestoneDoji", clrRed);
            if(lastDojiTime != current.time) {
               notifyPattern("Gravestone Doji", current.time);
               lastDojiTime = current.time;
            }
         }
         else {
            drawPattern(current.time, "Doji", clrGray);
            if(lastDojiTime != current.time) {
               notifyPattern("Doji", current.time);
               lastDojiTime = current.time;
            }
         }
      }
   }
}


//------------------------------------------------------------------
// Inside Bar Pattern Detector
//------------------------------------------------------------------
void insideBarCandlesPatternDetector()
{
   int lookback = 5;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   ArrayResize(rates, lookback); // MT5 requires explicit array sizing
   int copied = CopyRates(_Symbol, _Period, 0, lookback, rates);
   
   if(copied < 2) return;
   
   static datetime lastInsideTime = 0;

   for(int i = 0; i < copied - 1; i++) {
      if(!isCandleClosed(i, rates)) continue;
      
      MqlRates current = rates[i];
      MqlRates previous = rates[i+1];
      
      // Check if current is inside previous
      if(current.high < previous.high && current.low > previous.low) {
         if(lastInsideTime != current.time) {
            drawPatternBox(previous.time, current.time, 
                          previous.high, previous.low, 
                          clrGoldenrod, "InsideBar");
            notifyPattern("Inside Bar", current.time);
            lastInsideTime = current.time;
         }
      }
   }
}

//------------------------------------------------------------------
// Harami Pattern Detector
//------------------------------------------------------------------
void haramiDetector()
{
   int lookback = 5;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   ArrayResize(rates, lookback); // MT5 array sizing requirement
   int copied = CopyRates(_Symbol, _Period, 0, lookback, rates);
   
   if(copied < 2) return;
   
   static datetime lastHaramiTime = 0;

   for(int i = 0; i < copied - 1; i++) {
      if(!isCandleClosed(i, rates)) continue;
      
      MqlRates current = rates[i];
      MqlRates previous = rates[i+1];
      
      // Enhanced Harami detection with body size comparison
      bool isBullishHarami = previous.close < previous.open && 
                            current.close > current.open &&
                            current.open > previous.close &&
                            current.close < previous.open &&
                            bodySize(current) < bodySize(previous) * 0.75;

      bool isBearishHarami = previous.close > previous.open && 
                            current.close < current.open &&
                            current.open < previous.close &&
                            current.close > previous.open &&
                            bodySize(current) < bodySize(previous) * 0.75;

      if(isBullishHarami || isBearishHarami) {
         string patternType = isBullishHarami ? "BullishHarami" : "BearishHarami";
         color patternColor = isBullishHarami ? ColorToARGB(clrDodgerBlue, 255) : 
                              ColorToARGB(clrOrangeRed, 255);
         
         if(lastHaramiTime != current.time) {
            drawHaramiBox(previous.time, current.time,
                         MathMax(previous.high, current.high),
                         MathMin(previous.low, current.low),
                         patternColor, patternType);
            notifyHaramiPattern(patternType, previous.close, current.time);
            lastHaramiTime = current.time;
         }
      }
   }
}


//------------------------------------------------------------------
// Tweezers Top/Bottom Detector
//------------------------------------------------------------------
/*
void tweezersTopAndBottomDetector()
{
   int lookback = 5;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   ArrayResize(rates, lookback); // MT5 array sizing requirement
   int copied = CopyRates(_Symbol, _Period, 0, lookback, rates);
   
   if(copied < 2) return;
   
   static datetime lastTweezerTime = 0;
   double tolerance = 10 * _Point * MathPow(10, _Digits%2); // Auto-adjust for 3/5 digit brokers

   for(int i = 0; i < copied - 1; i++) {
      if(!isCandleClosed(i, rates)) continue;
      
      MqlRates current = rates[i];
      MqlRates previous = rates[i+1];
      
      // Enhanced Tweezer Top criteria
      bool topCondition = MathAbs(current.high - previous.high) <= tolerance &&
                         current.close < current.open &&    // Current bearish
                         previous.close > previous.open &&  // Previous bullish
                         current.high > current.close &&    // Upper shadow exists
                         previous.high > previous.close;    // Previous upper shadow

      // Enhanced Tweezer Bottom criteria
      bool bottomCondition = MathAbs(current.low - previous.low) <= tolerance &&
                            current.close > current.open &&   // Current bullish
                            previous.close < previous.open && // Previous bearish
                            current.low < current.open &&     // Lower shadow exists
                            previous.low < previous.open;     // Previous lower shadow

      if(topCondition || bottomCondition) {
         string patternType = topCondition ? "TweezerTop" : "TweezerBottom";
         color patternColor = topCondition ? clrRed : clrDodgerBlue;
         double patternPrice = topCondition ? current.high : current.low;
         
         if(lastTweezerTime != current.time) {
            drawTweezerMark(current.time, patternPrice, patternType, patternColor);
            notifyTweezerPattern(patternType, patternPrice, current.time);
            lastTweezerTime = current.time;
         }
      }
   }
}
*/

void tweezersTopAndBottomDetector()
{
   MqlRates candles[2];
   ArraySetAsSeries(candles, true);
   
   if(CopyRates(_Symbol, _Period, 0, 2, candles) < 2) return;
   
   // Skip if current candle is still forming
   if(!tweezerIsCandleClosed(0, candles)) return;

   MqlRates current = candles[0];
   MqlRates previous = candles[1];
   
   double tolerance = TolerancePoints * _Point;
   bool isTweezerTop = false;
   bool isTweezerBottom = false;

   // Trend Validation
   bool uptrend = isUptrend(TrendPeriod);
   bool downtrend = isDowntrend(TrendPeriod);

   // Tweezer Top Criteria
   if(MathAbs(current.high - previous.high) <= tolerance)
   {
      bool hasUpperShadows = (current.high - current.close >= MinShadowSize) && 
                            (previous.high - previous.close >= MinShadowSize);
      
      isTweezerTop = (current.close < current.open) &&       // Bearish current
                    (previous.close > previous.open) &&      // Bullish previous
                    hasUpperShadows; //&&
                    // uptrend;
   }

   // Tweezer Bottom Criteria
   if(MathAbs(current.low - previous.low) <= tolerance)
   {
      bool hasLowerShadows = (current.open - current.low >= MinShadowSize) && 
                            (previous.open - previous.low >= MinShadowSize);
      
      isTweezerBottom = (current.close > current.open) &&    // Bullish current
                       (previous.close < previous.open) &&   // Bearish previous
                       hasLowerShadows; // &&
                       // downtrend;
   }

   // Pattern Found
   if((isTweezerTop || isTweezerBottom) && (lastPatternTime != current.time))
   {
      string patternType = isTweezerTop ? "Tweezer Top" : "Tweezer Bottom";
      color patternColor = isTweezerTop ? TopColor : BottomColor;
      double patternPrice = isTweezerTop ? current.high : current.low;

      drawPatternMarker(current.time, patternPrice, patternType, patternColor);
      drawTweezerMark(current.time, patternPrice, patternType, patternColor);
      sendNotification(patternType, patternPrice);
      
      lastPatternTime = current.time;
   }
}


//------------------------------------------------------------------
// Pin Bar (Hammer/Shooting Star) Detector
//------------------------------------------------------------------
void pinBarCandlesPatternDetector()
{
   int lookback = 5;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   ArrayResize(rates, lookback); // MT5 array sizing requirement
   int copied = CopyRates(_Symbol, _Period, 0, lookback, rates);
   
   if(copied < 1) return;
   
   static datetime lastPinBarTime = 0;

   for(int i = 0; i < copied; i++) {
      if(!isCandleClosed(i, rates)) continue;
      
      MqlRates current = rates[i];
      double body = bodySize(current);
      double upper = pinBarUpperShadow(current);
      double lower = pinBarLowerShadow(current);
      double totalRange = current.high - current.low;

      if(totalRange == 0) continue;

      // Enhanced Pin Bar validation
      bool isHammer = (lower >= 2 * body) &&       // Lower shadow >= 2x body
                     (upper <= body * 0.3) &&      // Upper shadow <= 30% body
                     (body < totalRange * 0.3);    // Body < 30% total range

      bool isShootingStar = (upper >= 2 * body) && // Upper shadow >= 2x body
                           (lower <= body * 0.3) && // Lower shadow <= 30% body
                           (body < totalRange * 0.3); // Body < 30% total range

      if(isHammer || isShootingStar) {
         string patternType = isHammer ? "Hammer" : "ShootingStar";
         color patternColor = isHammer ? clrLime : clrRed;
         double patternPrice = isHammer ? current.low : current.high;
         
         if(lastPinBarTime != current.time) {
            drawPinBarMarker(current.time, patternPrice, patternType, patternColor);
            notifyPinBar(patternType, patternPrice, current.time);
            lastPinBarTime = current.time;
         }
      }
   }
}


//------------------------------------------------------------------
// Order Block Pattern Detector (Simplified)
//------------------------------------------------------------------
void orderBlockCandlesPatternDetector()
{
   int lookback = 10;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   ArrayResize(rates, lookback); // MT5 array sizing requirement
   int copied = CopyRates(_Symbol, _Period, 0, lookback, rates);
   
   if(copied < 3) return;
   
   static datetime lastBlockTime = 0;

   for(int i = 2; i < copied; i++) { // Start from oldest relevant candle
      if(!orderBlockIsCandleClosed(i, rates)) continue;
      
      MqlRates current = rates[i];
      MqlRates prev1 = rates[i-1];
      MqlRates prev2 = rates[i-2];

      // Enhanced Order Block detection
      bool bullishBlock = prev2.close < prev2.open &&         // Strong bearish candle
                         (prev2.open - prev2.close) > (prev2.high - prev2.low) * 0.7 && // Body dominates range
                         prev1.close > prev1.open &&          // Bullish reaction
                         prev1.close > prev2.open &&          // Reaction above bearish open
                         current.close > prev1.high;          // Break of reaction high

      bool bearishBlock = prev2.close > prev2.open &&         // Strong bullish candle
                         (prev2.close - prev2.open) > (prev2.high - prev2.low) * 0.7 &&
                         prev1.close < prev1.open &&          // Bearish reaction
                         prev1.close < prev2.open &&          // Reaction below bullish open
                         current.close < prev1.low;           // Break of reaction low

      if(bullishBlock || bearishBlock) {
         string patternType = bullishBlock ? "BullishOB" : "BearishOB";
         color blockColor = bullishBlock ? clrRoyalBlue : clrCrimson;
         double blockHigh = MathMax(MathMax(prev2.high, prev1.high), current.high);
         double blockLow = MathMin(MathMin(prev2.low, prev1.low), current.low);
         
         if(lastBlockTime != prev2.time) {
            drawOrderBlockZone(prev2.time, current.time, blockHigh, blockLow, blockColor, patternType);
            notifyOrderBlock(patternType, blockHigh, blockLow, current.time);
            lastBlockTime = prev2.time;
         }
      }
   }
}

//------------------------------------------------------------------
// Supply/Demand Zone Detector (Basic)
//------------------------------------------------------------------
void supplyAndDemandDetector()
{
   int lookback = 50;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   ArrayResize(rates, lookback); // MT5 array sizing requirement
   int copied = CopyRates(_Symbol, _Period, 0, lookback, rates);
   
   if(copied < 4) return;
   
   static datetime lastZoneTime = 0;
   double minMove = 100 * _Point; // 100 pips base movement
   double consolidationFactor = 0.4; // 40% of initial move

   for(int i = 3; i < copied; i++) { // Process from oldest to newest
      if(!isCandleClosed(i, rates)) continue;
      
      MqlRates current = rates[i];
      MqlRates prev1 = rates[i-1];
      MqlRates prev2 = rates[i-2];
      MqlRates prev3 = rates[i-3];

      // Enhanced zone detection using price momentum
      double baseMove = prev3.high - prev3.low;
      bool demandZone = prev3.close > prev3.open &&               // Bullish base candle
                       baseMove >= minMove &&                     // Significant move
                       (prev2.high - prev2.low) < baseMove * consolidationFactor && // Consolidation
                       (prev1.high - prev1.low) < baseMove * consolidationFactor &&
                       current.close > prev3.high &&              // Breakout
                       current.close > MathMax(prev1.close, prev2.close);

      bool supplyZone = prev3.close < prev3.open &&               // Bearish base candle
                       baseMove >= minMove &&
                       (prev2.high - prev2.low) < baseMove * consolidationFactor &&
                       (prev1.high - prev1.low) < baseMove * consolidationFactor &&
                       current.close < prev3.low &&
                       current.close < MathMin(prev1.close, prev2.close);

      if(demandZone || supplyZone) {
         string patternType = demandZone ? "DemandZone" : "SupplyZone";
         color zoneColor = demandZone ? clrDarkGreen : clrDarkRed;
         double zoneTop = demandZone ? prev3.low : prev3.high;
         double zoneBottom = demandZone ? prev3.low - (baseMove * 0.5) : prev3.high + (baseMove * 0.5);
         
         if(lastZoneTime != prev3.time) {
            drawSupplyDemandZone(prev3.time, current.time, zoneTop, zoneBottom, zoneColor, patternType);
            notifySupplyDemand(patternType, zoneTop, zoneBottom, current.time);
            lastZoneTime = prev3.time;
         }
      }
   }
}

//------------------------------------------------------------------
// Break of Structure Detector (Basic)
//------------------------------------------------------------------
void bos()
{
   int lookback = 50;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   ArrayResize(rates, lookback);
   int copied = CopyRates(_Symbol, _Period, 0, lookback, rates);
   
   if(copied < 20) return;
   
   static datetime lastBOSTime = 0;
   const int swingLength = 3; // Number of candles for swing detection
   const double minDistance = 50 * _Point * 10; // 50 pips minimum structure distance

   // Find latest swing highs and lows
   double swingHighs[], swingLows[];
   findSwings(rates, swingLength, swingHighs, swingLows);

   // Check for structure breaks
   checkBullishBOS(rates, swingHighs, lastBOSTime, minDistance);
   checkBearishBOS(rates, swingLows, lastBOSTime, minDistance);
}

void trendAndRangeDetector(){
}

//===============================
// COMMON HELPER FUNCTIONS
//===============================
void deleteAllRectanglesAndMarkersWhenWeSwitchTimeframe()
{
   string patternPrefixes[] = {"DemandZone", "SupplyZone", "BullishOB", "BearishOB",
                              "TweezerTop", "TweezerBottom", "Hammer", "ShootingStar",
                              "BOS", "InsideBar", "MorningStar", "EveningStar"};
   
   int total = ObjectsTotal(0);
   for(int i = total-1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      
      // Delete by type
      ENUM_OBJECT type = (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE);
      if(type == OBJ_RECTANGLE || type == OBJ_ARROW || type == OBJ_TREND)
      {
         ObjectDelete(0, name);
      }
      
      // Additional safety: Delete by name pattern
      for(int p=0; p<ArraySize(patternPrefixes); p++)
      {
         if(StringFind(name, patternPrefixes[p]) == 0)
         {
            ObjectDelete(0, name);
            break;
         }
      }
   }
}

double bodySize(const MqlRates &candle) {
   return MathAbs(candle.open - candle.close);
}

bool isCandleClosed(int index, const MqlRates &rates[]) {
   // MT5: Index 0 is the forming candle (not closed).
   return (index > 0);
}

void drawPatternBox(datetime startTime, datetime endTime, double high, double low, color clr, string patternType) {
   string objName = patternType + "_" + TimeToString(startTime);
   ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, high, endTime, low);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
}

void notifyPattern(string patternType, datetime time) {
   string timeframe = EnumToString(_Period);
   string message = StringFormat("%s %s %s detected at %s", _Symbol, timeframe, patternType, TimeToString(time, TIME_DATE|TIME_MINUTES));
   Alert(message);
   SendNotification(message);
}

double lowerShadow(const MqlRates &candle) {
   return candle.close > candle.open 
          ? candle.open - candle.low 
          : candle.close - candle.low;
}

double upperShadow(const MqlRates &candle) {
   return candle.high - (candle.close > candle.open 
                         ? candle.close 
                         : candle.open);
}

double pinBarUpperShadow(const MqlRates &candle) {
   return candle.high - MathMax(candle.open, candle.close);
}

double pinBarLowerShadow(const MqlRates &candle) {
   return MathMin(candle.open, candle.close) - candle.low;
}


void drawPattern(datetime time, string patternType, color clr) {
   string objName = patternType + "_" + TimeToString(time);
   int arrowCode = (patternType == "DragonflyDoji") ? 225 : 
                   (patternType == "GravestoneDoji") ? 226 : 220;
   
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_ARROW, 0, time, candlePricePosition(time));
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
   }
}

double candlePricePosition(datetime time) {
   MqlRates rt[1];
   CopyRates(_Symbol, _Period, time, 1, rt);
   return (rt[0].high + (rt[0].high - rt[0].low)*0.2); // Place above candle
}

void drawHaramiBox(datetime startTime, datetime endTime, 
                  double top, double bottom, 
                  color clr, string patternType) 
{
   string objName = StringFormat("%s_%d_%d", patternType, startTime, endTime);
   
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, top, endTime, bottom);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   }
}

void notifyHaramiPattern(string patternType, double triggerPrice, datetime time) 
{
   string timeframe = EnumToString(_Period);
   string message = StringFormat("%s detected on %s %s %s\nTime: %s\nPrice Level: %.5f",
                    patternType, _Symbol, timeframe, EnumToString(_Period),
                    TimeToString(time, TIME_DATE|TIME_MINUTES), triggerPrice);
   
   Alert(message);
   if(!SendNotification(message)) {
      Print("Failed to send notification: ", GetLastError());
   }
}

void drawTweezerMark(datetime time, double price, string type, color clr) 
{
   string objName = StringFormat("%s_%s_%.5f", type, TimeToString(time, TIME_DATE|TIME_MINUTES), price);
   int arrowCode = (type == "TweezerTop") ? 234 : 233; // Up/down arrows
   
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price + (arrowCode == 234 ? 50*_Point : -50*_Point));
   }
}

void notifyTweezerPattern(string patternType, double price, datetime time) 
{
   string timeframe = EnumToString(_Period);
   string message = StringFormat("%s detected on %s %s\nTime: %s\nPrice: %.5f",
                    patternType, _Symbol, timeframe,
                    TimeToString(time, TIME_DATE|TIME_MINUTES), price);
   
   Alert(message);
   if(!SendNotification(message)) {
      Print("Notification failed: ", GetLastError());
   }
}

void drawPinBarMarker(datetime time, double price, string type, color clr) 
{
   string objName = StringFormat("%s_%s", type, TimeToString(time, TIME_DATE|TIME_MINUTES));
   int arrowCode = (type == "Hammer") ? 241 : 242; // Down/Up arrows
   double markerOffset = (type == "Hammer") ? -10*_Point : 10*_Point;
   
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_ARROW, 0, time, price + markerOffset);
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
   }
}

void notifyPinBar(string patternType, double price, datetime time) 
{
   string timeframe = EnumToString(_Period);
   string message = StringFormat("%s detected on %s %s %s\nTime: %s\nPrice: %.5f",
                    patternType, _Symbol, timeframe, EnumToString(_Period),
                    TimeToString(time, TIME_DATE|TIME_MINUTES), price);
   
   Alert(message);
   if(!SendNotification(message)) {
      Print("Notification failed: ", GetLastError());
   }
}

bool orderBlockIsCandleClosed(int index, const MqlRates &rates[]) {
   return (index < ArraySize(rates)-1); // Skip forming candle (MT5 index 0)
}

void drawOrderBlockZone(datetime startTime, datetime endTime, double top, double bottom, color clr, string type) 
{
   string objName = StringFormat("%s_%s_%s", type, TimeToString(startTime), TimeToString(endTime));
   
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, top, endTime, bottom);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);  // Fixed property name
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   }
}

void notifyOrderBlock(string patternType, double high, double low, datetime time) 
{
   string timeframe = EnumToString(_Period);
   string message = StringFormat("%s Order Block detected on %s %s\nTime: %s\nRange: %.5f-%.5f",
                    patternType, _Symbol, timeframe,
                    TimeToString(time, TIME_DATE|TIME_MINUTES), low, high);
   
   Alert(message);
   if(!SendNotification(message)) {
      Print("Notification failed: ", GetLastError());
   }
}

void drawSupplyDemandZone(datetime startTime, datetime endTime, 
                         double top, double bottom, 
                         color clr, string type) 
{
   string objName = StringFormat("%s_%s_%.5f", type, TimeToString(startTime), top);
   
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, top, endTime, bottom);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   }
}

void notifySupplyDemand(string patternType, double top, double bottom, datetime time) 
{
   string tf = EnumToString(_Period);
   string message = StringFormat("%s detected on %s %s\nTime: %s\nZone: %.5f - %.5f",
                    patternType, _Symbol, tf,
                    TimeToString(time, TIME_DATE|TIME_MINUTES), bottom, top);
   
   Alert(message);
   if(!SendNotification(message)) {
      Print("Notification failed: ", GetLastError());
   }
}

// Helper function to find swing points
void findSwings(const MqlRates &rates[], int swingLength, double &swingHighs[], double &swingLows[])
{
   ArrayResize(swingHighs, ArraySize(rates));
   ArrayResize(swingLows, ArraySize(rates));
   ArrayInitialize(swingHighs, EMPTY_VALUE);
   ArrayInitialize(swingLows, EMPTY_VALUE);

   for(int i = swingLength; i < ArraySize(rates)-swingLength; i++)
   {
      bool isSwingHigh = true;
      bool isSwingLow = true;
      
      for(int j = 1; j <= swingLength; j++)
      {
         if(rates[i].high < rates[i+j].high || rates[i].high < rates[i-j].high)
            isSwingHigh = false;
         
         if(rates[i].low > rates[i+j].low || rates[i].low > rates[i-j].low)
            isSwingLow = false;
      }
      
      if(isSwingHigh) swingHighs[i] = rates[i].high;
      if(isSwingLow) swingLows[i] = rates[i].low;
   }
}

// Check for bullish structure break
void checkBullishBOS(const MqlRates &rates[], const double &swingHighs[], datetime &lastBOSTime, double minDistance)
{
   double currentHigh = rates[0].high;
   double currentClose = rates[0].close;
   
   for(int i = 1; i < ArraySize(rates); i++)
   {
      if(swingHighs[i] != EMPTY_VALUE && 
         currentClose > swingHighs[i] && 
         (currentHigh - swingHighs[i]) >= minDistance)
      {
         if(lastBOSTime != rates[0].time)
         {
            drawBOSStructure(rates[i].time, rates[0].time, swingHighs[i], clrGreen, "BullishBOS");
            notifyBOS("Bullish BOS", swingHighs[i], rates[0].time);
            lastBOSTime = rates[0].time;
         }
         break;
      }
   }
}

// Check for bearish structure break
void checkBearishBOS(const MqlRates &rates[], const double &swingLows[], datetime &lastBOSTime, double minDistance)
{
   double currentLow = rates[0].low;
   double currentClose = rates[0].close;
   
   for(int i = 1; i < ArraySize(rates); i++)
   {
      if(swingLows[i] != EMPTY_VALUE && 
         currentClose < swingLows[i] && 
         (swingLows[i] - currentLow) >= minDistance)
      {
         if(lastBOSTime != rates[0].time)
         {
            drawBOSStructure(rates[i].time, rates[0].time, swingLows[i], clrRed, "BearishBOS");
            notifyBOS("Bearish BOS", swingLows[i], rates[0].time);
            lastBOSTime = rates[0].time;
         }
         break;
      }
   }
}

// Draw BOS structure
void drawBOSStructure(datetime startTime, datetime endTime, double priceLevel, color clr, string type)
{
   string objName = type + "_" + TimeToString(startTime);
   
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_TREND, 0, startTime, priceLevel, endTime, priceLevel);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, objName, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true);
   }
}

// Send BOS notification
void notifyBOS(string bosType, double level, datetime time)
{
   string message = StringFormat("%s detected on %s %s\nTime: %s\nLevel: %.5f",
                    bosType, _Symbol, EnumToString(_Period),
                    TimeToString(time, TIME_DATE|TIME_MINUTES), level);
   
   Alert(message);
   if(!SendNotification(message))
   {
      Print("Notification failed: ", GetLastError());
   }
}


bool isUptrend(int period)
{
   // Create MA handle
   int maHandle = iMA(_Symbol, _Period, period, 0, MODE_SMA, PRICE_CLOSE);
   
   // Buffer for MA values [0 = current, 1 = previous]
   double maValues[2];
   
   if(CopyBuffer(maHandle, 0, 0, 2, maValues) < 2)
      return false;
      
   return maValues[0] > maValues[1];
}

bool isDowntrend(int period)
{
   int maHandle = iMA(_Symbol, _Period, period, 0, MODE_SMA, PRICE_CLOSE);
   double maValues[2];
   
   if(CopyBuffer(maHandle, 0, 0, 2, maValues) < 2)
      return false;
      
   return maValues[0] < maValues[1];
}

//+------------------------------------------------------------------+
//| Candle Validation                                                |
//+------------------------------------------------------------------+
bool tweezerIsCandleClosed(int index, MqlRates &rates[])
{
   // For live candle (index 0), check if it's new
   if(index == 0) 
      return (rates[0].tick_volume > 0) && (rates[0].time != rates[1].time);
   return true;
}

//+------------------------------------------------------------------+
//| Drawing Functions                                                |
//+------------------------------------------------------------------+
void drawPatternMarker(datetime time, double price, string text, color clr)
{
   // string tag = "Tweezer_" + (string)time;
   string tag = text + " " + (string)time;
   
   if(ObjectCreate(0, tag, OBJ_ARROW_UP, 0, time, price))
   {
      ObjectSetInteger(0, tag, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, tag, OBJPROP_WIDTH, 3);
      ObjectSetString(0, tag, OBJPROP_TEXT, text);
   }
}

//+------------------------------------------------------------------+
//| Notification System                                              |
//+------------------------------------------------------------------+
void sendNotification(string patternType, double price)
{
   string message = StringFormat("%s detected at %s (Price: %s)",
                                patternType,
                                TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
                                DoubleToString(price, _Digits));

   // Platform alert
   Alert(message);
   
   // Push notification (if enabled)
   if(TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
      SendNotification(message);
}

