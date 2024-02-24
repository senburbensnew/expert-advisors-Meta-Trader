#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

input int fastMA_period = 8;
input int slowMA_period = 55;
input int twoHundredSMA_period = 200;
input double lotSize = 0.01;
input int InputStopLoss = 100;
input int InputTakeProfit = 200;
input double TrailStop = 100; 

// Define variable for storing MA values
int fastHandlerMA;
int slowHandlerMA;
int twoHundredSMAHandler;
int rsiHandler;
int enveloppesHandler1;
int enveloppesHandler2;
int volumesHandler;

double fastBuffer[];
double slowBuffer[];
datetime openTimeBuy = 0;
datetime openTimeSell = 0;

double AccountBalance = 0.0;

CTrade trade;

int OnInit(){   
   AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   Print("ACCOUNT_BALANCE = $", AccountBalance);
   
   if(!checkIfParametersValuesAreCorrect()){
      return INIT_PARAMETERS_INCORRECT;
   }      
   
   fastHandlerMA = iMA(_Symbol, PERIOD_CURRENT, fastMA_period, 0, MODE_EMA, PRICE_CLOSE);
   slowHandlerMA = iMA(_Symbol, PERIOD_CURRENT, slowMA_period, 0, MODE_EMA, PRICE_CLOSE);  
   twoHundredSMAHandler = iMA(_Symbol, PERIOD_CURRENT, twoHundredSMA_period, 0, MODE_SMA, PRICE_CLOSE);
   // Add RSI indicator in subwindow 1
   rsiHandler = iRSI(_Symbol, PERIOD_CURRENT, 1, PRICE_CLOSE);
   // Add enveloppes 1 indicator in subwindow 1  
   enveloppesHandler1 = iEnvelopes(_Symbol, PERIOD_CURRENT, 1, 0, MODE_SMMA, PRICE_CLOSE, 6.000);   
   // Add enveloppes 2 indicator in subwindow 1  
   enveloppesHandler2 = iEnvelopes(_Symbol, PERIOD_CURRENT, 1, 0, MODE_SMMA, PRICE_CLOSE, 0.0008);
   // Volumes indicator
   volumesHandler = iVolume(_Symbol, PERIOD_CURRENT, VOLUME_TICK);

   
   if(!checkIfHanlersCreationHasSucceed()){
      return INIT_FAILED;
   }   
   
   ChartIndicatorAdd(ChartID(), 0, fastHandlerMA); 
   ChartIndicatorAdd(ChartID(), 0, slowHandlerMA); 
   ChartIndicatorAdd(ChartID(), 0, twoHundredSMAHandler);
   ChartIndicatorAdd(ChartID(), 1, rsiHandler);  
   ChartIndicatorAdd(ChartID(), 1, enveloppesHandler1);  
   ChartIndicatorAdd(ChartID(), 1, enveloppesHandler2); 
   ChartIndicatorAdd(ChartID(), 1, volumesHandler); 
         
   ArraySetAsSeries(fastBuffer,true);
   ArraySetAsSeries(slowBuffer,true);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   if(fastHandlerMA != INVALID_HANDLE)
      IndicatorRelease(fastHandlerMA);
   if(slowHandlerMA != INVALID_HANDLE)
      IndicatorRelease(slowHandlerMA);
}

void OnTick(){
   int values = CopyBuffer(fastHandlerMA,0,0,2,fastBuffer);
   if(values != 2){
      Print("Not enough data for fast moving average");
      return;
   }
   values = CopyBuffer(slowHandlerMA,0,0,2,slowBuffer);
   if(values != 2){
      Print("Not enough data for slow moving average");
      return;
   }
   Comment("fast[0]", fastBuffer[0], "\n",
           "fast[1]", fastBuffer[1], "\n",
           "slow[0]", slowBuffer[0], "\n",
           "slow[1]", slowBuffer[1]);  
           
   // check for cross buy
   if(fastBuffer[1] <= slowBuffer[1] && fastBuffer[0] > slowBuffer[0] && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT,0)){
      openTimeBuy = iTime(_Symbol, PERIOD_CURRENT,0);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = ask - InputStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tp = ask + InputTakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lotSize, ask, sl, tp,"Cross EA");
      string message = "Buy position taken for " + _Symbol;
      SendNotification(message);
   }
   
   // check for cross sell
   if(fastBuffer[1] >= slowBuffer[1] && fastBuffer[0] < slowBuffer[0] && openTimeSell != iTime(_Symbol, PERIOD_CURRENT,0)){
      openTimeSell = iTime(_Symbol, PERIOD_CURRENT,0);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = bid + InputStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tp = bid - InputTakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, lotSize, bid, sl, tp,"Cross EA");
      string message = "Sell position taken for " + _Symbol;
      SendNotification(message);
   }  
}

bool checkIfParametersValuesAreCorrect(){
   bool parametersAreCorrect = true;   
   if(fastMA_period <= 0){
      Alert("Fast moving average period <= 0");
      parametersAreCorrect = false;
   }
   if(slowMA_period <= 0){
      Alert("Slow moving average period <= 0");
      parametersAreCorrect = false;
   }
   if(fastMA_period >= slowMA_period){
      Alert("Fast period >= slow period");
      parametersAreCorrect = false;
   }
   if(lotSize < 0.01){
      Alert("lot size not correct");
      parametersAreCorrect = false;
   }
   if(InputStopLoss <= 0){
      Alert("Stop loss <= 0");
      parametersAreCorrect = false;
   }
   if(InputTakeProfit <= 0){
      Alert("TakeProfit <= 0");
      parametersAreCorrect = false;
   }
   return parametersAreCorrect;
}

bool checkIfHanlersCreationHasSucceed(){
   bool creationSucceed = true;    
   if(fastHandlerMA == INVALID_HANDLE){
      Alert("Failed to create fast handler");
      creationSucceed = false;
   }   
   if(slowHandlerMA == INVALID_HANDLE){
      Alert("Failed to create slow handler");
      creationSucceed = false;
   }
   if(twoHundredSMAHandler == INVALID_HANDLE){
      Alert("Failed to create twoHundredSMAHandler handler");
      creationSucceed = false;
   }
   if(rsiHandler == INVALID_HANDLE){
      Alert("Failed to create rsiHandler handler");
      creationSucceed = false;
   }  
   if(enveloppesHandler1 == INVALID_HANDLE){
      Alert("Failed to create enveloppesHandler1 handler");
      creationSucceed = false;
   }  
   if(enveloppesHandler2 == INVALID_HANDLE){
      Alert("Failed to create enveloppesHandler2 handler");
      creationSucceed = false;
   }if(volumesHandler == INVALID_HANDLE){
      Alert("Failed to create volumesHandler handler");
      creationSucceed = false;
   }
   return creationSucceed;
}
