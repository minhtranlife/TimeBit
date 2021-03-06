//+------------------------------------------------------------------+
//|                                                     EaZigZag.mq5 |
//|                                       Copyright 2020, DeepCandle |
//|                                       https://www.deepcandle.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, DeepCandle"
#property link      "https://www.deepcandle.com"
#property version   "1.00"

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Expert\Money\MoneyFixedMargin.mqh>
//---
CPositionInfo               m_position;                                         // trade position object
CTrade                      m_trade;                                            // trading object
CSymbolInfo                 m_symbol;                                           // symbol info object
CAccountInfo                m_account;                                          // account info wrapper
CDealInfo                   m_deal;                                             // deals object
COrderInfo                  m_order;                                            // pending orders object

input group                                         "General Information"  
input double                InpVolume               = 0.01;                     //Volume trade
input ushort                InpStopLoss             = 10;                       //Stop Loss (in pips)
input ushort                InpTakeProfit           = 10;                       //TakeProfit (in pips)
input int                   InpDistance             = 10;                       //Khoảng cách mở lệnh đến đỉnh đấy (%)

input group                 "Indicator ZigZag Level 1";
input int                   InpZigZagLevel1Depth            = 8;                //ZigZag Level 1 Depth
input int                   InpZigZagLevel1Deviation        = 5;                //ZigZag Level 1 Deviation
input int                   InpZigZagLevel1BackStep         = 3;                //ZigZag Level 1 Backstep

input group                 "Indicator ZigZag Level 2";
input int                   InpZigZagLevel2Depth            = 16;               //ZigZag Level 2 Depth
input int                   InpZigZagLevel2Deviation        = 5;                //ZigZag Level 2 Deviation
input int                   InpZigZagLevel2BackStep         = 3;                //ZigZag Level 2 Backstep

input group                 "Indicator ZigZag Level 3";
input int                   InpZigZagLevel3Depth            = 32;               //ZigZag Level 3 Depth
input int                   InpZigZagLevel3Deviation        = 5;                //ZigZag Level 3 Deviation
input int                   InpZigZagLevel3BackStep         = 3;                //ZigZag Level 3 Backstep

input group                 "Indicator Bollinger Band"
input int                   InpBandsPeriod                  = 20;               //Bands Period
input int                   InpBandsShift                   = 0;                //Bands Shift
input double                InpBandsDeviation               = 2.000;            //Bands Deviation 
input ENUM_APPLIED_PRICE    InpBandsAppliedPrice            = PRICE_CLOSE;      //Bands applied price
input int                   InpBBDistanceDown               = 5;                //Khoảng cách BB Lower vs đáy ZZ (points)
input int                   InpBBDistanceUp                 = 5;                //Khoảng cách BB Upper vs đỉnh ZZ(points)


input group                 "Indicator MFI";
input int                   InpMFIPeriod                    = 14;               //MFI Period
input ENUM_APPLIED_VOLUME   InpMFIVolumes                   = VOLUME_TICK;      //MFI Volumes 


input group                 "Indicator RSI"
input int                   InpRSIPeriod                    = 14;               //RSI period
input ENUM_APPLIED_PRICE    InpRSIApplied_Price             = PRICE_CLOSE;      //RSI applied price 


input group                 "Indicator Bears Power"
input int                   InpBearsPeriod                  = 13;               //Bears Power period
input double                InpBearsVolumeMax               = 0.0003;             //Bears Volume Max
input double                InpBearsVolumeMin               = -0.0003;            //Bears Volume Min

input group                 "Indicator Bulls Power"
input int                   InpBullsPeriod                  = 13;               //Bulls Power period 
input double                InpBullVolumeMax                = 0.0003;              //Bull Volume Max
input double                InpBullVolumeMin                = -0.0003;             //Bull Volume Min
//---
input group                 "System";
input ulong                 m_slippage                      = 10;               // Slippage (in points)
input ulong                 m_magic                         = 88888888;         // Magic number
//---
double                      m_adjusted_point;                                   // point value adjusted for 3 or 5 points
//---
bool                        m_need_open_buy                 = false;
bool                        m_need_open_sell                = false;
bool                        m_waiting_transaction           = false;            // "true" -> it's forbidden to trade, we expect a transaction
ulong                       m_waiting_order_ticket          = 0;                // ticket of the expected order
bool                        m_transaction_confirmed         = false;            // "true" -> transaction confirmed
string                      message_log                     = "";
//---
MqlRates                    rates[];
//---
int                         zigzag_level_1_handler;      
int                         zigzag_level_2_handler;
int                         zigzag_level_3_handler;

