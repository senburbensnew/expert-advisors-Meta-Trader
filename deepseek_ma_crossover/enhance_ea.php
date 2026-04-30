<?php
$fp = 'c:\Users\rubens\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\deepseek_ma_crossover\deepseek_ultimate_expert_advisor.mq5';

// Read UTF-16 LE file (strip BOM and convert to UTF-8 for processing)
$raw  = file_get_contents($fp);
$utf8 = mb_convert_encoding($raw, 'UTF-8', 'UTF-16');
// Normalize all line endings to LF
$c = str_replace(["\r\n", "\r"], "\n", $utf8);
// Strip trailing whitespace from each line (MetaEditor adds trailing spaces)
$c = preg_replace('/[ \t]+\n/', "\n", $c);

$orig_len = strlen($c);
$fails = [];

function R(string &$c, string $old, string $new, string $label): void {
    global $fails;
    if (strpos($c, $old) === false) { $fails[] = "FAIL [$label]"; return; }
    $c = str_replace($old, $new, $c);
    echo "OK   [$label]\n";
}

// ============================================================
// 1. Remove dead global lastCurrentPrice
// ============================================================
R($c,
    "double lastCurrentPrice = 0; // Variable to store the last current price\n",
    '',
    'Remove lastCurrentPrice'
);

// ============================================================
// 2. Alert/Push inputs – phone only by default
// ============================================================
R($c,
    'input int     profitNotifyMinutes = 15;   // Profit P&L notification interval (minutes)',
    'input int     profitNotifyMinutes = 15;   // Profit P&L notification interval (minutes)
input bool    enableAlerts             = false; // Enable popup alerts (false = phone only)
input bool    enablePushNotifications  = true;  // Enable mobile push notifications
input bool    enableTrendFilter        = false; // Only show patterns aligned with MA trend',
    'Alert/Push inputs'
);

// ============================================================
// 3. Confluence + reversal globals
// ============================================================
R($c,
    'datetime lastProfitNotifyTime = 0;  // Last time a profit notification was sent',
    'datetime lastProfitNotifyTime = 0;  // Last time a profit notification was sent
int      g_bullishCount    = 0;     // Bullish pattern count on last closed bar
int      g_bearishCount    = 0;     // Bearish pattern count on last closed bar
datetime g_confluenceBar   = 0;     // Bar time of last confluence check
string   g_confluenceNames = "";    // Pattern names in current confluence',
    'Confluence globals'
);

// ============================================================
// 4. MA simplification: remove EMA8, keep EMA21/EMA50/SMA200
// ============================================================
R($c,
    'input int      fastMaPeriod = 8;       // Fast MA Period (EMA)
input int      twentyoneMaPeriod = 21;    // Middle MA Period (EMA)
input int      middleMaPeriod = 50;    // Middle MA Period (EMA)
input int      slowMaPeriod = 200;     // Slow MA Period (SMA)',
    'input int      fastMaPeriod   = 21;  // Fast MA Period (EMA21)
input int      middleMaPeriod = 50;  // Middle MA Period (EMA50)
input int      slowMaPeriod   = 200; // Slow MA Period (SMA200)',
    'MA inputs'
);

R($c,
    'int fastMaHandler, twentyoneMaHandler, middleMaHandler, slowMaHandler;',
    'int fastMaHandler, middleMaHandler, slowMaHandler;',
    'Remove twentyoneMaHandler declaration'
);

R($c,
    '#define FAST_MA_OBJ "FastMA"
#define twentyoneMA_MA_OBJ "twentyoneMA"
#define MIDDLE_MA_OBJ "MiddleMA"
#define SLOW_MA_OBJ "SlowMA"',
    '#define FAST_MA_OBJ   "EMA21"
#define MIDDLE_MA_OBJ "EMA50"
#define SLOW_MA_OBJ   "SMA200"',
    'MA defines'
);

