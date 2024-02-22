// Define input parameters
input int lookbackBars = 20; // Number of bars to look back for swing high/lows
input double sensitivity = 0.5; // Sensitivity factor for swing high/low detection
input bool sendAlerts = true; // Option to send alerts

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
    // Calculate swing highs and lows
    double lastHigh = High[ArrayMaximum(High, lookbackBars)];
    double lastLow = Low[ArrayMinimum(Low, lookbackBars)];

    // Calculate sensitivity thresholds
    double highThreshold = lastHigh + sensitivity * (lastHigh - lastLow);
    double lowThreshold = lastLow - sensitivity * (lastHigh - lastLow);

    // Check for break of structure
    if (Close > highThreshold && lastBreakType != BullishBreak)
    {
        // Break of structure to the upside
        lastBreakType = BullishBreak;
        Print("Bullish break of structure detected at price: ", Close);
        if (sendAlerts)
            SendNotification("Bullish break of structure detected at price: ", Close);
    }
    else if (Close < lowThreshold && lastBreakType != BearishBreak)
    {
        // Break of structure to the downside
        lastBreakType = BearishBreak;
        Print("Bearish break of structure detected at price: ", Close);
        if (sendAlerts)
            SendNotification("Bearish break of structure detected at price: ", Close);
    }
}

// Function to send notification
void SendNotification(string message, double price)
{
    string msg = message + DoubleToString(price, _Digits);
    Notification(msg);
}
