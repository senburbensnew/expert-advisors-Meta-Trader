$fp = 'c:\Users\rubens\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\deepseek_ma_crossover\deepseek_ultimate_expert_advisor.mq5'
$c = [System.IO.File]::ReadAllText($fp, [System.Text.Encoding]::Unicode)
$c = $c.Replace("`n", "`n").Replace("`r", "`n")  # normalize to LF

# ============================================================
# STEP 1 – Remove dead global variable lastCurrentPrice
# ============================================================
$c = $c.Replace(
    'double lastCurrentPrice = 0; // Variable to store the last current price' + "`n",
    ''
)

# ============================================================
# STEP 2 – Add alert/push/trend-filter input controls
#           (insert after profitNotifyMinutes line)
# ============================================================
$c = $c.Replace(
    'input int     profitNotifyMinutes = 15;   // Profit P&L notification interval (minutes)',
    'input int     profitNotifyMinutes = 15;   // Profit P&L notification interval (minutes)' + "`n" +
    'input bool    enableAlerts            = true;  // Enable popup alerts' + "`n" +
    'input bool    enablePushNotifications = true;  // Enable mobile push notifications' + "`n" +
    'input bool    enableTrendFilter       = false; // Only show patterns aligned with MA trend'
)

# ============================================================
# STEP 3 – Add confluence tracking globals
#           (insert after lastProfitNotifyTime line)
# ============================================================
$c = $c.Replace(
    'datetime lastProfitNotifyTime = 0;  // Last time a profit notification was sent',
    'datetime lastProfitNotifyTime = 0;  // Last time a profit notification was sent' + "`n" +
    'int      g_bullishCount  = 0;       // Bullish pattern count on last closed bar' + "`n" +
    'int      g_bearishCount  = 0;       // Bearish pattern count on last closed bar' + "`n" +
    'datetime g_confluenceBar = 0;       // Bar time of last confluence check' + "`n" +
    'string   g_confluenceNames = "";    // Pattern names contributing to confluence'
)

# ============================================================
# STEP 4 – Add unified sendAlert() helper BEFORE OnInit
#           Insert before "int OnInit()"
# ============================================================
$alertHelper = @'
//+------------------------------------------------------------------+
//| Unified alert dispatcher                                         |
//+------------------------------------------------------------------+
void sendAlert(const string msg)
{
   Print(msg);
   if(MQL5InfoInteger(MQL5_TESTING)) return;
   if(enableAlerts)            Alert(msg);
   if(enablePushNotifications) SendNotification(msg);
}

//+------------------------------------------------------------------+
//| Returns true if the last closed bar is above the 50-period SMA   |
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
//| Returns human-readable MA alignment string for dashboard / alerts|
//+------------------------------------------------------------------+
string getMaAlignment()
{
   double fast[1], mid21[1], mid50[1], slow[1];
   if(CopyBuffer(fastMaHandler,      0, 1, 1, fast)  < 1) return "N/A";
   if(CopyBuffer(twentyoneMaHandler, 0, 1, 1, mid21) < 1) return "N/A";
   if(CopyBuffer(middleMaHandler,    0, 1, 1, mid50) < 1) return "N/A";
   if(CopyBuffer(slowMaHandler,      0, 1, 1, slow)  < 1) return "N/A";
   if(fast[0] > mid21[0] && mid21[0] > mid50[0] && mid50[0] > slow[0])
      return "BULLISH (EMA8>21>50>SMA200)";
   if(fast[0] < mid21[0] && mid21[0] < mid50[0] && mid50[0] < slow[0])
      return "BEARISH (EMA8<21<50<SMA200)";
   return "MIXED";
}

