#include <Trade\Trade.mqh>

#property copyright "Your Name"
#property link      "https://www.example.com"
#property version   "2.00"

// Add constants for object names
#define FAST_MA_OBJ   "EMA21"
#define MIDDLE_MA_OBJ "EMA50"
#define SLOW_MA_OBJ   "SMA200"

input int      stochKPeriod = 14;       // Stochastic %K Period
input int      stochDPeriod = 3;        // Stochastic %D Period
input int      stochSlowing = 3;        // Stochastic Slowing
input double   riskPercentage = 1.0;    // Risk Percentage per Trade
input double   rrRatio = 3.0;           // Risk/Reward Ratio (1:3)
input double   maxLotSize = 100.0;      // Maximum Lot Size
input int      stochOverbought = 80;    // Stochastic Overbought Level
input int      stochOversold = 20;      // Stochastic Oversold Level

input int      fastMaPeriod   = 21;  // Fast MA Period (EMA21)
input int      middleMaPeriod = 50;  // Middle MA Period (EMA50)
input int      slowMaPeriod   = 200; // Slow MA Period (SMA200)
input int      maDrawBars     = 300; // Bars of MA history to draw on chart

input long    minVolume = 0;          // Minimum volume filter (0 = disabled; use 0 for indices/crypto/gold)
input int     profitNotifyMinutes = 15;   // Profit P&L notification interval (minutes)
input bool    enableAlerts             = false; // Enable popup alerts (false = phone only)
input bool    enablePushNotifications  = true;  // Enable mobile push notifications
input bool    enableTrendFilter        = true;  // Only trade patterns aligned with MA trend
int stochasticOscillatorHandler;
int fastMaHandler, middleMaHandler, slowMaHandler;
datetime lastCandleTime;
input int    TrendPeriod     = 5;     // Period for trend detection
input double TolerancePoints = 10;    // Points tolerance for matching highs/lows
input double MinShadowSize   = 0.0002;// Minimum shadow size (adjust for asset)
input color  TopColor        = clrRed;
input color  BottomColor     = clrBlue;
input int      atrPeriod        = 14;       // ATR Period for dynamic SL
input double   atrMultiplier    = 1.5;      // ATR multiplier for SL distance
input double   capitalFraction  = 0.10;     // Real capital fraction (FundedNext: 0.10 = 10%)
input int      magicNumber      = 20260430; // EA magic number
input int      maxOpenTrades    = 3;        // Maximum concurrent open trades
datetime lastPatternTime;
datetime lastProfitNotifyTime = 0;  // Last time a profit notification was sent
int      g_bullishCount    = 0;     // Bullish pattern count on last closed bar
int      g_bearishCount    = 0;     // Bearish pattern count on last closed bar
datetime g_confluenceBar   = 0;     // Bar time of last confluence check
string   g_confluenceNames = "";    // Pattern names in current confluence

int maHandle;
datetime previousBarTime;
CTrade   trade;
int      atrHandle;


//+------------------------------------------------------------------+
//| Unified push-notification dispatcher (phone only by default)    |
//+------------------------------------------------------------------+
void sendAlert(const string msg)
{
   Print(msg);
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(enableAlerts)            Alert(msg);
   if(enablePushNotifications) SendNotification(msg);
}

//+------------------------------------------------------------------+
//| Trend helpers – reuse existing 50-SMA handle (no memory leak)    |
//+------------------------------------------------------------------+
bool isBullishTrend()
{
   double ma[1];
   if(CopyBuffer(maHandle, 0, 1, 1, ma) < 1) return false;
   return iClose(_Symbol, _Period, 1) > ma[0];
}

bool isBearishTrend()
{
   double ma[1];
   if(CopyBuffer(maHandle, 0, 1, 1, ma) < 1) return false;
   return iClose(_Symbol, _Period, 1) < ma[0];
}

