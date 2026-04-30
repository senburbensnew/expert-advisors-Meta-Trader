"""
Comprehensive EA Enhancement Script
Handles all enhancements including:
- MA simplification (21/50/200 only)
- FVG fix
- Memory leak fix
- BOS fix
- Trend reversal detector
- Phone-only notifications
- Confluence tracking
- Code cleanup
"""
import codecs, re, sys

FP = (r'c:\Users\rubens\AppData\Roaming\MetaQuotes\Terminal'
      r'\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts'
      r'\deepseek_ma_crossover\deepseek_ultimate_expert_advisor.mq5')

with codecs.open(FP, 'r', encoding='utf-16') as f:
    c = f.read()

orig_len = len(c)

# ==============================================================
# HELPER to do a required replacement (aborts on failure)
# ==============================================================
failures = []

def R(old, new, label):
    global c
    if old not in c:
        failures.append(f'FAIL [{label}]: old string not found')
        return
    c = c.replace(old, new, 1)
    print(f'OK   [{label}]')


# ==============================================================
# 1. Remove dead global: lastCurrentPrice
# ==============================================================
R(
    'double lastCurrentPrice = 0; // Variable to store the last current price\n',
    '',
    'Remove lastCurrentPrice'
)

# ==============================================================
# 2. Change input defaults: phone-only notifications
#    enableAlerts = false, enablePushNotifications = true
# ==============================================================
R(
    'input int     profitNotifyMinutes = 15;   // Profit P&L notification interval (minutes)',
    ('input int     profitNotifyMinutes = 15;   // Profit P&L notification interval (minutes)\n'
     'input bool    enableAlerts             = false; // Enable popup alerts (phone-only = false)\n'
     'input bool    enablePushNotifications  = true;  // Enable mobile push notifications\n'
     'input bool    enableTrendFilter        = false; // Only show patterns aligned with MA trend'),
    'Alert/Push inputs'
)

# ==============================================================
# 3. Add confluence globals after lastProfitNotifyTime
# ==============================================================
R(
    'datetime lastProfitNotifyTime = 0;  // Last time a profit notification was sent',
    ('datetime lastProfitNotifyTime = 0;  // Last time a profit notification was sent\n'
     'int      g_bullishCount   = 0;      // Bullish pattern count on last closed bar\n'
     'int      g_bearishCount   = 0;      // Bearish pattern count on last closed bar\n'
     'datetime g_confluenceBar  = 0;      // Bar time of last confluence check\n'
     'string   g_confluenceNames = "";    // Pattern names in current confluence\n'
     'bool     g_wasBullishTrend = false; // Previous trend state (for reversal detection)\n'
     'bool     g_wasBearishTrend = false;'),
    'Confluence/reversal globals'
)

# ==============================================================
# 4. MA simplification:
#    Remove fastMaPeriod=8, rename twentyoneMaPeriod -> fastMaPeriod
#    Remove twentyoneMaHandler, use fastMaHandler for 21 EMA
# ==============================================================
R(
    ('input int      fastMaPeriod = 8;       // Fast MA Period (EMA)\n'
     'input int      twentyoneMaPeriod = 21;    // Middle MA Period (EMA)\n'
     'input int      middleMaPeriod = 50;    // Middle MA Period (EMA)\n'
     'input int      slowMaPeriod = 200;     // Slow MA Period (SMA)'),
    ('input int      fastMaPeriod   = 21;  // Fast MA Period (EMA21)\n'
     'input int      middleMaPeriod = 50;  // Middle MA Period (EMA50)\n'
     'input int      slowMaPeriod   = 200; // Slow MA Period (SMA200)'),
    'MA inputs simplification'
)

R(
    'int fastMaHandler, twentyoneMaHandler, middleMaHandler, slowMaHandler;',
    'int fastMaHandler, middleMaHandler, slowMaHandler;',
    'Remove twentyoneMaHandler declaration'
)

# ==============================================================
# 5. Fix #define: remove twentyoneMA_MA_OBJ, map FAST to EMA21
# ==============================================================
R(
    ('#define FAST_MA_OBJ "FastMA"\n'
     '#define twentyoneMA_MA_OBJ "twentyoneMA"\n'
     '#define MIDDLE_MA_OBJ "MiddleMA"\n'
     '#define SLOW_MA_OBJ "SlowMA"'),
    ('#define FAST_MA_OBJ   "EMA21"\n'
     '#define MIDDLE_MA_OBJ "EMA50"\n'
     '#define SLOW_MA_OBJ   "SMA200"'),
    'MA defines simplification'
)

# ==============================================================
# 6. Fix OnInit MA handle creation
# ==============================================================
R(
    ('   fastMaHandler = iMA(_Symbol, PERIOD_CURRENT, fastMaPeriod, 0, MODE_EMA, PRICE_CLOSE);\n'
     '   twentyoneMaHandler = iMA(_Symbol, PERIOD_CURRENT, twentyoneMaPeriod, 0, MODE_EMA, PRICE_CLOSE);\n'
     '   middleMaHandler = iMA(_Symbol, PERIOD_CURRENT, middleMaPeriod, 0, MODE_EMA, PRICE_CLOSE);\n'
     '   slowMaHandler = iMA(_Symbol, PERIOD_CURRENT, slowMaPeriod, 0, MODE_SMA, PRICE_CLOSE);'),
    ('   fastMaHandler   = iMA(_Symbol, PERIOD_CURRENT, fastMaPeriod,   0, MODE_EMA, PRICE_CLOSE); // EMA21\n'
     '   middleMaHandler = iMA(_Symbol, PERIOD_CURRENT, middleMaPeriod, 0, MODE_EMA, PRICE_CLOSE); // EMA50\n'
     '   slowMaHandler   = iMA(_Symbol, PERIOD_CURRENT, slowMaPeriod,   0, MODE_SMA, PRICE_CLOSE); // SMA200'),
    'MA handle creation'
)

