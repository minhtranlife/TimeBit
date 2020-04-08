//+------------------------------------------------------------------+
//|                                                      RWF_v84.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Expert\Money\MoneyFixedMargin.mqh>
//---
CPositionInfo                       m_position;                                 // trade position object
CTrade                              m_trade;                                    // trading object
CSymbolInfo                         m_symbol;                                   // symbol info object
CAccountInfo                        m_account;                                  // account info wrapper
CDealInfo                           m_deal;                                     // deals object
COrderInfo                          m_order;                                    // pending orders object
CMoneyFixedMargin                   *m_money;

input string                        InpTimeStart                        = "01:00:00";       // Timestart
input string                        InpTimeStop                         = "23:30:00";       // Timestop
input int                           Inp_Blance_Percent_Stop                     = 20;               //Blance Stop (%) 

input string                        InpVolumes                          = "0.01, 0.02, 0.04, 0.08, 0.16, 0.32, 0.64, 1.28";

input ushort                        Inp_Range_CD                        = 70;               //Range CD min (pips)

input int                           Inp_ZZ_m5_zz_depth                     = 12;                //ZigZag M5 Depth
input int                           Inp_ZZ_m5_zz_deviation                 = 5;                 //ZigZag M5 Deviation
input int                           Inp_ZZ_m5_zz_backStep                  = 3;                 //ZigZag M5 Backstep
input color                         Inp_ZZ_m5_zz_color                     = clrYellow;         //ZigZag M5 Color   

input int                           Inp_ZZ_m1_zz_depth                     = 12;                //ZigZag M1 Depth
input int                           Inp_ZZ_m1_zz_deviation                 = 5;                 //ZigZag M1 Deviation
input int                           Inp_ZZ_M1_BackStep                  = 3;                 //ZigZag M1 Backstep
input color                         Inp_ZZ_m1_zz_color                  = clrBlue;           //ZigZag M1 Color

//---
input double                        Inp_Fibo_AB_Percent_Small             = 10.0;             //Fibo AB (Small)
input double                        Inp_Fibo_AB_Percent_Big             = 40.0;             //Fibo AB  (Big)

//---
input double                        Inp_Fibo_CD_Percent_Small             = 10.0;              //Fibo CD (Small)
input double                        Inp_Fibo_CD_Percent_Big             = 40.0;              //Fibo CD (Big)

input color                         Inp_Fibo_AB_color                   = clrAqua;
input color                         Inp_Fibo_CD_color                   = clrGreen;

double                              m_adjusted_point;                                       // point value adjusted for 3 or 5 points



int                                 handle_ZZ_M5;
int                                 handle_ZZ_M1;
MqlRates                            Rates_Array[];
double                              M5_ZZ_ABCD[4];
datetime                            M5_ZZ_ABCD_DateTime[4];
double                              M1_ZZ_CD[2];
datetime                            M1_ZZ_CD_DateTime[2];
string                              m5_trend;
string                              Order_type;
string                              volumes_string_array[];

