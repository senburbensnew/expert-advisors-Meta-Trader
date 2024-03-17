// Define input parameters
input int fastMA_period = 9;
input int slowMA_period = 21;
input ENUM_MA_METHOD maMethod = MODE_EMA; // Moving average method
input ENUM_APPLIED_PRICE maPrice = PRICE_CLOSE; // Applied price for moving average
input int volumePeriod = 14; // Period for the volume indicator
input double volumeThreshold = 1.5; // Volume threshold for trading signals
input double envelopeDeviation = 0.1; // Deviation for envelope indicator
input int envelopeShift = 0; // Shift for envelope indicator
input double structureSensitivity = 0.5; // Sensitivity for detecting breaks of structure
input double lotSize = 0.1; // Lot size

// Define variables for storing MA values, volume, envelope values, and last structure levels
double fastMA, slowMA;
double volume;
double upperEnvelope, lowerEnvelope;
double lastHigh, lastLow;

// OnInit() function
void OnInit()
{
    // No initialization needed
}

// OnTick() function
void OnTick()
{
    // Calculate moving averages
    fastMA = iMA(NULL, 0, fastMA_period, 0, maMethod, maPrice, 0);
    slowMA = iMA(NULL, 0, slowMA_period, 0, maMethod, maPrice, 0);

    // Calculate volume
    volume = iVolume(NULL, 0, volumePeriod, 0);

    // Calculate envelope values
    upperEnvelope = iEnvelopes(NULL, 0, fastMA_period, 0, MODE_UPPER, envelopeDeviation, envelopeShift);
    lowerEnvelope = iEnvelopes(NULL, 0, fastMA_period, 0, MODE_LOWER, envelopeDeviation, envelopeShift);

    // Update last structure levels
    UpdateStructureLevels();

    // Check for buy signal
    if (fastMA > slowMA && volume > volumeThreshold * iVolume(NULL, 0, volumePeriod, 1) && Close > upperEnvelope && Close > lastHigh)
    {
        // Buy signal
        BuySignal();
    }
    // Check for sell signal
    else if (fastMA < slowMA && volume > volumeThreshold * iVolume(NULL, 0, volumePeriod, 1) && Close < lowerEnvelope && Close < lastLow)
    {
        // Sell signal
        SellSignal();
    }
}

// Function to execute buy trade
void BuySignal()
{
    // Place buy order
    if (!OrderSend(Symbol(), OP_BUY, lotSize, Ask, 3, 0, 0, "MA, Volume, Envelope and Structure Buy", 0, 0, clrGreen))
    {
        Print("Error in placing buy order: ", GetLastError());
    }
}

// Function to execute sell trade
void SellSignal()
{
    // Place sell order
    if (!OrderSend(Symbol(), OP_SELL, lotSize, Bid, 3, 0, 0, "MA, Volume, Envelope and Structure Sell", 0, 0, clrRed))
    {
        Print("Error in placing sell order: ", GetLastError());
    }
}

// Function to update last structure levels
void UpdateStructureLevels()
{
    // Calculate last swing high/low levels
    lastHigh = High[ArrayMaximum(High, 20)];
    lastLow = Low[ArrayMinimum(Low, 20)];
}