//---
int                         band_handler;

int                         mfi_handler;

int                         rsi_handler;

int                         bull_handler;
int                         bear_handler;
//---
double                      zigzag_level_1_array[2];
double                      zigzag_level_2_array[2];
double                      zigzag_level_3_array[2];
double                      zigzag_value_trend_array[2];
//---

datetime                    zigzag_value_trend_time[2];
//---
double                      band_array_upper[];
double                      band_array_lower[];
double                      band_array_middle[];
double                      mfi_array[];
double                      rsi_array[]; 
double                      bull_array[];
double                      bear_array[];


           
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
//---
   if (!m_symbol.Name(Symbol())) // sets symbol name
        return (INIT_FAILED);
    RefreshRates();
    //---
    m_trade.SetExpertMagicNumber(m_magic);
    m_trade.SetMarginMode();
    m_trade.SetTypeFillingBySymbol(m_symbol.Name());
    m_trade.SetDeviationInPoints(m_slippage);
    
     if(!InitZigZagLevel1()){
        return INIT_FAILED;
    }
    if(!InitZigZagLevel2()){
        return INIT_FAILED;
    }    
    if(!InitZigZagLevel3()){
        return INIT_FAILED;
    } 
    if(!InitBands()){
        return INIT_FAILED;
    }  
    if(!InitMFI()){
        return INIT_FAILED;
    }    
    if(!InitRSI()){
        return INIT_FAILED;
    } 
    if(!InitBulls()){
        return INIT_FAILED;
    } 
    if(!InitBears()){
        return INIT_FAILED;
    }
    
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
void OnTick(){
//---
    message_log = "";
    
    InitZigZagValues(zigzag_level_1_handler, zigzag_level_1_array);
    InitZigZagValues(zigzag_level_2_handler, zigzag_level_2_array);
    InitZigZagValues(zigzag_level_3_handler, zigzag_level_3_array);  
    
    InitZigZagZHighLowArray();
    //---
    ArraySetAsSeries(band_array_lower, true);    
    ArraySetAsSeries(band_array_upper, true);
    ArraySetAsSeries(band_array_middle, true);
    CopyBuffer(band_handler,2, 0, 3, band_array_lower);
    CopyBuffer(band_handler,1, 0, 3, band_array_upper);
    CopyBuffer(band_handler,0, 0, 3, band_array_middle);
    ArraySetAsSeries(mfi_array, true);    
    CopyBuffer(mfi_handler,0,0,3,mfi_array);  
    ArraySetAsSeries(rsi_array,true);
    CopyBuffer(rsi_handler,0,0,3, rsi_array);
    ArraySetAsSeries(bull_array,true);
    CopyBuffer(bull_handler,0,0,3, bull_array);
    ArraySetAsSeries(bear_array,true);
    CopyBuffer(bear_handler,0,0,3, bear_array);
    //message_log +="zzlv1 = " + zigzag_level_1_array[1] +  "zzlv2 = " + zigzag_level_2_array[1] + "zzlv3 = " + zigzag_level_3_array[1];
    //message_log += "\n C Trend = " + zigzag_value_trend_array[1] + " - D trend = " + zigzag_value_trend_array[0] ;
    

    SetupConditions();
    
    double bid = m_symbol.Bid();
    double ask = m_symbol.Ask();   
    
    string signal = GetSignal();
    //message_log += "\n" + signal;
    //Comment(message_log);
    
    
    if(PositionsTotal() == 0){
        
        if(signal == "BUY") {
            if(zigzag_value_trend_array[0] + InpDistance*10*_Point <= SymbolInfoDouble(Symbol(),SYMBOL_ASK)){           
                double sl = ask - InpStopLoss * 10 * _Point;
                double tp = ask + InpTakeProfit * 10 * _Point;
                m_trade.Buy(InpVolume, m_symbol.Name(),ask, sl, tp); 
            }
            
        }
        if(signal == "SELL") {
            if(zigzag_value_trend_array[0] - InpDistance*10*_Point >= SymbolInfoDouble(Symbol(),SYMBOL_BID)){
                double sl = bid + InpStopLoss * 10 * _Point;
                double tp = bid - InpTakeProfit * 10 * _Point;
                m_trade.Sell(InpVolume, m_symbol.Name(),bid, sl, tp);
            }            
          
        }
    }
}

