//+------------------------------------------------------------------+
//|                                             ExactReversalPoint.mq5 |
//|                                            Copyright 2025, Your Name |
//|                                                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property description "Exact Reversal Point (ERP) Indicator"
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   4

// Plot properties
#property indicator_label1  "Bullish ERP"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#property indicator_label2  "Bearish ERP"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

#property indicator_label3  "Support Levels"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSkyBlue
#property indicator_style3  STYLE_DASH
#property indicator_width3  1

#property indicator_label4  "Resistance Levels"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_style4  STYLE_DASH
#property indicator_width4  1

// Input parameters
input int      InpRSIPeriod = 14;           // RSI Period
input int      InpMACDFast = 12;            // MACD Fast Period
input int      InpMACDSlow = 26;            // MACD Slow Period
input int      InpMACDSignal = 9;           // MACD Signal Period
input int      InpATRPeriod = 14;           // ATR Period for volatility
input double   InpFibLevel1 = 38.2;         // 1st Fibonacci Level
input double   InpFibLevel2 = 50.0;         // 2nd Fibonacci Level
input double   InpFibLevel3 = 61.8;         // 3rd Fibonacci Level
input int      InpSwingLookback = 20;       // Lookback for Swing High/Low
input int      InpMinStrength = 3;          // Minimum signals for ERP confirmation (1-7)
input bool     InpShowSupportResistance = true; // Show Support/Resistance levels

// Global variables
double BullishERPBuffer[];     // Bullish reversal buffer
double BearishERPBuffer[];     // Bearish reversal buffer
double SupportBuffer[];        // Support levels buffer
double ResistanceBuffer[];     // Resistance levels buffer
double RSIBuffer[];            // RSI values
double MACDMainBuffer[];       // MACD Main line
double MACDSignalBuffer[];     // MACD Signal line