# ==============================================================
# 7. Fix handle validation check in OnInit
# ==============================================================
R(
    'if(fastMaHandler == INVALID_HANDLE || middleMaHandler == INVALID_HANDLE || slowMaHandler == INVALID_HANDLE)',
    'if(fastMaHandler == INVALID_HANDLE || middleMaHandler == INVALID_HANDLE || slowMaHandler == INVALID_HANDLE)',
    'Handle validation (no change needed)'
)

# ==============================================================
# 8. Fix CreateMaObject calls (replace twentyoneMA_MA_OBJ with FAST_MA_OBJ)
# ==============================================================
R(
    ('   CreateMaObject(twentyoneMA_MA_OBJ, clrRed);    // Fast MA (Blue)\n'
     '   CreateMaObject(MIDDLE_MA_OBJ, clrBlue); // Middle MA (Green)\n'
     '   CreateMaObject(SLOW_MA_OBJ, clrWhite);     // Slow MA (Red)'),
    ('   CreateMaObject(FAST_MA_OBJ,   clrDodgerBlue);  // EMA21\n'
     '   CreateMaObject(MIDDLE_MA_OBJ, clrOrange);      // EMA50\n'
     '   CreateMaObject(SLOW_MA_OBJ,   clrWhite);       // SMA200'),
    'CreateMaObject calls'
)

# ==============================================================
# 9. Fix ChartIndicatorAdd (use fastMaHandler instead of twentyoneMaHandler)
# ==============================================================
R(
    ('   // ChartIndicatorAdd(ChartID(), 0, fastMaHandler); \n'
     '   ChartIndicatorAdd(ChartID(), 0, twentyoneMaHandler); \n'
     '   ChartIndicatorAdd(ChartID(), 0, middleMaHandler); \n'
     '   ChartIndicatorAdd(ChartID(), 0, slowMaHandler); \n'
     '   // ChartIndicatorAdd(ChartID(), 1, stochasticOscillatorHandler); '),
    ('   ChartIndicatorAdd(ChartID(), 0, fastMaHandler);    // EMA21\n'
     '   ChartIndicatorAdd(ChartID(), 0, middleMaHandler);  // EMA50\n'
     '   ChartIndicatorAdd(ChartID(), 0, slowMaHandler);    // SMA200'),
    'ChartIndicatorAdd calls'
)

# ==============================================================
# 10. Fix IndicatorRelease in OnDeinit
# ==============================================================
R(
    ('   IndicatorRelease(fastMaHandler);\n'
     '   IndicatorRelease(middleMaHandler);\n'
     '   IndicatorRelease(slowMaHandler);\n'
     '   IndicatorRelease(stochasticOscillatorHandler);'),
    ('   IndicatorRelease(fastMaHandler);\n'
     '   IndicatorRelease(middleMaHandler);\n'
     '   IndicatorRelease(slowMaHandler);\n'
     '   IndicatorRelease(stochasticOscillatorHandler);\n'
     '   IndicatorRelease(maHandle);'),
    'IndicatorRelease in OnDeinit'
)

# Remove the duplicate maHandle release block that was there before
R(
    ('       if(maHandle != INVALID_HANDLE)\n'
     '    {\n'
     '        IndicatorRelease(maHandle); // Release the handle\n'
     '    }\n'),
    '',
    'Remove duplicate maHandle release'
)

# ==============================================================
# 11. Remove BarsCalculated for twentyoneMaHandler
# ==============================================================
R(
    ('   if(BarsCalculated(fastMaHandler) < slowMaPeriod ||   \n'
     '      BarsCalculated(middleMaHandler) < slowMaPeriod || \n'
     '      BarsCalculated(slowMaHandler) < slowMaPeriod)\n'
     '      return;'),
    ('   if(BarsCalculated(fastMaHandler)   < slowMaPeriod ||\n'
     '      BarsCalculated(middleMaHandler) < slowMaPeriod ||\n'
     '      BarsCalculated(slowMaHandler)   < slowMaPeriod)\n'
     '      return;'),
    'BarsCalculated check'
)

# ==============================================================
# 12. Fix CopyBuffer for fastMa (was using fastMaHandler already – OK)
#     Remove twentyoneMa references in OnTick
# ==============================================================
R(
    ('   double fastMa[], middleMa[], slowMa[];\n'
     '   CopyBuffer(fastMaHandler, 0, 0, 3, fastMa);\n'
     '   CopyBuffer(middleMaHandler, 0, 0, 3, middleMa);\n'
     '   CopyBuffer(slowMaHandler, 0, 0, 3, slowMa);'),
    ('   double fastMa[], middleMa[], slowMa[];\n'
     '   CopyBuffer(fastMaHandler,   0, 0, 3, fastMa);   // EMA21\n'
     '   CopyBuffer(middleMaHandler, 0, 0, 3, middleMa); // EMA50\n'
     '   CopyBuffer(slowMaHandler,   0, 0, 3, slowMa);   // SMA200'),
    'CopyBuffer calls'
)

# ==============================================================
# 13. Fix UpdateMA lines (remove FAST_MA_OBJ for old 8 EMA, keep new)
# ==============================================================
R(
    ('   // Update MA lines on the chart\n'
     '   ObjectSetDouble(0, FAST_MA_OBJ, OBJPROP_PRICE, fastMa[0]);\n'
     '   ObjectSetDouble(0, MIDDLE_MA_OBJ, OBJPROP_PRICE, middleMa[0]);\n'
     '   ObjectSetDouble(0, SLOW_MA_OBJ, OBJPROP_PRICE, slowMa[0]);'),
    ('   // Update MA lines on the chart\n'
     '   ObjectSetDouble(0, FAST_MA_OBJ,   OBJPROP_PRICE, fastMa[0]);   // EMA21\n'
     '   ObjectSetDouble(0, MIDDLE_MA_OBJ, OBJPROP_PRICE, middleMa[0]); // EMA50\n'
     '   ObjectSetDouble(0, SLOW_MA_OBJ,   OBJPROP_PRICE, slowMa[0]);   // SMA200'),
    'UpdateMA lines'
)

