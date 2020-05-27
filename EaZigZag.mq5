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
input double                InpVolume               = 0.01;
input ushort                InpRangeXY              = 70;                       //ZigZag Level 4 Range CD (in pips)
input ushort                InpStopLoss             = 10;                       //Stop Loss last position (in pips)
input ushort                InpTakeProfit           = 10;
input int                   InpDistance             = 10;                       //Khoảng cách mở lệnh đến đỉnh đấy (%)

input group                 "Indicator ZigZag Level 1";
input int                   InpZigZagLevel1Depth            = 8;                //ZigZag Level 1 Depth
input int                   InpZigZagLevel1Deviation        = 5;                //ZigZag Level 1 Deviation
input int                   InpZigZagLevel1BackStep         = 3;                //ZigZag Level 1 Backstep
input color                 InpZigZagLevel1Color            = clrBlue;          //ZigZag Level 1 Color
input int                   InpZigZagLevel1Width            = 5;                //ZigZag Level 1 Width
input bool                  InpZigZagLevel1Display          = 0;                //Display ZigZag Level 1

input group                 "Indicator ZigZag Level 2";
input int                   InpZigZagLevel2Depth            = 16;               //ZigZag Level 2 Depth
input int                   InpZigZagLevel2Deviation        = 5;                //ZigZag Level 2 Deviation
input int                   InpZigZagLevel2BackStep         = 3;                //ZigZag Level 2 Backstep
input color                 InpZigZagLevel2Color            = clrRed;           //ZigZag Level 2 Color
input int                   InpZigZagLevel2Width            = 5;                //ZigZag Level 2 Width
input bool                  InpZigZagLevel2Display          = 0;                //Display ZigZag Level 2

input group                 "Indicator ZigZag Level 3";
input int                   InpZigZagLevel3Depth            = 32;               //ZigZag Level 3 Depth
input int                   InpZigZagLevel3Deviation        = 5;                //ZigZag Level 3 Deviation
input int                   InpZigZagLevel3BackStep         = 3;                //ZigZag Level 3 Backstep
input color                 InpZigZagLevel3Color            = clrPurple;        //ZigZag Level 3 Color
input int                   InpZigZagLevel3Width            = 5;                //ZigZag Level 3 Width
input bool                  InpZigZagLevel3Display          = 0;                //Display ZigZag Level 3

input group                 "Indicator ZigZag Level 4";
input int                   InpZigZagLevel4Depth            = 64;               //ZigZag Level 4 Depth
input int                   InpZigZagLevel4Deviation        = 5;                //ZigZag Level 4 Deviation
input int                   InpZigZagLevel4BackStep         = 3;                //ZigZag Level 4 Backstep
input color                 InpZigZagLevel4Color            = clrYellow;        //ZigZag Level 4 Color
input int                   InpZigZagLevel4Width            = 5;                //ZigZag Level 4 Width
input bool                  InpZigZagLevel4Display          = 1;                //Display ZigZag Level 4

//---
input group                 "System";
input ulong                 m_slippage                      = 10;                // Slippage (in points)
input ulong                 m_magic                         = 88888888;          // Magic number
//---
double                      m_adjusted_point;                           // point value adjusted for 3 or 5 points
//---
bool                        m_need_open_buy                 = false;
bool                        m_need_open_sell                = false;
bool                        m_waiting_transaction           = false;            // "true" -> it's forbidden to trade, we expect a transaction
ulong                       m_waiting_order_ticket          = 0;                // ticket of the expected order
bool                        m_transaction_confirmed         = false;            // "true" -> transaction confirmed
string                      message_log                     = "";
//---
MqlRates                    rates[];
int                         zigzag_level_1_handler;      
int                         zigzag_level_2_handler;
int                         zigzag_level_3_handler;
int                         zigzag_level_4_handler;

double                      zigzag_level_1_array[50];
double                      zigzag_level_2_array[50];
double                      zigzag_level_3_array[50];
double                      zigzag_level_4_array[50];

datetime                    zigzag_level_1_time[50];
datetime                    zigzag_level_2_time[50];
datetime                    zigzag_level_3_time[50];
datetime                    zigzag_level_4_time[50];
double                      distance;
           
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
    if(!InitZigZagLevel4()){
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
    ShowZigZag(); 
    SetupConditions();
    
    double bid = m_symbol.Bid();
    double ask = m_symbol.Ask();
    //Check hội tụ
    
    string signal = GetSignal();
    
    distance = (MathAbs(zigzag_level_4_array[0] - zigzag_level_4_array[1])/100 ) * InpDistance; 
    //Check Range XY
    if(signal == "BUY") {
        if(zigzag_level_4_array[0] + distance <= ask){
            double sl = ask - InpStopLoss * 10 * _Point;
            double tp = ask + InpTakeProfit * 10 * _Point;
            m_trade.Buy(InpVolume, m_symbol.Name(),ask, sl, tp); 
        }
    }
    if(signal == "SELL") {  
        if(zigzag_level_4_array[0] - distance >= bid){
            double sl = bid + InpStopLoss * 10 * _Point;
            double tp = bid - InpTakeProfit * 10 * _Point;
            m_trade.Sell(InpVolume, m_symbol.Name(),bid, sl, tp);            
        }
    }
            
            

}

