// Define input parameters
input int fastMA_period = 9;
input int slowMA_period = 21;
input double lotSize = 0.1;

// Define variable for storing the order ticket
int orderTicket;

// Define variable for storing MA values
double fastMA, slowMA;

// OnInit() function
void OnInit()
{
    // Assign indicators to variables
    fastMA = iMA(NULL, 0, fastMA_period, 0, MODE_EMA, PRICE_CLOSE, 0);
    slowMA = iMA(NULL, 0, slowMA_period, 0, MODE_EMA, PRICE_CLOSE, 0);
}

// OnTick() function
void OnTick()
{
    // Check for crossover
    if(fastMA > slowMA)
    {
        // Buy signal
        if(!OrderSend(Symbol(), OP_BUY, lotSize, Ask, 3, 0, 0, "MA Crossover Buy", 0, 0, clrGreen))
        {
            Print("Error in placing buy order: ", GetLastError());
        }
    }
    else if(fastMA < slowMA)
    {
        // Sell signal
        if(!OrderSend(Symbol(), OP_SELL, lotSize, Bid, 3, 0, 0, "MA Crossover Sell", 0, 0, clrRed))
        {
            Print("Error in placing sell order: ", GetLastError());
        }
    }
}

// OnTick() function
void OnTick()
{
    // Check for open orders
    for(int i=OrdersTotal()-1; i>=0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS) == true)
        {
            if(OrderType() == OP_BUY)
            {
                // Close buy order if sell signal
                if(fastMA < slowMA)
                {
                    if(!OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrRed))
                    {
                        Print("Error in closing buy order: ", GetLastError());
                    }
                }
            }
            else if(OrderType() == OP_SELL)
            {
                // Close sell order if buy signal
                if(fastMA > slowMA)
                {
                    if(!OrderClose(OrderTicket(), OrderLots(), Ask, 3, clrGreen))
                    {
                        Print("Error in closing sell order: ", GetLastError());
                    }
                }
            }
        }
    }
}
