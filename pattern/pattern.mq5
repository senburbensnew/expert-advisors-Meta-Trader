//+------------------------------------------------------------------+
//|                                                  PatternEA.mq5   |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

// #include <Trade/Trade.mql5>

input int ZigZagDepth = 12;       // ZigZag Depth
input int ZigZagDeviation = 5;    // ZigZag Deviation
input int ZigZagBackstep = 3;     // ZigZag Backstep
input double PatternTolerance = 0.001; // Price tolerance for patterns

// ZigZag buffer
int zigzagHandle;
double zigzagHighs[], zigzagLows[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   zigzagHandle = iCustom(_Symbol, _Period, "Examples\\ZigZag", ZigZagDepth, ZigZagDeviation, ZigZagBackstep);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(IsNewBar())
   {
      CheckPatterns();
   }
}

//+------------------------------------------------------------------+
//| Check for new bar                                                |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastTime = 0;
   datetime currentTime = iTime(_Symbol, _Period, 0);
   if(lastTime != currentTime)
   {
      lastTime = currentTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Main pattern checking function                                   |
//+------------------------------------------------------------------+
void CheckPatterns()
{
   GetZigZagSwings();
   // CheckHeadAndShoulders();
   // CheckInverseHeadAndShoulders();
   CheckDoubleTop();
   CheckDoubleBottom();
}

//+------------------------------------------------------------------+
//| Retrieve ZigZag swings                                           |
//+------------------------------------------------------------------+
void GetZigZagSwings()
{
   ArraySetAsSeries(zigzagHighs, true);
   ArraySetAsSeries(zigzagLows, true);
   CopyBuffer(zigzagHandle, 0, 0, 100, zigzagHighs); // Highs buffer
   CopyBuffer(zigzagHandle, 1, 0, 100, zigzagLows);  // Lows buffer
}

//+------------------------------------------------------------------+
//| Check for Head and Shoulders pattern                             |
//+------------------------------------------------------------------+
void CheckHeadAndShoulders()
{
   double shoulders[3], troughs[2];
   int shoulderIndex = 0, troughIndex = 0;

   for(int i=0; i<100; i++)
   {
      if(zigzagHighs[i] != 0 && shoulderIndex < 3)
      {
         shoulders[shoulderIndex] = zigzagHighs[i];
         shoulderIndex++;
      }
      if(zigzagLows[i] != 0 && troughIndex < 2)
      {
         troughs[troughIndex] = zigzagLows[i];
         troughIndex++;
      }
   }

   if(shoulderIndex == 3 && troughIndex == 2)
   {
      // Check if middle peak is the highest
      if(shoulders[1] > shoulders[0] && shoulders[1] > shoulders[2])
      {
         // Check neckline (troughs)
         if(troughs[1] < troughs[0]) // Lower lows for bearish pattern
         {
            double neckline = (troughs[0] + troughs[1]) / 2;
            double currentClose = iClose(_Symbol, _Period, 0);
            
            if(currentClose < neckline - PatternTolerance)
            {
               Alert("Head and Shoulders Pattern Detected");
               DrawPattern("HS", neckline);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for Inverse Head and Shoulders pattern                     |
//+------------------------------------------------------------------+
void CheckInverseHeadAndShoulders()
{
   double troughs[3], peaks[2];
   int troughIndex = 0, peakIndex = 0;

   for(int i=0; i<100; i++)
   {
      if(zigzagLows[i] != 0 && troughIndex < 3)
      {
         troughs[troughIndex] = zigzagLows[i];
         troughIndex++;
      }
      if(zigzagHighs[i] != 0 && peakIndex < 2)
      {
         peaks[peakIndex] = zigzagHighs[i];
         peakIndex++;
      }
   }

   if(troughIndex == 3 && peakIndex == 2)
   {
      // Check if middle trough is the lowest
      if(troughs[1] < troughs[0] && troughs[1] < troughs[2])
      {
         // Check neckline (peaks)
         if(peaks[1] > peaks[0]) // Higher highs for bullish pattern
         {
            double neckline = (peaks[0] + peaks[1]) / 2;
            double currentClose = iClose(_Symbol, _Period, 0);
            
            if(currentClose > neckline + PatternTolerance)
            {
               Alert("Inverse Head and Shoulders Pattern Detected");
               DrawPattern("IHS", neckline);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for Double Top pattern                                     |
//+------------------------------------------------------------------+
void CheckDoubleTop()
{
   double tops[2];
   int topIndex = 0;

   for(int i=0; i<100; i++)
   {
      if(zigzagHighs[i] != 0 && topIndex < 2)
      {
         tops[topIndex] = zigzagHighs[i];
         topIndex++;
      }
   }

   if(topIndex == 2)
   {
      if(MathAbs(tops[0] - tops[1]) < PatternTolerance)
      {
         double currentClose = iClose(_Symbol, _Period, 0);
         double trough = FindLowestLowBetween(tops[0], tops[1]);
         
         if(currentClose < trough - PatternTolerance)
         {
            Alert("Double Top Pattern Detected");
            DrawPattern("DT", trough);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for Double Bottom pattern                                  |
//+------------------------------------------------------------------+
void CheckDoubleBottom()
{
   double bottoms[2];
   int bottomIndex = 0;

   for(int i=0; i<100; i++)
   {
      if(zigzagLows[i] != 0 && bottomIndex < 2)
      {
         bottoms[bottomIndex] = zigzagLows[i];
         bottomIndex++;
      }
   }

   if(bottomIndex == 2)
   {
      if(MathAbs(bottoms[0] - bottoms[1]) < PatternTolerance)
      {
         double currentClose = iClose(_Symbol, _Period, 0);
         double peak = FindHighestHighBetween(bottoms[0], bottoms[1]);
         
         if(currentClose > peak + PatternTolerance)
         {
            Alert("Double Bottom Pattern Detected");
            DrawPattern("DB", peak);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Helper function to draw patterns                                 |
//+------------------------------------------------------------------+
void DrawPattern(string type, double level)
{
   string name = type+"_"+TimeToString(TimeCurrent());
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, level);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
}

//+------------------------------------------------------------------+
//| Find lowest low between two prices                               |
//+------------------------------------------------------------------+
double FindLowestLowBetween(double price1, double price2)
{
   // Implementation needed to find lowest low between two points
   return MathMin(price1, price2);
}

//+------------------------------------------------------------------+
//| Find highest high between two prices                             |
//+------------------------------------------------------------------+
double FindHighestHighBetween(double price1, double price2)
{
   // Implementation needed to find highest high between two points
   return MathMax(price1, price2);
}
//+------------------------------------------------------------------+