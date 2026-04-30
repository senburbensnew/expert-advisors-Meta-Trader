<?php
$fp = 'c:\Users\rubens\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\deepseek_ma_crossover\deepseek_ultimate_expert_advisor.mq5';

// File is now UTF-8 with BOM (written by enhance_ea.php)
$raw = file_get_contents($fp);
if (substr($raw, 0, 3) === "\xef\xbb\xbf") {
    $c = substr($raw, 3); // strip UTF-8 BOM
} else {
    $c = mb_convert_encoding($raw, 'UTF-8', 'UTF-16'); // fallback for UTF-16
}
$c = str_replace(["\r\n", "\r"], "\n", $c);

$fails = [];
function R(string &$c, string $old, string $new, string $label): void {
    global $fails;
    if (strpos($c, $old) === false) { $fails[] = "FAIL [$label]"; return; }
    $c = str_replace($old, $new, $c);
    echo "OK   [$label]\n";
}

// ============================================================
// 1. Remove duplicate bullishCross/bearishCross (ERROR)
// ============================================================
R($c,
    '   // Simplified crossover detection (fastMA vs middleMA only)
   bool bullishCross = (fastMa[0] > middleMa[0]) && (fastMa[1] <= middleMa[1]);
   bool bearishCross = (fastMa[0] < middleMa[0]) && (fastMa[1] >= middleMa[1]);
',
    '',
    'Remove duplicate crossover vars'
);

// ============================================================
// 2. Fix deprecated MQL5_TESTING → MQL_TESTER (WARNING)
// ============================================================
R($c,
    'MQL5InfoInteger(MQL5_TESTING)',
    'MQL5InfoInteger(MQL_TESTER)',
    'Fix MQL5_TESTING deprecated'
);

// ============================================================
// 3. Fix detectTrendReversal static arrays (WARNING lines 129-130)
// ============================================================
R($c,
    '   double fast[3], slow[3];
   if(CopyBuffer(fastMaHandler, 0, 1, 3, fast) < 3) return;
   if(CopyBuffer(maHandle,      0, 1, 3, slow) < 3) return;
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);',
    '   double fast[], slow[];
   if(CopyBuffer(fastMaHandler, 0, 1, 3, fast) < 3) return;
   if(CopyBuffer(maHandle,      0, 1, 3, slow) < 3) return;
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);',
    'Fix detectTrendReversal dynamic arrays'
);

// ============================================================
// 4. Fix priceCrosses50: param shadows global + static arrays (WARNING)
// ============================================================
R($c,
    'void priceCrosses50MovingAverageDetector(int maHandle)
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
    if(CopyClose(_Symbol, _Period, 0, 2, closePrices) != 2)',
    'void priceCrosses50MovingAverageDetector(int pHandle)
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
    if(CopyClose(_Symbol, _Period, 0, 2, closePrices) != 2)',
    'Fix priceCrosses50 param shadow + arrays'
);

// ============================================================
// 5. Fix tweezersTopAndBottomDetector static MqlRates (WARNING line 1095)
// ============================================================
R($c,
    '   MqlRates candles[2];
   ArraySetAsSeries(candles, true);',
    '   MqlRates candles[];
   ArrayResize(candles, 2);
   ArraySetAsSeries(candles, true);',
    'Fix tweezers static MqlRates array'
);

// ============================================================
// 6. Fix ColorToARGB uint->color cast (WARNING lines 578, 1024)
// ============================================================
R($c,
    '    color transparentClr = ColorToARGB(clr, 25);',
    '    color transparentClr = (color)ColorToARGB(clr, 25);',
    'Fix ColorToARGB cast in drawFVG'
);

R($c,
    '         color patternColor = isBullishHarami ? ColorToARGB(clrDodgerBlue, 255) :
                              ColorToARGB(clrOrangeRed, 255);',
    '         color patternColor = isBullishHarami ? (color)ColorToARGB(clrDodgerBlue, 255) :
                              (color)ColorToARGB(clrOrangeRed, 255);',
    'Fix ColorToARGB cast in haramiDetector'
);

// ============================================================
// REPORT
// ============================================================
if (!empty($fails)) {
    echo "\n=== FAILURES ===\n";
    foreach ($fails as $f) echo "  $f\n";
    echo "File NOT written.\n";
    exit(1);
}

// Write back UTF-8 with BOM
file_put_contents($fp, "\xef\xbb\xbf" . $c);
echo "\nSUCCESS – file written.\n";