# ==============================================================
# 14. Insert helper functions BEFORE OnInit
# ==============================================================
HELPERS = r"""//+------------------------------------------------------------------+
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
//| Trend helpers – use existing 50-SMA handle (no new handle)       |
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
//| Returns human-readable MA alignment (EMA21/EMA50/SMA200)        |
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
//| Registers a pattern signal; fires confluence alert at 2+         |
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
      string msg = StringFormat(
         "[CONFLUENCE] %s %s – %d %s signals agree:\n%s\nMA Align: %s",
         _Symbol, EnumToString(_Period), count, dir,
         g_confluenceNames, getMaAlignment());
      sendAlert(msg);
   }
}

//+------------------------------------------------------------------+
//| Detects trend reversals using EMA21 / SMA50 crossover + slope    |
//+------------------------------------------------------------------+
void detectTrendReversal()
{
   double fast[3], slow[3];
   if(CopyBuffer(fastMaHandler, 0, 1, 3, fast)   < 3) return;
   if(CopyBuffer(maHandle,      0, 1, 3, slow)   < 3) return;
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);

   // EMA21 crosses above SMA50 → bullish reversal
   bool bullReversal = (fast[1] <= slow[1]) && (fast[0] > slow[0]);
   // EMA21 crosses below SMA50 → bearish reversal
   bool bearReversal = (fast[1] >= slow[1]) && (fast[0] < slow[0]);

   if(bullReversal)
   {
      string msg = StringFormat(
         "[TREND REVERSAL] %s %s – Potential BULLISH reversal\n"
         "EMA21 crossed ABOVE SMA50 at %s\n"
         "MA Align: %s",
         _Symbol, EnumToString(_Period),
         TimeToString(iTime(_Symbol, _Period, 1), TIME_DATE|TIME_MINUTES),
         getMaAlignment());
      sendAlert(msg);
      registerSignal("TrendReversal Bull", true);
   }
   else if(bearReversal)
   {
      string msg = StringFormat(
         "[TREND REVERSAL] %s %s – Potential BEARISH reversal\n"
         "EMA21 crossed BELOW SMA50 at %s\n"
         "MA Align: %s",
         _Symbol, EnumToString(_Period),
         TimeToString(iTime(_Symbol, _Period, 1), TIME_DATE|TIME_MINUTES),
         getMaAlignment());
      sendAlert(msg);
      registerSignal("TrendReversal Bear", false);
   }
}

"""

R(
    '//+------------------------------------------------------------------+\n//| Expert initialization function',
    HELPERS + '//+------------------------------------------------------------------+\n//| Expert initialization function',
    'Insert helper functions'
)

# ==============================================================
# 15. Add calls at the top of OnTick
# ==============================================================
R(
    'void OnTick()\n{\n    checkProfitNotification();  // P&L update every N minutes while in trade\n    updateDashboard();          // Refresh on-chart info panel\n',
    ('void OnTick()\n{\n'
     '    checkProfitNotification();  // P&L update every N minutes while in trade\n'
     '    updateDashboard();          // Refresh on-chart info panel\n'
     '    detectTrendReversal();      // Check for EMA21/SMA50 crossover reversal\n'),
    'Add detectTrendReversal call in OnTick'
)

# ==============================================================
# 16. Remove dead end-of-OnTick code, replace with live signals
# ==============================================================
OLD_ONTICK_END = (
    '   // Check for Stochastic crossover signals\n'
    '   bool stochBuy = (K[0] > stochOversold && K[1] <= stochOversold);  // %K crosses above 20\n'
    '   bool stochSell = (K[0] < stochOverbought && K[1] >= stochOverbought); // %K crosses below 80\n'
    '\n'
    '   // Check existing positions\n'
    '   bool positionExists = PositionSelect(_Symbol);\n'
    '\n'
    '   // Calculate risk amount based on account equity\n'
    '   double equity = AccountInfoDouble(ACCOUNT_EQUITY);\n'
    '   double riskAmount = equity * 0.01; // 1% of equity\n'
    '\n'
    '   // Broker-specific constraints\n'
    '   double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;\n'
    '   double minLotSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);\n'
    '   double brokerMaxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);\n'
    '   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);\n'
    '}'
)

NEW_ONTICK_END = (
    '   // ---- MA crossover alerts ----\n'
    '   bool bullishCross = (fastMa[0] > middleMa[0]) && (fastMa[1] <= middleMa[1]);\n'
    '   bool bearishCross = (fastMa[0] < middleMa[0]) && (fastMa[1] >= middleMa[1]);\n'
    '   if(bullishCross)\n'
    '   {\n'
    '      sendAlert(StringFormat("[MA Cross] %s %s – EMA21 crossed ABOVE EMA50\\nMA: %s",\n'
    '                             _Symbol, EnumToString(_Period), getMaAlignment()));\n'
    '      registerSignal("MA Bull Cross", true);\n'
    '   }\n'
    '   if(bearishCross)\n'
    '   {\n'
    '      sendAlert(StringFormat("[MA Cross] %s %s – EMA21 crossed BELOW EMA50\\nMA: %s",\n'
    '                             _Symbol, EnumToString(_Period), getMaAlignment()));\n'
    '      registerSignal("MA Bear Cross", false);\n'
    '   }\n'
    '\n'
    '   // ---- Stochastic overbought / oversold alerts ----\n'
    '   bool stochBuy  = (K[0] > stochOversold  && K[1] <= stochOversold);\n'
    '   bool stochSell = (K[0] < stochOverbought && K[1] >= stochOverbought);\n'
    '   if(stochBuy)\n'
    '   {\n'
    '      sendAlert(StringFormat("[Stoch] %s %s – %%K crossed above %d (oversold exit) K=%.1f\\nMA: %s",\n'
    '                             _Symbol, EnumToString(_Period), stochOversold, K[0], getMaAlignment()));\n'
    '      registerSignal("Stoch Bull", true);\n'
    '   }\n'
    '   if(stochSell)\n'
    '   {\n'
    '      sendAlert(StringFormat("[Stoch] %s %s – %%K crossed below %d (overbought exit) K=%.1f\\nMA: %s",\n'
    '                             _Symbol, EnumToString(_Period), stochOverbought, K[0], getMaAlignment()));\n'
    '      registerSignal("Stoch Bear", false);\n'
    '   }\n'
    '}'
)

