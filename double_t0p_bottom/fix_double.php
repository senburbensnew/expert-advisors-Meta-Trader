<?php
$fp = 'c:\Users\rubens\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\double_t0p_bottom\double_t0p_bottom.mq5';

$raw = file_get_contents($fp);
if (substr($raw, 0, 3) === "\xef\xbb\xbf") {
    $c = substr($raw, 3);
    $enc = 'utf8bom';
} elseif (substr($raw, 0, 2) === "\xff\xfe") {
    $c = mb_convert_encoding($raw, 'UTF-8', 'UTF-16LE');
    $enc = 'utf16le';
} else {
    $c = $raw;
    $enc = 'utf8';
}
$c = str_replace(["\r\n", "\r"], "\n", $c);

// ============================================================
// 1. Replace MQL4 series arrays with MQL5 functions
//    High[x] → iHigh(_Symbol,_Period,x)
//    Low[x]  → iLow(_Symbol,_Period,x)
//    Time[x] → iTime(_Symbol,_Period,x)
//    Bars    → iBars(_Symbol,_Period)
// ============================================================
$c = preg_replace('/\bHigh\[([^\]]+)\]/', 'iHigh(_Symbol,_Period,$1)', $c);
$c = preg_replace('/\bLow\[([^\]]+)\]/',  'iLow(_Symbol,_Period,$1)',  $c);
$c = preg_replace('/\bTime\[([^\]]+)\]/', 'iTime(_Symbol,_Period,$1)', $c);
$c = preg_replace('/\bBars\b(?!\s*\()/',  'iBars(_Symbol,_Period)',     $c);

echo "OK   [MQL4 series arrays → MQL5 functions]\n";

// ============================================================
// 2. Fix CTrade::Sell — remove extra 0 param before comment
// ============================================================
$c = str_replace(
    'trade.Sell(LotSize, _Symbol, 0, sl, tp, 0, "Double Top Pattern Sell")',
    'trade.Sell(LotSize, _Symbol, 0, sl, tp, "Double Top Pattern Sell")',
    $c
);
echo "OK   [Fix trade.Sell param count]\n";

// ============================================================
// 3. Fix CTrade::Buy — remove extra 0 param before comment
// ============================================================
$c = str_replace(
    'trade.Buy(LotSize, _Symbol, 0, sl, tp, 0, "Double Bottom Pattern Buy")',
    'trade.Buy(LotSize, _Symbol, 0, sl, tp, "Double Bottom Pattern Buy")',
    $c
);
echo "OK   [Fix trade.Buy param count]\n";

// Write back
if ($enc === 'utf8bom') {
    file_put_contents($fp, "\xef\xbb\xbf" . $c);
} elseif ($enc === 'utf16le') {
    file_put_contents($fp, "\xff\xfe" . mb_convert_encoding($c, 'UTF-16LE', 'UTF-8'));
} else {
    file_put_contents($fp, $c);
}
echo "\nSUCCESS – file written.\n";
