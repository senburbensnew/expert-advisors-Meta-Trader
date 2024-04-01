#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

input int fastMaPeriod = 8;
input int middleMaPeriod = 55;
input int slowMaPeriod = 200;

input float lotsize = 0.01;
input float slFactor = 1;
input float tpFactor = 10;
input float trailingStop = 50.0;

input double riskPercent = 1.0; // risk % of acccount balance
input int tpRatio = 4;

int slowMaHandler;
int fastMaHandler;
int middleMaHandler;

int rsiHandler;
int enveloppesHandler1;
int enveloppesHandler2;

enum PositionDirection{ NoTrend, Bullish, Bearish };   
PositionDirection trendDirection = PositionDirection::NoTrend;
enum PriceAboveSlowMa { Above, Below, NA };  
PriceAboveSlowMa priceAboveSlowMA = PriceAboveSlowMa::NA;

CTrade trade;

int OnInit(){  
   fastMaHandler = iMA(_Symbol, PERIOD_CURRENT, fastMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   middleMaHandler = iMA(_Symbol, PERIOD_CURRENT, middleMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowMaHandler = iMA(_Symbol, PERIOD_CURRENT, slowMaPeriod, 0, MODE_SMA, PRICE_CLOSE);

   rsiHandler = iRSI(_Symbol, PERIOD_CURRENT, 1, PRICE_CLOSE); // Add RSI indicator in subwindow 1 
   enveloppesHandler1 = iEnvelopes(_Symbol, PERIOD_CURRENT, 1, 0, MODE_SMMA, PRICE_CLOSE, 6.000); // Add enveloppes 1 indicator in subwindow 1   
   enveloppesHandler2 = iEnvelopes(_Symbol, PERIOD_CURRENT, 1, 0, MODE_SMMA, PRICE_CLOSE, 0.0008); // Add enveloppes 2 indicator in subwindow 1  

   ChartIndicatorAdd(ChartID(), 0, fastMaHandler); 
   ChartIndicatorAdd(ChartID(), 0, middleMaHandler); 
   ChartIndicatorAdd(ChartID(), 0, slowMaHandler);
       
   ChartIndicatorAdd(ChartID(), 1, rsiHandler);  
   ChartIndicatorAdd(ChartID(), 1, enveloppesHandler1);  
   ChartIndicatorAdd(ChartID(), 1, enveloppesHandler2); 
   
   checkPriceAboveSlowMA();
   
   return(INIT_SUCCEEDED);
}

void checkPriceAboveSlowMA(){
  double slowMaBufferValue[];  
  CopyBuffer(slowMaHandler, MAIN_LINE, 1, 2, slowMaBufferValue);
  double slowMaValue = NormalizeDouble(slowMaBufferValue[1], _Digits);
  double ask = getAskPrice();
  double bid = getBidPrice();
  
  if(bid > slowMaValue && ask > slowMaValue){
    priceAboveSlowMA = PriceAboveSlowMa::Above;
  }else if(bid < slowMaValue && ask < slowMaValue){
    priceAboveSlowMA = PriceAboveSlowMa::Below;
  }
}

void OnDeinit(const int reason){}

void OnTick(){
  double slowMaBufferValue[];  
  double fastMaBufferValue[];  
  double middleMaBufferValue[];  
  
  CopyBuffer(slowMaHandler, MAIN_LINE, 1, 2, slowMaBufferValue);
  CopyBuffer(fastMaHandler, MAIN_LINE, 1, 2, fastMaBufferValue);
  CopyBuffer(middleMaHandler, MAIN_LINE, 1, 2, middleMaBufferValue);
  
  double slowMaValue = NormalizeDouble(slowMaBufferValue[1], _Digits); 
  double fastMaValue = NormalizeDouble(fastMaBufferValue[1], _Digits); 
  double middleMaValue = NormalizeDouble(middleMaBufferValue[1], _Digits); 
      
  double ask = getAskPrice();
  double bid = getBidPrice();

  if(PositionsTotal() != 0){ return; }
  
  if(trendDirection != PositionDirection::Bullish && bid > slowMaValue && ask > slowMaValue){
     if(priceAboveSlowMA != PriceAboveSlowMa::Above){
      string message = "" + _Symbol + ":" + currentTimeFrame() + " => Price crossed above SLOW MA => Buy signal opportunity.";
      Print(message);
      SendNotification(message);
      // trade.Buy(lotsize, _Symbol, ask, ask - 0.0020, ask + (5 * 0.0020));
      priceAboveSlowMA = PriceAboveSlowMa::Above;
      trendDirection = PositionDirection::Bullish;
     };
     /* if(fastMaBufferValue[1] > middleMaBufferValue[1] && middleMaBufferValue[1] > slowMaBufferValue[1]){
        string message = "" + _Symbol + ":" + currentTimeFrame() + " ===> Buy signal opportunity.";
        Print(message);
        SendNotification(message);
        // trade.Buy(lotsize, _Symbol, ask, ask - 0.0010, ask + (5 * 0.0010)); 
        trendDirection = PositionDirection::Bullish;
     }*/
  }else if(trendDirection != PositionDirection::Bearish && bid < slowMaValue && ask < slowMaValue){
     if(priceAboveSlowMA != PriceAboveSlowMa::Below){
      string message = "" + _Symbol + ":" + currentTimeFrame() + " => Price crossed below SLOW MA => Sell signal opportunity.";
      Print(message);
      SendNotification(message);
      // trade.Sell(lotsize, _Symbol, bid, bid + 0.0020, bid - (5 * 0.0020)); 
      priceAboveSlowMA = PriceAboveSlowMa::Below;
      trendDirection = PositionDirection::Bearish;
     }
     /* if(fastMaBufferValue[1] < middleMaBufferValue[1] && middleMaBufferValue[1] < slowMaBufferValue[1]){
        string message = "" + _Symbol + ":" + currentTimeFrame() + " ===> Sell signal opportunity.";
        Print(message);
        SendNotification(message);
        // trade.Sell(lotsize, _Symbol, bid, bid + 0.0010, bid - (5 * 0.0010)); 
        trendDirection = PositionDirection::Bearish;
     } */
  }
  
  double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
  double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
  double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);   
  double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent / 100;
  // double moneyLotStep = (slDistance / tickSize) * tickValue * lotStep;
  // double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;
  double pipsToRisk = riskMoney / tickValue;
  
  Comment(
      "TREND DIRECTION => ", getTrendDirection(), "\n",
      "ASK PRICE => ", DoubleToString(ask, _Digits), "\n",
      "BID PRICE => ", DoubleToString(bid, _Digits), "\n", 
      "SLOW_MA_VALUE => ", DoubleToString(slowMaValue, _Digits), "\n",
      "FAST_MA_VALUE => ", DoubleToString(fastMaValue, _Digits), "\n",
      "MIDDLE_MA_VALUE => ", DoubleToString(middleMaValue, _Digits), "\n",
      "TickSize => ", DoubleToString(tickSize, _Digits), "\n",
      "TickValue => ", DoubleToString(tickValue, _Digits), "\n",
      "LotStep => ", DoubleToString(lotStep, _Digits), "\n",
      "RiskMoney => ", DoubleToString(riskMoney, _Digits), "\n",
      "PipsToRisk => ", DoubleToString(pipsToRisk, _Digits)
  );
}

double getAskPrice(){
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK); 
   ask = NormalizeDouble(ask, _Digits); 
   return ask;
}