string GetSignal(){
    
    if(zigzag_level_1_array[1] != 0.0 && zigzag_level_2_array[1] != 0.0 && zigzag_level_3_array[1] != 0.0){
        if(zigzag_level_1_array[1] == zigzag_level_2_array[1] && zigzag_level_2_array[1] == zigzag_level_3_array[1]){ 
            if(zigzag_value_trend_array[0] > zigzag_value_trend_array[1]){              
                if( zigzag_value_trend_array[0] <= band_array_upper[1] + InpBBDistanceUp *_Point){                    
                    if(zigzag_value_trend_array[0] >= band_array_upper[1] - InpBBDistanceUp *_Point){                  
                        if(mfi_array[1] >= 80){                     
                            if(rsi_array[1] >= 70){                                
                                if(bull_array[1] <= InpBullVolumeMax && bull_array[1] >= InpBullVolumeMin){                                  
                                    if(bear_array[1] <= InpBearsVolumeMax && bear_array[1]>= InpBearsVolumeMin ){                                       
                                        return "SELL";
                                    }                                                              
                                }
                            }                        
                        }
                    }
                }
            }
            if(zigzag_value_trend_array[0] < zigzag_value_trend_array[1]){
                if( zigzag_value_trend_array[0] <= band_array_lower[1] + InpBBDistanceDown *_Point){
                    if(zigzag_value_trend_array[0] >= band_array_lower[1] - InpBBDistanceDown *_Point){
                        if(mfi_array[1] <= 20){
                            if(rsi_array[1] <= 30){
                                if(bull_array[1] <= InpBullVolumeMax && bull_array[1] >= InpBullVolumeMin){
                                    if(bear_array[1] <= InpBearsVolumeMax && bear_array[1]>= InpBearsVolumeMin ){
                                        return "BUY"; 
                                    }
                                }
                            }
                        }
                    }
                } 
            }
        } 
    }
  
    return "NO-TRADE";            
}
void SetupConditions() {    
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
    //---
}  
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool InitZigZagLevel1() {
   zigzag_level_1_handler  = iCustom(m_symbol.Name(),Period(),"Examples/ZigZag",InpZigZagLevel1Depth, InpZigZagLevel1Deviation, InpZigZagLevel1BackStep);
   if(zigzag_level_1_handler != NULL){
      return (true);
   }
   return false;
}
bool InitZigZagLevel2() {
   zigzag_level_2_handler  = iCustom(m_symbol.Name(),Period(),"Examples/ZigZag",InpZigZagLevel2Depth, InpZigZagLevel2Deviation, InpZigZagLevel2BackStep);
   if(zigzag_level_2_handler != NULL){
      return (true);
   }
   return false;
}
bool InitZigZagLevel3() {
   zigzag_level_3_handler  = iCustom(m_symbol.Name(),Period(),"Examples/ZigZag",InpZigZagLevel3Depth, InpZigZagLevel3Deviation, InpZigZagLevel3BackStep);
   if(zigzag_level_3_handler != NULL){
      return (true);
   }
   return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool InitZigZagZHighLowArray(){
   double zz_high_low_array[];
   int start_pos = 0, count = 500;
   int CopyNumber = CopyBuffer(zigzag_level_3_handler, 0, start_pos, count, zz_high_low_array);
      
   if(CopyNumber > 0) {
      ArraySetAsSeries(zz_high_low_array, true);          
      ArraySetAsSeries(rates, true);
      if(CopyRates(m_symbol.Name(), Period(), start_pos, count, rates) > 0){   
         int counter = 0;
         for(int i = 0; i <= CopyNumber && counter < ArraySize(zigzag_value_trend_array) && !IsStopped(); i++){
            if(zz_high_low_array[i] != 0.0){
               zigzag_value_trend_array[counter] = zz_high_low_array[i];
               zigzag_value_trend_time[counter] = rates[i].time;
               counter++;               
            }
         }
      }      
      return true;
   }else {
       Print("Indicator Bufer Unavailable");
       return false;
   }
}
void InitZigZagValues(int zzhandler, double & zz_high_low_array[]) {

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

bool InitBands(){
   band_handler = iBands(m_symbol.Name(),Period(),InpBandsPeriod, InpBandsShift, InpBandsDeviation, InpBandsAppliedPrice);
   if(band_handler != NULL){
      return (true);
   }
   return false;   
}

bool InitMFI(){
   mfi_handler = iMFI(m_symbol.Name(),Period(),InpMFIPeriod, InpMFIVolumes);
   if(mfi_handler != NULL){
      return (true);
   }
   return false;   
}
bool InitRSI() {
   rsi_handler  = iRSI(m_symbol.Name(),Period(),InpRSIPeriod,InpRSIApplied_Price);
   if(rsi_handler != NULL){
      return (true);
   }
   return false;
}

bool InitBears(){
   bear_handler = iBearsPower(m_symbol.Name(),Period(),InpBearsPeriod);
   if(bear_handler != NULL){
      return (true);
   }
   return false;
}

bool InitBulls(){
   bull_handler = iBullsPower(m_symbol.Name(),Period(),InpBullsPeriod);
   if(bull_handler != NULL){
      return (true);
   }
   return false;
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction & trans,const MqlTradeRequest & request,const MqlTradeResult & result) {  
    //--- get transaction type as enumeration value
    ENUM_TRADE_TRANSACTION_TYPE type = trans.type;
    //--- if transaction is result of addition of the transaction in history
    if (type == TRADE_TRANSACTION_DEAL_ADD) {
        long deal_ticket = 0;
        long deal_order = 0;
        long deal_time = 0;
        long deal_time_msc = 0;
        long deal_type = -1;
        long deal_entry = -1;
        long deal_magic = 0;
        long deal_reason = -1;
        long deal_position_id = 0;
        double deal_volume = 0.0;
        double deal_price = 0.0;
        double deal_commission = 0.0;
        double deal_swap = 0.0;
        double deal_profit = 0.0;
        string deal_symbol = "";
        string deal_comment = "";
        string deal_external_id = "";
        if (HistoryDealSelect(trans.deal)) {
            deal_ticket = HistoryDealGetInteger(trans.deal, DEAL_TICKET);
            deal_order = HistoryDealGetInteger(trans.deal, DEAL_ORDER);
            deal_time = HistoryDealGetInteger(trans.deal, DEAL_TIME);
            deal_time_msc = HistoryDealGetInteger(trans.deal, DEAL_TIME_MSC);
            deal_type = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
            deal_entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
            deal_magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
            deal_reason = HistoryDealGetInteger(trans.deal, DEAL_REASON);
            deal_position_id = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);

            deal_volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
            deal_price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
            deal_commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
            deal_swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
            deal_profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);

            deal_symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
            deal_comment = HistoryDealGetString(trans.deal, DEAL_COMMENT);
            deal_external_id = HistoryDealGetString(trans.deal, DEAL_EXTERNAL_ID);
        } else
            return;
        if (deal_symbol == m_symbol.Name() && deal_magic == m_magic)
            if (deal_entry == DEAL_ENTRY_IN)
                if (deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_SELL) {
                    if (m_waiting_transaction)
                        if (m_waiting_order_ticket == deal_order) {
                            Print(__FUNCTION__, " Transaction confirmed");
                            m_transaction_confirmed = true;
                        }
                }
    }
}
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