R($c,
    '   fastMaHandler = iMA(_Symbol, PERIOD_CURRENT, fastMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   twentyoneMaHandler = iMA(_Symbol, PERIOD_CURRENT, twentyoneMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   middleMaHandler = iMA(_Symbol, PERIOD_CURRENT, middleMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowMaHandler = iMA(_Symbol, PERIOD_CURRENT, slowMaPeriod, 0, MODE_SMA, PRICE_CLOSE);',
    '   fastMaHandler   = iMA(_Symbol, PERIOD_CURRENT, fastMaPeriod,   0, MODE_EMA, PRICE_CLOSE); // EMA21
   middleMaHandler = iMA(_Symbol, PERIOD_CURRENT, middleMaPeriod, 0, MODE_EMA, PRICE_CLOSE); // EMA50
   slowMaHandler   = iMA(_Symbol, PERIOD_CURRENT, slowMaPeriod,   0, MODE_SMA, PRICE_CLOSE); // SMA200',
    'MA handle creation'
);

R($c,
    '   CreateMaObject(twentyoneMA_MA_OBJ, clrRed);    // Fast MA (Blue)
   CreateMaObject(MIDDLE_MA_OBJ, clrBlue); // Middle MA (Green)
   CreateMaObject(SLOW_MA_OBJ, clrWhite);     // Slow MA (Red)',
    '   CreateMaObject(FAST_MA_OBJ,   clrDodgerBlue);  // EMA21
   CreateMaObject(MIDDLE_MA_OBJ, clrOrange);      // EMA50
   CreateMaObject(SLOW_MA_OBJ,   clrWhite);       // SMA200',
    'CreateMaObject'
);

R($c,
    '   // ChartIndicatorAdd(ChartID(), 0, fastMaHandler);
   ChartIndicatorAdd(ChartID(), 0, twentyoneMaHandler);
   ChartIndicatorAdd(ChartID(), 0, middleMaHandler);
   ChartIndicatorAdd(ChartID(), 0, slowMaHandler);
   // ChartIndicatorAdd(ChartID(), 1, stochasticOscillatorHandler);',
    '   ChartIndicatorAdd(ChartID(), 0, fastMaHandler);    // EMA21
   ChartIndicatorAdd(ChartID(), 0, middleMaHandler);  // EMA50
   ChartIndicatorAdd(ChartID(), 0, slowMaHandler);    // SMA200',
    'ChartIndicatorAdd'
);

R($c,
    '   IndicatorRelease(fastMaHandler);
   IndicatorRelease(middleMaHandler);
   IndicatorRelease(slowMaHandler);
   IndicatorRelease(stochasticOscillatorHandler);

       if(maHandle != INVALID_HANDLE)
    {
        IndicatorRelease(maHandle); // Release the handle
    }',
    '   IndicatorRelease(fastMaHandler);
   IndicatorRelease(middleMaHandler);
   IndicatorRelease(slowMaHandler);
   IndicatorRelease(stochasticOscillatorHandler);
   IndicatorRelease(maHandle);',
    'IndicatorRelease'
);

R($c,
    '   if(BarsCalculated(fastMaHandler) < slowMaPeriod ||
      BarsCalculated(middleMaHandler) < slowMaPeriod ||
      BarsCalculated(slowMaHandler) < slowMaPeriod)
      return;',
    '   if(BarsCalculated(fastMaHandler)   < slowMaPeriod ||
      BarsCalculated(middleMaHandler) < slowMaPeriod ||
      BarsCalculated(slowMaHandler)   < slowMaPeriod)
      return;',
    'BarsCalculated'
);

R($c,
    '   double fastMa[], middleMa[], slowMa[];
   CopyBuffer(fastMaHandler, 0, 0, 3, fastMa);
   CopyBuffer(middleMaHandler, 0, 0, 3, middleMa);
   CopyBuffer(slowMaHandler, 0, 0, 3, slowMa);',
    '   double fastMa[], middleMa[], slowMa[];
   CopyBuffer(fastMaHandler,   0, 0, 3, fastMa);   // EMA21
   CopyBuffer(middleMaHandler, 0, 0, 3, middleMa); // EMA50
   CopyBuffer(slowMaHandler,   0, 0, 3, slowMa);   // SMA200',
    'CopyBuffer'
);