R(OLD_ONTICK_END, NEW_ONTICK_END, 'Replace dead OnTick end with live signals')

# ==============================================================
# 17. Fix FVG detection (standard single-gap logic)
# ==============================================================
R(
    ('        // Bullish FVG (Bearish c3 -> Bullish c1)\n'
     '        if(c3.close < c3.open &&    // Bearish candle\n'
     '           c1.close > c1.open &&    // Bullish candle\n'
     '           c2.low > c3.high &&      // Gap between c3 and c2\n'
     '           c1.low > c2.high)        // Gap remains unfilled\n'
     '        {\n'
     '            double fvgTop = c3.high;\n'
     '            double fvgBottom = c2.low;'),
    ('        // Bullish FVG: gap between c3.high (oldest) and c1.low (newest)\n'
     '        if(c1.low > c3.high)  // Standard ICT FVG – unfilled price imbalance up\n'
     '        {\n'
     '            double fvgTop    = c1.low;   // Upper edge of imbalance zone\n'
     '            double fvgBottom = c3.high;  // Lower edge of imbalance zone'),
    'Fix Bullish FVG'
)

R(
    ('        // Bearish FVG (Bullish c3 -> Bearish c1)\n'
     '        if(c3.close > c3.open &&    // Bullish candle\n'
     '           c1.close < c1.open &&    // Bearish candle\n'
     '           c2.high < c3.low &&      // Gap between c3 and c2\n'
     '           c1.high < c2.low)        // Gap remains unfilled\n'
     '        {\n'
     '            double fvgTop = c2.high;\n'
     '            double fvgBottom = c3.low;'),
    ('        // Bearish FVG: gap between c1.high (newest) and c3.low (oldest)\n'
     '        if(c1.high < c3.low)  // Standard ICT FVG – unfilled price imbalance down\n'
     '        {\n'
     '            double fvgTop    = c3.low;   // Upper edge of imbalance zone\n'
     '            double fvgBottom = c1.high;  // Lower edge of imbalance zone'),
    'Fix Bearish FVG'
)

# ==============================================================
# 18. Fix FVG notification
# ==============================================================
R(
    ('void sendFVGNotification(string type, double top, double bottom, datetime time)\n'
     '{\n'
     '    string timeframe = EnumToString(_Period);\n'
     '    double fvgSizePips = MathAbs(top - bottom) / ((_Digits == 3 || _Digits ==5) ? 0.001 : 0.0001);\n'
     '    \n'
     '    string message = StringFormat("%s FVG detected on %s %s\\nTime: %s\\nSize: %.1f pips",\n'
     '                     type, _Symbol, timeframe, TimeToString(time), fvgSizePips);\n'
     '    \n'
     '    Alert(message);\n'
     '    SendNotification(message); // Requires MT5 notifications enabled\n'
     '}'),
    ('void sendFVGNotification(string type, double top, double bottom, datetime time)\n'
     '{\n'
     '    double pipDiv   = (_Digits == 3 || _Digits == 5) ? 0.001 : 0.0001;\n'
     '    double sizePips = MathAbs(top - bottom) / pipDiv;\n'
     '    bool   isBull   = (type == "Bullish");\n'
     '    if(enableTrendFilter && isBull  && !isBullishTrend()) return;\n'
     '    if(enableTrendFilter && !isBull && !isBearishTrend()) return;\n'
     '    string message = StringFormat(\n'
     '       "[FVG] %s %s – %s Fair Value Gap\\nZone: %s – %s  Size: %.1f pips\\nMA: %s",\n'
     '       _Symbol, EnumToString(_Period), type,\n'
     '       DoubleToString(bottom, _Digits), DoubleToString(top, _Digits),\n'
     '       sizePips, getMaAlignment());\n'
     '    sendAlert(message);\n'
     '    registerSignal(type + " FVG", isBull);\n'
     '}'),
    'Fix FVG notification'
)

# ==============================================================
# 19. Fix isUptrend / isDowntrend (memory leak)
# ==============================================================
R(
    ('bool isUptrend(int period)\n'
     '{\n'
     '   // Create MA handle\n'
     '   int maHandle = iMA(_Symbol, _Period, period, 0, MODE_SMA, PRICE_CLOSE);\n'
     '   \n'
     '   // Buffer for MA values [0 = current, 1 = previous]\n'
     '   double maValues[2];\n'
     '   \n'
     '   if(CopyBuffer(maHandle, 0, 0, 2, maValues) < 2)\n'
     '      return false;\n'
     '      \n'
     '   return maValues[0] > maValues[1];\n'
     '}\n'
     '\n'
     'bool isDowntrend(int period)\n'
     '{\n'
     '   int maHandle = iMA(_Symbol, _Period, period, 0, MODE_SMA, PRICE_CLOSE);\n'
     '   double maValues[2];\n'
     '   \n'
     '   if(CopyBuffer(maHandle, 0, 0, 2, maValues) < 2)\n'
     '      return false;\n'
     '      \n'
     '   return maValues[0] < maValues[1];\n'
     '}'),
    ('// Uses global maHandle (SMA50) – no new handles created on each call\n'
     'bool isUptrend(int period)   { return isBullishTrend(); }\n'
     'bool isDowntrend(int period) { return isBearishTrend(); }'),
    'Fix isUptrend/isDowntrend memory leak'
)

