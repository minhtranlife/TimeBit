//+------------------------------------------------------------------+
//|                                                    FXScalper.mq5 |
//|                                      Copyright 2020, DeepCandle. |
//|                                       https://www.deepcandle.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, DeepCandle."
#property link      "https://www.deepcandle.com"
#property version   "1.00"
#include <Trade\SymbolInfo.mqh>  
CSymbolInfo   m_symbol;      
input group     "###ZZ Single TimeFrame Crawler" 
input group     "Indicator ZigZag Level 1"
input int       Inp_ZZ_Level_1_Depth            = 4;                //ZigZag Level  1 Depth
input int       Inp_ZZ_Level_1_Deviation        = 5;                //ZigZag Level  1 Deviation
input int       Inp_ZZ_Level_1_BackStep         = 3;                //ZigZag Level  1 Backstep
//input color     Inp_ZZ_Level_1_Color            = clrBlue;          //ZigZag Level  1 Color 
//input int       Inp_ZZ_Level_1_Width            = 3;                //ZigZag Level  1 Width 

input group     "Indicator ZigZag Level 2"
input int       Inp_ZZ_Level_2_Depth            = 8;                //ZigZag Level  2 Depth
input int       Inp_ZZ_Level_2_Deviation        = 5;                //ZigZag Level  2 Deviation
input int       Inp_ZZ_Level_2_BackStep         = 3;                //ZigZag Level  2 Backstep
//input color     Inp_ZZ_Level_2_Color            = clrRed;           //ZigZag Level  2 Color 
//input int       Inp_ZZ_Level_2_Width            = 5;                //ZigZag Level  2 Width 

input group     "Indicator ZigZag Level 3"
input int       Inp_ZZ_Level_3_Depth            = 16;               //ZigZag Level  3 Depth
input int       Inp_ZZ_Level_3_Deviation        = 5;                //ZigZag Level  3 Deviation
input int       Inp_ZZ_Level_3_BackStep         = 3;                //ZigZag Level  3 Backstep
//input color     Inp_ZZ_Level_3_Color            = clrPurple;        //ZigZag Level  3 Color 
//input int       Inp_ZZ_Level_3_Width            = 7;                //ZigZag Level  3 Width 

input group     "Indicator ZigZag Level 4"
input int       Inp_ZZ_Level_4_Depth            = 32;               //ZigZag Level  4 Depth
input int       Inp_ZZ_Level_4_Deviation        = 5;                //ZigZag Level  4 Deviation
input int       Inp_ZZ_Level_4_BackStep         = 3;                //ZigZag Level  4 Backstep
//input color     Inp_ZZ_Level_4_Color            = clrYellow;        //ZigZag Level  4 Color 
//input int       Inp_ZZ_Level_4_Width            = 10;               //ZigZag Level  4 Width 

input group     "Indicator RSI"
input int       Inp_RSI_Period                  = 14;                //RSI period
input ENUM_APPLIED_PRICE Inp_RSI_Applied_Price  = PRICE_CLOSE;       //RSI applied price

input group     "Indicator Momentum"
input int       Inp_Momentum_Period                   = 14;          //Momentum Period
input ENUM_APPLIED_PRICE Inp_Momentum_Applied_Price   = PRICE_CLOSE; //Momentum applied price

input group     "Indicator Bears Power"
input int       Inp_Bears_Period                = 13;                //Bears Power period

input group     "Indicator Bulls Power"
input int       Inp_Bulls_Period                = 13;                //Bulls Power period

input group     "Indicator Bollinger Band"
input int       Inp_Bands_Period                = 20;                //Bands Period
input int       Inp_Bands_Shift                 = 0;                 //Bands Shift
input double    Inp_Bands_Deviation             = 2.000;             //Bands Deviation 
input ENUM_APPLIED_PRICE Inp_Bands_Applied_Price   = PRICE_CLOSE;    //Bands applied price

int             zz_level_1_handler;      
int             zz_level_2_handler;
int             zz_level_3_handler;
int             zz_level_4_handler;

double          zz_Level_1_HighLow_Array[2];   
double          zz_Level_2_HighLow_Array[2]; 
double          zz_Level_3_HighLow_Array[2]; 
double          zz_Level_4_HighLow_Array[2];

int             rsi_handler;
double          rsi_array[];

