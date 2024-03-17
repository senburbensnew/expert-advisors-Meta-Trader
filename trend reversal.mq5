// Define input parameters
input int fastMA_period = 9;
input int slowMA_period = 21;
input double lotSize = 0.1;

// Define variable for storing the order ticket
int orderTicket;

// Define variable for storing MA values
double fastMA, slowMA;
double prev_fastMA, prev_slowMA;

// OnInit() function
void OnInit()
{
    // Assign indicators to variables
    fastMA = iMA(NULL, 0, fastMA_period, 0, MODE_EMA, PRICE_CLOSE, 0);
    slowMA = iMA(NULL, 0, slowMA_period, 0, MODE_EMA, PRICE_CLOSE, 0);
    prev_fastMA = fastMA;
    prev_slowMA = slowMA;
}

// OnTick() function
void OnTick()
{
    // Update MA values
    fastMA = iMA(NULL, 0, fastMA_period, 0, MODE_EMA, PRICE_CLOSE, 0);
    slowMA = iMA(NULL, 0, slowMA_period, 0, MODE_EMA, PRICE_CLOSE, 0);

    // Check for trend reversal
    if(prev_fastMA > prev_slowMA && fastMA < slowMA)
    {
        // Potential bullish reversal
        Print("Potential bullish reversal detected.");
    }
    else if(prev_fastMA < prev_slowMA && fastMA > slowMA)
    {
        // Potential bearish reversal
        Print("Potential bearish reversal detected.");
    }

    // Update previous MA values
    prev_fastMA = fastMA;
    prev_slowMA = slowMA;
}
