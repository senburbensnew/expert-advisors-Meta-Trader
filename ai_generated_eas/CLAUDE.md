# CLAUDE.md — deepseek_ma_crossover EA

## Project

MQL5 Expert Advisor for MetaTrader 5.
Main file: `deepseek_ultimate_expert_advisor.mq5`

---

## File encoding — CRITICAL

After all transformations, `deepseek_ultimate_expert_advisor.mq5` is now **plain UTF-8 (no BOM)**.
MetaEditor accepts plain UTF-8 — do NOT add any BOM when writing back.

**PHP read/write pattern:**
```php
$raw = file_get_contents($fp);
// Strip UTF-8 BOM if present (3 bytes: ef bb bf)
$c = (substr($raw, 0, 3) === "\xef\xbb\xbf") ? substr($raw, 3) : $raw;
$c = str_replace(["\r\n", "\r"], "\n", $c);
$c = preg_replace('/[ \t]+\n/', "\n", $c); // strip trailing whitespace
// ... modifications ...
file_put_contents($fp, $c); // plain UTF-8, no BOM
```

**NEVER use single-quoted PHP strings for BOM bytes** — `'\xef\xbb\xbf'` writes literal text, not bytes.
Use double-quoted `"\xef\xbb\xbf"` or `chr(0xef).chr(0xbb).chr(0xbf)`.

**Python is NOT available** (`C:\python312\python.exe` missing).
PHP is at `C:\php\php.exe`.

---

## Moving average architecture (current)

| Variable          | Period | Type | Object name |
|-------------------|--------|------|-------------|
| `fastMaHandler`   | 21     | EMA  | `"EMA21"`   |
| `middleMaHandler` | 50     | EMA  | `"EMA50"`   |
| `slowMaHandler`   | 200    | SMA  | `"SMA200"`  |
| `maHandle`        | 50     | SMA  | (internal)  |

`maHandle` (SMA50) is reused by `isUptrend`/`isDowntrend`, `isBullishTrend`, `isBearishTrend`, `detectTrendReversal`.
Do **not** create new `iMA()` handles inside per-tick functions — memory leak.

---

## Notification architecture

All notifications go through a single dispatcher. No direct `Alert()` or `SendNotification()` calls.

```mql5
void sendAlert(const string msg)   // phone push only by default
void registerSignal(name, isBull)  // tracks confluence; fires alert at 2+ signals
```

Input flags:
- `enableAlerts = false`           — popup alerts (disabled by default)
- `enablePushNotifications = true` — mobile push (enabled by default)
- `enableTrendFilter = false`      — skip patterns not aligned with SMA50 trend

Backtesting skip: `if(MQLInfoInteger(MQL_TESTER)) return;`
(NOT `MQL5InfoInteger(MQL5_TESTING)` — deprecated and wrong function)

---

## Key functions added / changed

| Function | Purpose |
|---|---|
| `sendAlert(msg)` | Unified dispatcher — phone only, skips during backtesting |
| `isBullishTrend()` / `isBearishTrend()` | Reuse `maHandle` (SMA50), no leak |
| `getMaAlignment()` | Returns human-readable EMA21/EMA50/SMA200 alignment string |
| `registerSignal(name, bull)` | Confluence tracker; fires alert when 2+ signals agree |
| `detectTrendReversal()` | EMA21 crosses above/below SMA50 — phone notification |
| `checkProfitNotification()` | P&L update every N minutes while in trade |
| `updateDashboard()` | On-chart `Comment()` panel with position, P&L, MA, patterns |

---

## Bugs fixed

| Bug | Fix |
|---|---|
| FVG double-gap logic (nearly impossible to trigger) | Standard ICT: `c1.low > c3.high` (bull), `c1.high < c3.low` (bear) |
| `isUptrend`/`isDowntrend` creating new `iMA` handle on every tick | Replaced with `isBullishTrend()`/`isBearishTrend()` (reuse `maHandle`) |
| Single shared `lastBOSTime` blocked alternating BOS signals | Split into `lastBullishBOSTime` / `lastBearishBOSTime` |
| Supply/Demand zone using arbitrary `baseMove * 0.5` offset | Zone = body of impulse candle (`MathMax/Min(open, close)`) |
| `maxLotSize` local variable shadowing global input | Renamed local to `brokerMaxLot` |
| `currentTimeFrame()` dead function (never called) | Removed |
| Commented-out `runAllPatternDetectors(int lookbackPeriod)` block | Removed |
| `trendAndRangeDetector()` empty function | Removed |
| Dead global `lastCurrentPrice` | Removed |

## Compilation errors fixed (post-enhance_ea.php)

| Error | Fix |
|---|---|
| `bullishCross`/`bearishCross` declared twice in `OnTick` | Removed old `// Simplified crossover detection` block |
| `MQL5_TESTING` deprecated | `MQL5InfoInteger(MQL5_TESTING)` → `MQLInfoInteger(MQL_TESTER)` |
| `double fast[3], slow[3]` static arrays in `detectTrendReversal` | Changed to `double fast[], slow[]` |
| `int maHandle` param shadows global in `priceCrosses50` | Renamed param to `pHandle` |
| `double maValues[2]`, `double closePrices[2]` static arrays | Changed to `double maValues[]`, `double closePrices[]` |
| `MqlRates candles[2]` static in `tweezersTopAndBottomDetector` | Changed to `MqlRates candles[]` + `ArrayResize(candles, 2)` |
| `ColorToARGB()` returns `uint`, assigned to `color` | Added `(color)` cast in `drawFVG` and `haramiDetector` |

---

## Dead code removed

- `lastCurrentPrice` global variable
- `currentTimeFrame()` function and its comment header
- `trendAndRangeDetector()` empty function
- `twentyoneMaPeriod` / `twentyoneMaHandler` (EMA8 and the old 21-period handler)
- `fastMaPeriod = 8` (EMA8) input
- Commented-out `runAllPatternDetectors(int lookbackPeriod)` block
- All direct `Alert()` / `SendNotification()` calls across pattern detectors

---

## Scripts in this folder

| Script | Purpose |
|---|---|
| `enhance_ea.php` | Full enhancement — 38 replacements on the original file |
| `fix_errors.php` | Compilation error fixes applied after enhance_ea.php |

**Note:** `enhance_ea.php` was written for the original UTF-16 file. The current file is plain UTF-8.
If re-running from scratch, use the original `.mq5` backup or re-run both scripts in sequence.

---

## Other EAs fixed this session

**`double_t0p_bottom/double_t0p_bottom.mq5`** — MQL4 → MQL5 migration:
- `High[i]` / `Low[i]` / `Time[i]` → `iHigh()`/ `iLow()` / `iTime()` functions
- `Bars` → `iBars(_Symbol, _Period)`
- `trade.Sell(..., tp, 0, "comment")` → removed extra `0` param (CTrade takes 6 args, not 7)
- Script: `double_t0p_bottom/fix_double.php`

---

## Next steps

1. **Backtest** `deepseek_ultimate_expert_advisor.mq5` — verify FVG, BOS, trend reversal signals fire correctly.
2. **Live demo** — attach to chart with `enablePushNotifications = true`, confirm phone notifications arrive.
3. Optional: add `lotSize` auto-calculation based on `riskPercentage` and actual SL distance.
4. Optional: `enableTrendFilter = true` to suppress counter-trend pattern noise.
5. Optional: backtest `double_t0p_bottom.mq5` to validate double top/bottom detection logic.