//+------------------------------------------------------------------+
//| Register a pattern signal – updates confluence counter            |
//+------------------------------------------------------------------+
void registerSignal(const string name, bool isBullish)
{
   datetime bar = iTime(_Symbol, _Period, 1);
   if(bar != g_confluenceBar)
   {
      g_bullishCount   = 0;
      g_bearishCount   = 0;
      g_confluenceNames = "";
      g_confluenceBar  = bar;
   }
   if(isBullish) g_bullishCount++;
   else          g_bearishCount++;
   g_confluenceNames += (g_confluenceNames == "" ? "" : ", ") + name;

   // Fire confluence alert when 2+ patterns agree
   int count = isBullish ? g_bullishCount : g_bearishCount;
   if(count == 2)
   {
      string dir = isBullish ? "BULLISH" : "BEARISH";
      string msg = StringFormat(
         "[CONFLUENCE] %s %s – %d %s patterns agree: %s\nMA: %s",
         _Symbol, EnumToString(_Period),
         count, dir, g_confluenceNames, getMaAlignment());
      sendAlert(msg);
   }
}

'@

$c = $c.Replace(
    '//+------------------------------------------------------------------+' + "`n" +
    '//| Expert initialization function',
    $alertHelper +
    '//+------------------------------------------------------------------+' + "`n" +
    '//| Expert initialization function'
)

# ============================================================
# STEP 5 – Remove dead commented-out blocks (/* ... */)
# ============================================================
# Remove commented-out runAllPatternDetectors with lookbackPeriod param
$c = $c -replace '(?s)/\*\s*\r?\n\s*void runAllPatternDetectors\(int lookbackPeriod.*?\*/', ''

# Remove commented-out old tweezersTopAndBottomDetector
$c = $c -replace '(?s)/\*\r?\nvoid tweezersTopAndBottomDetector\(\).*?^\*/', ''

# ============================================================
# STEP 6 – Remove dead code at end of OnTick
#           (everything after the stoch array setup that is unused)
# ============================================================
$oldOnTickEnd = @'
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
   double brokerMaxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
}
'@

$newOnTickEnd = @'
   // ---- MA crossover signals (send notification but no trade execution) ----
   bool bullishCross = (fastMa[0] > middleMa[0]) && (fastMa[1] <= middleMa[1]);
   bool bearishCross = (fastMa[0] < middleMa[0]) && (fastMa[1] >= middleMa[1]);

   if(bullishCross)
   {
      string msg = StringFormat("[MA Cross] %s %s – EMA8 crossed ABOVE EMA50\nMA Alignment: %s",
                                _Symbol, EnumToString(_Period), getMaAlignment());
      sendAlert(msg);
      registerSignal("MA BullishCross", true);
   }
   if(bearishCross)
   {
      string msg = StringFormat("[MA Cross] %s %s – EMA8 crossed BELOW EMA50\nMA Alignment: %s",
                                _Symbol, EnumToString(_Period), getMaAlignment());
      sendAlert(msg);
      registerSignal("MA BearishCross", false);
   }

   // ---- Stochastic overbought / oversold signals ----
   bool stochBuy  = (K[0] > stochOversold  && K[1] <= stochOversold);
   bool stochSell = (K[0] < stochOverbought && K[1] >= stochOverbought);

   if(stochBuy)
   {
      string msg = StringFormat("[Stochastic] %s %s – %%K crossed above %d (oversold exit)\nK=%.1f  MA: %s",
                                _Symbol, EnumToString(_Period), stochOversold, K[0], getMaAlignment());
      sendAlert(msg);
      registerSignal("Stoch OversoldExit", true);
   }
   if(stochSell)
   {
      string msg = StringFormat("[Stochastic] %s %s – %%K crossed below %d (overbought exit)\nK=%.1f  MA: %s",
                                _Symbol, EnumToString(_Period), stochOverbought, K[0], getMaAlignment());
      sendAlert(msg);
      registerSignal("Stoch OverboughtExit", false);
   }
}
'@

$c = $c.Replace($oldOnTickEnd, $newOnTickEnd)

