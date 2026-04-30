#property copyright "Copyright 2023, Your Company"
#property link      "https://www.mql5.com"
#property version   "1.00"

input int    FastEMA = 12;          // Fast EMA period
input int    SlowEMA = 26;          // Slow EMA period
input int    RSIPeriod = 14;        // RSI period
input double OversoldLevel = 30.0;  // RSI oversold level
input double OverboughtLevel = 70.0;// RSI overbought level
input int    MACDSignalPeriod = 9;  // MACD signal period

int fastEMAHandle, slowEMAHandle, rsiHandle, macdHandle;
datetime lastBarTime;

int OnInit()
{
   fastEMAHandle = iMA(_Symbol, _Period, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   slowEMAHandle = iMA(_Symbol, _Period, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, _Period, RSIPeriod, PRICE_CLOSE);
   macdHandle = iMACD(_Symbol, _Period, FastEMA, SlowEMA, MACDSignalPeriod, PRICE_CLOSE);
   
   if(fastEMAHandle == INVALID_HANDLE || slowEMAHandle == INVALID_HANDLE || 
      rsiHandle == INVALID_HANDLE || macdHandle == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
   }
   
   lastBarTime = 0;
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   IndicatorRelease(fastEMAHandle);
   IndicatorRelease(slowEMAHandle);
   IndicatorRelease(rsiHandle);
   IndicatorRelease(macdHandle);
}


void OnTick()
{
   datetime currentTime = iTime(_Symbol, _Period, 0);
   if(currentTime == lastBarTime)
      return;
   lastBarTime = currentTime;

   // Get indicator values
   double fastEMA[2], slowEMA[2], rsi[2], macdMain[2], macdSignal[2];
   
   if(CopyBuffer(fastEMAHandle, 0, 0, 2, fastEMA) < 2) return;
   if(CopyBuffer(slowEMAHandle, 0, 0, 2, slowEMA) < 2) return;
   if(CopyBuffer(rsiHandle, 0, 0, 2, rsi) < 2) return;
   if(CopyBuffer(macdHandle, MAIN_LINE, 0, 2, macdMain) < 2) return;
   if(CopyBuffer(macdHandle, SIGNAL_LINE, 0, 2, macdSignal) < 2) return;

   // Check for EMA crossover
   bool emaBullish = fastEMA[0] > slowEMA[0] && fastEMA[1] <= slowEMA[1];
   bool emaBearish = fastEMA[0] < slowEMA[0] && fastEMA[1] >= slowEMA[1];

   // Check RSI conditions
   bool rsiBullish = rsi[0] > OversoldLevel && rsi[1] <= OversoldLevel;
   bool rsiBearish = rsi[0] < OverboughtLevel && rsi[1] >= OverboughtLevel;

   // Check MACD crossover
   bool macdBullish = macdMain[0] > macdSignal[0] && macdMain[1] <= macdSignal[1];
   bool macdBearish = macdMain[0] < macdSignal[0] && macdMain[1] >= macdSignal[1];

   // Generate signals
   if((emaBullish || macdBullish) && rsiBullish){
      string message = StringFormat("Bullish reversal detected on %s %s\nRSI: %.2f\nFast EMA: %.5f\nSlow EMA: %.5f",
                                    _Symbol, EnumToString(_Period), rsi[0], fastEMA[0], slowEMA[0]);
      Print(message);
      SendNotification(message);
   }else if((emaBearish || macdBearish) && rsiBearish){
      string message = StringFormat("Bearish reversal detected on %s %s\nRSI: %.2f\nFast EMA: %.5f\nSlow EMA: %.5f",
                                    _Symbol, EnumToString(_Period), rsi[0], fastEMA[0], slowEMA[0]);
      Print(message);
      SendNotification(message);
   }
}
//+------------------------------------------------------------------+