int                                 MaxPosition                      = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  { 
   
//--- 
   if(!ConvertVolume()){
      Print("Stop! Input Volume false!");
      return(INIT_FAILED);
   }   
   if(!m_symbol.Name(Symbol())){  // sets symbol name
      Print("Get Symbol name false!");
      return (INIT_FAILED);
   }   
      
   if(!InitZigZagM5()){
      Print("InitM5ZZ false!");
      return(INIT_FAILED);
   }
   if(!InitZigZagM1()){
      Print("InitM1ZZ false!");
      return (INIT_FAILED);
   }
   
   SetAdjustedPoint();
   
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
void OnTick()
  {
//---
     
      ShowZZM5();
      ShowZZM1();
      ShowM5Fibo();
      if(CheckBase()){
         Print("Check base ok");
         if(!CheckBalanceStop()){
            Print("check blance stop ok");
            if(CheckM5Range(M5_ZZ_ABCD[1], M5_ZZ_ABCD[0])){
               Print("Check range M5 ok");
               if(CheckM5FiboCondition(M5_ZZ_ABCD[3], M5_ZZ_ABCD[2], M5_ZZ_ABCD[1])){
                  Print("Check M5 Fibo ok");
                  if(CheckM1Reverse(M1_ZZ_CD[1], M1_ZZ_CD[0], m5_trend)){
                     Print("Check M1 Reverse ok! Ready for trade!", Order_type);
                     
                     
                  }else{
                     Print("Check M1 Reverse false");
                  }
                  
                  //
               }else{
                  ObjectDelete( 0, "FIBOAB");
                  Print("Check M5 Fibo false");
               }               
               
            }else{
               Print("Check range M5 false!");
               
            }
            
         }else{
            Print("check blance stop false! Stop Trading");
         }
      }else{
         Print("Check base false");
      }
      
   
  }
//+------------------------------------------------------------------+


   
bool InitZigZagM5() {
   handle_ZZ_M5  = iCustom(m_symbol.Name(),PERIOD_M5,"Examples/ZigZag",Inp_ZZ_m5_zz_depth, Inp_ZZ_m5_zz_deviation, Inp_ZZ_m5_zz_backStep);
   if(handle_ZZ_M5 != NULL){
      return (true);
   }
   return false;
}
//+------------------------------------------------------------------+
//| Set M5 ZZ ABCD                                                   |
//+------------------------------------------------------------------+
bool SetM5ZZABCD(int handle, double & ABCD[], datetime & ABCD_DateTime[]){

   double ZZ_Buffer[];
   int start_pos = 0, count = 200;
   int CopyNumber = CopyBuffer(handle, 0, start_pos, count, ZZ_Buffer);
   
   if(CopyNumber > 0) {
      ArraySetAsSeries(ZZ_Buffer, true);  
               
      ArraySetAsSeries(Rates_Array, true);
      if(CopyRates(m_symbol.Name(), PERIOD_M5, start_pos, count, Rates_Array) > 0){   
         int Zcount_M5 = 0;
         for(int i = 0; i <= CopyNumber && Zcount_M5 <= 3 && !IsStopped(); i++){
            if(ZZ_Buffer[i] != 0.0){
               ABCD[Zcount_M5] = ZZ_Buffer[i];
               ABCD_DateTime[Zcount_M5] = Rates_Array[i].time;
               Zcount_M5++;               
            }
         }
      }
      if(ABCD[3] > ABCD[1] && ABCD[2] > ABCD[0]){
         m5_trend = "DOWN";
      }
      if(ABCD[3] < ABCD[1] && ABCD[2] < ABCD[0]){
         m5_trend = "UP";
      }
      
      return true;
   }
       
   else {
       Print("Indicator Bufer Unavailable");
       return false;
   }
   
   return false;
}


void ShowZZM5(){
   SetM5ZZABCD(handle_ZZ_M5, M5_ZZ_ABCD, M5_ZZ_ABCD_DateTime);
   DrawZZM5ABCD(M5_ZZ_ABCD[3], M5_ZZ_ABCD[2], M5_ZZ_ABCD[1], M5_ZZ_ABCD[0], M5_ZZ_ABCD_DateTime[3],  M5_ZZ_ABCD_DateTime[2],  M5_ZZ_ABCD_DateTime[1],  M5_ZZ_ABCD_DateTime[0], Inp_ZZ_m5_zz_color);
}
//+------------------------------------------------------------------+
//|  Show ZigZag M5                                                  |
//+------------------------------------------------------------------+
void DrawZZM5ABCD(double A, double B,double C, double D,datetime TimeA, datetime TimeB, datetime TimeC, datetime TimeD, color ColorZZM5){
   ObjectDelete(0,"M5LineAB");
   if (!ObjectCreate(0, "M5LineAB", OBJ_TREND, 0, TimeA, A, TimeB, B))
      return;
      
   ObjectSetInteger(0, "M5LineAB", OBJPROP_COLOR, ColorZZM5);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_WIDTH, 10);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_BACK, false);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, "M5LineAB", OBJPROP_ZORDER, 0);
   
   ObjectDelete(0,"M5LineBC");
   if (!ObjectCreate(0, "M5LineBC", OBJ_TREND, 0, TimeB, B, TimeC, C))
      return;
   ObjectSetInteger(0, "M5LineBC", OBJPROP_COLOR, ColorZZM5);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_WIDTH, 10);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_BACK, false);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, "M5LineBC", OBJPROP_ZORDER, 0);
   
   ObjectDelete(0,"M5LineCD");
   if (!ObjectCreate(0, "M5LineCD", OBJ_TREND, 0, TimeC, C, TimeD, D))
      return;
   ObjectSetInteger(0, "M5LineCD", OBJPROP_COLOR, ColorZZM5);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_WIDTH, 10);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_BACK, false);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, "M5LineCD", OBJPROP_ZORDER, 0);
   
   ObjectDelete(0,"M5A");
   if(!ObjectCreate(0,"M5A",OBJ_TEXT,0,TimeA,A))
      return;
   ObjectSetString(0,"M5A",OBJPROP_TEXT,"M5A");
   ObjectSetString(0,"M5A",OBJPROP_FONT,"Arial");  
   ObjectSetInteger(0,"M5A",OBJPROP_FONTSIZE,10); 
   ObjectSetInteger(0,"M5A",OBJPROP_COLOR,ColorZZM5);
   
   ObjectDelete(0,"M5B");
   if(!ObjectCreate(0,"M5B",OBJ_TEXT,0,TimeB,B))
      return;
   ObjectSetString(0,"M5B",OBJPROP_TEXT,"M5B");
   ObjectSetString(0,"M5B",OBJPROP_FONT,"Arial");  
   ObjectSetInteger(0,"M5B",OBJPROP_FONTSIZE,10); 
   ObjectSetInteger(0,"M5B",OBJPROP_COLOR,Yellow);
   
   ObjectDelete(0,"M5C");
   if(!ObjectCreate(0,"M5C",OBJ_TEXT,0,TimeC,C))
      return;
   ObjectSetString(0,"M5C",OBJPROP_TEXT,"M5C");
   ObjectSetString(0,"M5C",OBJPROP_FONT,"Arial");  
   ObjectSetInteger(0,"M5C",OBJPROP_FONTSIZE,10); 
   ObjectSetInteger(0,"M5C",OBJPROP_COLOR,ColorZZM5);
   
   ObjectDelete(0,"M5D");
   if(!ObjectCreate(0,"M5D",OBJ_TEXT,0,TimeD,D))
      return;
   ObjectSetString(0,"M5D",OBJPROP_TEXT,"M5D");
   ObjectSetString(0,"M5D",OBJPROP_FONT,"Arial");  
   ObjectSetInteger(0,"M5D",OBJPROP_FONTSIZE,10); 
   ObjectSetInteger(0,"M5D",OBJPROP_COLOR,ColorZZM5);   
}