//+------------------------------------------------------------------+
//| Human-readable MA alignment string                               |
//+------------------------------------------------------------------+
string getMaAlignment()
{
   double fast[1], mid[1], slow[1];
   if(CopyBuffer(fastMaHandler,   0, 1, 1, fast) < 1) return "N/A";
   if(CopyBuffer(middleMaHandler, 0, 1, 1, mid)  < 1) return "N/A";
   if(CopyBuffer(slowMaHandler,   0, 1, 1, slow) < 1) return "N/A";
   if(fast[0] > mid[0] && mid[0] > slow[0]) return "BULLISH (EMA21>EMA50>SMA200)";
   if(fast[0] < mid[0] && mid[0] < slow[0]) return "BEARISH (EMA21<EMA50<SMA200)";
   return "MIXED";
}

//+------------------------------------------------------------------+
//| Registers a pattern; fires confluence alert at 2+ agreements     |
//+------------------------------------------------------------------+
void registerSignal(const string name, bool isBullish)
{
   datetime bar = iTime(_Symbol, _Period, 1);
   if(bar != g_confluenceBar)
   {
      g_bullishCount    = 0;
      g_bearishCount    = 0;
      g_confluenceNames = "";
      g_confluenceBar   = bar;
   }
   if(isBullish) g_bullishCount++;
   else          g_bearishCount++;
   g_confluenceNames += (g_confluenceNames == "" ? "" : ", ") + name;

   int count = isBullish ? g_bullishCount : g_bearishCount;
   if(count == 3)   // Require 3 signals for higher-quality setups
   {
      string dir = isBullish ? "BULLISH" : "BEARISH";
      sendAlert(StringFormat(
         "[CONFLUENCE] %s %s\n%d %s signals agree:\n%s\nMA: %s",
         _Symbol, EnumToString(_Period), count, dir,
         g_confluenceNames, getMaAlignment()));
      enterTrade(isBullish);
   }
}

//+------------------------------------------------------------------+
//| Trend-reversal detector: EMA21 vs SMA50 crossover               |
//+------------------------------------------------------------------+
void detectTrendReversal()
{
   double fast[], slow[];
   if(CopyBuffer(fastMaHandler, 0, 1, 3, fast) < 3) return;
   if(CopyBuffer(maHandle,      0, 1, 3, slow) < 3) return;
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);

   bool bullReversal = (fast[1] <= slow[1]) && (fast[0] > slow[0]); // EMA21 crosses above SMA50
   bool bearReversal = (fast[1] >= slow[1]) && (fast[0] < slow[0]); // EMA21 crosses below SMA50

   if(bullReversal)
   {
      sendAlert(StringFormat(
         "[TREND REVERSAL] %s %s – Potential BULLISH reversal\n"
         "EMA21 crossed ABOVE SMA50 at %s\nMA: %s",
         _Symbol, EnumToString(_Period),
         TimeToString(iTime(_Symbol,_Period,1), TIME_DATE|TIME_MINUTES),
         getMaAlignment()));
      registerSignal("TrendReversal Bull", true);
   }
   else if(bearReversal)
   {
      sendAlert(StringFormat(
         "[TREND REVERSAL] %s %s – Potential BEARISH reversal\n"
         "EMA21 crossed BELOW SMA50 at %s\nMA: %s",
         _Symbol, EnumToString(_Period),
         TimeToString(iTime(_Symbol,_Period,1), TIME_DATE|TIME_MINUTES),
         getMaAlignment()));
      registerSignal("TrendReversal Bear", false);
   }
}
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
   fastMaHandler   = iMA(_Symbol, PERIOD_CURRENT, fastMaPeriod,   0, MODE_EMA, PRICE_CLOSE); // EMA21
   middleMaHandler = iMA(_Symbol, PERIOD_CURRENT, middleMaPeriod, 0, MODE_EMA, PRICE_CLOSE); // EMA50
   slowMaHandler   = iMA(_Symbol, PERIOD_CURRENT, slowMaPeriod,   0, MODE_SMA, PRICE_CLOSE); // SMA200

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

   // Draw MA history as colored segments
   DrawMAHistory();

   // Create Stochastic handle
   stochasticOscillatorHandler = iStochastic(_Symbol, PERIOD_CURRENT, stochKPeriod, stochDPeriod, stochSlowing, MODE_SMA, STO_LOWHIGH);

   if(stochasticOscillatorHandler == INVALID_HANDLE)
   {
      Print("Error creating Stochastic indicator handle");
      return(INIT_FAILED);
   }

   atrHandle = iATR(_Symbol, PERIOD_CURRENT, atrPeriod);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Error creating ATR handle");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(magicNumber);


   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Draw MA curves as colored OBJ_TREND segments                     |
