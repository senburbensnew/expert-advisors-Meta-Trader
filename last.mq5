#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

input int fastMaPeriod = 8;
input int middleMaPeriod = 55;
input int slowMaPeriod = 200;

// input float lotsize = 0.01;
// input float slFactor = 1;
// input float tpFactor = 10;
// input float trailingStop = 50.0;

// input int pipsAway = 20;

// input double riskPercent = 1.0; // risk % of acccount balance
// input int tpRatio = 4;

int slowMaHandler;
int fastMaHandler;
int middleMaHandler;

// int rsiHandler;
// int enveloppesHandler1;
// int enveloppesHandler2;

enum PositionDirection{ NoTrend, Bullish, Bearish };   
PositionDirection trendDirection = PositionDirection::NoTrend;
// PositionDirection fastAndMiddleMATrendDirection = PositionDirection::NoTrend;
// PositionDirection fastAndSlowMATrendDirection = PositionDirection::NoTrend;
// PositionDirection middleAndSlowMATrendDirection = PositionDirection::NoTrend;

enum PriceAboveSlowMa { Above, Below, NA };  
PriceAboveSlowMa priceAboveSlowMA = PriceAboveSlowMa::NA;
// enum OrderDirection{Buy, Sell};

// CTrade trade;

int OnInit(){  
   // Print(calculateLotSize(1.0, calculateStopLoss(OrderDirection::Sell)));
   // testLotSize();
   
   fastMaHandler = iMA(_Symbol, PERIOD_CURRENT, fastMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   middleMaHandler = iMA(_Symbol, PERIOD_CURRENT, middleMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowMaHandler = iMA(_Symbol, PERIOD_CURRENT, slowMaPeriod, 0, MODE_SMA, PRICE_CLOSE);

   // rsiHandler = iRSI(_Symbol, PERIOD_CURRENT, 1, PRICE_CLOSE); // Add RSI indicator in subwindow 1 
   // enveloppesHandler1 = iEnvelopes(_Symbol, PERIOD_CURRENT, 1, 0, MODE_SMMA, PRICE_CLOSE, 6.000); // Add enveloppes 1 indicator in subwindow 1   
   // enveloppesHandler2 = iEnvelopes(_Symbol, PERIOD_CURRENT, 1, 0, MODE_SMMA, PRICE_CLOSE, 0.0008); // Add enveloppes 2 indicator in subwindow 1  

   ChartIndicatorAdd(ChartID(), 0, fastMaHandler); 
   ChartIndicatorAdd(ChartID(), 0, middleMaHandler); 
   ChartIndicatorAdd(ChartID(), 0, slowMaHandler);
       
   // ChartIndicatorAdd(ChartID(), 1, rsiHandler);  
   // ChartIndicatorAdd(ChartID(), 1, enveloppesHandler1);  
   // ChartIndicatorAdd(ChartID(), 1, enveloppesHandler2); 
   
   // initializeFastAndMiddleMATrendDirection();
   // initializeFastAndSlowMATrendDirection();
   // initializeMiddleAndSlowMATrendDirection();
   checkPriceAboveSlowMA();
   
   // Set a timer to call OnTimer function every 5 minutes (300 seconds)
   // EventSetTimer(300);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   // Remove the timer when the EA is removed or the terminal shuts down
   // EventKillTimer();
}

/* void OnTimer(){
   // Get the total number of open positions
   int totalPositions = PositionsTotal();
   
   // Loop through each open position
   for(int i = 0; i < totalPositions; i++){
      // Get the position ticket
      ulong positionTicket = PositionGetTicket(i);
      
      // Get the position information
      if(PositionSelectByTicket(positionTicket)){
         // Retrieve the current equity
         double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         
         // Get details of the position
         string symbol = PositionGetString(POSITION_SYMBOL);
         double volume = PositionGetDouble(POSITION_VOLUME);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double profit = PositionGetDouble(POSITION_PROFIT);
         
         // Create the notification message
         string message = StringFormat("Symbol: %s\nVolume: %.2f\nOpen Price: %.5f\nCurrent Price: %.5f\nProfit: %.2f\nCurrent Equity: %.2f",
                                       symbol, volume, openPrice, currentPrice, profit, currentEquity);
         
         // Send the notification
         if(!SendNotification(message)){
            Print("Error sending notification for position ", positionTicket);
         }
       }
    }
} */

void hasPriceCrossSlowMa(){
   double slowMaBufferValue[];
   CopyBuffer(slowMaHandler, MAIN_LINE, 1, 2, slowMaBufferValue); 
   double slowMaValue = NormalizeDouble(slowMaBufferValue[1], _Digits);    
   double ask = getAskPrice();
   ask = NormalizeDouble(ask, _Digits);    
   double bid = getBidPrice();
   bid = NormalizeDouble(bid, _Digits); 
   
   if(priceAboveSlowMA == PriceAboveSlowMa::Above && ask < slowMaValue && bid < slowMaValue){
        string message = "" + _Symbol + ":" + currentTimeFrame() + " ===> Price crosses below Slow MA.";
        SendNotification(message);
        priceAboveSlowMA = PriceAboveSlowMa::Below;
   }else if(priceAboveSlowMA == PriceAboveSlowMa::Below && ask > slowMaValue && bid > slowMaValue){
        string message = "" + _Symbol + ":" + currentTimeFrame() + " ===> Price crosses above Slow MA.";
        SendNotification(message);
        priceAboveSlowMA = PriceAboveSlowMa::Above;
   }
}

void tripleMACrossOver(){
  double slowMaBufferValue[];  
  double fastMaBufferValue[];  
  double middleMaBufferValue[];  
  
  CopyBuffer(slowMaHandler, MAIN_LINE, 1, 2, slowMaBufferValue);
  CopyBuffer(fastMaHandler, MAIN_LINE, 1, 2, fastMaBufferValue);
  CopyBuffer(middleMaHandler, MAIN_LINE, 1, 2, middleMaBufferValue);
  
  double slowMaValue = NormalizeDouble(slowMaBufferValue[1], _Digits); 
  double fastMaValue = NormalizeDouble(fastMaBufferValue[1], _Digits); 
  double middleMaValue = NormalizeDouble(middleMaBufferValue[1], _Digits); 
  
  if(trendDirection != PositionDirection::Bullish && fastMaValue > middleMaValue && middleMaValue > slowMaValue){
      string message = "" + _Symbol + ":" + currentTimeFrame() + " => Triple MA cross over => Buy signal opportunity.";
      SendNotification(message);
      trendDirection = PositionDirection::Bullish;
  }else if(trendDirection != PositionDirection::Bearish && fastMaValue < middleMaValue && middleMaValue < slowMaValue){
      string message = "" + _Symbol + ":" + currentTimeFrame() + " => Triple MA cross over => Buy signal opportunity.";
      SendNotification(message);
      trendDirection = PositionDirection::Bearish;
  }
}


void OnTick(){
  hasPriceCrossSlowMa();
  tripleMACrossOver();
  // checkIfFastMACrossMiddleMA();
  // checkIfFastMACrossSlowMA();
  // checkIfMiddleMACrossSlowMA();

  /* double slowMaBufferValue[];  
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
      if(fastMaBufferValue[1] > middleMaBufferValue[1] && middleMaBufferValue[1] > slowMaBufferValue[1]){
        string message = "" + _Symbol + ":" + currentTimeFrame() + " ===> Buy signal opportunity.";
        Print(message);
        SendNotification(message);
        // trade.Buy(lotsize, _Symbol, ask, ask - 0.0010, ask + (5 * 0.0010)); 
        trendDirection = PositionDirection::Bullish;
     }
  }else if(trendDirection != PositionDirection::Bearish && bid < slowMaValue && ask < slowMaValue){
     if(priceAboveSlowMA != PriceAboveSlowMa::Below){
      string message = "" + _Symbol + ":" + currentTimeFrame() + " => Price crossed below SLOW MA => Sell signal opportunity.";
      Print(message);
      SendNotification(message);
      // trade.Sell(lotsize, _Symbol, bid, bid + 0.0020, bid - (5 * 0.0020)); 
      priceAboveSlowMA = PriceAboveSlowMa::Below;
      trendDirection = PositionDirection::Bearish;
     }
      if(fastMaBufferValue[1] < middleMaBufferValue[1] && middleMaBufferValue[1] < slowMaBufferValue[1]){
        string message = "" + _Symbol + ":" + currentTimeFrame() + " ===> Sell signal opportunity.";
        Print(message);
        SendNotification(message);
        // trade.Sell(lotsize, _Symbol, bid, bid + 0.0010, bid - (5 * 0.0010)); 
        trendDirection = PositionDirection::Bearish;
     
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
  }*/
}

void checkPriceAboveSlowMA(){
  double slowMaBufferValue[];  
  CopyBuffer(slowMaHandler, MAIN_LINE, 1, 2, slowMaBufferValue);
  double slowMaValue = NormalizeDouble(slowMaBufferValue[1], _Digits);
  
  double ask = NormalizeDouble(getAskPrice(), _Digits);
  double bid = NormalizeDouble(getBidPrice(), _Digits);
  
  if(bid > slowMaValue && ask > slowMaValue){
    priceAboveSlowMA = PriceAboveSlowMa::Above;
  }else if(bid < slowMaValue && ask < slowMaValue){
    priceAboveSlowMA = PriceAboveSlowMa::Below;
  }
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

/* void initializeFastAndMiddleMATrendDirection(){  
  double fastMaBufferValue[];  
  double middleMaBufferValue[];  
  
  CopyBuffer(fastMaHandler, MAIN_LINE, 1, 2, fastMaBufferValue);
  CopyBuffer(middleMaHandler, MAIN_LINE, 1, 2, middleMaBufferValue);
  
  double fastMaValue = NormalizeDouble(fastMaBufferValue[1], _Digits); 
  double middleMaValue = NormalizeDouble(middleMaBufferValue[1], _Digits); 
   
   if(fastMaValue > middleMaValue){ 
      fastAndMiddleMATrendDirection = PositionDirection::Bullish;
   }else if(fastMaValue < middleMaValue){
      fastAndMiddleMATrendDirection = PositionDirection::Bearish;
   }
}

void initializeFastAndSlowMATrendDirection(){  
  double fastMaBufferValue[];  
  double slowMaBufferValue[];  
  
  CopyBuffer(fastMaHandler, MAIN_LINE, 1, 2, fastMaBufferValue);
  CopyBuffer(slowMaHandler, MAIN_LINE, 1, 2, slowMaBufferValue);
  
  double fastMaValue = NormalizeDouble(fastMaBufferValue[1], _Digits); 
  double slowMaValue = NormalizeDouble(slowMaBufferValue[1], _Digits); 
   
   if(fastMaValue > slowMaValue){ 
      fastAndSlowMATrendDirection = PositionDirection::Bullish;
   }else if(fastMaValue < slowMaValue){
      fastAndSlowMATrendDirection = PositionDirection::Bearish;
   }
}

void initializeMiddleAndSlowMATrendDirection(){  
  double middleMaBufferValue[];  
  double slowMaBufferValue[];  
  
  CopyBuffer(middleMaHandler, MAIN_LINE, 1, 2, middleMaBufferValue);
  CopyBuffer(slowMaHandler, MAIN_LINE, 1, 2, slowMaBufferValue);
  
  double middleMaValue = NormalizeDouble(middleMaBufferValue[1], _Digits); 
  double slowMaValue = NormalizeDouble(slowMaBufferValue[1], _Digits); 
   
   if(middleMaValue > slowMaValue){ 
      middleAndSlowMATrendDirection = PositionDirection::Bullish;
   }else if(middleMaValue < slowMaValue){
      middleAndSlowMATrendDirection = PositionDirection::Bearish;
   }
}

void checkIfFastMACrossMiddleMA(){
  double fastMaBufferValue[];  
  double middleMaBufferValue[];  
  
  CopyBuffer(fastMaHandler, MAIN_LINE, 1, 2, fastMaBufferValue);
  CopyBuffer(middleMaHandler, MAIN_LINE, 1, 2, middleMaBufferValue);
  
  double fastMaValue = NormalizeDouble(fastMaBufferValue[1], _Digits); 
  double middleMaValue = NormalizeDouble(middleMaBufferValue[1], _Digits); 
   
   if(fastMaValue > middleMaValue && fastAndMiddleMATrendDirection != PositionDirection::Bullish){ 
        string message = "" + _Symbol + ":" + currentTimeFrame() + " Fast MA crosses Middle MA ===> Buy signal opportunity.";
        SendNotification(message);
        fastAndMiddleMATrendDirection = PositionDirection::Bullish;
   }else if(fastMaValue < middleMaValue && fastAndMiddleMATrendDirection != PositionDirection::Bearish){
        string message = "" + _Symbol + ":" + currentTimeFrame() + " Fast MA crosses Middle MA ===> Sell signal opportunity.";
        SendNotification(message);
        fastAndMiddleMATrendDirection = PositionDirection::Bearish;
   }
} 


void checkIfFastMACrossSlowMA(){
  double fastMaBufferValue[];  
  double slowMaBufferValue[];  
  
  CopyBuffer(fastMaHandler, MAIN_LINE, 1, 2, fastMaBufferValue);
  CopyBuffer(slowMaHandler, MAIN_LINE, 1, 2, slowMaBufferValue);
  
  double fastMaValue = NormalizeDouble(fastMaBufferValue[1], _Digits); 
  double slowMaValue = NormalizeDouble(slowMaBufferValue[1], _Digits); 
   
   if(fastMaValue > slowMaValue && fastAndSlowMATrendDirection != PositionDirection::Bullish){ 
        string message = "" + _Symbol + ":" + currentTimeFrame() + " Fast MA crosses Slow MA ===> Buy signal opportunity.";
        SendNotification(message);
        fastAndSlowMATrendDirection = PositionDirection::Bullish;
   }else if(fastMaValue < slowMaValue && fastAndSlowMATrendDirection != PositionDirection::Bearish){
        string message = "" + _Symbol + ":" + currentTimeFrame() + " Fast MA crosses Slow MA ===> Sell signal opportunity.";
        SendNotification(message);
        fastAndSlowMATrendDirection = PositionDirection::Bearish;
   }
} 

void checkIfMiddleMACrossSlowMA(){
  double middleMaBufferValue[];  
  double slowMaBufferValue[];  
  
  CopyBuffer(middleMaHandler, MAIN_LINE, 1, 2, middleMaBufferValue);
  CopyBuffer(slowMaHandler, MAIN_LINE, 1, 2, slowMaBufferValue);
  
  double middleMaValue = NormalizeDouble(middleMaBufferValue[1], _Digits); 
  double slowMaValue = NormalizeDouble(slowMaBufferValue[1], _Digits); 
   
   if(middleMaValue > slowMaValue && middleAndSlowMATrendDirection != PositionDirection::Bullish){ 
        string message = "" + _Symbol + ":" + currentTimeFrame() + " Middle MA crosses Slow MA ===> Buy signal opportunity.";
        SendNotification(message);
        middleAndSlowMATrendDirection = PositionDirection::Bullish;
   }else if(middleMaValue < slowMaValue && middleAndSlowMATrendDirection != PositionDirection::Bearish){
        string message = "" + _Symbol + ":" + currentTimeFrame() + " Middle MA crosses Slow MA ===> Sell signal opportunity.";
        SendNotification(message);
        middleAndSlowMATrendDirection = PositionDirection::Bearish;
   }
} 

double calculateStopLoss(OrderDirection orderDirection){ 
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);   
   double stopLossDistance = pipsAway * point;
   double stopLossLevel = 0.0;
   
   switch(orderDirection){
      case OrderDirection::Buy :
         stopLossLevel = NormalizeDouble(getAskPrice() - stopLossDistance, _Digits);
      break;
      case OrderDirection::Sell :
         stopLossLevel = NormalizeDouble(getBidPrice() + stopLossDistance, _Digits);
      break;
   }
   
   return stopLossLevel;
}

double testLotSize(){
   double risk = 1.0;
   double stopLossLevel = calculateStopLoss(OrderDirection::Sell);
   Print(Symbol(), " stopLossLevel : ", stopLossLevel);
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE) * 10 / 100;
   Print(Symbol(), " accountBalance : ", accountBalance);
   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   Print(Symbol(), " tickValue : ", tickValue);
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   Print(Symbol(), " tickSize : ", tickSize);
   double tickValueInAccountCurrency = tickValue * tickSize;
   Print(Symbol(), " tickValueInAccountCurrency : ", tickValueInAccountCurrency);
   double riskAmount = accountBalance * risk / 100.0;
   Print(Symbol(), " riskAmount : ", riskAmount);
   double stopLossDistance = getAskPrice() - stopLossLevel;
   Print(Symbol(), " stopLossDistance : ", stopLossDistance); 
   double lotSize = riskAmount / (stopLossDistance * tickValueInAccountCurrency);
   Print(Symbol(), " lotSize : ", lotSize);
   return lotSize;
}

double calculateLotSize(double riskInPercent, double slDistance){   
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);   
   
   if(tickSize == 0 || tickValue == 0 || lotStep == 0){
      Print(__FUNCTION__, " > LotSize cannot be calculated...");
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskInPercent / 100;
   double moneyLotStep = (slDistance / tickSize) * tickValue * lotStep;
   
   if(moneyLotStep == 0) {
      Print(__FUNCTION__, " > LotSize cannot be calculated...");
      return 0;
   }
   
   double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;
      
   return lots; 
}

void checkForUpdateSLAndTP(){}

bool chekIfPositionForCurrentSymbolIsAlreadyOpen(){
   bool positionAlreadyOpen = false;
   return false;
}*/

/* double calculateTakeProfit(PositionDirection positionDirection, double entryPrice, double sl){
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
} */

/*string getTrendDirection(){
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
*/