# ==============================================================
# 20. Fix BOS: separate lastBOSTime variables
# ==============================================================
R(
    ('void bos()\n'
     '{\n'
     '   int lookback = 50;\n'
     '   MqlRates rates[];\n'
     '   ArraySetAsSeries(rates, true);\n'
     '   ArrayResize(rates, lookback);\n'
     '   int copied = CopyRates(_Symbol, _Period, 0, lookback, rates);\n'
     '\n'
     '   if(copied < 20) return;\n'
     '\n'
     '   static datetime lastBOSTime = 0;\n'
     '   const int swingLength = 3; // Number of candles for swing detection\n'
     '   const double minDistance = 50 * _Point * 10; // 50 pips minimum structure distance\n'
     '\n'
     '   // Find latest swing highs and lows\n'
     '   double swingHighs[], swingLows[];\n'
     '   findSwings(rates, swingLength, swingHighs, swingLows);\n'
     '\n'
     '   // Check for structure breaks\n'
     '   checkBullishBOS(rates, swingHighs, lastBOSTime, minDistance);\n'
     '   checkBearishBOS(rates, swingLows, lastBOSTime, minDistance);\n'
     '}'),
    ('void bos()\n'
     '{\n'
     '   int lookback = 50;\n'
     '   MqlRates rates[];\n'
     '   ArraySetAsSeries(rates, true);\n'
     '   ArrayResize(rates, lookback);\n'
     '   int copied = CopyRates(_Symbol, _Period, 0, lookback, rates);\n'
     '\n'
     '   if(copied < 20) return;\n'
     '\n'
     '   static datetime lastBullishBOSTime = 0;  // Separate: prevents bearish from blocking bullish\n'
     '   static datetime lastBearishBOSTime = 0;\n'
     '   const int    swingLength = 3;\n'
     '   const double minDistance = 50 * _Point * 10; // 50-pip minimum structure distance\n'
     '\n'
     '   double swingHighs[], swingLows[];\n'
     '   findSwings(rates, swingLength, swingHighs, swingLows);\n'
     '\n'
     '   checkBullishBOS(rates, swingHighs, lastBullishBOSTime, minDistance);\n'
     '   checkBearishBOS(rates, swingLows,  lastBearishBOSTime, minDistance);\n'
     '}'),
    'Fix BOS separate lastBOSTime'
)

# ==============================================================
# 21. Fix Supply/Demand zone coordinates
# ==============================================================
R(
    ('      if(demandZone || supplyZone) {\n'
     '         string patternType = demandZone ? "DemandZone" : "SupplyZone";\n'
     '         color zoneColor = demandZone ? clrDarkGreen : clrDarkRed;\n'
     '         double zoneTop = demandZone ? prev3.low : prev3.high;\n'
     '         double zoneBottom = demandZone ? prev3.low - (baseMove * 0.5) : prev3.high + (baseMove * 0.5);'),
    ('      if(demandZone || supplyZone) {\n'
     '         string patternType = demandZone ? "DemandZone" : "SupplyZone";\n'
     '         color  zoneColor   = demandZone ? clrDarkGreen : clrDarkRed;\n'
     '         // Zone = body of the impulse (base) candle\n'
     '         double zoneTop    = MathMax(prev3.open, prev3.close);\n'
     '         double zoneBottom = MathMin(prev3.open, prev3.close);'),
    'Fix Supply/Demand zone coordinates'
)

# ==============================================================
# 22. Replace all notification functions with unified sendAlert()
# ==============================================================
R(
    ('void notifyEngulfing(string patternType, string symbol, datetime dt)\n'
     '{\n'
     '   string timeframe = EnumToString(_Period);\n'
     '   string message = StringFormat("%s Engulfing detected on %s %s %s at %s", \n'
     '                    patternType, symbol, timeframe, EnumToString(_Period), TimeToString(dt));\n'
     '   \n'
     '   Print(message);\n'
     '   if(!MQL5InfoInteger(MQL5_TESTING)) // Send alerts only if not in tester\n'
     '   {\n'
     '      SendNotification(message);\n'
     '      Alert(message);\n'
     '   }\n'
     '}'),
    ('void notifyEngulfing(string patternType, string symbol, datetime dt)\n'
     '{\n'
     '   bool isBull = (StringFind(patternType, "Bullish") >= 0);\n'
     '   if(enableTrendFilter && isBull  && !isBullishTrend()) return;\n'
     '   if(enableTrendFilter && !isBull && !isBearishTrend()) return;\n'
     '   string message = StringFormat(\n'
     '      "[Pattern] %s %s – %s Engulfing at %s\\nMA: %s",\n'
     '      symbol, EnumToString(_Period), patternType,\n'
     '      TimeToString(dt, TIME_DATE|TIME_MINUTES), getMaAlignment());\n'
     '   sendAlert(message);\n'
     '   registerSignal(patternType + " Engulfing", isBull);\n'
     '}'),
    'Fix notifyEngulfing'
)