//+------------------------------------------------------------------+
void DrawMAHistory()
{
   int bars = MathMin(maDrawBars, Bars(_Symbol, _Period) - 1);
   double fast[], mid[], slow[];
   if(CopyBuffer(fastMaHandler,   0, 0, bars + 1, fast)  < bars + 1) return;
   if(CopyBuffer(middleMaHandler, 0, 0, bars + 1, mid)   < bars + 1) return;
   if(CopyBuffer(slowMaHandler,   0, 0, bars + 1, slow)  < bars + 1) return;
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(mid,  true);
   ArraySetAsSeries(slow, true);

   ObjectsDeleteAll(0, "MA_seg_");

   for(int i = 0; i < bars; i++)
   {
      datetime t1 = iTime(_Symbol, _Period, i + 1);
      datetime t2 = iTime(_Symbol, _Period, i);
      DrawMASeg("MA_seg_F" + IntegerToString(i), t1, fast[i+1], t2, fast[i], clrAqua, 2);
      DrawMASeg("MA_seg_M" + IntegerToString(i), t1, mid[i+1],  t2, mid[i],  clrGold, 2);
      DrawMASeg("MA_seg_S" + IntegerToString(i), t1, slow[i+1], t2, slow[i], clrRed,  2);
   }
   ChartRedraw(0);
}

