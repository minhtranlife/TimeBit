//+------------------------------------------------------------------+
//|                                                    SimpleRWF.mq5 |
//|                                      Copyright 2020, DeepCandle. |
//|                                       https://www.deepcandle.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, DeepCandle."
#property link      "https://www.deepcandle.com"
#property version   "1.00"
//---
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Expert\Money\MoneyFixedMargin.mqh>
//---
CPositionInfo               m_position;                                  // trade position object
CTrade                      m_trade;                                     // trading object
CSymbolInfo                 m_symbol;                                    // symbol info object
CAccountInfo                m_account;                                   // account info wrapper
CDealInfo                   m_deal;                                      // deals object
COrderInfo                  m_order;                                     // pending orders object
//---
enum ENUM_TP_MODE{
                            auto                      = 0 ,               //No
                            manual                    = 1                 //Yes
};

//---
//--- input parameters
input group                                         "General Information"                
//input string                InpTimeStart            = "00:15:00";        // Timestart
//input string                InpTimeStop             = "23:45:00";        // Timestop
input string                InpVolumeString         = "0.01,0.02,0.04,0.08,0.16,0.32,0.64,1.28,2.56,5.12";  //Volume
//---
input ushort                InpM5RangeCD            = 10;                //M5 Range(CD)(in pips)
input double                InpTPF236Distance       = 2;                 //Distance from fibo to open price (pips)
//---
input int                   InpBalanceStopLoss      = 25;                //Balance stop (in percent)
input ushort                InpStopLoss             = 10;                //Stop Loss (in pips)
input double                InpLastPriceDistance    = 10;                //Distance from new open price to last open price (int pips)
//---
input ENUM_TP_MODE          InpTPModeCheck          = 0;                 //Optimize TP
input int                   InpTPDistance           = 3;                 //TP point plus
//---
input bool                  Inp2ndReverseCheck      = 0;                 //Next check reverse
//---
input group                                         "ZigZag M5";
input int                   InpM5ZigZagDepth        = 5;                 //M5 ZigZag Depth
input int                   InpM5ZigZagDeviation    = 5;                 //M5 ZigZag Deviation
input int                   InpM5ZigZagBackStep     = 3;                 //M5 ZigZag Backstep
input color                 InpM5ZigZagABCDColor    = clrYellow;         //M5 ZigZag ABCD Color
input int                   InpM5ZigZagABCDWidth    = 5;                 //M5 ZigZag width
input bool                  InpM5ZigZagDisplay      = 0;                 //Display M5 ZigZag 
//---
input group                                         "ZigZag M1";
input int                   InpM1ZigZagDepth        = 5;                 //M1 ZigZag Depth
input int                   InpM1ZigZagDeviation    = 5;                 //M1 ZigZag Deviation
input int                   InpM1ZigZagBackStep     = 3;                 //M1 ZigZag Backstep
input color                 InpM1ZigZagCDColor      = clrAliceBlue;      //M1 ZigZag CD Color
input int                   InpM1ZigZagCDWidth      = 3;                 //M1 ZigZag CD Width
input bool                  InpM1ZigZagDisplay      = 0;                 //Display M1 ZigZag
//---
input group                                         "Fibo M5";
input double                InpM5FiboABPercentSmall = 10.0;              //M5 Fibo AB (Small)
input double                InpM5FiboABPercentBig   = 80.0;              //M5 Fibo AB  (Big)
input color                 InpM5FiboABColor        = clrAqua;            //M5 Fibo AB Color
input bool                  InpM5FiboABDisplay      = 0;                 //Display M5 Fibo AB 
input double                InpM5FiboCDPercentSmall = 10.0;              //M5 Fibo CD (Small)
input double                InpM5FiboCDPercentBig   = 80.0;              //M5 Fibo CD (Big)
input color                 InpM5FiboCDColor        = clrMediumAquamarine;//M5 Fibo CD Color
input bool                  InpM5FiboCDDisplay      = 0;                 //Display M5 Fibo CD

input int                   InpTPLevelChange        = 4;                 //TP Level Change
input double                InpTPFiboLevel1         = 23.6;              //TP Fibo Level 1   
input double                InpTPFiboLevel2         = 38.2;              //TP Fibo Level 2
input color                 InpTPColor              = clrMagenta;        //TP Fibo Color
input bool                  InpTPDisplay            = 0;                 //Display TP Fibo 
//---
input group                                         "System";
input ulong                 m_slippage              = 10;               // Slippage(in points)
input ulong                 m_magic                 = 88888888;         // Magic number
//---
MqlRates                    rates[];

string                      volumes_array[];
//---
double                      ExtStopLoss             = 0.0;
double                      ExtTakeProfit           = 0.0;
double                      ExtTrailingStop         = 0.0;
double                      ExtTrailingStep         = 0.0;
//---
double                      m_adjusted_point;                           // point value adjusted for 3 or 5 points
//---
bool                        m_need_open_buy         = false;
bool                        m_need_open_sell        = false;
bool                        m_waiting_transaction   = false;            // "true" -> it's forbidden to trade, we expect a transaction
ulong                       m_waiting_order_ticket  = 0;                // ticket of the expected order
bool                        m_transaction_confirmed = false;            // "true" -> transaction confirmed
string                      message_log             = "";
//---
int                         is_set_abcd             = 0;