R($c,
    '   // Update MA lines on the chart
   ObjectSetDouble(0, FAST_MA_OBJ, OBJPROP_PRICE, fastMa[0]);
   ObjectSetDouble(0, MIDDLE_MA_OBJ, OBJPROP_PRICE, middleMa[0]);
   ObjectSetDouble(0, SLOW_MA_OBJ, OBJPROP_PRICE, slowMa[0]);',
    '   // Update MA lines on the chart
   ObjectSetDouble(0, FAST_MA_OBJ,   OBJPROP_PRICE, fastMa[0]);   // EMA21
   ObjectSetDouble(0, MIDDLE_MA_OBJ, OBJPROP_PRICE, middleMa[0]); // EMA50
   ObjectSetDouble(0, SLOW_MA_OBJ,   OBJPROP_PRICE, slowMa[0]);   // SMA200',
    'UpdateMA lines'
);

// ============================================================
// 5. Insert helper functions before OnInit
// ============================================================
$helpers = <<<'MQL5'
//+------------------------------------------------------------------+
//| Unified push-notification dispatcher (phone only by default)    |
//+------------------------------------------------------------------+
void sendAlert(const string msg)
{
   Print(msg);
   if(MQL5InfoInteger(MQL5_TESTING)) return;
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
   if(count == 2)
   {
      string dir = isBullish ? "BULLISH" : "BEARISH";
      sendAlert(StringFormat(
         "[CONFLUENCE] %s %s\n%d %s signals agree:\n%s\nMA: %s",
         _Symbol, EnumToString(_Period), count, dir,
         g_confluenceNames, getMaAlignment()));
   }
}

//+------------------------------------------------------------------+
//| Trend-reversal detector: EMA21 vs SMA50 crossover               |
//+------------------------------------------------------------------+
void detectTrendReversal()
{
   double fast[3], slow[3];
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

MQL5;

R($c,
    "//+------------------------------------------------------------------+\n//| Expert initialization function",
    $helpers . "//+------------------------------------------------------------------+\n//| Expert initialization function",
    'Insert helper functions'
);

// ============================================================
// 6. Add detectTrendReversal call in OnTick
// ============================================================
R($c,
    "void OnTick()\n{\n    checkProfitNotification();  // P&L update every N minutes while in trade\n    updateDashboard();          // Refresh on-chart info panel\n",
    "void OnTick()\n{\n    checkProfitNotification();  // P&L update every N minutes while in trade\n    updateDashboard();          // Refresh on-chart info panel\n    detectTrendReversal();      // Check for EMA21/SMA50 crossover reversal\n",
    'Add detectTrendReversal in OnTick'
);

// ============================================================
// 7. Replace dead end-of-OnTick with live MA+Stoch signals
// ============================================================
R($c,
    '   // Check for Stochastic crossover signals
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
   double brokerMaxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
}',
    '   // ---- EMA21 vs EMA50 crossover alerts ----
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
}',
    'Replace dead OnTick end'
);