void DrawMASeg(const string name, datetime t1, double p1,
               datetime t2, double p2, color clr, int width)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   else
   {
      ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
      ObjectSetDouble( 0, name, OBJPROP_PRICE, 0, p1);
      ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
      ObjectSetDouble( 0, name, OBJPROP_PRICE, 1, p2);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,     width);
   ObjectSetInteger(0, name, OBJPROP_STYLE,     STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK,      true);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    checkProfitNotification();  // P&L update every N minutes while in trade
    checkBreakEven();           // Move SL to break-even when 1R in profit
    updateDashboard();          // Refresh on-chart info panel
    detectTrendReversal();      // Check for EMA21/SMA50 crossover reversal
    datetime currentBarTime = iTime(_Symbol, _Period, 0);

    // Check if a new bar has formed
    if(currentBarTime != previousBarTime)
    {
        priceCrosses50MovingAverageDetector(maHandle); // Call the detector
        DrawMAHistory();                               // Redraw colored MA lines
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

   if(BarsCalculated(fastMaHandler)   < slowMaPeriod ||
      BarsCalculated(middleMaHandler) < slowMaPeriod ||
      BarsCalculated(slowMaHandler)   < slowMaPeriod)
      return;

   double fastMa[], middleMa[], slowMa[];
   CopyBuffer(fastMaHandler,   0, 0, 3, fastMa);   // EMA21
   CopyBuffer(middleMaHandler, 0, 0, 3, middleMa); // EMA50
   CopyBuffer(slowMaHandler,   0, 0, 3, slowMa);   // SMA200

   ArraySetAsSeries(fastMa, true);
   ArraySetAsSeries(middleMa, true);
   ArraySetAsSeries(slowMa, true);




   if(BarsCalculated(stochasticOscillatorHandler) < stochKPeriod + stochDPeriod + stochSlowing)
      return;

   double K[], D[];
   CopyBuffer(stochasticOscillatorHandler, 0, 0, 3, K); // %K values
   CopyBuffer(stochasticOscillatorHandler, 1, 0, 3, D); // %D values

   ArraySetAsSeries(K, true);
   ArraySetAsSeries(D, true);

   // ---- EMA21 vs EMA50 crossover alerts ----
   bool bullishCross = (fastMa[0] > middleMa[0]) && (fastMa[1] <= middleMa[1]);
   bool bearishCross = (fastMa[0] < middleMa[0]) && (fastMa[1] >= middleMa[1]);
   if(bullishCross)
   {
      sendAlert(StringFormat("[MA Cross] %s %s – EMA21 crossed ABOVE EMA50\nMA: %s",
                             _Symbol, EnumToString(_Period), getMaAlignment()));
      registerSignal("MA Bull Cross", true);
   }
   if(bearishCross)
   {
      sendAlert(StringFormat("[MA Cross] %s %s – EMA21 crossed BELOW EMA50\nMA: %s",
                             _Symbol, EnumToString(_Period), getMaAlignment()));
      registerSignal("MA Bear Cross", false);
   }

   // ---- Stochastic overbought / oversold alerts ----
   bool stochBuy  = (K[0] > stochOversold  && K[1] <= stochOversold);
   bool stochSell = (K[0] < stochOverbought && K[1] >= stochOverbought);
   if(stochBuy)
   {
      sendAlert(StringFormat("[Stoch] %s %s – %%K exiting oversold (%d) K=%.1f\nMA: %s",
                             _Symbol, EnumToString(_Period), stochOversold, K[0], getMaAlignment()));
      registerSignal("Stoch Bull", true);
   }
   if(stochSell)
   {
      sendAlert(StringFormat("[Stoch] %s %s – %%K exiting overbought (%d) K=%.1f\nMA: %s",
                             _Symbol, EnumToString(_Period), stochOverbought, K[0], getMaAlignment()));
      registerSignal("Stoch Bear", false);
   }
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



//+------------------------------------------------------------------+
//| Sends profit P&L notification every N minutes while in trade     |
//+------------------------------------------------------------------+
void checkProfitNotification()
{
   if(!PositionSelect(_Symbol)) return;

   datetime currentTime = TimeCurrent();
   if((int)(currentTime - lastProfitNotifyTime) < profitNotifyMinutes * 60) return;

   double   profit       = PositionGetDouble(POSITION_PROFIT);
   double   swap         = PositionGetDouble(POSITION_SWAP);
   double   totalProfit  = profit + swap;
   long     posType      = PositionGetInteger(POSITION_TYPE);
   double   openPrice    = PositionGetDouble(POSITION_PRICE_OPEN);
   double   lots         = PositionGetDouble(POSITION_VOLUME);
   double   sl           = PositionGetDouble(POSITION_SL);
   double   tp           = PositionGetDouble(POSITION_TP);
   double   currentPrice = (posType == POSITION_TYPE_BUY)
                           ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                           : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   string direction = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   string currency  = AccountInfoString(ACCOUNT_CURRENCY);
   string sign      = (totalProfit >= 0) ? "+" : "";

   string message = StringFormat(
      "[P&L Update] %s %s %.2f lots\n"
      "Open: %s | Now: %s\n"
      "SL: %s | TP: %s\n"
      "Profit: %s%.2f %s (incl. swap)",
      _Symbol, direction, lots,
      DoubleToString(openPrice, _Digits),
      DoubleToString(currentPrice, _Digits),
      (sl > 0) ? DoubleToString(sl, _Digits) : "None",
      (tp > 0) ? DoubleToString(tp, _Digits) : "None",
      sign, totalProfit, currency
   );

   sendAlert(message);
   lastProfitNotifyTime = currentTime;
}

//+------------------------------------------------------------------+
//| Updates the on-chart information dashboard via Comment()         |
//+------------------------------------------------------------------+
void updateDashboard()
{
   string dash  = "============ EA Dashboard ============\n";
   dash += StringFormat("Symbol : %s  |  TF : %s\n", _Symbol, EnumToString(_Period));
   dash += StringFormat("Equity : %.2f %s\n",
                        AccountInfoDouble(ACCOUNT_EQUITY),
                        AccountInfoString(ACCOUNT_CURRENCY));

   if(PositionSelect(_Symbol))
   {
      long   posType    = PositionGetInteger(POSITION_TYPE);
      double profit     = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      double lots       = PositionGetDouble(POSITION_VOLUME);
      double openPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl         = PositionGetDouble(POSITION_SL);
      double tp         = PositionGetDouble(POSITION_TP);
      string dir        = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      string sign       = (profit >= 0) ? "+" : "";

      dash += "--- Open Position ---\n";
      dash += StringFormat("Dir   : %s  |  Lots : %.2f\n", dir, lots);
      dash += StringFormat("Open  : %s\n", DoubleToString(openPrice, _Digits));
      dash += StringFormat("SL    : %s  |  TP   : %s\n",
                           (sl > 0) ? DoubleToString(sl, _Digits) : "None",
                           (tp > 0) ? DoubleToString(tp, _Digits) : "None");
      dash += StringFormat("P&L   : %s%.2f %s\n",
                           sign, profit, AccountInfoString(ACCOUNT_CURRENCY));

      int secsLeft = profitNotifyMinutes * 60 - (int)(TimeCurrent() - lastProfitNotifyTime);
      if(secsLeft > 0)
         dash += StringFormat("Next P&L alert in : %d min %d sec\n", secsLeft / 60, secsLeft % 60);
      else
         dash += "P&L alert : sending now...\n";
   }
   else
   {
      dash += "--- No open position ---\n";
   }

   dash += "--- MA Alignment ---\n";
   dash += getMaAlignment() + "\n";
   dash += "--- Patterns (Last Bar) ---\n";
   if(g_bullishCount > 0)
      dash += StringFormat("Bull x%d: %s\n", g_bullishCount, g_confluenceNames);
   if(g_bearishCount > 0)
      dash += StringFormat("Bear x%d: %s\n", g_bearishCount, g_confluenceNames);
   if(g_bullishCount == 0 && g_bearishCount == 0)
      dash += "None on last bar\n";

   Comment(dash);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");  // Clear on-chart dashboard
   ObjectsDeleteAll(0, "Tweezer*");
   ObjectsDeleteAll(0, "MA_seg_"); // Remove all MA segment objects

   IndicatorRelease(fastMaHandler);
   IndicatorRelease(middleMaHandler);
   IndicatorRelease(slowMaHandler);
   IndicatorRelease(stochasticOscillatorHandler);
   IndicatorRelease(maHandle);
   IndicatorRelease(atrHandle);
}



//------------------------------------------------------------------
// price crosses 50 Moving Average Detector
//------------------------------------------------------------------
void priceCrosses50MovingAverageDetector(int pHandle)
{
    double maValues[];
    ArraySetAsSeries(maValues, true);
    if(CopyBuffer(pHandle, 0, 0, 2, maValues) != 2)
    {
        Print("Error copying MA values");
        return;
    }

    double closePrices[];
    ArraySetAsSeries(closePrices, true);
    if(CopyClose(_Symbol, _Period, 0, 2, closePrices) != 2)
    {
        Print("Error copying closing prices");
        return;
    }

    // Price crosses above SMA50
    if(closePrices[1] < maValues[1] && closePrices[0] > maValues[0])
    {
        sendAlert(StringFormat("[Price x SMA50] %s %s – Price crossed ABOVE SMA50\nMA: %s",
                  _Symbol, EnumToString(_Period), getMaAlignment()));
    }
    // Price crosses below SMA50
    if(closePrices[1] > maValues[1] && closePrices[0] < maValues[0])
    {
        sendAlert(StringFormat("[Price x SMA50] %s %s – Price crossed BELOW SMA50\nMA: %s",
                  _Symbol, EnumToString(_Period), getMaAlignment()));
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

        // Bullish FVG: standard ICT – gap between c3.high (oldest) and c1.low (newest)
        if(c1.low > c3.high)  // Unfilled price imbalance upward
        {
            double fvgTop    = c1.low;   // Upper edge of FVG zone
            double fvgBottom = c3.high;  // Lower edge of FVG zone

            if(isValidFVG(fvgTop, fvgBottom) &&
               lastBullishFVG != c3.time)
            {
                drawFVG(c3.time, c2.time, fvgTop, fvgBottom, clrDodgerBlue, "Bullish");
                sendFVGNotification("Bullish", fvgTop, fvgBottom, c3.time);
                lastBullishFVG = c3.time;
            }
        }

        // Bearish FVG: standard ICT – gap between c1.high (newest) and c3.low (oldest)
        if(c1.high < c3.low)  // Unfilled price imbalance downward
        {
            double fvgTop    = c3.low;   // Upper edge of FVG zone
            double fvgBottom = c1.high;  // Lower edge of FVG zone

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
    double atr = getATRValue();
    if(atr <= 0) return false;
    return (MathAbs(top - bottom) >= atr * 0.05); // FVG must be >= 5% of ATR (works on any asset)
}

void drawFVG(datetime startTime, datetime endTime, double top, double bottom, color clr, string type)
{
    string objName = type + "FVG_" + TimeToString(startTime, TIME_DATE|TIME_MINUTES);

    if(ObjectFind(0, objName) >= 0) return; // Avoid duplicates

    color transparentClr = (color)ColorToARGB(clr, 25); // 10% opacity

    ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, top, endTime, bottom);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, transparentClr);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, transparentClr);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    ObjectSetInteger(0, objName, OBJPROP_FILL, true);
}