R(
    ('void notifyPattern(string patternType, datetime time) {\n'
     '   string timeframe = EnumToString(_Period);\n'
     '   string message = StringFormat("%s %s %s detected at %s", _Symbol, timeframe, patternType, TimeToString(time, TIME_DATE|TIME_MINUTES));\n'
     '   Alert(message);\n'
     '   SendNotification(message);\n'
     '}'),
    ('void notifyPattern(string patternType, datetime time)\n'
     '{\n'
     '   bool isBull = (StringFind(patternType,"Morning")>=0 || StringFind(patternType,"Dragonfly")>=0);\n'
     '   if(enableTrendFilter && isBull  && !isBullishTrend()) return;\n'
     '   if(enableTrendFilter && !isBull && !isBearishTrend()) return;\n'
     '   string message = StringFormat(\n'
     '      "[Pattern] %s %s – %s at %s\\nMA: %s",\n'
     '      _Symbol, EnumToString(_Period), patternType,\n'
     '      TimeToString(time, TIME_DATE|TIME_MINUTES), getMaAlignment());\n'
     '   sendAlert(message);\n'
     '   registerSignal(patternType, isBull);\n'
     '}'),
    'Fix notifyPattern'
)

R(
    ('void notifyHaramiPattern(string patternType, double triggerPrice, datetime time) \n'
     '{\n'
     '   string timeframe = EnumToString(_Period);\n'
     '   string message = StringFormat("%s detected on %s %s %s\\nTime: %s\\nPrice Level: %.5f",\n'
     '                    patternType, _Symbol, timeframe, EnumToString(_Period),\n'
     '                    TimeToString(time, TIME_DATE|TIME_MINUTES), triggerPrice);\n'
     '   \n'
     '   Alert(message);\n'
     '   if(!SendNotification(message)) {\n'
     '      Print("Failed to send notification: ", GetLastError());\n'
     '   }\n'
     '}'),
    ('void notifyHaramiPattern(string patternType, double triggerPrice, datetime time)\n'
     '{\n'
     '   bool isBull = (StringFind(patternType, "Bullish") >= 0);\n'
     '   if(enableTrendFilter && isBull  && !isBullishTrend()) return;\n'
     '   if(enableTrendFilter && !isBull && !isBearishTrend()) return;\n'
     '   string message = StringFormat(\n'
     '      "[Pattern] %s %s – %s at %s\\nLevel: %s\\nMA: %s",\n'
     '      _Symbol, EnumToString(_Period), patternType,\n'
     '      TimeToString(time, TIME_DATE|TIME_MINUTES),\n'
     '      DoubleToString(triggerPrice, _Digits), getMaAlignment());\n'
     '   sendAlert(message);\n'
     '   registerSignal(patternType, isBull);\n'
     '}'),
    'Fix notifyHaramiPattern'
)

R(
    ('void sendNotification(string patternType, double price)\n'
     '{\n'
     '   string message = StringFormat("%s detected at %s (Price: %s)",\n'
     '                                patternType,\n'
     '                                TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),\n'
     '                                DoubleToString(price, _Digits));\n'
     '\n'
     '   // Platform alert\n'
     '   Alert(message);\n'
     '   \n'
     '   // Push notification (if enabled)\n'
     '   if(TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))\n'
     '      SendNotification(message);\n'
     '}'),
    ('void sendNotification(string patternType, double price)\n'
     '{\n'
     '   bool isBull = (StringFind(patternType, "Bottom") >= 0);\n'
     '   string message = StringFormat(\n'
     '      "[Pattern] %s %s – %s\\nPrice: %s\\nMA: %s",\n'
     '      _Symbol, EnumToString(_Period), patternType,\n'
     '      DoubleToString(price, _Digits), getMaAlignment());\n'
     '   sendAlert(message);\n'
     '   registerSignal(patternType, isBull);\n'
     '}'),
    'Fix sendNotification (tweezer)'
)

R(
    ('void notifyTweezerPattern(string patternType, double price, datetime time) \n'
     '{\n'
     '   string timeframe = EnumToString(_Period);\n'
     '   string message = StringFormat("%s detected on %s %s\\nTime: %s\\nPrice: %.5f",\n'
     '                    patternType, _Symbol, timeframe,\n'
     '                    TimeToString(time, TIME_DATE|TIME_MINUTES), price);\n'
     '   \n'
     '   Alert(message);\n'
     '   if(!SendNotification(message)) {\n'
     '      Print("Notification failed: ", GetLastError());\n'
     '   }\n'
     '}'),
    ('void notifyTweezerPattern(string patternType, double price, datetime time)\n'
     '{\n'
     '   bool isBull = (StringFind(patternType, "Bottom") >= 0);\n'
     '   if(enableTrendFilter && isBull  && !isBullishTrend()) return;\n'
     '   if(enableTrendFilter && !isBull && !isBearishTrend()) return;\n'
     '   string message = StringFormat(\n'
     '      "[Pattern] %s %s – %s at %s\\nPrice: %s\\nMA: %s",\n'
     '      _Symbol, EnumToString(_Period), patternType,\n'
     '      TimeToString(time, TIME_DATE|TIME_MINUTES),\n'
     '      DoubleToString(price, _Digits), getMaAlignment());\n'
     '   sendAlert(message);\n'
     '   registerSignal(patternType, isBull);\n'
     '}'),
    'Fix notifyTweezerPattern'
)

R(
    ('void notifyPinBar(string patternType, double price, datetime time) \n'
     '{\n'
     '   string timeframe = EnumToString(_Period);\n'
     '   string message = StringFormat("%s detected on %s %s %s\\nTime: %s\\nPrice: %.5f",\n'
     '                    patternType, _Symbol, timeframe, EnumToString(_Period),\n'
     '                    TimeToString(time, TIME_DATE|TIME_MINUTES), price);\n'
     '   \n'
     '   Alert(message);\n'
     '   if(!SendNotification(message)) {\n'
     '      Print("Notification failed: ", GetLastError());\n'
     '   }\n'
     '}'),
    ('void notifyPinBar(string patternType, double price, datetime time)\n'
     '{\n'
     '   bool isBull = (patternType == "Hammer");\n'
     '   if(enableTrendFilter && isBull  && !isBullishTrend()) return;\n'
     '   if(enableTrendFilter && !isBull && !isBearishTrend()) return;\n'
     '   string message = StringFormat(\n'
     '      "[Pattern] %s %s – %s at %s\\nPrice: %s\\nMA: %s",\n'
     '      _Symbol, EnumToString(_Period), patternType,\n'
     '      TimeToString(time, TIME_DATE|TIME_MINUTES),\n'
     '      DoubleToString(price, _Digits), getMaAlignment());\n'
     '   sendAlert(message);\n'
     '   registerSignal(patternType, isBull);\n'
     '}'),
    'Fix notifyPinBar'
)