int             momentum_handler;
double          momentum_array[];

int             bear_handler;
double          bear_array[];

int             bull_handler;
double          bull_array[];

int             band_handler;
double          band_array_upper[];
double          band_array_lower[];
double          band_array_middle[]; 

        
MqlRates rates[];
                        
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    //---
    if (!m_symbol.Name(Symbol())) // sets symbol name
        return (INIT_FAILED);
    RefreshRates();
    
    if(!InitZigZagLevel1()) {
        return (INIT_FAILED);
    }
    
    if(!InitZigZagLevel2()) {
        return (INIT_FAILED);
    }
    
    if(!InitZigZagLevel3()) {
        return (INIT_FAILED);
    }
    
    if(!InitZigZagLevel4()) {
        return (INIT_FAILED);
    }
    
    if(!InitRSI()){
        return (INIT_FAILED);
    }

    if(!InitMomentum()){
        return (INIT_FAILED);
    }
    
    if(!InitBears()){
         return (INIT_FAILED);
    }
    
    if(!InitBulls()){
         return (INIT_FAILED);
    }
    
    if(!InitBands()){
        return (INIT_FAILED);
    }
    string colume_names = "datetime,price_open,price_close,price_hight,price_low,tick_volume,ask,bid,zzlevel1,zzlevel2,zzlevel3,zzlevel4,rsi,momentum,bear_power,bull_power,band_upper,band_lower,band_middle";
    Print(colume_names);
    //---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    //--- we work only at the time of the birth of new bar
    static datetime PrevBars = 0;
    datetime time_0 = iTime(m_symbol.Name(), Period(), 0);
    if (time_0 == PrevBars)
        return;
    PrevBars = time_0;
    if (!RefreshRates()) {
        PrevBars = 0;
        return;
    }
    
    //---change 
    ArraySetAsSeries(rates, true);
    CopyRates(Symbol(), Period(), 0, 2, rates);
    
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    string line  = (string)rates[1].time + ",";
    line += (string)rates[1].open + "," + (string)rates[1].close + "," + (string)rates[1].high + "," + (string)rates[1].low+ ",";
    line += (string)rates[1].tick_volume + ",";
    line += (string)ask + "," + (string)bid + ",";
    //---
    
    InitZZHighLowValues(zz_level_1_handler, zz_Level_1_HighLow_Array);
    line += (string)zz_Level_1_HighLow_Array[1] + ",";
    
    
    InitZZHighLowValues(zz_level_2_handler, zz_Level_2_HighLow_Array);
    line += (string)zz_Level_2_HighLow_Array[1] + ",";
    
    InitZZHighLowValues(zz_level_3_handler, zz_Level_3_HighLow_Array);
    line += (string)zz_Level_3_HighLow_Array[1] + ",";
    
    InitZZHighLowValues(zz_level_4_handler, zz_Level_4_HighLow_Array);
    line += (string)zz_Level_4_HighLow_Array[1]+ ",";
    
    //---RSI
    ArraySetAsSeries(rsi_array, true);    
    CopyBuffer(rsi_handler, 0, 0, 3, rsi_array);
    line += DoubleToString(NormalizeDouble(rsi_array[1],2))+ ",";   
    
    //---Momentum
    ArraySetAsSeries(momentum_array, true);    
    CopyBuffer(momentum_handler, 0, 0, 3, momentum_array);
    line += DoubleToString(momentum_array[1],2)+ ",";
   
    //---Bear
    ArraySetAsSeries(bear_array, true);  
    CopyBuffer(bear_handler, 0, 0, 3, bear_array);
    line += DoubleToString(bear_array[1])+ ",";
    //---Bull
    ArraySetAsSeries(bull_array, true);  
    CopyBuffer(bull_handler, 0, 0, 3, bull_array);
    line += DoubleToString(bull_array[1])+ ",";
    
    //---Bollinger Band
    ArraySetAsSeries(band_array_lower, true);    
    ArraySetAsSeries(band_array_upper, true);
    ArraySetAsSeries(band_array_middle, true);
    CopyBuffer(band_handler,2, 0, 3, band_array_lower);
    CopyBuffer(band_handler,1, 0, 3, band_array_upper);
    CopyBuffer(band_handler,0, 0, 3, band_array_middle);    
    line += DoubleToString(band_array_upper[1])+ ",";
    line += DoubleToString(band_array_lower[1])+ ",";
    line += DoubleToString(band_array_middle[1]);   
  
    Print(line);
    
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates(void) {
    //--- refresh rates
    if (!m_symbol.RefreshRates()) {
        Print("RefreshRates error");
        return (false);
    }
    //--- protection against the return value of "zero"
    if (m_symbol.Ask() == 0 || m_symbol.Bid() == 0)
        return (false);
    //---
    return (true);
}