void sendFVGNotification(string type, double top, double bottom, datetime time)
{
    bool   isBull   = (type == "Bullish");
    if(enableTrendFilter && isBull  && !isBullishTrend()) return;
    if(enableTrendFilter && !isBull && !isBearishTrend()) return;
    double atr  = getATRValue();
    double pct  = (atr > 0) ? MathAbs(top - bottom) / atr * 100.0 : 0;
    string message = StringFormat(
       "[FVG] %s %s – %s Fair Value Gap\nZone: %s – %s  (%.1f%% ATR)\nMA: %s",
       _Symbol, EnumToString(_Period), type,
       DoubleToString(bottom,_Digits), DoubleToString(top,_Digits),
       pct, getMaAlignment());
    sendAlert(message);
    registerSignal(type + " FVG", isBull);
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
        sendAlert(StringFormat("[Pattern] %s %s – Three White Soldiers\nMA: %s",
                  _Symbol, EnumToString(_Period), getMaAlignment()));
        registerSignal("Three White Soldiers", true);
    }

    if(blackSoldiers)
    {
        datetime startTime = timePrices[OLDEST];
        datetime endTime = timePrices[NEWEST] + PeriodSeconds(_Period);
        DrawSoldiersPatternBox("TBS_Box", startTime, endTime,
                      lowPrices[NEWEST], highPrices[OLDEST], clrIndianRed);
        sendAlert(StringFormat("[Pattern] %s %s – Three Black Soldiers\nMA: %s",
                  _Symbol, EnumToString(_Period), getMaAlignment()));
        registerSignal("Three Black Soldiers", false);
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
         datetime currentCandleCloseTime = rates[current].time + PeriodSeconds(_Period);
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
   bool isBull = (StringFind(patternType, "Bullish") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[Pattern] %s %s – %s Engulfing at %s\nMA: %s",
             symbol, EnumToString(_Period), patternType,
             TimeToString(dt, TIME_DATE|TIME_MINUTES), getMaAlignment()));
   registerSignal(patternType + " Engulfing", isBull);
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
         color patternColor = isBullishHarami ? (color)ColorToARGB(clrDodgerBlue, 255) :
                              (color)ColorToARGB(clrOrangeRed, 255);

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
   MqlRates candles[];
   ArrayResize(candles, 2);
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
   double atrVal = getATRValue();
   double minMove = (atrVal > 0) ? atrVal * 0.5 : 100 * _Point; // ATR-based – adapts to any asset
   double consolidationFactor = 0.4;

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
         color  zoneColor   = demandZone ? clrDarkGreen : clrDarkRed;
         // Zone = body of the impulse (base) candle
         double zoneTop    = MathMax(prev3.open, prev3.close);
         double zoneBottom = MathMin(prev3.open, prev3.close);

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

   static datetime lastBullishBOSTime = 0;  // Prevents bearish from blocking bullish
   static datetime lastBearishBOSTime = 0;
   const int swingLength = 3;
   double    minDistance = MathMax(getATRValue() * 0.5, 10 * _Point); // ATR-based, any asset

   double swingHighs[], swingLows[];
   findSwings(rates, swingLength, swingHighs, swingLows);

   checkBullishBOS(rates, swingHighs, lastBullishBOSTime, minDistance);
   checkBearishBOS(rates, swingLows,  lastBearishBOSTime, minDistance);
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