int                         m5_zigzag_handler;
int                         m1_zigzag_handler;

double                      m5_abcd_array[4];
datetime                    m5_time_array[4];

double                      m1_cd_array[2];
datetime                    m1_time_array[2];

double                      m5_zz_a_price;
datetime                    m5_zz_a_time;
double                      m5_zz_b_price;
datetime                    m5_zz_b_time;
double                      m5_zz_c_price;
datetime                    m5_zz_c_time;
double                      m5_zz_d_price;
datetime                    m5_zz_d_time;

double                      last_open_price;
int                         position_type;
int                         m5_zz_display           = 0;
bool                        m_update_sl             = false;
double                      last_tp_price;
//---
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    
    //---
    if (!m_symbol.Name(Symbol())) // sets symbol name
        return (INIT_FAILED);
    RefreshRates();
    //---
    m_trade.SetExpertMagicNumber(m_magic);
    m_trade.SetMarginMode();
    m_trade.SetTypeFillingBySymbol(m_symbol.Name());
    m_trade.SetDeviationInPoints(m_slippage);
    
    //---
    if(!InitZigZagM5()){
        return INIT_FAILED;
    }
    if(!InitZigZagM1()){
        return INIT_FAILED;
    }
    
    InitVolumesArray();
    //---
    return (INIT_SUCCEEDED);
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
//|  Init M5 ZigZag                                                  |
//+------------------------------------------------------------------+
bool InitZigZagM5() {
    m5_zigzag_handler  = iCustom(m_symbol.Name(),PERIOD_M5,"Examples/ZigZag", InpM5ZigZagDepth, InpM5ZigZagDeviation, InpM5ZigZagBackStep);
    if(m5_zigzag_handler != NULL){
        message_log += "\n#Init M5 ZigZag ok";        
        return true;
      
    }else {
        message_log += "\n#Init M5 ZigZag failed";        
        return false;   
    }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool InitM5ZZHighLowArray(){
   double m5_zz_high_low_array[];
   int start_pos = 0, count = 200;
   int CopyNumber = CopyBuffer(m5_zigzag_handler, 0, start_pos, count, m5_zz_high_low_array);
   
   if(CopyNumber > 0) {
      ArraySetAsSeries(m5_zz_high_low_array, true);          
      ArraySetAsSeries(rates, true);
      if(CopyRates(m_symbol.Name(), PERIOD_M5, start_pos, count, rates) > 0){   
         int counter = 0;
         for(int i = 0; i <= CopyNumber && counter <= 3 && !IsStopped(); i++){
            if(m5_zz_high_low_array[i] != 0.0){
               m5_abcd_array[counter] = m5_zz_high_low_array[i];
               m5_time_array[counter] = rates[i].time;
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
//+------------------------------------------------------------------+
//|  Init M1 ZigZag                                                  |
//+------------------------------------------------------------------+
bool InitZigZagM1(){
   m1_zigzag_handler = iCustom(m_symbol.Name(),PERIOD_M1,"Examples/ZigZag",InpM1ZigZagDepth, InpM1ZigZagDeviation, InpM1ZigZagBackStep);
   if(m1_zigzag_handler != NULL){
      Print("Init M1 ZigZag ok");     
      return true;
   }else {
      Print("Init M1 ZigZag failed");      
      return false;
   }
}
//+------------------------------------------------------------------+
//| Init M1 CD Array                                                 |
//+------------------------------------------------------------------+
bool InitM1CDArray(){
   double m1_zz_high_low_array[];
   int start_pos = 0, count = 100;
   int CopyNumber = CopyBuffer(m1_zigzag_handler, 0, start_pos, count, m1_zz_high_low_array);
   
   if(CopyNumber > 0) {
      ArraySetAsSeries(m1_zz_high_low_array, true);           
      ArraySetAsSeries(rates, true);
      
      if(CopyRates(m_symbol.Name(), PERIOD_M1, start_pos, count, rates) > 0){   
         int counter = 0;
         for(int i = 0; i <= CopyNumber && counter <= 1 && !IsStopped(); i++){
            if(m1_zz_high_low_array[i] != 0.0){
               m1_cd_array[counter] = m1_zz_high_low_array[i];
               m1_time_array[counter] = rates[i].time;
               counter++;               
            }
         }
      }
            
      return true;
   }
       
   else {
       Print("Indicator Buffer Unavailable");
       return false;
   }
   
   return false;
}
//+------------------------------------------------------------------+
//|   Calculate M5 Range CD                                          |
//+------------------------------------------------------------------+
double CalculateM5RangeCD(){

   double rangeCD = -1;
   
   if(m_symbol.Digits() == 3){
      rangeCD = MathAbs(m5_abcd_array[1] - m5_abcd_array[0]) * 100;
   }
   
   if(m_symbol.Digits() == 5){
      rangeCD = MathAbs(m5_abcd_array[1] - m5_abcd_array[0]) * 10000;
   }
   return rangeCD;
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
//+------------------------------------------------------------------+
//| Close positions                                                  |
//+------------------------------------------------------------------+
/*void CloseAllPositions() {
    for(int i=PositionsTotal()-1; i>=0; i--) {
        ulong ticket = PositionGetTicket(i);
        m_trade.PositionClose(i);
    } 
                    
}*/
void CloseAllPositions() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) // returns the number of current positions
        if (m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
            if (m_position.Symbol() == m_symbol.Name() && m_position.Magic() == m_magic)
                //if (m_position.PositionType() == pos_type) // gets the position type
                    m_trade.PositionClose(m_position.Ticket()); // close a position by the specified symbol
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
    //---change 
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetM5PriceAtFiboPercent(double price_at_x, double price_at_y, double percent_value_check){
    
    double price_at_percent = 0.0;
    
    double range_xy = MathAbs(price_at_x - price_at_y);
   
    if(price_at_x > price_at_y){
        price_at_percent = price_at_y + (percent_value_check/100) * range_xy;
      
   }else if(price_at_x < price_at_y) {
        price_at_percent = price_at_y - (percent_value_check/100) * range_xy;
   }
   return price_at_percent;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckM5FiboForBuy(){

   double price_small = GetM5PriceAtFiboPercent(m5_abcd_array[3], m5_abcd_array[2], InpM5FiboABPercentSmall);
   double price_big = GetM5PriceAtFiboPercent(m5_abcd_array[3], m5_abcd_array[2], InpM5FiboABPercentBig);

   if(m5_abcd_array[1] > price_small && m5_abcd_array[1]  < price_big){
      return (true);
   }else{
      return (false);
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckM5FiboForSell(){
   double price_small = GetM5PriceAtFiboPercent(m5_abcd_array[1], m5_abcd_array[0], InpM5FiboCDPercentSmall);
   double price_big = GetM5PriceAtFiboPercent(m5_abcd_array[1], m5_abcd_array[0], InpM5FiboCDPercentBig);
   
   //message_log +=  "\n" + DoubleToString(NormalizeDouble(price_small, _Digits)) + ", " +  DoubleToString(NormalizeDouble(m5_time_array[1], _Digits)) + ", " + DoubleToString(NormalizeDouble(price_big, _Digits));
   
   if(m5_abcd_array[2] < price_small && m5_abcd_array[2] >  price_big){
      return (true);
   }else{
      return (false);
   }
   return (false);
}

bool CheckTPConditionForBuy() {
    //double f236 = GetM5PriceAtFiboPercent(m5_abcd_array[1], m5_abcd_array[0], InpM5FiboCDPercentSmall);
    double f236 = GetM5PriceAtFiboPercent(m5_abcd_array[1], m5_abcd_array[0], InpTPFiboLevel1);
    if(f236 - m_symbol.Ask() >= InpTPF236Distance *10*_Point) {
    
    
        return true;
    }
    return false;
}

bool CheckTPConditionForSell() {
    //double f236 = GetM5PriceAtFiboPercent(m5_abcd_array[1], m5_abcd_array[0], InpM5FiboCDPercentSmall);
    double f236 = GetM5PriceAtFiboPercent(m5_abcd_array[1], m5_abcd_array[0], InpTPFiboLevel1);
    if(m_symbol.Bid() - f236 >= InpTPF236Distance *10*_Point) {
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetSignal() {
    
    if(m5_abcd_array[3] > m5_abcd_array[2] && m5_abcd_array[3] > m5_abcd_array[1] && m5_abcd_array[3] > m5_abcd_array[0]) {
        if(m5_abcd_array[2] < m5_abcd_array[1]  && m5_abcd_array[2] > m5_abcd_array[0]) {
            if(m5_abcd_array[1] > m5_abcd_array[0]) {
                if(CalculateM5RangeCD() >= InpM5RangeCD){   
                    if(CheckM5FiboForBuy()) {
                        if(m1_cd_array[1] < m1_cd_array[0]) {
                            if(CheckTPConditionForBuy()) {
                                return "BUY"; 
                            }
                        }
                    }
                }
            }
        }
    }
    
    if(m5_abcd_array[3] < m5_abcd_array[2]  && m5_abcd_array[3] < m5_abcd_array[1] && m5_abcd_array[3] < m5_abcd_array[0]) {
        if(m5_abcd_array[2] > m5_abcd_array[1]  && m5_abcd_array[2] < m5_abcd_array[0]) {
            if(m5_abcd_array[1] < m5_abcd_array[0]) {
                if(CalculateM5RangeCD() >= InpM5RangeCD){
                    if(CheckM5FiboForSell()) {
                        if(m1_cd_array[1] > m1_cd_array[0]) {
                            if(CheckTPConditionForSell()) {
                                return "SELL";
                            }
                        }
                    }
                }
            }
        }
    }
    
    return "NO-TRADE";
}

void InitVolumesArray() {
    string sep=",";                // A separator as a character 
    ushort u_sep;                  // The code of the separator character 
    u_sep=StringGetCharacter(sep,0); 
    //--- Split the string to substrings 
    int k=StringSplit(InpVolumeString,u_sep,volumes_array); 
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {  
    
    message_log = "";
    
    InitM5ZZHighLowArray();
    InitM1CDArray();
    if(InpM1ZigZagDisplay){
        DrawZZM1CD();
    }
    
    SetupConditions();
    
    //message_log += "M5<ABCD> = " + (string)m5_abcd_array[3] + "," + (string)m5_abcd_array[2] + "," + (string)m5_abcd_array[1] + "," + (string)m5_abcd_array[0];
    //message_log += "\nM1<CD> = " + (string)m1_cd_array[1] + "," + (string)m1_cd_array[0];
    //message_log += "\nSignal = " + GetSignal();
    
    string signal = GetSignal();
    
    int positions_total = PositionsTotal();
   
    
    double bid = m_symbol.Bid();
    double ask = m_symbol.Ask();
    
    if(positions_total == 0) {  
        //---        
        ObjectDelete( 0, "FIBOBUYORSELL"); 
        ObjectDelete(0,"M5LineAB");     
        ObjectDelete(0,"M5LineBC");
        ObjectDelete(0,"M5LineCD");
        ObjectDelete(0,"M5A");
        ObjectDelete(0,"M5B");
        ObjectDelete(0,"M5C");
        ObjectDelete(0,"M5D");
        ObjectDelete( 0, "FIBOTP");
        
        //---              
        if(signal == "BUY") {        
            m5_zz_a_price = m5_abcd_array[3];
            m5_zz_b_price = m5_abcd_array[2];
            m5_zz_c_price = m5_abcd_array[1];
            m5_zz_d_price = m5_abcd_array[0];
            //---            
            m5_zz_a_time = m5_time_array[3];
            m5_zz_b_time = m5_time_array[2];
            m5_zz_c_time = m5_time_array[1];
            m5_zz_d_time = m5_time_array[0];
            //---            
            if(InpM5ZigZagDisplay){
                DrawZZM5ABCD();
            }  
            if(InpM5FiboABDisplay){
                DrawM5FiboBuySell(m5_zz_a_price, m5_zz_b_price, m5_zz_a_time, m5_zz_b_time, InpM5FiboABPercentSmall, InpM5FiboABPercentBig, InpM5FiboABColor);
            } 
            if(InpTPDisplay){
                DrawM5FiboTP(m5_zz_c_price, m5_zz_d_price,m5_zz_c_time,m5_zz_d_time);
            }                      
            //---            
            if(InpTPModeCheck==0) {
                double tp = CalculateTP(m5_zz_c_price, m5_zz_d_price);
                last_tp_price = tp;   
                m_trade.Buy(StringToDouble(volumes_array[positions_total]), Symbol(), ask, 0, tp, NULL);
            }
            
            if(InpTPModeCheck==1) {
                double tp = CalculateTP(m5_zz_c_price, m5_zz_d_price);
                last_tp_price = tp;   
                m_trade.Buy(StringToDouble(volumes_array[positions_total]), Symbol(), ask, 0, 0, NULL);
            }
           
            last_open_price = ask; 
            position_type = 0;
        }
        
        if(signal == "SELL") {
            m5_zz_a_price = m5_abcd_array[3];
            m5_zz_b_price = m5_abcd_array[2];
            m5_zz_c_price = m5_abcd_array[1];
            m5_zz_d_price = m5_abcd_array[0];
            //---         
            m5_zz_a_time = m5_time_array[3];
            m5_zz_b_time = m5_time_array[2];
            m5_zz_c_time = m5_time_array[1];
            m5_zz_d_time = m5_time_array[0];
            //---            
            if(InpM5ZigZagDisplay){
                DrawZZM5ABCD();
            }
            if(InpM5FiboCDDisplay){
                DrawM5FiboBuySell(m5_zz_c_price, m5_zz_d_price, m5_zz_c_time, m5_zz_d_time, InpM5FiboCDPercentSmall, InpM5FiboCDPercentBig, InpM5FiboCDColor);
            }
            if(InpTPDisplay){
                DrawM5FiboTP(m5_zz_c_price, m5_zz_d_price,m5_zz_c_time,m5_zz_d_time);
            }           
            //---            
            if(InpTPModeCheck == 0){
                double tp = CalculateTP(m5_zz_c_price, m5_zz_d_price);
                last_tp_price = tp;   
                m_trade.Sell(StringToDouble(volumes_array[positions_total]), Symbol(), bid, 0, tp, NULL);
            }
            
            if(InpTPModeCheck == 1){
                double tp = CalculateTP(m5_zz_c_price, m5_zz_d_price);
                last_tp_price = tp;       
                m_trade.Sell(StringToDouble(volumes_array[positions_total]), Symbol(), bid, 0, 0, NULL);
            }
            
            
            last_open_price = bid;
            position_type = 1;
        }
        //---
        
        //---        
    }
    
    if(positions_total == 1 || positions_total == 2 || positions_total == 3 || positions_total == 4 || positions_total == 5
        ||positions_total == 6 || positions_total == 7 || positions_total == 8 || positions_total == 9 || positions_total == 10
        ||positions_total == 11 || positions_total == 12 || positions_total == 13 || positions_total == 14 || positions_total == 15
        ||positions_total == 16 || positions_total == 17 || positions_total == 18 || positions_total == 19 || positions_total == 20) {
        
            if(position_type == 0) {      
                //---Buy   
               if(last_open_price - InpLastPriceDistance*10*_Point >= ask) {
                    if(Inp2ndReverseCheck == 0){
                        if(InpTPModeCheck == 0){ 
                            double tp = CalculateTP(m5_zz_c_price, m5_abcd_array[0]);                
                            m_trade.Buy(StringToDouble(volumes_array[positions_total]), Symbol(), ask, 0, tp, NULL);
                            last_open_price = ask;
                            last_tp_price = tp;   
                            SetTP(tp, position_type);
                        }
                        if(InpTPModeCheck == 1){ 
                            double tp = CalculateTP(m5_zz_c_price, m5_abcd_array[0]);
                            last_tp_price = tp;
                            m_trade.Buy(StringToDouble(volumes_array[positions_total]), Symbol(), ask, 0, 0, NULL);
                            last_open_price = ask;
                        }
                    }
                    if(Inp2ndReverseCheck == 1){
                        if(m1_cd_array[1] < m1_cd_array[0]) {                         
                            if(InpTPModeCheck == 0){ 
                                double tp = CalculateTP(m5_zz_c_price, m5_abcd_array[0]);                
                                m_trade.Buy(StringToDouble(volumes_array[positions_total]), Symbol(), ask, 0, tp, NULL);
                                last_open_price = ask;
                                last_tp_price = tp;   
                                SetTP(tp, position_type);
                            }
                            if(InpTPModeCheck == 1){ 
                                double tp = CalculateTP(m5_zz_c_price, m5_abcd_array[0]);
                                last_tp_price = tp;
                                m_trade.Buy(StringToDouble(volumes_array[positions_total]), Symbol(), ask, 0, 0, NULL);
                                last_open_price = ask;
                            }
                        }          
                    }                            
               }               
            }
            
            if(position_type == 1) {
               //---Sell           
               if(bid - last_open_price >=  InpLastPriceDistance*10*_Point ) {                    
                    if(Inp2ndReverseCheck == 0){
                        if(InpTPModeCheck == 0){
                            double tp = CalculateTP(m5_zz_c_price, m5_abcd_array[0]);                                       
                            m_trade.Sell(StringToDouble(volumes_array[positions_total]), Symbol(), bid, 0,tp, NULL);
                            last_open_price = bid;
                            last_tp_price = tp;   
                            SetTP(tp, position_type);
                        }
                        if(InpTPModeCheck == 1){ 
                            double tp = CalculateTP(m5_zz_c_price, m5_abcd_array[0]); 
                            last_tp_price = tp;   
                            m_trade.Sell(StringToDouble(volumes_array[positions_total]), Symbol(), bid, 0,0, NULL);
                            last_open_price = bid;
                        } 
                    }
                    if(Inp2ndReverseCheck == 1){
                        if(m1_cd_array[1] > m1_cd_array[0]) {                                    
                            if(InpTPModeCheck == 0){
                                double tp = CalculateTP(m5_zz_c_price, m5_abcd_array[0]);                                       
                                m_trade.Sell(StringToDouble(volumes_array[positions_total]), Symbol(), bid, 0,tp, NULL);
                                last_open_price = bid;
                                last_tp_price = tp;   
                                SetTP(tp, position_type);
                            }
                            if(InpTPModeCheck == 1){ 
                                double tp = CalculateTP(m5_zz_c_price, m5_abcd_array[0]); 
                                last_tp_price = tp;   
                                m_trade.Sell(StringToDouble(volumes_array[positions_total]), Symbol(), bid, 0,0, NULL);
                                last_open_price = bid;
                            } 
                        }
                    }            
               }                         
            }
            //---               
          
    }   
    
    //--- Update TP
    if(positions_total == 1 || positions_total == 2 || positions_total == 3 || positions_total == 4 || positions_total == 5
        ||positions_total == 6 || positions_total == 7 || positions_total == 8 || positions_total == 9 || positions_total == 10
        ||positions_total == 11 || positions_total == 12 || positions_total == 13 || positions_total == 14 || positions_total == 15
        ||positions_total == 16 || positions_total == 17 || positions_total == 18 || positions_total == 19 || positions_total == 20) {
               
        UpdateTP(last_tp_price, position_type);
        
        if(InpTPModeCheck == 1){ 
            string line = "";
            if(position_type == 0) {  
                //---Buy
                line += "Buy: ";                
                //line += "\nAsk:" + DoubleToString(ask);
                //line += "\nLast TP: " + DoubleToString(last_tp_price);
                /*if(ask < last_tp_price + InpTPDistance *_Point){
                    if(ask > last_tp_price - InpTPDistance *_Point){
                        line += "\nask in tprange";
                        if(m5_abcd_array[1] < m5_abcd_array[0]){
                            line += "\nM5 D<E";                            
                            CloseAllPositions();
                        }
                    }
                }*/
                //---                
                double tp_new = CalculateTP(m5_zz_c_price, m5_abcd_array[1]);
                line += "\nNew TP: " + DoubleToString(tp_new);
                if(bid < tp_new + InpTPDistance *_Point){
                    if(bid > tp_new - InpTPDistance *_Point){
                        line += "\nbid in tprange";
                        if(m5_abcd_array[1] < m5_abcd_array[0]){
                            line += "\nM5 D<E";                            
                            CloseAllPositions();
                        }
                    }
                }
                //---
                
            }
            if(position_type == 1) {
                //---Sell
                line += "Sell: ";            
                line += "\nBid:" + DoubleToString(bid);
                line += "\nLast TP: " + DoubleToString(last_tp_price);
                if(bid < last_tp_price + InpTPDistance *_Point){
                    if(bid > last_tp_price - InpTPDistance *_Point){                    
                        line += "bid in tprange";
                        if(m5_abcd_array[1] > m5_abcd_array[0]){
                            line += "M5 D>E";
						    CloseAllPositions();
					    } 
                    }
                }
                
            }
            DrawM5FiboTP(m5_zz_c_price, m5_abcd_array[1], m5_zz_c_time, m5_time_array[1]);
            Comment(line);
        }
    }  

    //
    //---Update SL    
    if(positions_total == ArraySize(volumes_array)) {   
        double sl = 0.0;
        if(InpTPModeCheck == 0){
            if(position_type == 0) {    
                sl = last_open_price - InpStopLoss *10 * _Point;            
            }
            if(position_type == 1) {
                sl = last_open_price + InpStopLoss *10 * _Point;
            }
            UpdateSL(sl);
        }
        
    }
    //---Check Balance Stop 
    double profit = 0.0;
    for(int i=PositionsTotal()-1;i>=0;i--){
         if (m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
            if (m_position.Symbol() == m_symbol.Name() && m_position.Magic() == m_magic)
                 profit += PositionGetDouble(POSITION_PROFIT);
      
    }    
    double balance = m_account.Balance();
    //message_log += "Profit = " + profit;
    if(profit < 0){
      double curren_profit_percent = MathAbs(profit / balance) * 100;
      //message_log += "\ncurren_profit_percent = " + curren_profit_percent;
      if(curren_profit_percent > InpBalanceStopLoss){
            CloseAllPositions();
            //Comment("Close All Possition");
      }
    }
    //---         
    //Comment(message_log);
   
}
//+------------------------------------------------------------------+
//| Update TP                                                        |
//+------------------------------------------------------------------+
void UpdateTP(double last_tp, int pos_type) {
    // Check gia hien tai co pha dinh/day D
    //calculate TP theo C vaf bid/ask hien tai
    double new_tp = last_tp;
    
    if(pos_type==0) {
        if(m5_zz_d_price > m_symbol.Ask() ){          
            new_tp = CalculateTP(m5_zz_c_price, m_symbol.Ask());
        }
    }
    
    if(pos_type==1) {
        if(m5_zz_d_price < m_symbol.Bid()){
            new_tp = CalculateTP(m5_zz_c_price, m_symbol.Bid());
        }
    }
    
    SetTP(new_tp,pos_type);  
   
}
//+------------------------------------------------------------------+
//| Set TP                                                           |
//+------------------------------------------------------------------+
void SetTP(double lastest_pos_tp, int pos_type) {
    
    Print("\n\n\n>>>>>>>>>>>>>SetTP<<<<<<<<<<<");
    
    for(int i = PositionsTotal()-1; i>=0; i--) {
        
        ulong ticket = PositionGetTicket(i);
        
        PositionSelectByTicket(ticket);
        //---
        double currentSL = PositionGetDouble(POSITION_SL);
        //---        
        double currentTP = PositionGetDouble(POSITION_TP);
        
        //Print("ticket=",ticket, "\ncurrent_tp=", currentTP, "\nlast_pos_tp=", lastest_pos_tp);        
        
        if(currentTP != lastest_pos_tp) {
            if(pos_type == 0){
                if(lastest_pos_tp < currentTP){
                    m_trade.PositionModify(ticket, currentSL, lastest_pos_tp);
                    last_tp_price = lastest_pos_tp;    
                }
            }
            if(pos_type == 1){
                 if(lastest_pos_tp > currentTP){
                    m_trade.PositionModify(ticket, currentSL, lastest_pos_tp); 
                    last_tp_price = lastest_pos_tp;      
                }
            }            
            //Print("\nCONDITION OK");
            
        }else {
            //Print("\nCONDITION OK");
        }
    }
}
//+------------------------------------------------------------------+
//| Update SL                                                        |
//+------------------------------------------------------------------+
void UpdateSL(double lastest_pos_sl) {
    
    Print("\n\n\n>>>>>>>>>>>>>UpdateSL<<<<<<<<<<<");
    
    for(int i = PositionsTotal()-1; i>=0; i--) {
        
        ulong ticket = PositionGetTicket(i);
        
        PositionSelectByTicket(ticket);
          
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        
        Print("ticket=",ticket, "\ncurrent_SL=", currentSL, "\nlast_pos_sl=", lastest_pos_sl);
        
        
        if(currentSL != lastest_pos_sl) {
            Print("\nCONDITION OK");
            m_trade.PositionModify(ticket, lastest_pos_sl, currentTP);
            
        }else {
            Print("\nCONDITION OK");
        }
    }
    
}
//+------------------------------------------------------------------+
//| Calculate TP                                                                  |
//+------------------------------------------------------------------+
double CalculateTP(double price_at_x, double price_at_y){
    double tp = 0.0;
    if(PositionsTotal() <= InpTPLevelChange){
        tp = GetM5PriceAtFiboPercent(price_at_x, price_at_y, InpTPFiboLevel1);
    }else{
        tp = GetM5PriceAtFiboPercent(price_at_x, price_at_y, InpTPFiboLevel2);
    }
    return tp;   

}
//+------------------------------------------------------------------+
//| Check Balance Stop                                               |
//+------------------------------------------------------------------+
bool CheckBalanceStop(){
    double profit = 0.0;
    for(int i=PositionsTotal()-1;i>=0;i--){
         if (m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
            if (m_position.Symbol() == m_symbol.Name() && m_position.Magic() == m_magic)
                 profit += PositionGetDouble(POSITION_PROFIT);
      
    }
    double balance = m_account.Balance();
   
    if(profit < 0){
      double curren_profit_percent = MathAbs(profit / balance) * 100;
      if(curren_profit_percent > InpBalanceStopLoss){
         //Print("Check Balance Stop ok");
         return true;
         
      }else{
          Print("Check Balance Stop false");
          return false;
      }   
    }
    message_log += "Profit= " + (string)profit;
     
   return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawZZM5ABCD(){
   ObjectDelete(0,"M5LineAB");
   if (!ObjectCreate(0, "M5LineAB", OBJ_TREND, 0, m5_zz_a_time, m5_zz_a_price, m5_zz_b_time, m5_zz_b_price))
      return;
      
   ObjectSetInteger(0, "M5LineAB", OBJPROP_COLOR, InpM5ZigZagABCDColor);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_WIDTH, InpM5ZigZagABCDWidth);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_BACK, false);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_ZORDER, 0);
   
   ObjectDelete(0,"M5LineBC");
   if (!ObjectCreate(0, "M5LineBC", OBJ_TREND, 0, m5_zz_b_time, m5_zz_b_price, m5_zz_c_time, m5_zz_c_price))
      return;
   ObjectSetInteger(0, "M5LineBC", OBJPROP_COLOR, InpM5ZigZagABCDColor);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_WIDTH, InpM5ZigZagABCDWidth);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_BACK, false);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_ZORDER, 0);
   
   ObjectDelete(0,"M5LineCD");
   if (!ObjectCreate(0, "M5LineCD", OBJ_TREND, 0, m5_zz_c_time, m5_zz_c_price, m5_zz_d_time, m5_zz_d_price))
      return;
   ObjectSetInteger(0, "M5LineCD", OBJPROP_COLOR, InpM5ZigZagABCDColor);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_WIDTH, InpM5ZigZagABCDWidth);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_BACK, false);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_ZORDER, 0);
   
   ObjectDelete(0,"M5A");
   if(!ObjectCreate(0,"M5A",OBJ_TEXT,0,m5_zz_a_time,m5_zz_a_price))
      return;
   ObjectSetString(0,"M5A",OBJPROP_TEXT,"M5A");
   ObjectSetString(0,"M5A",OBJPROP_FONT,"Arial");  
   ObjectSetInteger(0,"M5A",OBJPROP_FONTSIZE,10); 
   ObjectSetInteger(0,"M5A",OBJPROP_COLOR,InpM5ZigZagABCDColor);
   
   ObjectDelete(0,"M5B");
   if(!ObjectCreate(0,"M5B",OBJ_TEXT,0,m5_zz_b_time,m5_zz_b_price))
      return;
   ObjectSetString(0,"M5B",OBJPROP_TEXT,"M5B");
   ObjectSetString(0,"M5B",OBJPROP_FONT,"Arial");  
   ObjectSetInteger(0,"M5B",OBJPROP_FONTSIZE,10); 
   ObjectSetInteger(0,"M5B",OBJPROP_COLOR,InpM5ZigZagABCDColor);
   
   ObjectDelete(0,"M5C");
   if(!ObjectCreate(0,"M5C",OBJ_TEXT,0,m5_zz_c_time,m5_zz_c_price))
      return;
   ObjectSetString(0,"M5C",OBJPROP_TEXT,"M5C");
   ObjectSetString(0,"M5C",OBJPROP_FONT,"Arial");  
   ObjectSetInteger(0,"M5C",OBJPROP_FONTSIZE,10); 
   ObjectSetInteger(0,"M5C",OBJPROP_COLOR,InpM5ZigZagABCDColor);
   
   ObjectDelete(0,"M5D");
   if(!ObjectCreate(0,"M5D",OBJ_TEXT,0,m5_zz_d_time,m5_zz_d_price))
      return;
   ObjectSetString(0,"M5D",OBJPROP_TEXT,"M5D");
   ObjectSetString(0,"M5D",OBJPROP_FONT,"Arial");  
   ObjectSetInteger(0,"M5D",OBJPROP_FONTSIZE,10); 
   ObjectSetInteger(0,"M5D",OBJPROP_COLOR,InpM5ZigZagABCDColor);   
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawZZM1CD(){
   ObjectDelete(0,"LineCD");
   if (!ObjectCreate(0, "LineCD", OBJ_TREND, 0, m1_time_array[1], m1_cd_array[1], m1_time_array[0], m1_cd_array[0]))
      return;
   ObjectSetInteger(0, "LineCD", OBJPROP_COLOR, InpM1ZigZagCDColor);
   ObjectSetInteger(0, "LineCD", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "LineCD", OBJPROP_WIDTH, InpM1ZigZagCDWidth);
   ObjectSetInteger(0, "LineCD", OBJPROP_BACK, false);
   ObjectSetInteger(0, "LineCD", OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, "LineCD", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, "LineCD", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, "LineCD", OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, "LineCD", OBJPROP_ZORDER, 0);
   
   ObjectDelete(0,"C");
   if(!ObjectCreate(0,"C",OBJ_TEXT,0,m1_time_array[1],m1_cd_array[1]))
      return;
   ObjectSetString(0,"C",OBJPROP_TEXT,"C");
   ObjectSetString(0,"C",OBJPROP_FONT,"Arial");  
   ObjectSetInteger(0,"C",OBJPROP_FONTSIZE,10); 
   ObjectSetInteger(0,"C",OBJPROP_COLOR,InpM1ZigZagCDColor);
   
   ObjectDelete(0,"D");
   if(!ObjectCreate(0,"D",OBJ_TEXT,0,m1_time_array[0],m1_cd_array[0]))
      return;
   ObjectSetString(0,"D",OBJPROP_TEXT,"D");
   ObjectSetString(0,"D",OBJPROP_FONT,"Arial");  
   ObjectSetInteger(0,"D",OBJPROP_FONTSIZE,10); 
   ObjectSetInteger(0,"D",OBJPROP_COLOR,InpM1ZigZagCDColor);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawM5FiboBuySell(double A, double B, datetime TimeA, datetime TimeB, double fibo_percent_small, double fibo_percent_big, color ColorFibo){
   ObjectDelete( 0, "FIBOBUYORSELL");
   if(!ObjectCreate( 0, "FIBOBUYORSELL", OBJ_FIBO, 0, TimeA, A, TimeB, B))
      return;
   ObjectSetInteger(0, "FIBOBUYORSELL", OBJPROP_LEVELCOLOR, ColorFibo);
   ObjectSetInteger(0, "FIBOBUYORSELL", OBJPROP_LEVELSTYLE, STYLE_SOLID);
   ObjectSetInteger(0, "FIBOBUYORSELL", OBJPROP_RAY_LEFT, true);
   ObjectSetInteger(0, "FIBOBUYORSELL", OBJPROP_LEVELS, 4);
   ObjectSetDouble(0,  "FIBOBUYORSELL", OBJPROP_LEVELVALUE, 0, 0.000);
   ObjectSetDouble(0,  "FIBOBUYORSELL", OBJPROP_LEVELVALUE, 1, fibo_percent_small/100);
   ObjectSetDouble(0,  "FIBOBUYORSELL", OBJPROP_LEVELVALUE, 2, fibo_percent_big/100);
   ObjectSetDouble(0,  "FIBOBUYORSELL", OBJPROP_LEVELVALUE, 3, 1.000);
   ObjectSetString(0,  "FIBOBUYORSELL", OBJPROP_LEVELTEXT, 0, "0.0% (%$)");
   ObjectSetString(0,  "FIBOBUYORSELL", OBJPROP_LEVELTEXT, 1, DoubleToString(fibo_percent_small,1)+"% (%$)");
   ObjectSetString(0,  "FIBOBUYORSELL", OBJPROP_LEVELTEXT, 2, DoubleToString(fibo_percent_big,1) +"% (%$)");
   ObjectSetString(0,  "FIBOBUYORSELL", OBJPROP_LEVELTEXT, 3, "100.0% (%$)");
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawM5FiboTP(double A, double B, datetime TimeA, datetime TimeB){
   ObjectDelete( 0, "FIBOTP");
   if(!ObjectCreate( 0, "FIBOTP", OBJ_FIBO, 0, TimeA, A, TimeB, B))
      return;
   ObjectSetInteger(0, "FIBOTP", OBJPROP_LEVELCOLOR, InpTPColor);
   ObjectSetInteger(0, "FIBOTP", OBJPROP_LEVELSTYLE, STYLE_SOLID);
   ObjectSetInteger(0, "FIBOTP", OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, "FIBOTP", OBJPROP_LEVELS, 4);
   ObjectSetDouble(0,  "FIBOTP", OBJPROP_LEVELVALUE, 0, 0.000);
   ObjectSetDouble(0,  "FIBOTP", OBJPROP_LEVELVALUE, 1, InpTPFiboLevel1/100);
   ObjectSetDouble(0,  "FIBOTP", OBJPROP_LEVELVALUE, 2, InpTPFiboLevel2/100);
   ObjectSetDouble(0,  "FIBOTP", OBJPROP_LEVELVALUE, 3, 1.000);
   ObjectSetString(0,  "FIBOTP", OBJPROP_LEVELTEXT, 0, "0.0% (%$)");
   ObjectSetString(0,  "FIBOTP", OBJPROP_LEVELTEXT, 1, DoubleToString(InpTPFiboLevel1,1)+"% (%$)");
   ObjectSetString(0,  "FIBOTP", OBJPROP_LEVELTEXT, 2, DoubleToString(InpTPFiboLevel2,1) +"% (%$)");
   ObjectSetString(0,  "FIBOTP", OBJPROP_LEVELTEXT, 3, "100.0% (%$)");
}