bool InitZigZagLevel1() {
   zz_level_1_handler  = iCustom(m_symbol.Name(),Period(),"Examples/ZigZag",Inp_ZZ_Level_1_Depth, Inp_ZZ_Level_1_Deviation, Inp_ZZ_Level_1_BackStep);
   if(zz_level_1_handler != NULL){
      return (true);
   }
   return false;
}

bool InitZigZagLevel2() {
   zz_level_2_handler  = iCustom(m_symbol.Name(),Period(),"Examples/ZigZag",Inp_ZZ_Level_2_Depth, Inp_ZZ_Level_2_Deviation, Inp_ZZ_Level_2_BackStep);
   if(zz_level_2_handler != NULL){
      return (true);
   }
   return false;
}

bool InitZigZagLevel3() {
   zz_level_3_handler  = iCustom(m_symbol.Name(),Period(),"Examples/ZigZag",Inp_ZZ_Level_3_Depth, Inp_ZZ_Level_3_Deviation, Inp_ZZ_Level_3_BackStep);
   if(zz_level_3_handler != NULL){
      return (true);
   }
   return false;
}

bool InitZigZagLevel4() {
   zz_level_4_handler  = iCustom(m_symbol.Name(),Period(),"Examples/ZigZag",Inp_ZZ_Level_4_Depth, Inp_ZZ_Level_4_Deviation, Inp_ZZ_Level_4_BackStep);
   if(zz_level_4_handler != NULL){
      return (true);
   }
   return false;
}


void InitZZHighLowValues(int zzhandler, double & zz_high_low_array[]) {

    double zz_array_buffer[];
        
    int CopyNumber = CopyBuffer(zzhandler, 0, 0, 3, zz_array_buffer);
   
    if(CopyNumber > 0) {
    
      ArraySetAsSeries(zz_array_buffer, true);  
      
      if(CopyRates(m_symbol.Name(), Period(),0, 3, rates) > 0) {   
      
            int counter = 0;
            
            for(int i = 0; i <= CopyNumber && counter < 2 && !IsStopped(); i++){
                zz_high_low_array[counter] = zz_array_buffer[i];
                counter++; 
            } 
        }     
    }  
}
//+------------------------------------------------------------------+
//| RSI                                                                 |
//+------------------------------------------------------------------+
bool InitRSI() {
   rsi_handler  = iRSI(m_symbol.Name(),Period(),Inp_RSI_Period,Inp_RSI_Applied_Price);
   if(rsi_handler != NULL){
      return (true);
   }
   return false;
}

//+------------------------------------------------------------------+
//|  Momentum                                                                |
//+------------------------------------------------------------------+
bool InitMomentum(){
   momentum_handler = iMomentum(m_symbol.Name(),Period(),Inp_Momentum_Period,Inp_Momentum_Applied_Price);
   if(momentum_handler != NULL){
      return (true);
   }
   return false;
}
//+------------------------------------------------------------------+
//| Bears Power                                                      |
//+------------------------------------------------------------------+
bool InitBears(){
   bear_handler = iBearsPower(m_symbol.Name(),Period(),Inp_Bears_Period);
   if(bear_handler != NULL){
      return (true);
   }
   return false;
}

//+------------------------------------------------------------------+
//|  BullPower                                                       |
//+------------------------------------------------------------------+
bool InitBulls(){
   bull_handler = iBullsPower(m_symbol.Name(),Period(),Inp_Bulls_Period);
   if(bull_handler != NULL){
      return (true);
   }
   return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool InitBands(){
   band_handler = iBands(m_symbol.Name(),Period(),Inp_Bands_Period, Inp_Bands_Shift, Inp_Bands_Deviation, Inp_Bands_Applied_Price);
   if(band_handler != NULL){
      return (true);
   }
   return false;   
}