bool InitZigZagM1(){
   handle_ZZ_M1 = iCustom(m_symbol.Name(),PERIOD_M1,"Examples/ZigZag",Inp_ZZ_m1_zz_depth, Inp_ZZ_m1_zz_deviation, Inp_ZZ_M1_BackStep);
   if(handle_ZZ_M1 != NULL){
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get M1 ZZ CD                                                     |
//+------------------------------------------------------------------+
void SetM1ZZCD(int handle, double & CD[], datetime & CD_DateTime[]){
   double ZZ_Buffer[];
   int start_pos = 0, count = 200;
   int CopyNumber = CopyBuffer(handle, 0, start_pos, count, ZZ_Buffer);
   
   if(CopyNumber <= 0)
      Print("Indicator Bufer Unavailable");
   ArraySetAsSeries(ZZ_Buffer, true);  
               
   ArraySetAsSeries(Rates_Array, true);
   if(CopyRates(m_symbol.Name(), PERIOD_M1, start_pos, count, Rates_Array) > 0){   
      int Zcount_M5 = 0;
      for(int i = 0; i <= CopyNumber && Zcount_M5 <= 1 && !IsStopped(); i++){
         if(ZZ_Buffer[i] != 0.0){
            CD[Zcount_M5] = ZZ_Buffer[i];
            CD_DateTime[Zcount_M5] = Rates_Array[i].time;
            Zcount_M5++;               
         }
      }
   } 
}
void ShowZZM1(){
   SetM1ZZCD(handle_ZZ_M1, M1_ZZ_CD, M1_ZZ_CD_DateTime);
   DrawZZM1CD(M1_ZZ_CD[1], M1_ZZ_CD[0], M1_ZZ_CD_DateTime[1], M1_ZZ_CD_DateTime[0], Inp_ZZ_m1_zz_color);
}
//+------------------------------------------------------------------+
//|  Show ZigZag M1                                                  |
//+------------------------------------------------------------------+
void DrawZZM1CD(double C, double D, datetime TimeC, datetime TimeD, color ColorZZM1){  
   ObjectDelete(0,"LineCD");
   if (!ObjectCreate(0, "LineCD", OBJ_TREND, 0, TimeC, C, TimeD, D))
      return;
   ObjectSetInteger(0, "LineCD", OBJPROP_COLOR, ColorZZM1);
   ObjectSetInteger(0, "LineCD", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "LineCD", OBJPROP_WIDTH, 10);
   ObjectSetInteger(0, "LineCD", OBJPROP_BACK, false);
   ObjectSetInteger(0, "LineCD", OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, "LineCD", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, "LineCD", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, "LineCD", OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, "LineCD", OBJPROP_ZORDER, 0);
   
   ObjectDelete(0,"C");
   if(!ObjectCreate(0,"C",OBJ_TEXT,0,TimeC,C))
      return;
   ObjectSetString(0,"C",OBJPROP_TEXT,"C");
   ObjectSetString(0,"C",OBJPROP_FONT,"Arial");  
   ObjectSetInteger(0,"C",OBJPROP_FONTSIZE,10); 
   ObjectSetInteger(0,"C",OBJPROP_COLOR,ColorZZM1);
   
   ObjectDelete(0,"D");
   if(!ObjectCreate(0,"D",OBJ_TEXT,0,TimeD,D))
      return;
   ObjectSetString(0,"D",OBJPROP_TEXT,"D");
   ObjectSetString(0,"D",OBJPROP_FONT,"Arial");  
   ObjectSetInteger(0,"D",OBJPROP_FONTSIZE,10); 
   ObjectSetInteger(0,"D",OBJPROP_COLOR,ColorZZM1);   
}


bool CheckBase(){
   if(CheckFreeMargin()){
      if(checktime(starttime(),endtime())){
         Print("Check Free Margin ok");
         return true;
      }else{
         Print("Check time error");
         return false;
      }
   }else{
      Print("Check Free Margin false");
      return false;
   }
   return false;

}
bool CheckFreeMargin(){
   double free_margin = m_account.FreeMargin();
   double balance = m_account.Balance();
   if(free_margin >= (Inp_Blance_Percent_Stop/100) * balance)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check time range function                                        |
//+------------------------------------------------------------------+
datetime starttime(){
   string currentdatestr=TimeToString(TimeCurrent(),TIME_DATE);
   string datetimenow=currentdatestr+ " "+InpTimeStart;
   return StringToTime(datetimenow);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime endtime(){
   string currentdatestr=TimeToString(TimeCurrent(),TIME_DATE);
   string datetimenow=currentdatestr+ " "+InpTimeStop;
   return StringToTime(datetimenow);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool checktime(datetime start,datetime end){
   datetime dt=TimeCurrent();                          // current time
   if(start<end)
      if(dt>=start && dt<end)
         return(true); // check if we are in the range
   if(start>=end)
      if(dt>=start|| dt<end)
         return(true);
   return(false);
}

bool CheckBalanceStop(){
   double profit = m_account.Profit();
   double balance = m_account.Balance();
   
   if(profit < 0){
      double curren_profit_percent = MathAbs(profit / balance) * 100;
      if(curren_profit_percent < Inp_Blance_Percent_Stop){
         Print("Check Balance Stop ok");
         return true;
         
      }else{
          Print("Check Balance Stop false");
          return false;
      }   
   }
     
   return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckCoditionBuy(double m5zza, double m5zzb, double m5zzc, double m5zzd){
   if(m5zza > m5zzc && m5zzb > m5zzd)
      return (true);
   return (false);
}
bool CheckCoditionSell(double m5zza, double m5zzb, double m5zzc, double m5zzd){
   if(m5zza < m5zzc && m5zzc < m5zzd)
      return (true);
   return (false);
}
bool CheckM5Range(double m5zzc, double m5zzd){  
    
   if(CalculateCD(m5zzc, m5zzd) >= Inp_Range_CD){
      Print("M5 Range ok");
      return (true);     
   }else{
      //Print("M5 Range false");
      return false;
   }
   return (false);
}
double CalculateCD(double m5zzc, double m5zzd){
   double rangeCD = 0.0;
   if(m_symbol.Digits() == 3){
      rangeCD = MathAbs(m5zzc - m5zzd) * 100;
      
   }
   if(m_symbol.Digits() == 5){
      rangeCD = MathAbs(m5zzc - m5zzd) * 10000;
   }
   Print("C= ", m5zzc, ", D = ", m5zzd,"- Range = ", rangeCD);
   
   return rangeCD;
}

bool CheckM5FiboCondition(double m5zza, double m5zzb, double m5zzc){
   double pricesmall = GetPriceFibo(m5zza, m5zzb, Inp_Fibo_AB_Percent_Small);
   double pricebig = GetPriceFibo(m5zza, m5zzb, Inp_Fibo_AB_Percent_Big);
   if(pricesmall < m5zzc < pricebig){
      Print("Check M5 Fibo ok");
      return (true);
   }else{
      Print("Check M5 Fibo false");
      return (false);
   }
   return (false);
}
void ShowM5Fibo(){
   DrawM5FiboABC(M5_ZZ_ABCD[3], M5_ZZ_ABCD[2], M5_ZZ_ABCD_DateTime[3], M5_ZZ_ABCD_DateTime[2],Inp_Fibo_AB_Percent_Small, Inp_Fibo_AB_Percent_Big,Inp_Fibo_AB_color);
}

void DrawM5FiboABC(double A, double B, datetime TimeA, datetime TimeB, double fibo_percent_small, double fibo_percent_big, color ColorFiboAB){
   ObjectDelete( 0, "FIBOAB");
   if(!ObjectCreate( 0, "FIBOAB", OBJ_FIBO, 0, TimeA, A, TimeB, B))
      return;
   ObjectSetInteger(0, "FIBOAB", OBJPROP_LEVELCOLOR, ColorFiboAB);
   ObjectSetInteger(0, "FIBOAB", OBJPROP_LEVELSTYLE, STYLE_SOLID);
   ObjectSetInteger(0, "FIBOAB", OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, "FIBOAB", OBJPROP_LEVELS, 4);
   ObjectSetDouble(0,  "FIBOAB", OBJPROP_LEVELVALUE, 0, 0.000);
   ObjectSetDouble(0,  "FIBOAB", OBJPROP_LEVELVALUE, 1, fibo_percent_small/100);
   ObjectSetDouble(0,  "FIBOAB", OBJPROP_LEVELVALUE, 2, fibo_percent_big/100);
   ObjectSetDouble(0,  "FIBOAB", OBJPROP_LEVELVALUE, 3, 1.000);
   ObjectSetString(0,  "FIBOAB", OBJPROP_LEVELTEXT, 0, "0.0% (%$)");
   ObjectSetString(0,  "FIBOAB", OBJPROP_LEVELTEXT, 1, DoubleToString(fibo_percent_small,1)+"% (%$)");
   ObjectSetString(0,  "FIBOAB", OBJPROP_LEVELTEXT, 2, DoubleToString(fibo_percent_big,1) +"% (%$)");
   ObjectSetString(0,  "FIBOAB", OBJPROP_LEVELTEXT, 3, "100.0% (%$)");
}


double GetPriceFibo(double m5zza, double m5zzb, double percent){
   double price = 0.0;
   if(m5zza > m5zzb){
      double range = m5zza - m5zzb;
      price = price = m5zzb + (percent/100)* range;
   }
   if(m5zza < m5zzb){
      double range = m5zzb - m5zza;
      price = m5zzb - (percent/100)* range;
   }
   return price;
}

bool CheckM1Reverse(double m1zzc, double m1zzd, string trend){
   if(trend == "UP"){
      if( m1zzc > m1zzd){
         Order_type = "SELL";
         return (true);
      }
   }
   if(trend == "DOWN"){
      if( m1zzc < m1zzd){
         Order_type = "BUY";
         return (true);
      }
   }   
   return (false);
}


bool ConvertVolume(){
   string to_split= InpVolumes;
   StringReplace(to_split," ","");
   string sep=",";                // A separator as a character
   ushort u_sep;                  // The code of the separator character
   Print("String", to_split);
   //--- Get the separator code
   u_sep=StringGetCharacter(sep,0);
   //--- Split the string to substrings
   //Print("Befor Split");
   MaxPosition = StringSplit(to_split,u_sep,volumes_string_array);
   /*Print("After Split");
   Print("Max position= ", MaxPosition);
   for(int i =0; i < MaxPosition; i++){
      Print("Str = ", volumes_string_array[i]);
   }*/
   if(MaxPosition >0){
      return (true);
   }
 
   return false;
}

void SetAdjustedPoint(){
   int digits_adjust = 1;
   if(m_symbol.Digits() == 3 || m_symbol.Digits() == 5)
      digits_adjust = 10;
   m_adjusted_point = m_symbol.Point() * digits_adjust;   
}