void notifyPattern(string patternType, datetime time)
{
   bool isBull = (StringFind(patternType,"Morning")>=0 || StringFind(patternType,"Dragonfly")>=0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[Pattern] %s %s – %s at %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             TimeToString(time, TIME_DATE|TIME_MINUTES), getMaAlignment()));
   registerSignal(patternType, isBull);
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
   bool isBull = (StringFind(patternType, "Bullish") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[Pattern] %s %s – %s at %s\nLevel: %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             TimeToString(time, TIME_DATE|TIME_MINUTES),
             DoubleToString(triggerPrice, _Digits), getMaAlignment()));
   registerSignal(patternType, isBull);
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
   bool isBull = (StringFind(patternType, "Bottom") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[Pattern] %s %s – %s at %s\nPrice: %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             TimeToString(time, TIME_DATE|TIME_MINUTES),
             DoubleToString(price, _Digits), getMaAlignment()));
   registerSignal(patternType, isBull);
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
   bool isBull = (patternType == "Hammer");
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[Pattern] %s %s – %s at %s\nPrice: %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             TimeToString(time, TIME_DATE|TIME_MINUTES),
             DoubleToString(price, _Digits), getMaAlignment()));
   registerSignal(patternType, isBull);
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
   bool isBull = (StringFind(patternType, "Bullish") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[OB] %s %s – %s at %s\nZone: %s – %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             TimeToString(time, TIME_DATE|TIME_MINUTES),
             DoubleToString(low,_Digits), DoubleToString(high,_Digits), getMaAlignment()));
   registerSignal(patternType, isBull);
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
   bool isBull = (patternType == "DemandZone");
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[S/D] %s %s – %s at %s\nZone: %s – %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             TimeToString(time, TIME_DATE|TIME_MINUTES),
             DoubleToString(bottom,_Digits), DoubleToString(top,_Digits), getMaAlignment()));
   registerSignal(patternType, isBull);
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
   bool isBull = (StringFind(bosType, "Bullish") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[BOS] %s %s – %s at %s\nLevel: %s\nMA: %s",
             _Symbol, EnumToString(_Period), bosType,
             TimeToString(time, TIME_DATE|TIME_MINUTES),
             DoubleToString(level, _Digits), getMaAlignment()));
   registerSignal(bosType, isBull);
}