R(
    ('void notifyOrderBlock(string patternType, double high, double low, datetime time) \n'
     '{\n'
     '   string timeframe = EnumToString(_Period);\n'
     '   string message = StringFormat("%s Order Block detected on %s %s\\nTime: %s\\nRange: %.5f-%.5f",\n'
     '                    patternType, _Symbol, timeframe,\n'
     '                    TimeToString(time, TIME_DATE|TIME_MINUTES), low, high);\n'
     '   \n'
     '   Alert(message);\n'
     '   if(!SendNotification(message)) {\n'
     '      Print("Notification failed: ", GetLastError());\n'
     '   }\n'
     '}'),
    ('void notifyOrderBlock(string patternType, double high, double low, datetime time)\n'
     '{\n'
     '   bool isBull = (StringFind(patternType, "Bullish") >= 0);\n'
     '   if(enableTrendFilter && isBull  && !isBullishTrend()) return;\n'
     '   if(enableTrendFilter && !isBull && !isBearishTrend()) return;\n'
     '   string message = StringFormat(\n'
     '      "[OB] %s %s – %s at %s\\nZone: %s – %s\\nMA: %s",\n'
     '      _Symbol, EnumToString(_Period), patternType,\n'
     '      TimeToString(time, TIME_DATE|TIME_MINUTES),\n'
     '      DoubleToString(low, _Digits), DoubleToString(high, _Digits), getMaAlignment());\n'
     '   sendAlert(message);\n'
     '   registerSignal(patternType, isBull);\n'
     '}'),
    'Fix notifyOrderBlock'
)

R(
    ('void notifySupplyDemand(string patternType, double top, double bottom, datetime time) \n'
     '{\n'
     '   string tf = EnumToString(_Period);\n'
     '   string message = StringFormat("%s detected on %s %s\\nTime: %s\\nZone: %.5f - %.5f",\n'
     '                    patternType, _Symbol, tf,\n'
     '                    TimeToString(time, TIME_DATE|TIME_MINUTES), bottom, top);\n'
     '   \n'
     '   Alert(message);\n'
     '   if(!SendNotification(message)) {\n'
     '      Print("Notification failed: ", GetLastError());\n'
     '   }\n'
     '}'),
    ('void notifySupplyDemand(string patternType, double top, double bottom, datetime time)\n'
     '{\n'
     '   bool isBull = (patternType == "DemandZone");\n'
     '   if(enableTrendFilter && isBull  && !isBullishTrend()) return;\n'
     '   if(enableTrendFilter && !isBull && !isBearishTrend()) return;\n'
     '   string message = StringFormat(\n'
     '      "[S/D] %s %s – %s at %s\\nZone: %s – %s\\nMA: %s",\n'
     '      _Symbol, EnumToString(_Period), patternType,\n'
     '      TimeToString(time, TIME_DATE|TIME_MINUTES),\n'
     '      DoubleToString(bottom, _Digits), DoubleToString(top, _Digits), getMaAlignment());\n'
     '   sendAlert(message);\n'
     '   registerSignal(patternType, isBull);\n'
     '}'),
    'Fix notifySupplyDemand'
)

R(
    ('void notifyBOS(string bosType, double level, datetime time)\n'
     '{\n'
     '   string message = StringFormat("%s detected on %s %s\\nTime: %s\\nLevel: %.5f",\n'
     '                    bosType, _Symbol, EnumToString(_Period),\n'
     '                    TimeToString(time, TIME_DATE|TIME_MINUTES), level);\n'
     '   \n'
     '   Alert(message);\n'
     '   if(!SendNotification(message))\n'
     '   {\n'
     '      Print("Notification failed: ", GetLastError());\n'
     '   }\n'
     '}'),
    ('void notifyBOS(string bosType, double level, datetime time)\n'
     '{\n'
     '   bool isBull = (StringFind(bosType, "Bullish") >= 0);\n'
     '   if(enableTrendFilter && isBull  && !isBullishTrend()) return;\n'
     '   if(enableTrendFilter && !isBull && !isBearishTrend()) return;\n'
     '   string message = StringFormat(\n'
     '      "[BOS] %s %s – %s at %s\\nLevel: %s\\nMA: %s",\n'
     '      _Symbol, EnumToString(_Period), bosType,\n'
     '      TimeToString(time, TIME_DATE|TIME_MINUTES),\n'
     '      DoubleToString(level, _Digits), getMaAlignment());\n'
     '   sendAlert(message);\n'
     '   registerSignal(bosType, isBull);\n'
     '}'),
    'Fix notifyBOS'
)