// ============================================================
// 8. Fix FVG (standard ICT single-gap logic)
// ============================================================
R($c,
    '        // Bullish FVG (Bearish c3 -> Bullish c1)
        if(c3.close < c3.open &&    // Bearish candle
           c1.close > c1.open &&    // Bullish candle
           c2.low > c3.high &&      // Gap between c3 and c2
           c1.low > c2.high)        // Gap remains unfilled
        {
            double fvgTop = c3.high;
            double fvgBottom = c2.low;',
    '        // Bullish FVG: standard ICT – gap between c3.high (oldest) and c1.low (newest)
        if(c1.low > c3.high)  // Unfilled price imbalance upward
        {
            double fvgTop    = c1.low;   // Upper edge of FVG zone
            double fvgBottom = c3.high;  // Lower edge of FVG zone',
    'Fix Bullish FVG'
);

R($c,
    '        // Bearish FVG (Bullish c3 -> Bearish c1)
        if(c3.close > c3.open &&    // Bullish candle
           c1.close < c1.open &&    // Bearish candle
           c2.high < c3.low &&      // Gap between c3 and c2
           c1.high < c2.low)        // Gap remains unfilled
        {
            double fvgTop = c2.high;
            double fvgBottom = c3.low;',
    '        // Bearish FVG: standard ICT – gap between c1.high (newest) and c3.low (oldest)
        if(c1.high < c3.low)  // Unfilled price imbalance downward
        {
            double fvgTop    = c3.low;   // Upper edge of FVG zone
            double fvgBottom = c1.high;  // Lower edge of FVG zone',
    'Fix Bearish FVG'
);

// ============================================================
// 9. Fix FVG notification
// ============================================================
R($c,
    'void sendFVGNotification(string type, double top, double bottom, datetime time)
{
    string timeframe = EnumToString(_Period);
    double fvgSizePips = MathAbs(top - bottom) / ((_Digits == 3 || _Digits ==5) ? 0.001 : 0.0001);

    string message = StringFormat("%s FVG detected on %s %s\nTime: %s\nSize: %.1f pips",
                     type, _Symbol, timeframe, TimeToString(time), fvgSizePips);

    Alert(message);
    SendNotification(message); // Requires MT5 notifications enabled
}',
    'void sendFVGNotification(string type, double top, double bottom, datetime time)
{
    double pipDiv   = (_Digits == 3 || _Digits == 5) ? 0.001 : 0.0001;
    double sizePips = MathAbs(top - bottom) / pipDiv;
    bool   isBull   = (type == "Bullish");
    if(enableTrendFilter && isBull  && !isBullishTrend()) return;
    if(enableTrendFilter && !isBull && !isBearishTrend()) return;
    string message = StringFormat(
       "[FVG] %s %s – %s Fair Value Gap\nZone: %s – %s  %.1f pips\nMA: %s",
       _Symbol, EnumToString(_Period), type,
       DoubleToString(bottom,_Digits), DoubleToString(top,_Digits),
       sizePips, getMaAlignment());
    sendAlert(message);
    registerSignal(type + " FVG", isBull);
}',
    'Fix FVG notification'
);

// ============================================================
// 10. Fix isUptrend/isDowntrend (memory leak – new handle per tick)
// ============================================================
R($c,
    'bool isUptrend(int period)
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
}',
    '// Reuse global maHandle (SMA50) – zero memory leak
bool isUptrend(int period)   { return isBullishTrend(); }
bool isDowntrend(int period) { return isBearishTrend(); }',
    'Fix isUptrend/isDowntrend memory leak'
);

// ============================================================
// 11. Fix BOS: separate lastBOSTime per direction
// ============================================================
R($c,
    '   static datetime lastBOSTime = 0;
   const int swingLength = 3; // Number of candles for swing detection
   const double minDistance = 50 * _Point * 10; // 50 pips minimum structure distance

   // Find latest swing highs and lows
   double swingHighs[], swingLows[];
   findSwings(rates, swingLength, swingHighs, swingLows);

   // Check for structure breaks
   checkBullishBOS(rates, swingHighs, lastBOSTime, minDistance);
   checkBearishBOS(rates, swingLows, lastBOSTime, minDistance);',
    '   static datetime lastBullishBOSTime = 0;  // Prevents bearish from blocking bullish
   static datetime lastBearishBOSTime = 0;
   const int    swingLength = 3;
   const double minDistance = 50 * _Point * 10; // 50-pip minimum

   double swingHighs[], swingLows[];
   findSwings(rates, swingLength, swingHighs, swingLows);

   checkBullishBOS(rates, swingHighs, lastBullishBOSTime, minDistance);
   checkBearishBOS(rates, swingLows,  lastBearishBOSTime, minDistance);',
    'Fix BOS separate lastBOSTime'
);

// ============================================================
// 12. Fix Supply/Demand zone (body of impulse candle, not offset)
// ============================================================
R($c,
    '         string patternType = demandZone ? "DemandZone" : "SupplyZone";
         color zoneColor = demandZone ? clrDarkGreen : clrDarkRed;
         double zoneTop = demandZone ? prev3.low : prev3.high;
         double zoneBottom = demandZone ? prev3.low - (baseMove * 0.5) : prev3.high + (baseMove * 0.5);',
    '         string patternType = demandZone ? "DemandZone" : "SupplyZone";
         color  zoneColor   = demandZone ? clrDarkGreen : clrDarkRed;
         // Zone = body of the impulse (base) candle
         double zoneTop    = MathMax(prev3.open, prev3.close);
         double zoneBottom = MathMin(prev3.open, prev3.close);',
    'Fix Supply/Demand zone'
);

// ============================================================
// 13. Replace all scattered notification functions
// ============================================================
R($c,
    'void notifyEngulfing(string patternType, string symbol, datetime dt)
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
}',
    'void notifyEngulfing(string patternType, string symbol, datetime dt)
{
   bool isBull = (StringFind(patternType, "Bullish") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[Pattern] %s %s – %s Engulfing at %s\nMA: %s",
             symbol, EnumToString(_Period), patternType,
             TimeToString(dt, TIME_DATE|TIME_MINUTES), getMaAlignment()));
   registerSignal(patternType + " Engulfing", isBull);
}',
    'Fix notifyEngulfing'
);

R($c,
    'void notifyPattern(string patternType, datetime time) {
   string timeframe = EnumToString(_Period);
   string message = StringFormat("%s %s %s detected at %s", _Symbol, timeframe, patternType, TimeToString(time, TIME_DATE|TIME_MINUTES));
   Alert(message);
   SendNotification(message);
}',
    'void notifyPattern(string patternType, datetime time)
{
   bool isBull = (StringFind(patternType,"Morning")>=0 || StringFind(patternType,"Dragonfly")>=0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[Pattern] %s %s – %s at %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             TimeToString(time, TIME_DATE|TIME_MINUTES), getMaAlignment()));
   registerSignal(patternType, isBull);
}',
    'Fix notifyPattern'
);