// Indicator handles
int RSIHandle;
int MACDHandle;
int ATRHandle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set up buffers
   SetIndexBuffer(0, BullishERPBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BearishERPBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SupportBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, ResistanceBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, RSIBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, MACDMainBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, MACDSignalBuffer, INDICATOR_CALCULATIONS);
   
   // Arrow settings
   PlotIndexSetInteger(0, PLOT_ARROW, 233);  // Up arrow for bullish ERP
   PlotIndexSetInteger(1, PLOT_ARROW, 234);  // Down arrow for bearish ERP
   
   // Get indicator handles
   RSIHandle = iRSI(Symbol(), Period(), InpRSIPeriod, PRICE_CLOSE);
   MACDHandle = iMACD(Symbol(), Period(), InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   ATRHandle = iATR(Symbol(), Period(), InpATRPeriod);
   
   if(RSIHandle == INVALID_HANDLE || MACDHandle == INVALID_HANDLE || ATRHandle == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
   }
   
   // Initialize arrays
   ArrayInitialize(BullishERPBuffer, EMPTY_VALUE);
   ArrayInitialize(BearishERPBuffer, EMPTY_VALUE);
   ArrayInitialize(SupportBuffer, EMPTY_VALUE);
   ArrayInitialize(ResistanceBuffer, EMPTY_VALUE);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(RSIHandle);
   IndicatorRelease(MACDHandle);
   IndicatorRelease(ATRHandle);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Check for minimal data
   if(rates_total < InpSwingLookback + 10)
      return(0);
   
   // Calculate starting point
   int start;
   if(prev_calculated == 0)
   {
      start = InpSwingLookback + 10;
      
      // Initialize arrays with EMPTY_VALUE
      for(int i = 0; i < start; i++)
      {
         BullishERPBuffer[i] = EMPTY_VALUE;
         BearishERPBuffer[i] = EMPTY_VALUE;
         SupportBuffer[i] = EMPTY_VALUE;
         ResistanceBuffer[i] = EMPTY_VALUE;
      }
   }
   else
   {
      start = prev_calculated - 1;
   }
   
   // Copy indicator data
   if(CopyBuffer(RSIHandle, 0, 0, rates_total, RSIBuffer) <= 0)
      return(0);
      
   if(CopyBuffer(MACDHandle, 0, 0, rates_total, MACDMainBuffer) <= 0)
      return(0);
      
   if(CopyBuffer(MACDHandle, 1, 0, rates_total, MACDSignalBuffer) <= 0)
      return(0);
   
   // Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      // Initialize buffers
      BullishERPBuffer[i] = EMPTY_VALUE;
      BearishERPBuffer[i] = EMPTY_VALUE;
      SupportBuffer[i] = EMPTY_VALUE;
      ResistanceBuffer[i] = EMPTY_VALUE;
      
      // Skip if not enough bars
      if(i < InpSwingLookback)
         continue;
      
      // Calculate Support and Resistance levels
      if(InpShowSupportResistance)
      {
         CalculateSupportResistance(i, high, low, SupportBuffer, ResistanceBuffer);
      }
      
      // Count bullish signals
      int bullishSignals = 0;
      int bearishSignals = 0;
      
      // 1. Support & Resistance Check
      if(IsAtSupport(i, low))
         bullishSignals++;
      if(IsAtResistance(i, high))
         bearishSignals++;
      
      // 2. Fibonacci Retracement Check
      if(IsAtFibonacciRetracement(i, high, low, close, true))
         bullishSignals++;
      if(IsAtFibonacciRetracement(i, high, low, close, false))
         bearishSignals++;
      
      // 3. Trendline & Channel Break Check
      if(IsTrendlineBreak(i, high, low, close, true))
         bullishSignals++;
      if(IsTrendlineBreak(i, high, low, close, false))
         bearishSignals++;
      
      // 4. Candlestick Reversal Pattern Check
      if(HasReversalCandlePattern(i, open, high, low, close, true))
         bullishSignals++;
      if(HasReversalCandlePattern(i, open, high, low, close, false))
         bearishSignals++;
      
      // 5. Indicator Divergence Check
      if(HasDivergence(i, high, low, close, RSIBuffer, MACDMainBuffer, true))
         bullishSignals++;
      if(HasDivergence(i, high, low, close, RSIBuffer, MACDMainBuffer, false))
         bearishSignals++;
      
      // 6. Volume Confirmation Check
      if(HasVolumeConfirmation(i, close, volume, true))
         bullishSignals++;
      if(HasVolumeConfirmation(i, close, volume, false))
         bearishSignals++;
      
      // 7. Harmonic Pattern Check
      if(HasHarmonicPattern(i, high, low, close, true))
         bullishSignals++;
      if(HasHarmonicPattern(i, high, low, close, false))
         bearishSignals++;
      
      // Set ERP signals if enough confirmation signals are present
      if(bullishSignals >= InpMinStrength)
         BullishERPBuffer[i] = low[i] - 10 * Point();
         
      if(bearishSignals >= InpMinStrength)
         BearishERPBuffer[i] = high[i] + 10 * Point();
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate Support and Resistance levels                          |
//+------------------------------------------------------------------+
void CalculateSupportResistance(const int idx, const double &high[], const double &low[],
                               double &supportBuffer[], double &resistanceBuffer[])
{
   // Previous swing high and low points
   double swingHigh = high[ArrayMaximum(high, idx - InpSwingLookback, InpSwingLookback)];
   double swingLow = low[ArrayMinimum(low, idx - InpSwingLookback, InpSwingLookback)];
   
   // If price is approaching these levels, mark them as support/resistance
   double currentPrice = (high[idx] + low[idx]) / 2.0;
   double priceRange = MathAbs(swingHigh - swingLow);
   double threshold = priceRange * 0.05; // 5% threshold
   
   if(MathAbs(currentPrice - swingLow) < threshold)
      supportBuffer[idx] = swingLow;
      
   if(MathAbs(currentPrice - swingHigh) < threshold)
      resistanceBuffer[idx] = swingHigh;
}

//+------------------------------------------------------------------+
//| Check if price is at a support level                             |
//+------------------------------------------------------------------+
bool IsAtSupport(const int idx, const double &low[])
{
   // Simple support definition: Current low is within a small percentage
   // of the lowest low over the lookback period
   
   double lowestLow = low[ArrayMinimum(low, idx - InpSwingLookback, InpSwingLookback)];
   double threshold = (lowestLow * 0.005); // 0.5% threshold
   
   return MathAbs(low[idx] - lowestLow) <= threshold;
}

//+------------------------------------------------------------------+
//| Check if price is at a resistance level                          |
//+------------------------------------------------------------------+
bool IsAtResistance(const int idx, const double &high[])
{
   // Simple resistance definition: Current high is within a small percentage
   // of the highest high over the lookback period
   
   double highestHigh = high[ArrayMaximum(high, idx - InpSwingLookback, InpSwingLookback)];
   double threshold = (highestHigh * 0.005); // 0.5% threshold
   
   return MathAbs(high[idx] - highestHigh) <= threshold;
}

//+------------------------------------------------------------------+
//| Check if price is at a Fibonacci retracement level               |
//+------------------------------------------------------------------+
bool IsAtFibonacciRetracement(const int idx, const double &high[], const double &low[],
                            const double &close[], const bool isBullish)
{
   // Find swing high and low for retracement calculation
   int swingHighIdx = ArrayMaximum(high, idx - InpSwingLookback, InpSwingLookback);
   int swingLowIdx = ArrayMinimum(low, idx - InpSwingLookback, InpSwingLookback);
   
   double swingHigh = high[swingHighIdx];
   double swingLow = low[swingLowIdx];
   double range = swingHigh - swingLow;
   
   // Skip if range is too small
   if(range < Point() * 50)
      return false;
   
   // Calculate Fibonacci levels
   double fib382 = swingLow + range * (InpFibLevel1 / 100.0);
   double fib500 = swingLow + range * (InpFibLevel2 / 100.0);
   double fib618 = swingLow + range * (InpFibLevel3 / 100.0);
   
   // For bullish case, price should be near a Fib level and moving up from a downtrend
   if(isBullish && swingHighIdx < swingLowIdx)
   {
      double threshold = range * 0.01; // 1% of the range
      
      return (MathAbs(close[idx] - fib382) < threshold ||
              MathAbs(close[idx] - fib500) < threshold ||
              MathAbs(close[idx] - fib618) < threshold) &&
             close[idx] > close[idx-1]; // Confirmation of upward movement
   }
   
   // For bearish case, price should be near a Fib level and moving down from an uptrend
   if(!isBullish && swingLowIdx < swingHighIdx)
   {
      double threshold = range * 0.01; // 1% of the range
      
      return (MathAbs(close[idx] - fib382) < threshold ||
              MathAbs(close[idx] - fib500) < threshold ||
              MathAbs(close[idx] - fib618) < threshold) &&
             close[idx] < close[idx-1]; // Confirmation of downward movement
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for trendline break                                        |
//+------------------------------------------------------------------+
bool IsTrendlineBreak(const int idx, const double &high[], const double &low[],
                    const double &close[], const bool isBullish)
{
   // Simplified trendline break detection
   if(idx < 5)
      return false;
      
   if(isBullish)
   {
      // Detect break of a falling trendline
      // Check if lows are making a series of higher lows
      return (low[idx] > low[idx-1] && low[idx-1] > low[idx-2] && 
              low[idx-2] > low[idx-3] && close[idx] > close[idx-1]);
   }
   else
   {
      // Detect break of a rising trendline
      // Check if highs are making a series of lower highs
      return (high[idx] < high[idx-1] && high[idx-1] < high[idx-2] && 
              high[idx-2] < high[idx-3] && close[idx] < close[idx-1]);
   }
}

//+------------------------------------------------------------------+
//| Check for reversal candlestick patterns                          |
//+------------------------------------------------------------------+
bool HasReversalCandlePattern(const int idx, const double &open[], const double &high[],
                             const double &low[], const double &close[], const bool isBullish)
{
   if(idx < 2) 
      return false;
   
   double bodySize = MathAbs(open[idx] - close[idx]);
   double totalSize = high[idx] - low[idx];
   
   if(isBullish)
   {
      // Bullish Engulfing
      bool bullishEngulfing = (close[idx] > open[idx] &&                // Current candle is bullish
                             open[idx] < close[idx-1] &&               // Current open is below previous close
                             close[idx] > open[idx-1] &&               // Current close is above previous open
                             open[idx-1] > close[idx-1]);              // Previous candle is bearish
      
      // Hammer pattern (small body, long lower shadow, little or no upper shadow)
      bool hammer = (close[idx] > open[idx] &&                          // Bullish candle
                   bodySize < totalSize * 0.3 &&                      // Small body
                   (high[idx] - MathMax(open[idx], close[idx])) < bodySize * 0.2 && // Little upper shadow
                   (MathMin(open[idx], close[idx]) - low[idx]) > bodySize * 2);  // Long lower shadow
      
      // Bullish Harami
      bool bullishHarami = (close[idx] > open[idx] &&                   // Current candle is bullish
                          open[idx-1] > close[idx-1] &&               // Previous candle is bearish
                          open[idx] > close[idx-1] &&                 // Current open is above previous close
                          close[idx] < open[idx-1]);                  // Current close is below previous open
                          
      return bullishEngulfing || hammer || bullishHarami;
   }
   else
   {
      // Bearish Engulfing
      bool bearishEngulfing = (close[idx] < open[idx] &&                // Current candle is bearish
                             open[idx] > close[idx-1] &&               // Current open is above previous close
                             close[idx] < open[idx-1] &&               // Current close is below previous open
                             open[idx-1] < close[idx-1]);              // Previous candle is bullish
      
      // Shooting Star (small body, long upper shadow, little or no lower shadow)
      bool shootingStar = (close[idx] < open[idx] &&                    // Bearish candle
                         bodySize < totalSize * 0.3 &&                // Small body
                         (MathMax(open[idx], close[idx]) - low[idx]) < bodySize * 0.2 && // Little lower shadow
                         (high[idx] - MathMin(open[idx], close[idx])) > bodySize * 2);  // Long upper shadow
      
      // Bearish Harami
      bool bearishHarami = (close[idx] < open[idx] &&                   // Current candle is bearish
                          open[idx-1] < close[idx-1] &&               // Previous candle is bullish
                          open[idx] < close[idx-1] &&                 // Current open is below previous close
                          close[idx] > open[idx-1]);                  // Current close is above previous open
                          
      return bearishEngulfing || shootingStar || bearishHarami;
   }
}

//+------------------------------------------------------------------+
//| Check for divergence between price and indicators                |
//+------------------------------------------------------------------+
bool HasDivergence(const int idx, const double &high[], const double &low[], 
                 const double &close[], const double &rsi[], const double &macd[],
                 const bool isBullish)
{
   if(idx < InpSwingLookback) 
      return false;
   
   if(isBullish)
   {
      // Find two significant lows in price
      int low1Idx = idx;
      int low2Idx = -1;
      
      // Find the second low
      for(int i = idx - 3; i >= idx - InpSwingLookback; i--)
      {
         if(low[i] < low[i-1] && low[i] < low[i+1]) // Simple low detection
         {
            low2Idx = i;
            break;
         }
      }
      
      if(low2Idx == -1) return false;
      
      // Check for bullish divergence (lower price lows but higher indicator lows)
      if(low[low1Idx] < low[low2Idx] && 
         (rsi[low1Idx] > rsi[low2Idx] || macd[low1Idx] > macd[low2Idx]))
      {
         return true;
      }
   }
   else
   {
      // Find two significant highs in price
      int high1Idx = idx;
      int high2Idx = -1;
      
      // Find the second high
      for(int i = idx - 3; i >= idx - InpSwingLookback; i--)
      {
         if(high[i] > high[i-1] && high[i] > high[i+1]) // Simple high detection
         {
            high2Idx = i;
            break;
         }
      }
      
      if(high2Idx == -1) return false;
      
      // Check for bearish divergence (higher price highs but lower indicator highs)
      if(high[high1Idx] > high[high2Idx] && 
         (rsi[high1Idx] < rsi[high2Idx] || macd[high1Idx] < macd[high2Idx]))
      {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for volume confirmation                                    |
//+------------------------------------------------------------------+
bool HasVolumeConfirmation(const int idx, const double &close[], const long &volume[],
                         const bool isBullish)
{
   if(idx < 5) 
      return false;
   
   // Calculate average volume for the last 5 bars
   long avgVolume = 0;
   for(int i = idx - 5; i < idx; i++)
   {
      avgVolume += volume[i];
   }
   avgVolume /= 5;
   
   if(isBullish)
   {
      // For bullish ERP, we want increasing price with above average volume
      return (close[idx] > close[idx-1] && volume[idx] > avgVolume * 1.5);
   }
   else
   {
      // For bearish ERP, we want decreasing price with above average volume
      return (close[idx] < close[idx-1] && volume[idx] > avgVolume * 1.5);
   }
}

//+------------------------------------------------------------------+
//| Check for harmonic patterns                                      |
//+------------------------------------------------------------------+
bool HasHarmonicPattern(const int idx, const double &high[], const double &low[],
                      const double &close[], const bool isBullish)
{
   // This is a simplified version of harmonic pattern detection
   // In a real implementation, you'd check for specific patterns like
   // Gartley, Butterfly, Bat, etc. with their precise Fibonacci ratios
   
   if(idx < InpSwingLookback) 
      return false;
   
   // Simplified check: Look for price approaching key Fibonacci extension
   // after a significant move
   
   if(isBullish)
   {
      // Find a significant drop followed by retracement
      double lowestLow = low[ArrayMinimum(low, idx - InpSwingLookback, InpSwingLookback)];
      double highestHigh = high[ArrayMaximum(high, idx - InpSwingLookback, InpSwingLookback)];
      double range = highestHigh - lowestLow;
      
      // Check if price is near a 78.6% or 88.6% retracement (common harmonic levels)
      double harmonicLevel1 = lowestLow + range * 0.786;
      double harmonicLevel2 = lowestLow + range * 0.886;
      
      return (MathAbs(close[idx] - harmonicLevel1) < range * 0.01 || 
              MathAbs(close[idx] - harmonicLevel2) < range * 0.01) &&
             close[idx] > close[idx-1]; // Confirming upward movement
   }
   else
   {
      // Find a significant rise followed by retracement
      double lowestLow = low[ArrayMinimum(low, idx - InpSwingLookback, InpSwingLookback)];
      double highestHigh = high[ArrayMaximum(high, idx - InpSwingLookback, InpSwingLookback)];
      double range = highestHigh - lowestLow;
      
      // Check if price is near a 78.6% or 88.6% retracement (common harmonic levels)
      double harmonicLevel1 = highestHigh - range * 0.786;
      double harmonicLevel2 = highestHigh - range * 0.886;
      
      return (MathAbs(close[idx] - harmonicLevel1) < range * 0.01 || 
              MathAbs(close[idx] - harmonicLevel2) < range * 0.01) &&
             close[idx] < close[idx-1]; // Confirming downward movement
   }
}
//+------------------------------------------------------------------+