// Reuse global maHandle (SMA50) – zero memory leak
bool isUptrend(int period)   { return isBullishTrend(); }
bool isDowntrend(int period) { return isBearishTrend(); }

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
   bool isBull = (StringFind(patternType, "Bottom") >= 0);
   sendAlert(StringFormat("[Pattern] %s %s – %s\nPrice: %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             DoubleToString(price, _Digits), getMaAlignment()));
   registerSignal(patternType, isBull);
}

//+------------------------------------------------------------------+
//| Return ATR value from last closed bar                            |
//+------------------------------------------------------------------+
double getATRValue()
{
   double atr[1];
   if(CopyBuffer(atrHandle, 0, 1, 1, atr) < 1) return 0;
   return atr[0];
}

//+------------------------------------------------------------------+
//| Lot size: risk 1% of real capital (10% of account equity)        |
//+------------------------------------------------------------------+
double calculateLotSize(double slDistance)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(slDistance <= 0) return minLot;

   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double realCap    = equity * capitalFraction;
   double riskAmt    = realCap * (riskPercentage / 100.0);

   // Dynamic point value – recalculated per trade so it works for any asset
   double tickVal    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz     = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double ptVal      = (tickSz > 0) ? tickVal / tickSz * _Point : 0;
   double slPoints   = slDistance / _Point;
   double riskPerLot = slPoints * ptVal;
   if(riskPerLot <= 0) return minLot;

   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot  = MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), maxLotSize);

   double lots = riskAmt / riskPerLot;
   lots = MathFloor(lots / lotStep) * lotStep;

   if(lots < minLot)
   {
      double actualRisk = minLot * riskPerLot;
      Print(StringFormat("[LOT] Calculated %.2f lots < min %.2f – using minimum. "
                         "Actual risk: %.2f %s (%.2f%% of real capital)",
                         lots, minLot, actualRisk,
                         AccountInfoString(ACCOUNT_CURRENCY),
                         actualRisk / (AccountInfoDouble(ACCOUNT_EQUITY) * capitalFraction) * 100.0));
      return minLot;
   }

   return MathMin(maxLot, lots);
}

