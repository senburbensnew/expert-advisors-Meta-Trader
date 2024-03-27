#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

input int maPeriod = 200;
input double riskPercent = 1.0; // risk % of acccount balance
input int tpRatio = 5;

int maHandler;

int rsiHandler;
int enveloppesHandler1;
int enveloppesHandler2;

enum PositionDirection{ NoCross, Bullish, Bearish };   
PositionDirection trendDirection = PositionDirection::Bullish;

CTrade trade;

int OnInit(){  
      maHandler = iMA(_Symbol, PERIOD_CURRENT, maPeriod, 0, MODE_SMA, PRICE_CLOSE);

   rsiHandler = iRSI(_Symbol, PERIOD_CURRENT, 1, PRICE_CLOSE); // Add RSI indicator in subwindow 1 
   enveloppesHandler1 = iEnvelopes(_Symbol, PERIOD_CURRENT, 1, 0, MODE_SMMA, PRICE_CLOSE, 6.000); // Add enveloppes 1 indicator in subwindow 1   
   enveloppesHandler2 = iEnvelopes(_Symbol, PERIOD_CURRENT, 1, 0, MODE_SMMA, PRICE_CLOSE, 0.0008); // Add enveloppes 2 indicator in subwindow 1  

   ChartIndicatorAdd(ChartID(), 0, maHandler);    
   ChartIndicatorAdd(ChartID(), 1, rsiHandler);  
   ChartIndicatorAdd(ChartID(), 1, enveloppesHandler1);  
   ChartIndicatorAdd(ChartID(), 1, enveloppesHandler2); 
   
   initPositionDirection();
   
   return(INIT_SUCCEEDED);
}

void initPositionDirection(){
  double maBufferValue[];  
  CopyBuffer(maHandler, MAIN_LINE, 1, 2, maBufferValue);
  
  double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits); 
  double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
  double maValue = NormalizeDouble(maBufferValue[0], _Digits); 
  
  if(bid > maValue && ask > maValue){
     trendDirection = PositionDirection::Bullish;
  }else if(bid < maValue && ask < maValue){
     trendDirection = PositionDirection::Bearish;
  }else{
     trendDirection = PositionDirection::NoCross;
  }
}

void OnDeinit(const int reason){
}

void OnTick(){
  double maBufferValue[];  
  CopyBuffer(maHandler, MAIN_LINE, 1, 2, maBufferValue);
  
  double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits); 
  double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
  double maValue = NormalizeDouble(maBufferValue[0], _Digits); 
  
  if(trendDirection != PositionDirection::Bullish && bid > maValue && ask > maValue){
     string message = "" + _Symbol + ":" + currentTimeFrame() + " ===> Buy signal opportunity.";
     Print(message);
     SendNotification(message);
     trendDirection = PositionDirection::Bullish;
  }else if(trendDirection != PositionDirection::Bearish && bid < maValue && ask < maValue){
     string message = "" + _Symbol + ":" + currentTimeFrame() + " ===> Sell signal opportunity.";
     Print(message);
     SendNotification(message);
     trendDirection = PositionDirection::Bearish;
  }
  
  Print(trendDirection, " | "
     ,DoubleToString(ask, _Digits), " | "
     ,DoubleToString(bid, _Digits), " | ", 
      DoubleToString(maValue, _Digits)
  );
}

string currentTimeFrame(){
   string timeframe = "M5"; 
   if(PERIOD_CURRENT == PERIOD_M1) {timeframe = "M1";};
   if(PERIOD_CURRENT == PERIOD_M5) {timeframe = "M5";};
   if(PERIOD_CURRENT == PERIOD_M30){timeframe = "M30";};
   if(PERIOD_CURRENT == PERIOD_H1) {timeframe = "H1";};
   if(PERIOD_CURRENT == PERIOD_H4) {timeframe = "H4";};
   if(PERIOD_CURRENT == PERIOD_D1) {timeframe = "D1";};
   if(PERIOD_CURRENT == PERIOD_W1) {timeframe = "W1";};
   if(PERIOD_CURRENT == PERIOD_MN1){timeframe = "MN";};   
   return timeframe;
}