# ============================================================
# STEP 7 – Fix FVG detection (standard single-gap logic)
# ============================================================
$oldFVGBullish = @'
        // Bullish FVG (Bearish c3 -> Bullish c1)
        if(c3.close < c3.open &&    // Bearish candle
           c1.close > c1.open &&    // Bullish candle
           c2.low > c3.high &&      // Gap between c3 and c2
           c1.low > c2.high)        // Gap remains unfilled
        {
            double fvgTop = c3.high;
            double fvgBottom = c2.low;
'@

$newFVGBullish = @'
        // Bullish FVG: unfilled gap between c3.high (oldest) and c1.low (newest)
        if(c1.low > c3.high)  // Standard ICT Fair Value Gap – price imbalance upward
        {
            double fvgTop    = c1.low;   // Upper boundary of the imbalance zone
            double fvgBottom = c3.high;  // Lower boundary of the imbalance zone
'@

$c = $c.Replace($oldFVGBullish, $newFVGBullish)

$oldFVGBearish = @'
        // Bearish FVG (Bullish c3 -> Bearish c1)
        if(c3.close > c3.open &&    // Bullish candle
           c1.close < c1.open &&    // Bearish candle
           c2.high < c3.low &&      // Gap between c3 and c2
           c1.high < c2.low)        // Gap remains unfilled
        {
            double fvgTop = c2.high;
            double fvgBottom = c3.low;
'@

$newFVGBearish = @'
        // Bearish FVG: unfilled gap between c1.high (newest) and c3.low (oldest)
        if(c1.high < c3.low)  // Standard ICT Fair Value Gap – price imbalance downward
        {
            double fvgTop    = c3.low;   // Upper boundary of the imbalance zone
            double fvgBottom = c1.high;  // Lower boundary of the imbalance zone
'@

$c = $c.Replace($oldFVGBearish, $newFVGBearish)

# ============================================================
# STEP 8 – Enhance FVG notification to include MA context
# ============================================================
$oldFVGNotify = @'
void sendFVGNotification(string type, double top, double bottom, datetime time)
{
    string timeframe = EnumToString(_Period);
    double fvgSizePips = MathAbs(top - bottom) / ((_Digits == 3 || _Digits ==5) ? 0.001 : 0.0001);

    string message = StringFormat("%s FVG detected on %s %s\nTime: %s\nSize: %.1f pips",
                     type, _Symbol, timeframe, TimeToString(time), fvgSizePips);

    Alert(message);
    SendNotification(message); // Requires MT5 notifications enabled
}
'@

$newFVGNotify = @'
void sendFVGNotification(string type, double top, double bottom, datetime time)
{
    double pipDiv    = (_Digits == 3 || _Digits == 5) ? 0.001 : 0.0001;
    double sizePips  = MathAbs(top - bottom) / pipDiv;
    bool   isBull    = (type == "Bullish");

    if(enableTrendFilter && isBull  && !isBullishTrend()) return;
    if(enableTrendFilter && !isBull && !isBearishTrend()) return;

    string message = StringFormat(
        "[FVG] %s %s – %s Fair Value Gap\nZone: %s – %s\nSize: %.1f pips\nMA: %s",
        _Symbol, EnumToString(_Period), type,
        DoubleToString(bottom, _Digits), DoubleToString(top, _Digits),
        sizePips, getMaAlignment());

    sendAlert(message);
    registerSignal(type + " FVG", isBull);
}
'@

$c = $c.Replace($oldFVGNotify, $newFVGNotify)

# ============================================================
# STEP 9 – Fix isUptrend / isDowntrend (memory leak)
# ============================================================
$oldUptrend = @'
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
'@

$newUptrend = @'
// Uses the existing global maHandle (50 SMA) – no new handles created on each call
bool isUptrend(int period)
{
   return isBullishTrend(); // Price above 50-period SMA
}

bool isDowntrend(int period)
{
   return isBearishTrend(); // Price below 50-period SMA
}
'@

$c = $c.Replace($oldUptrend, $newUptrend)

# ============================================================
# STEP 10 – Fix BOS: separate lastBOSTime for bullish/bearish
# ============================================================
$oldBOS = @'
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
'@

$newBOS = @'
void bos()
{
   int lookback = 50;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   ArrayResize(rates, lookback);
   int copied = CopyRates(_Symbol, _Period, 0, lookback, rates);

   if(copied < 20) return;

   static datetime lastBullishBOSTime = 0;  // Separate tracker for bullish BOS
   static datetime lastBearishBOSTime = 0;  // Separate tracker for bearish BOS
   const int    swingLength  = 3;
   const double minDistance  = 50 * _Point * 10; // 50-pip minimum structure distance

   double swingHighs[], swingLows[];
   findSwings(rates, swingLength, swingHighs, swingLows);

   checkBullishBOS(rates, swingHighs, lastBullishBOSTime, minDistance);
   checkBearishBOS(rates, swingLows,  lastBearishBOSTime, minDistance);
}
'@

$c = $c.Replace($oldBOS, $newBOS)

# ============================================================
# STEP 11 – Fix Supply/Demand zone coordinates
# ============================================================
$oldSDZone = @'
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
'@

$newSDZone = @'
      if(demandZone || supplyZone) {
         string patternType = demandZone ? "DemandZone" : "SupplyZone";
         color  zoneColor   = demandZone ? clrDarkGreen : clrDarkRed;
         // Zone spans the entire body of the base (impulse) candle
         double zoneTop    = MathMax(prev3.open, prev3.close);
         double zoneBottom = MathMin(prev3.open, prev3.close);

         if(lastZoneTime != prev3.time) {
            drawSupplyDemandZone(prev3.time, current.time, zoneTop, zoneBottom, zoneColor, patternType);
            notifySupplyDemand(patternType, zoneTop, zoneBottom, current.time);
            lastZoneTime = prev3.time;
         }
      }
'@

$c = $c.Replace($oldSDZone, $newSDZone)

# ============================================================
# STEP 12 – Replace all scattered Alert()/SendNotification()
#            with the unified sendAlert() + registerSignal()
# ============================================================

# --- priceCrosses50MA (already converted in Step 6 logic, but it also has its own) ---
$c = $c.Replace(
    '        string timeframe = EnumToString(_Period);' + "`n" +
    '        string message = StringFormat("%s %s Bullish crossover detected: Price crossed ABOVE 50-period SMA", _Symbol, timeframe);' + "`n" +
    '        Alert(message);' + "`n" +
    '        SendNotification(message);',
    '        string message = StringFormat("[Price x SMA50] %s %s – Price crossed ABOVE 50-period SMA\nMA: %s",' + "`n" +
    '                          _Symbol, EnumToString(_Period), getMaAlignment());' + "`n" +
    '        sendAlert(message);'
)
$c = $c.Replace(
    '        string timeframe = EnumToString(_Period);' + "`n" +
    '        string message = StringFormat("%s %s Bearish crossover detected: Price crossed BELOW 50-period SMA", _Symbol, timeframe);' + "`n" +
    '        Alert(message);' + "`n" +
    '        SendNotification(message);',
    '        string message = StringFormat("[Price x SMA50] %s %s – Price crossed BELOW 50-period SMA\nMA: %s",' + "`n" +
    '                          _Symbol, EnumToString(_Period), getMaAlignment());' + "`n" +
    '        sendAlert(message);'
)

# --- Three Soldiers ---
$c = $c.Replace(
    '        DrawSoldiersPatternBox("TWS_Box", startTime, endTime, ' + "`n" +
    '                      lowPrices[OLDEST], highPrices[NEWEST], clrLimeGreen);' + "`n" +
    '        Alert("Three White Soldiers detected");',
    '        DrawSoldiersPatternBox("TWS_Box", startTime, endTime,' + "`n" +
    '                      lowPrices[OLDEST], highPrices[NEWEST], clrLimeGreen);' + "`n" +
    '        string twsMsg = StringFormat("[Pattern] %s %s – Three White Soldiers\nMA: %s",' + "`n" +
    '                         _Symbol, EnumToString(_Period), getMaAlignment());' + "`n" +
    '        sendAlert(twsMsg);' + "`n" +
    '        registerSignal("Three White Soldiers", true);'
)
$c = $c.Replace(
    '        DrawSoldiersPatternBox("TBS_Box", startTime, endTime, ' + "`n" +
    '                      lowPrices[NEWEST], highPrices[OLDEST], clrIndianRed);' + "`n" +
    '        Alert("Three Black Soldiers detected");',
    '        DrawSoldiersPatternBox("TBS_Box", startTime, endTime,' + "`n" +
    '                      lowPrices[NEWEST], highPrices[OLDEST], clrIndianRed);' + "`n" +
    '        string tbsMsg = StringFormat("[Pattern] %s %s – Three Black Soldiers\nMA: %s",' + "`n" +
    '                         _Symbol, EnumToString(_Period), getMaAlignment());' + "`n" +
    '        sendAlert(tbsMsg);' + "`n" +
    '        registerSignal("Three Black Soldiers", false);'
)

# --- notifyEngulfing (fix duplicate timeframe + add MA context + register signal) ---
$oldEngulfNotify = @'
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
'@

$newEngulfNotify = @'
void notifyEngulfing(string patternType, string symbol, datetime dt)
{
   bool isBull = (StringFind(patternType, "Bullish") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;

   string message = StringFormat(
      "[Pattern] %s %s – %s Engulfing at %s\nMA: %s",
      symbol, EnumToString(_Period), patternType,
      TimeToString(dt, TIME_DATE|TIME_MINUTES), getMaAlignment());
   sendAlert(message);
   registerSignal(patternType + " Engulfing", isBull);
}
'@
$c = $c.Replace($oldEngulfNotify, $newEngulfNotify)

# --- notifyPattern (general) ---
$oldNotifyPattern = @'
void notifyPattern(string patternType, datetime time) {
   string timeframe = EnumToString(_Period);
   string message = StringFormat("%s %s %s detected at %s", _Symbol, timeframe, patternType, TimeToString(time, TIME_DATE|TIME_MINUTES));
   Alert(message);
   SendNotification(message);
}
'@
$newNotifyPattern = @'
void notifyPattern(string patternType, datetime time)
{
   bool isBull = (StringFind(patternType, "Morning") >= 0 ||
                  StringFind(patternType, "Dragonfly") >= 0 ||
                  StringFind(patternType, "Inside") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;

   string message = StringFormat(
      "[Pattern] %s %s – %s at %s\nMA: %s",
      _Symbol, EnumToString(_Period), patternType,
      TimeToString(time, TIME_DATE|TIME_MINUTES), getMaAlignment());
   sendAlert(message);
   registerSignal(patternType, isBull);
}
'@
$c = $c.Replace($oldNotifyPattern, $newNotifyPattern)

# --- notifyHaramiPattern ---
$oldHarami = @'
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
'@
$newHarami = @'
void notifyHaramiPattern(string patternType, double triggerPrice, datetime time)
{
   bool isBull = (StringFind(patternType, "Bullish") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;

   string message = StringFormat(
      "[Pattern] %s %s – %s at %s\nLevel: %s\nMA: %s",
      _Symbol, EnumToString(_Period), patternType,
      TimeToString(time, TIME_DATE|TIME_MINUTES),
      DoubleToString(triggerPrice, _Digits), getMaAlignment());
   sendAlert(message);
   registerSignal(patternType, isBull);
}
'@
$c = $c.Replace($oldHarami, $newHarami)

# --- sendNotification (tweezer) ---
$oldSendNotif = @'
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
'@
$newSendNotif = @'
void sendNotification(string patternType, double price)
{
   bool isBull = (StringFind(patternType, "Bottom") >= 0);
   string message = StringFormat(
      "[Pattern] %s %s – %s\nPrice: %s\nMA: %s",
      _Symbol, EnumToString(_Period), patternType,
      DoubleToString(price, _Digits), getMaAlignment());
   sendAlert(message);
   registerSignal(patternType, isBull);
}
'@
$c = $c.Replace($oldSendNotif, $newSendNotif)

# --- notifyTweezerPattern ---
$oldTweezNotify = @'
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
'@
$newTweezNotify = @'
void notifyTweezerPattern(string patternType, double price, datetime time)
{
   bool isBull = (StringFind(patternType, "Bottom") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;

   string message = StringFormat(
      "[Pattern] %s %s – %s at %s\nPrice: %s\nMA: %s",
      _Symbol, EnumToString(_Period), patternType,
      TimeToString(time, TIME_DATE|TIME_MINUTES),
      DoubleToString(price, _Digits), getMaAlignment());
   sendAlert(message);
   registerSignal(patternType, isBull);
}
'@
$c = $c.Replace($oldTweezNotify, $newTweezNotify)

# --- notifyPinBar ---
$oldPinNotify = @'
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
'@
$newPinNotify = @'
void notifyPinBar(string patternType, double price, datetime time)
{
   bool isBull = (patternType == "Hammer");
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;

   string message = StringFormat(
      "[Pattern] %s %s – %s at %s\nPrice: %s\nMA: %s",
      _Symbol, EnumToString(_Period), patternType,
      TimeToString(time, TIME_DATE|TIME_MINUTES),
      DoubleToString(price, _Digits), getMaAlignment());
   sendAlert(message);
   registerSignal(patternType, isBull);
}
'@
$c = $c.Replace($oldPinNotify, $newPinNotify)

# --- notifyOrderBlock ---
$oldOBNotify = @'
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
'@
$newOBNotify = @'
void notifyOrderBlock(string patternType, double high, double low, datetime time)
{
   bool isBull = (StringFind(patternType, "Bullish") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;

   string message = StringFormat(
      "[Order Block] %s %s – %s at %s\nZone: %s – %s\nMA: %s",
      _Symbol, EnumToString(_Period), patternType,
      TimeToString(time, TIME_DATE|TIME_MINUTES),
      DoubleToString(low, _Digits), DoubleToString(high, _Digits), getMaAlignment());
   sendAlert(message);
   registerSignal(patternType, isBull);
}
'@
$c = $c.Replace($oldOBNotify, $newOBNotify)

# --- notifySupplyDemand ---
$oldSDNotify = @'
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
'@
$newSDNotify = @'
void notifySupplyDemand(string patternType, double top, double bottom, datetime time)
{
   bool isBull = (patternType == "DemandZone");
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;

   string message = StringFormat(
      "[S/D Zone] %s %s – %s at %s\nZone: %s – %s\nMA: %s",
      _Symbol, EnumToString(_Period), patternType,
      TimeToString(time, TIME_DATE|TIME_MINUTES),
      DoubleToString(bottom, _Digits), DoubleToString(top, _Digits), getMaAlignment());
   sendAlert(message);
   registerSignal(patternType, isBull);
}
'@
$c = $c.Replace($oldSDNotify, $newSDNotify)

# --- notifyBOS ---
$oldBOSNotify = @'
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
'@
$newBOSNotify = @'
void notifyBOS(string bosType, double level, datetime time)
{
   bool isBull = (StringFind(bosType, "Bullish") >= 0);
   if(enableTrendFilter && isBull  && !isBullishTrend()) return;
   if(enableTrendFilter && !isBull && !isBearishTrend()) return;

   string message = StringFormat(
      "[BOS] %s %s – %s at %s\nLevel: %s\nMA: %s",
      _Symbol, EnumToString(_Period), bosType,
      TimeToString(time, TIME_DATE|TIME_MINUTES),
      DoubleToString(level, _Digits), getMaAlignment());
   sendAlert(message);
   registerSignal(bosType, isBull);
}
'@
$c = $c.Replace($oldBOSNotify, $newBOSNotify)

# ============================================================
# STEP 13 – Remove dead functions: currentTimeFrame() and
#            trendAndRangeDetector()
# ============================================================
$c = $c -replace '(?s)//\+---.*?\|\s*Helper function to get current timeframe.*?\+---.*?\r?\nstring currentTimeFrame\(\).*?\}\r?\n', ''
$c = $c.Replace(
    'void trendAndRangeDetector(){' + "`n" + '}',
    ''
)

# ============================================================
# STEP 14 – Enhanced dashboard: add MA alignment + signal summary
# ============================================================
$oldDashEnd = @'
   else
   {
      dash += "--- No open position ---\n";
   }

   Comment(dash);
}
'@

$newDashEnd = @'
   else
   {
      dash += "--- No open position ---\n";
   }

   // ---- MA alignment ----
   dash += "--- MA Alignment ---\n";
   dash += getMaAlignment() + "\n";

   // ---- Signal summary (last closed bar) ----
   dash += "--- Pattern Signals (Last Bar) ---\n";
   if(g_bullishCount > 0)
      dash += StringFormat("Bullish x%d: %s\n", g_bullishCount, g_confluenceNames);
   if(g_bearishCount > 0)
      dash += StringFormat("Bearish x%d: %s\n", g_bearishCount, g_confluenceNames);
   if(g_bullishCount == 0 && g_bearishCount == 0)
      dash += "No patterns on last bar\n";

   Comment(dash);
}
'@
$c = $c.Replace($oldDashEnd, $newDashEnd)

# ============================================================
# STEP 15 – Also replace the P&L update sendAlert/SendNotification
# ============================================================
$c = $c.Replace(
    '   Print(message);' + "`n" +
    '   Alert(message);' + "`n" +
    '   if(!MQL5InfoInteger(MQL5_TESTING))' + "`n" +
    '      SendNotification(message);' + "`n" + "`n" +
    '   lastProfitNotifyTime = currentTime;',
    '   sendAlert(message);' + "`n" +
    '   lastProfitNotifyTime = currentTime;'
)

# ============================================================
# VERIFY ALL CHANGES
# ============================================================
$checks = @(
    @{Label='Alert control inputs';        Token='enableAlerts'},
    @{Label='Push control input';          Token='enablePushNotifications'},
    @{Label='Trend filter input';          Token='enableTrendFilter'},
    @{Label='Confluence globals';          Token='g_bullishCount'},
    @{Label='sendAlert() helper';          Token='void sendAlert('},
    @{Label='isBullishTrend() helper';     Token='void isBullishTrend'},
    @{Label='getMaAlignment() helper';     Token='void getMaAlignment'},
    @{Label='registerSignal() helper';     Token='void registerSignal('},
    @{Label='FVG bullish fix';             Token='c1.low > c3.high'},
    @{Label='FVG bearish fix';             Token='c1.high < c3.low'},
    @{Label='isUptrend no leak';           Token='return isBullishTrend()'},
    @{Label='BOS separate lastBOSTimes';   Token='lastBullishBOSTime'},
    @{Label='SD zone fix';                 Token='MathMax(prev3.open, prev3.close)'},
    @{Label='MA crossover notification';   Token='MA BullishCross'},
    @{Label='Stoch notification';          Token='Stoch OversoldExit'},
    @{Label='Dashboard MA alignment';      Token='--- MA Alignment ---'},
    @{Label='Dashboard signals';           Token='Pattern Signals (Last Bar)'},
    @{Label='Dead var removed';            Token='lastCurrentPrice'},
    @{Label='Dead func removed';           Token='trendAndRangeDetector'}
)

$pass = 0; $fail = 0
foreach($ch in $checks) {
    $found = $c.Contains($ch.Token)
    # For removals, we want NOT found
    if($ch.Label -like '*removed*') { $found = !$found }
    if($found) { Write-Host "PASS: $($ch.Label)"; $pass++ }
    else        { Write-Host "FAIL: $($ch.Label)"; $fail++ }
}
Write-Host ""
Write-Host "Results: $pass passed, $fail failed"

if($fail -eq 0) {
    [System.IO.File]::WriteAllText($fp, $c, [System.Text.Encoding]::Unicode)
    Write-Host "SUCCESS – File written. Total chars: $($c.Length)"
} else {
    Write-Host "ABORTED – Fix failures above before writing."
}