R($c,
    'void notifyHaramiPattern(string patternType, double triggerPrice, datetime time)
{
   string timeframe = EnumToString(_Period);
   string message = StringFormat("%s detected on %s %s %s\nTime: %s\nPrice Level: %.5f",
                    patternType, _Symbol, timeframe, EnumToString(_Period),
                    TimeToString(time, TIME_DATE|TIME_MINUTES), triggerPrice);

   Alert(message);
   if(!SendNotification(message)) {
      Print("Failed to send notification: ", GetLastError());
   }
}',
    'void notifyHaramiPattern(string patternType, double triggerPrice, datetime time)
{
   bool isBull = (StringFind(patternType, "Bullish") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[Pattern] %s %s – %s at %s\nLevel: %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             TimeToString(time, TIME_DATE|TIME_MINUTES),
             DoubleToString(triggerPrice, _Digits), getMaAlignment()));
   registerSignal(patternType, isBull);
}',
    'Fix notifyHaramiPattern'
);

R($c,
    'void sendNotification(string patternType, double price)
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
}',
    'void sendNotification(string patternType, double price)
{
   bool isBull = (StringFind(patternType, "Bottom") >= 0);
   sendAlert(StringFormat("[Pattern] %s %s – %s\nPrice: %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             DoubleToString(price, _Digits), getMaAlignment()));
   registerSignal(patternType, isBull);
}',
    'Fix sendNotification'
);

R($c,
    'void notifyTweezerPattern(string patternType, double price, datetime time)
{
   string timeframe = EnumToString(_Period);
   string message = StringFormat("%s detected on %s %s\nTime: %s\nPrice: %.5f",
                    patternType, _Symbol, timeframe,
                    TimeToString(time, TIME_DATE|TIME_MINUTES), price);

   Alert(message);
   if(!SendNotification(message)) {
      Print("Notification failed: ", GetLastError());
   }
}',
    'void notifyTweezerPattern(string patternType, double price, datetime time)
{
   bool isBull = (StringFind(patternType, "Bottom") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[Pattern] %s %s – %s at %s\nPrice: %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             TimeToString(time, TIME_DATE|TIME_MINUTES),
             DoubleToString(price, _Digits), getMaAlignment()));
   registerSignal(patternType, isBull);
}',
    'Fix notifyTweezerPattern'
);