double getBidPrice(){
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID); 
   bid = NormalizeDouble(bid, _Digits); 
   return bid;
}

double calculateStopLoss(){
   double sl = 0.0; 
   /* double sl = slowMa[1];
   Print("slowMa[1] ===> ", slowMa[1]);
   sl = NormalizeDouble(sl, _Digits); 
   return sl; */
   return sl;
}

double calculateLotSize(double slDistance){   
   double lots = 0.0;
   /* double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);   
   
   if(tickSize == 0 || tickValue == 0 || lotStep == 0){
      Print(__FUNCTION__, " > LotSize cannot be calculated...");
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent / 100;
   double moneyLotStep = (slDistance / tickSize) * tickValue * lotStep;
   
   if(moneyLotStep == 0) {
      Print(__FUNCTION__, " > cannot divide by zero ...");
      return 0;
   }
   
   lots = MathFloor(riskMoney / moneyLotStep) * lotStep;
   Print("---------------------------------------------------------------------");            
   Print("riskMoney => ", riskMoney,
         "\nLot Size => ", lots,
         "\nslDistance => ", slDistance);
   Print("---------------------------------------------------------------------");
   
   lots = lots < 0.01 ? 0.01 : lots;*/
   return lots; 
}

/* void checkForUpdateSLAndTP(){}

bool chekIfPositionForCurrentSymbolIsAlreadyOpen(){
   bool positionAlreadyOpen = false;
   return false;
}

   
double calculateTakeProfit(PositionDirection positionDirection, double entryPrice, double sl){
     double tp = 0.0;
     switch(positionDirection){
         case PositionDirection::Buy :
            tp = entryPrice + (entryPrice - sl) * tpRatio;
            tp = NormalizeDouble(tp, _Digits);
         case PositionDirection::Sell :
            tp = entryPrice - (sl - entryPrice) * tpRatio;
            tp = NormalizeDouble(tp, _Digits);
     }
     return tp;
} 

double calculateLotSize(double slDistance){   
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);   
   
   if(tickSize == 0 || tickValue == 0 || lotStep == 0){
      Print(__FUNCTION__, " > LotSize cannot be calculated...");
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent / 100;
   double moneyLotStep = (slDistance / tickSize) * tickValue * lotStep;
   
   if(moneyLotStep == 0) {
      Print(__FUNCTION__, " > cannot divide by zero ...");
      return 0;
   }
   
   double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;
   Print("---------------------------------------------------------------------");            
   Print("riskMoney => ", riskMoney,
         "\nLot Size => ", lots,
         "\nslDistance => ", slDistance);
   Print("---------------------------------------------------------------------");
   
   lots = lots < 0.01 ? 0.01 : lots;
   return lots;
} */

string getTrendDirection(){
  string direction = "No trend";
  
  switch(trendDirection){
      case PositionDirection::NoTrend :
         direction = "No Trend";
      break;
      case PositionDirection::Bearish :
         direction = "Bearish";
      break;
      case PositionDirection::Bullish :
         direction = "Bullish";
      break;
  }
  
  return direction;
}

string currentTimeFrame(){
   string timeframe = "M1"; 
   long currentPeriod = Period();
      
   switch(currentPeriod){
      case 1:
      case 5:
      case 15:
      case 30:
        timeframe = "M"+currentPeriod;
      break;
      case 16385 :
        timeframe = "H1";
      break;
      case 16388:
        timeframe = "H4";
      break;
      case 16408:
        timeframe = "D1";
      break;
      case 32769:
        timeframe = "W1";
      break;
      case 49153:
        timeframe = "MN1";
      break;
   }   
   
   return timeframe;
}