string GetSignal(){
    if(zigzag_level_1_array[0] == zigzag_level_2_array[0] && zigzag_level_2_array[0] == zigzag_level_3_array[0]
         && zigzag_level_3_array[0] == zigzag_level_4_array[0]){
         
         if(CalculateZigZagLevel4RangeXY() >= InpRangeXY){
             if(zigzag_level_4_array[0] > zigzag_level_4_array[1]){
                return "SELL"; 
             }
             if(zigzag_level_4_array[0] < zigzag_level_4_array[1]){
                return "BUY"; 
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
double CalculateZigZagLevel4RangeXY(){
   double rangeXY = -1;
   
   if(m_symbol.Digits() == 3){
      rangeXY = MathAbs(zigzag_level_4_array[1] - zigzag_level_4_array[0]) * 100;
   }
   
   if(m_symbol.Digits() == 5){
      rangeXY = MathAbs(zigzag_level_4_array[1] - zigzag_level_4_array[0]) * 10000;
   }
   return rangeXY;
}
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
bool InitZigZagLevel4() {
   zigzag_level_4_handler  = iCustom(m_symbol.Name(),Period(),"Examples/ZigZag",InpZigZagLevel4Depth, InpZigZagLevel4Deviation, InpZigZagLevel4BackStep);
   if(zigzag_level_4_handler != NULL){
      return (true);
   }
   return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool InitZigZagZHighLowArray(int zigzag_handler,  double & zigzag_array[], datetime & zigzag_time[]){
   double zz_high_low_array[];
   int start_pos = 0, count = Bars(_Symbol,_Period);
   int CopyNumber = CopyBuffer(zigzag_handler, 0, start_pos, count, zz_high_low_array);
      
   if(CopyNumber > 0) {
      ArraySetAsSeries(zz_high_low_array, true);          
      ArraySetAsSeries(rates, true);
      if(CopyRates(m_symbol.Name(), Period(), start_pos, count, rates) > 0){   
         int counter = 0;
         for(int i = 0; i <= CopyNumber && counter < ArraySize(zigzag_array) && !IsStopped(); i++){
            if(zz_high_low_array[i] != 0.0){
               zigzag_array[counter] = zz_high_low_array[i];
               zigzag_time[counter] = rates[i].time;
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
void Drawline(string name, double x, double y, datetime time_x, datetime time_y, int width, color c ) {
    
   ObjectDelete(0,name);
   if (!ObjectCreate(0, name, OBJ_TREND, 0, time_x, x, time_y, y))
      return;
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   
}

void DrawZigZagLevel1() {
      
    for(int i =0; i<ArraySize(zigzag_level_1_array)-2; i++ ) {
        Drawline ("Level 1" + string(i) + "-" + string(i+1) ,zigzag_level_1_array[i],zigzag_level_1_array[i+1],zigzag_level_1_time[i], zigzag_level_1_time[i+1], InpZigZagLevel1Width, InpZigZagLevel1Color);
    }
    
}
void DrawZigZagLevel2() {
      
    for(int i =0; i<ArraySize(zigzag_level_2_array)-2; i++ ) {
        Drawline ("Level 2" + string(i) + "-" + string(i+1) ,zigzag_level_2_array[i],zigzag_level_2_array[i+1],zigzag_level_2_time[i], zigzag_level_2_time[i+1], InpZigZagLevel2Width, InpZigZagLevel2Color);
    }
    
}
void DrawZigZagLevel3() {
      
    for(int i =0; i<ArraySize(zigzag_level_3_array)-2; i++ ) {
        Drawline ("Level 3" + string(i) + "-" + string(i+1) ,zigzag_level_3_array[i],zigzag_level_3_array[i+1],zigzag_level_3_time[i], zigzag_level_3_time[i+1], InpZigZagLevel3Width, InpZigZagLevel3Color);
    }
    
}
void DrawZigZagLevel4() {
      
    for(int i =0; i<ArraySize(zigzag_level_4_array)-2; i++ ) {
        Drawline ("Level 4" + string(i) + "-" + string(i+1) ,zigzag_level_4_array[i],zigzag_level_4_array[i+1],zigzag_level_4_time[i], zigzag_level_4_time[i+1], InpZigZagLevel4Width, InpZigZagLevel4Color);
    }
    
}
void ShowZigZag(){
   //--- Level 1
    InitZigZagZHighLowArray(zigzag_level_1_handler, zigzag_level_1_array, zigzag_level_1_time);
    InitZigZagZHighLowArray(zigzag_level_2_handler, zigzag_level_2_array, zigzag_level_2_time);
    InitZigZagZHighLowArray(zigzag_level_3_handler, zigzag_level_3_array, zigzag_level_3_time);
    InitZigZagZHighLowArray(zigzag_level_4_handler, zigzag_level_4_array, zigzag_level_4_time);
    if(InpZigZagLevel1Display){
        DrawZigZagLevel1();
    }
    if(InpZigZagLevel2Display){
        DrawZigZagLevel2();
    }
    if(InpZigZagLevel3Display){
        DrawZigZagLevel3();
    }
    if(InpZigZagLevel4Display){
        DrawZigZagLevel4();
    }
    
    
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