//+------------------------------------------------------------------+
//| Count open trades opened by this EA (by magic number)            |
//+------------------------------------------------------------------+
int countOpenTrades()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0 &&
         PositionGetInteger(POSITION_MAGIC) == magicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Enter trade on high-probability confluence (2+ signals)          |
//+------------------------------------------------------------------+
void enterTrade(bool isBuy)
{
   if(PositionSelect(_Symbol)) return;   // Already in this symbol
   if(countOpenTrades() >= maxOpenTrades) return; // Global cap reached

   double atr = getATRValue();
   if(atr <= 0) return;

   // Enforce broker minimum stop distance (critical for indices and gold)
   long   stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist    = (stopsLevel + 5) * _Point;
   double slDist     = MathMax(atr * atrMultiplier, minDist);
   double lots       = calculateLotSize(slDist);
   double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(isBuy)
   {
      double sl = NormalizeDouble(ask - slDist, _Digits);
      double tp = NormalizeDouble(ask + slDist * rrRatio, _Digits);
      if(sl <= 0 || tp <= sl) return;
      if(trade.Buy(lots, _Symbol, ask, sl, tp, "Confluence Buy"))
         sendAlert(StringFormat("[TRADE OPEN] BUY %.2f lots @ %s  SL:%s  TP:%s  Risk:%.2f %s",
                                lots, DoubleToString(ask, _Digits),
                                DoubleToString(sl, _Digits), DoubleToString(tp, _Digits),
                                AccountInfoDouble(ACCOUNT_EQUITY) * capitalFraction * (riskPercentage/100.0),
                                AccountInfoString(ACCOUNT_CURRENCY)));
   }
   else
   {
      double sl = NormalizeDouble(bid + slDist, _Digits);
      double tp = NormalizeDouble(bid - slDist * rrRatio, _Digits);
      if(tp <= 0 || sl <= tp) return;
      if(trade.Sell(lots, _Symbol, bid, sl, tp, "Confluence Sell"))
         sendAlert(StringFormat("[TRADE OPEN] SELL %.2f lots @ %s  SL:%s  TP:%s  Risk:%.2f %s",
                                lots, DoubleToString(bid, _Digits),
                                DoubleToString(sl, _Digits), DoubleToString(tp, _Digits),
                                AccountInfoDouble(ACCOUNT_EQUITY) * capitalFraction * (riskPercentage/100.0),
                                AccountInfoString(ACCOUNT_CURRENCY)));
   }
}

//+------------------------------------------------------------------+
//| Move SL to break-even once price travels 1R in profit            |
//+------------------------------------------------------------------+
void checkBreakEven()
{
   if(!PositionSelect(_Symbol)) return;

   long   posType   = PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   if(currentSL <= 0) return;

   double slDist   = MathAbs(openPrice - currentSL);
   if(slDist <= 0) return;

   double beBuffer = MathMax(getATRValue() * 0.01, 2 * _Point); // ≥1% ATR, works any asset

   if(posType == POSITION_TYPE_BUY)
   {
      double price   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double beLevel = NormalizeDouble(openPrice + beBuffer, _Digits);
      if(price >= openPrice + slDist && currentSL < beLevel)
      {
         if(trade.PositionModify(_Symbol, beLevel, currentTP))
            sendAlert(StringFormat("[BREAK-EVEN] %s BUY SL moved to %.5f", _Symbol, beLevel));
      }
   }
   else if(posType == POSITION_TYPE_SELL)
   {
      double price   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double beLevel = NormalizeDouble(openPrice - beBuffer, _Digits);
      if(price <= openPrice - slDist && currentSL > beLevel)
      {
         if(trade.PositionModify(_Symbol, beLevel, currentTP))
            sendAlert(StringFormat("[BREAK-EVEN] %s SELL SL moved to %.5f", _Symbol, beLevel));
      }
   }
}