# ==============================================================
# 23. Fix priceCrosses50MA notification
# ==============================================================
R(
    ('    // Check for bullish cross (price crosses above MA)\n'
     '    if(closePrices[1] < maValues[1] && closePrices[0] > maValues[0])\n'
     '    {\n'
     '        string timeframe = EnumToString(_Period);\n'
     '        string message = StringFormat("%s %s Bullish crossover detected: Price crossed ABOVE 50-period SMA", _Symbol, timeframe);\n'
     '        Alert(message);\n'
     '        SendNotification(message);\n'
     '    }\n'
     '    \n'
     '    // Check for bearish cross (price crosses below MA)\n'
     '    if(closePrices[1] > maValues[1] && closePrices[0] < maValues[0])\n'
     '    {\n'
     '        string timeframe = EnumToString(_Period);\n'
     '        string message = StringFormat("%s %s Bearish crossover detected: Price crossed BELOW 50-period SMA", _Symbol, timeframe);\n'
     '        Alert(message);\n'
     '        SendNotification(message);\n'
     '    }\n'
     '}'),
    ('    // Bullish cross: price crosses above SMA50\n'
     '    if(closePrices[1] < maValues[1] && closePrices[0] > maValues[0])\n'
     '    {\n'
     '        string msg = StringFormat("[Price x SMA50] %s %s – Price crossed ABOVE SMA50\\nMA: %s",\n'
     '                      _Symbol, EnumToString(_Period), getMaAlignment());\n'
     '        sendAlert(msg);\n'
     '    }\n'
     '\n'
     '    // Bearish cross: price crosses below SMA50\n'
     '    if(closePrices[1] > maValues[1] && closePrices[0] < maValues[0])\n'
     '    {\n'
     '        string msg = StringFormat("[Price x SMA50] %s %s – Price crossed BELOW SMA50\\nMA: %s",\n'
     '                      _Symbol, EnumToString(_Period), getMaAlignment());\n'
     '        sendAlert(msg);\n'
     '    }\n'
     '}'),
    'Fix priceCrosses50MA notification'
)

# ==============================================================
# 24. Fix Three Soldiers notifications
# ==============================================================
R(
    ("        DrawSoldiersPatternBox(\"TWS_Box\", startTime, endTime, \n"
     "                      lowPrices[OLDEST], highPrices[NEWEST], clrLimeGreen);\n"
     "        Alert(\"Three White Soldiers detected\");"),
    ("        DrawSoldiersPatternBox(\"TWS_Box\", startTime, endTime,\n"
     "                      lowPrices[OLDEST], highPrices[NEWEST], clrLimeGreen);\n"
     "        sendAlert(StringFormat(\"[Pattern] %s %s – Three White Soldiers\\nMA: %s\",\n"
     "                  _Symbol, EnumToString(_Period), getMaAlignment()));\n"
     "        registerSignal(\"Three White Soldiers\", true);"),
    'Fix Three White Soldiers notification'
)

R(
    ("        DrawSoldiersPatternBox(\"TBS_Box\", startTime, endTime, \n"
     "                      lowPrices[NEWEST], highPrices[OLDEST], clrIndianRed);\n"
     "        Alert(\"Three Black Soldiers detected\");"),
    ("        DrawSoldiersPatternBox(\"TBS_Box\", startTime, endTime,\n"
     "                      lowPrices[NEWEST], highPrices[OLDEST], clrIndianRed);\n"
     "        sendAlert(StringFormat(\"[Pattern] %s %s – Three Black Soldiers\\nMA: %s\",\n"
     "                  _Symbol, EnumToString(_Period), getMaAlignment()));\n"
     "        registerSignal(\"Three Black Soldiers\", false);"),
    'Fix Three Black Soldiers notification'
)

# ==============================================================
# 25. Fix P&L notification to use sendAlert
# ==============================================================
R(
    ('   Print(message);\n'
     '   Alert(message);\n'
     '   if(!MQL5InfoInteger(MQL5_TESTING))\n'
     '      SendNotification(message);\n'
     '\n'
     '   lastProfitNotifyTime = currentTime;'),
    ('   sendAlert(message);\n'
     '   lastProfitNotifyTime = currentTime;'),
    'Fix P&L notification'
)

# ==============================================================
# 26. Remove dead functions: currentTimeFrame, trendAndRangeDetector
# ==============================================================
c = re.sub(
    r'//\+---.*?Helper function to get current timeframe.*?\+---.*?\nstring currentTimeFrame\(\)\{.*?\}\n',
    '', c, flags=re.DOTALL
)

R(
    'void trendAndRangeDetector(){\n}',
    '',
    'Remove trendAndRangeDetector'
)

# ==============================================================
# 27. Enhance dashboard: MA alignment + signal summary
# ==============================================================
R(
    ('   else\n'
     '   {\n'
     '      dash += "--- No open position ---\\n";\n'
     '   }\n'
     '\n'
     '   Comment(dash);\n'
     '}'),
    ('   else\n'
     '   {\n'
     '      dash += "--- No open position ---\\n";\n'
     '   }\n'
     '\n'
     '   dash += "--- MA Alignment ---\\n";\n'
     '   dash += getMaAlignment() + "\\n";\n'
     '   dash += "--- Patterns (Last Bar) ---\\n";\n'
     '   if(g_bullishCount > 0)\n'
     '      dash += StringFormat("Bull x%d: %s\\n", g_bullishCount, g_confluenceNames);\n'
     '   if(g_bearishCount > 0)\n'
     '      dash += StringFormat("Bear x%d: %s\\n", g_bearishCount, g_confluenceNames);\n'
     '   if(g_bullishCount == 0 && g_bearishCount == 0)\n'
     '      dash += "None on last bar\\n";\n'
     '\n'
     '   Comment(dash);\n'
     '}'),
    'Enhance dashboard'
)

# ==============================================================
# FINAL REPORT
# ==============================================================
print(f'\nOriginal size: {orig_len:,} chars')
print(f'New size:      {len(c):,} chars')

if failures:
    print(f'\n{"="*50}')
    print(f'FAILED: {len(failures)} replacements could not be applied:')
    for f in failures:
        print(' ', f)
    print('File NOT written.')
    sys.exit(1)
else:
    with codecs.open(FP, 'w', encoding='utf-16') as f:
        f.write(c)
    print(f'\nSUCCESS – file written ({len(c):,} chars)')