R($c,
    'void notifyPinBar(string patternType, double price, datetime time)
{
   string timeframe = EnumToString(_Period);
   string message = StringFormat("%s detected on %s %s %s\nTime: %s\nPrice: %.5f",
                    patternType, _Symbol, timeframe, EnumToString(_Period),
                    TimeToString(time, TIME_DATE|TIME_MINUTES), price);

   Alert(message);
   if(!SendNotification(message)) {
      Print("Notification failed: ", GetLastError());
   }
}',
    'void notifyPinBar(string patternType, double price, datetime time)
{
   bool isBull = (patternType == "Hammer");
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[Pattern] %s %s – %s at %s\nPrice: %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             TimeToString(time, TIME_DATE|TIME_MINUTES),
             DoubleToString(price, _Digits), getMaAlignment()));
   registerSignal(patternType, isBull);
}',
    'Fix notifyPinBar'
);

R($c,
    'void notifyOrderBlock(string patternType, double high, double low, datetime time)
{
   string timeframe = EnumToString(_Period);
   string message = StringFormat("%s Order Block detected on %s %s\nTime: %s\nRange: %.5f-%.5f",
                    patternType, _Symbol, timeframe,
                    TimeToString(time, TIME_DATE|TIME_MINUTES), low, high);

   Alert(message);
   if(!SendNotification(message)) {
      Print("Notification failed: ", GetLastError());
   }
}',
    'void notifyOrderBlock(string patternType, double high, double low, datetime time)
{
   bool isBull = (StringFind(patternType, "Bullish") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[OB] %s %s – %s at %s\nZone: %s – %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             TimeToString(time, TIME_DATE|TIME_MINUTES),
             DoubleToString(low,_Digits), DoubleToString(high,_Digits), getMaAlignment()));
   registerSignal(patternType, isBull);
}',
    'Fix notifyOrderBlock'
);

R($c,
    'void notifySupplyDemand(string patternType, double top, double bottom, datetime time)
{
   string tf = EnumToString(_Period);
   string message = StringFormat("%s detected on %s %s\nTime: %s\nZone: %.5f - %.5f",
                    patternType, _Symbol, tf,
                    TimeToString(time, TIME_DATE|TIME_MINUTES), bottom, top);

   Alert(message);
   if(!SendNotification(message)) {
      Print("Notification failed: ", GetLastError());
   }
}',
    'void notifySupplyDemand(string patternType, double top, double bottom, datetime time)
{
   bool isBull = (patternType == "DemandZone");
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[S/D] %s %s – %s at %s\nZone: %s – %s\nMA: %s",
             _Symbol, EnumToString(_Period), patternType,
             TimeToString(time, TIME_DATE|TIME_MINUTES),
             DoubleToString(bottom,_Digits), DoubleToString(top,_Digits), getMaAlignment()));
   registerSignal(patternType, isBull);
}',
    'Fix notifySupplyDemand'
);

