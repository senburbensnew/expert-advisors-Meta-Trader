// Define input parameters
input double sensitivity = 0.5; // Sensitivity for detecting breaks of structure
input int lookbackBars = 20; // Number of bars to look back for swing high/lows

// Define variable for storing the last break of structure type
enum BreakType
{
    NoBreak,
    BullishBreak,
    BearishBreak
};

// Define variable for storing the last break type
BreakType lastBreakType = NoBreak;

// OnInit() function
void OnInit()
{
    // No initialization needed
}

// OnTick() function
void OnTick()
{
    // Check for break of structure
    CheckBreakOfStructure();
}

// Function to check for break of structure
void CheckBreakOfStructure()
{
    // Calculate sensitivity threshold
    int timeframe = 240; // H4 timeframe in minutes
    double sensitivityThreshold = sensitivity * SymbolInfoDouble(Symbol(), SYMBOL_POINT) * MathPow(10, SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)) * 10;
    
    // Calculate last swing high/low levels
    double lastHigh = High[ArrayMaximum(High, lookbackBars)];
    double lastLow = Low[ArrayMinimum(Low, lookbackBars)];

    // Check for bullish break of structure
    if (High[1] > lastHigh && High[0] < lastHigh - sensitivityThreshold)
    {
        // Potential bullish reversal
        lastBreakType = BullishBreak;
        SendNotification("Bullish break of structure detected.");
    }
    // Check for bearish break of structure
    else if (Low[1] < lastLow && Low[0] > lastLow + sensitivityThreshold)
    {
        // Potential bearish reversal
        lastBreakType = BearishBreak;
        SendNotification("Bearish break of structure detected.");
    }
}

// Function to send push notification
void SendNotification(string message)
{
    Notification(message);
}
