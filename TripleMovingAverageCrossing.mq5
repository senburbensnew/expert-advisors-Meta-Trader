#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

input int fastMaPeriod = 8;
input int middleMaPeriod = 55;
input int slowMaPeriod = 200;
input double riskPercent = 1.0; // risk % of acccount balance
input int tpRatio = 5;

int fastMaHandler;
int middleMaHandler;
int slowMaHandler;

double fastMa[];
double middleMa[];
double slowMa[]; 
  
int rsiHandler;
int enveloppesHandler1;
int enveloppesHandler2;

CTrade trade;

enum PositionDirection{ Buy, Sell, DoNothing };   
PositionDirection trendDirection = PositionDirection::DoNothing;

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
    
   trendDirection = checkIfFastMaIsAboveOrBelowSlowMa();
   
   return(INIT_SUCCEEDED);
}

PositionDirection checkIfFastMaIsAboveOrBelowSlowMa(){
   PositionDirection actionToTake =  PositionDirection::DoNothing;
   
   CopyBuffer(fastMaHandler, MAIN_LINE, 1, 2, fastMa);
   CopyBuffer(middleMaHandler, MAIN_LINE, 1, 2, middleMa);
   CopyBuffer(slowMaHandler, MAIN_LINE, 1, 2, slowMa); 
   
   if(fastMa[1] > middleMa[1] && middleMa[1] > slowMa[1]){ 
      actionToTake = PositionDirection::Buy;
   }else if(fastMa[1] < middleMa[1] && middleMa[1] < slowMa[1]){
      actionToTake = PositionDirection::Sell;
   }
   
   return actionToTake;
}  

void OnDeinit(const int reason){}

void OnTick(){ 
   PositionDirection checkForNewDirection = checkIfFastMaIsAboveOrBelowSlowMa();
   bool positionAlreadyTakenForCurrentSymbol = chekIfPositionForCurrentSymbolIsAlreadyOpen();
   
   if(PositionsTotal() == 0){
     if(trendDirection != checkForNewDirection && checkForNewDirection == PositionDirection::Buy){
        SendNotification("Buy opportunity signal.");
        double ask = getAskPrice();
        double sl = calculateStopLoss();
        double tp = calculateTakeProfit(PositionDirection::Buy, ask, sl);
        // trade.Buy(calculateLotSize(ask-sl), _Symbol, ask, sl, tp);
        // string message = "Buy position taken for " + _Symbol;
        // SendNotification(message);
        trendDirection = checkForNewDirection;
     }else if(trendDirection != checkForNewDirection && checkForNewDirection == PositionDirection::Sell){
        SendNotification("Sell opportunity signal.");
        double bid = getBidPrice();
        double sl = calculateStopLoss();
        double tp = calculateTakeProfit(PositionDirection::Sell, bid, sl);
        // trade.Sell(calculateLotSize(sl-bid), _Symbol, bid, sl, tp);
        // string message = "Sell position taken for " + _Symbol;
        // SendNotification(message);
        trendDirection = checkForNewDirection;
     }
   }else{
      checkForUpdateSLAndTP();
   }
      
   Comment("fastMa[0] : ", DoubleToString(fastMa[0], _Digits),
           " | fastMa[1] : ", DoubleToString(fastMa[1], _Digits),
           "\nslowMa[0] : ", DoubleToString(slowMa[0], _Digits),
           " | slowMa[1] : ", DoubleToString(slowMa[1], _Digits),
           "\nPositionsTotal : ", PositionsTotal()); 
}

void checkForUpdateSLAndTP(){}

bool chekIfPositionForCurrentSymbolIsAlreadyOpen(){
   bool positionAlreadyOpen = false;
   return false;
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
     double sl = slowMa[1];
     Print("slowMa[1] ===> ", slowMa[1]);
     sl = NormalizeDouble(sl, _Digits); 
     return sl;
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
}