R($c,
    'void notifyBOS(string bosType, double level, datetime time)
{
   string message = StringFormat("%s detected on %s %s\nTime: %s\nLevel: %.5f",
                    bosType, _Symbol, EnumToString(_Period),
                    TimeToString(time, TIME_DATE|TIME_MINUTES), level);

   Alert(message);
   if(!SendNotification(message))
   {
      Print("Notification failed: ", GetLastError());
   }
}',
    'void notifyBOS(string bosType, double level, datetime time)
{
   bool isBull = (StringFind(bosType, "Bullish") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;
   sendAlert(StringFormat("[BOS] %s %s – %s at %s\nLevel: %s\nMA: %s",
             _Symbol, EnumToString(_Period), bosType,
             TimeToString(time, TIME_DATE|TIME_MINUTES),
             DoubleToString(level, _Digits), getMaAlignment()));
   registerSignal(bosType, isBull);
}',
    'Fix notifyBOS'
);

// ============================================================
// 14. Fix priceCrosses50MA notifications
// ============================================================
R($c,
    '    // Check for bullish cross (price crosses above MA)
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
}',
    '    // Price crosses above SMA50
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
}',
    'Fix priceCrosses50MA'
);

// ============================================================
// 15. Fix Three Soldiers notifications
// ============================================================
R($c,
    '        DrawSoldiersPatternBox("TWS_Box", startTime, endTime,
                      lowPrices[OLDEST], highPrices[NEWEST], clrLimeGreen);
        Alert("Three White Soldiers detected");',
    '        DrawSoldiersPatternBox("TWS_Box", startTime, endTime,
                      lowPrices[OLDEST], highPrices[NEWEST], clrLimeGreen);
        sendAlert(StringFormat("[Pattern] %s %s – Three White Soldiers\nMA: %s",
                  _Symbol, EnumToString(_Period), getMaAlignment()));
        registerSignal("Three White Soldiers", true);',
    'Fix Three White Soldiers'
);

R($c,
    '        DrawSoldiersPatternBox("TBS_Box", startTime, endTime,
                      lowPrices[NEWEST], highPrices[OLDEST], clrIndianRed);
        Alert("Three Black Soldiers detected");',
    '        DrawSoldiersPatternBox("TBS_Box", startTime, endTime,
                      lowPrices[NEWEST], highPrices[OLDEST], clrIndianRed);
        sendAlert(StringFormat("[Pattern] %s %s – Three Black Soldiers\nMA: %s",
                  _Symbol, EnumToString(_Period), getMaAlignment()));
        registerSignal("Three Black Soldiers", false);',
    'Fix Three Black Soldiers'
);

// ============================================================
// 16. Fix P&L notification to use sendAlert
// ============================================================
R($c,
    '   Print(message);
   Alert(message);
   if(!MQL5InfoInteger(MQL5_TESTING))
      SendNotification(message);

   lastProfitNotifyTime = currentTime;',
    '   sendAlert(message);
   lastProfitNotifyTime = currentTime;',
    'Fix P&L notification'
);

// ============================================================
// 17. Remove dead functions
// ============================================================
// Remove currentTimeFrame() - never called
R($c,
    '//+------------------------------------------------------------------+
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
}',
    '',
    'Remove currentTimeFrame'
);

// Remove trendAndRangeDetector() - empty body
R($c,
    "void trendAndRangeDetector(){\n}",
    '',
    'Remove trendAndRangeDetector'
);

// Remove commented-out large blocks
$c = preg_replace('/\/\*\s*\n\s*void runAllPatternDetectors\(int lookbackPeriod.*?\*\//s', '', $c);

// ============================================================
// 18. Enhance dashboard: add MA alignment + pattern signals
// ============================================================
R($c,
    '   else
   {
      dash += "--- No open position ---\n";
   }

   Comment(dash);
}',
    '   else
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
}',
    'Enhance dashboard'
);

// ============================================================
// REPORT
// ============================================================
echo "\nOriginal: {$orig_len} chars\nNew:      " . strlen($c) . " chars\n";

if (!empty($fails)) {
    echo "\n=== FAILURES ===\n";
    foreach ($fails as $f) echo "  $f\n";
    echo "File NOT written.\n";
    exit(1);
}

// Write back as UTF-16 LE with BOM
$out = mb_convert_encoding($c, 'UTF-16', 'UTF-8');
file_put_contents($fp, $out);
echo "\nSUCCESS – file written.\n";
