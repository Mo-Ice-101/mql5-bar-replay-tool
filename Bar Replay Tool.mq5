//+------------------------------------------------------------------+
//|                                              Bar Replay Tool.mq5 |
//|                                             © 2026, ChukwuBuikem |
//|                             https://www.mql5.com/en/users/bikeen |
//+------------------------------------------------------------------+
#property copyright "© 2026, ChukwuBuikem"
#property link      "https://www.mql5.com/en/users/bikeen"
#property indicator_chart_window
#property indicator_plots 1
#property indicator_buffers 5
#property indicator_type1 DRAW_COLOR_CANDLES
#property indicator_color1 clrGreen,clrRed,clrNONE;
#property indicator_width1 2
#property indicator_label1 "REPLAY: OPEN;REPLAY: HIGH;REPLAY: LOW;REPLAY: CLOSE"

#define _PROG_NAME "Bar Replay Tool"
#define _MENU_BUTTON _PROG_NAME + "MENU_BUTTON"
#define _REPLAY_ANCHORLINE _PROG_NAME + "REPLAY_VLINE"
#define _REPLAY_PRICE _PROG_NAME + "REPLAY_PRICE"
#define _REPLAY_PLAY_BUTTON _PROG_NAME + "REPLAY_PLAY_BUTTON"
#define _REPLAY_DASHBOARD _PROG_NAME + "REPLAY_DASHBOARD"
//--- PLAY AND PAUSE UNICODE SYMBOLS
#define _PLAY_SYMBOL ShortToString(0X25B6)
#define _PAUSE_SYMBOL ShortToString(0X23F8)
//--- REPLAY TRADE MACROS
#define _REPLAY_BUY_BUTTON _PROG_NAME + "REPLAY_BUY_BUTTON"
#define _REPLAY_SELL_BUTTON _PROG_NAME + "REPLAY_SELL_BUTTON"
#define _REPLAY_POSITION_ENTRY _PROG_NAME + "REPLAY_POSITION_ENTRY"
#define _REPLAY_POSITION_TP _PROG_NAME + "REPLAY_POSITION_TP"
#define _REPLAY_POSITION_SL _PROG_NAME + "REPLAY_POSITION_SL"

//--- CUSTOM DATA STRUCTURE
struct st_ChartInfo
  {
private:
   color             barUpClr;
   color             barDownClr;
   color             bullClr;
   color             bearClr;
   color             lineClr;
   color             askClr;
   color             bidClr;
public:
   //---
                     st_ChartInfo()
     {
      barUpClr = (color)ChartGetInteger(0, CHART_COLOR_CHART_UP);
      barDownClr = (color)ChartGetInteger(0, CHART_COLOR_CHART_DOWN);
      bullClr = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BULL);
      bearClr = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR);
      lineClr = (color)ChartGetInteger(0, CHART_COLOR_CHART_LINE);
      askClr = (color)ChartGetInteger(0, CHART_COLOR_ASK);
      bidClr = (color)ChartGetInteger(0, CHART_COLOR_BID);
     }
   //--- FUNCTIONS
   void              customize();
   void              restore();
   color             getPriceColor();

  } chartState;

//--- GLOBAL VARIABLES
MqlRates myRates[];
double openBuffer[], highBuffer[];
double lowBuffer[], closeBuffer[], colorBuffer[];
bool isPositionOpen = false;
bool replayMode = false;
bool isPlay = false;
datetime vlineTime = 0;
int stopBar = INT_MIN;
int bars = INT_MIN;
int lastCalculated = 0;
ENUM_POSITION_TYPE positionType = POSITION_TYPE_BUY;
double entryPrice = EMPTY_VALUE, tpPrice = EMPTY_VALUE, slPrice = EMPTY_VALUE;
double lastPrice = EMPTY_VALUE;

//+------------------------------------------------------------------+
//|                     CUSTOMIZE CHART                              |
//+------------------------------------------------------------------+
void st_ChartInfo::customize(void)
  {
//---
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrNONE);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrNONE);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrNONE);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrNONE);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, clrNONE);
   ChartSetInteger(0, CHART_COLOR_ASK, clrNONE);
   ChartSetInteger(0, CHART_COLOR_BID, clrNONE);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//|                        RESTORE CHART SETTINGS                    |
//+------------------------------------------------------------------+
void st_ChartInfo::restore(void)
  {
//---
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, bullClr);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, bearClr);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, barUpClr);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, barDownClr);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, lineClr);
   ChartSetInteger(0, CHART_COLOR_ASK, askClr);
   ChartSetInteger(0, CHART_COLOR_BID, bidClr);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//|                      OBTAIN PRICE COLOR                          |
//+------------------------------------------------------------------+
color st_ChartInfo::getPriceColor(void)
  {
//---
   return bidClr;
  }

//+------------------------------------------------------------------+
//|                    VIEWPORT DETECTION                            |
//+------------------------------------------------------------------+
datetime getViewportMiddleTime(void)
  {
//---
   datetime start = 0, end = 0;
   int first = (int) ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int visibleBars = (int) ChartGetInteger(0, CHART_VISIBLE_BARS);

   int last = first - visibleBars + 2;
   if(last < 0)
      last = 0;

   start = iTime(_Symbol, PERIOD_CURRENT, last);
   end = iTime(_Symbol, PERIOD_CURRENT, first);

   datetime rawMiddleTime = (start + end) / 2;
   int nearestBar = iBarShift(_Symbol, PERIOD_CURRENT, rawMiddleTime, false);
   if(nearestBar < 0)
      return 0;

   return iTime(_Symbol, PERIOD_CURRENT, nearestBar);
  }

//+------------------------------------------------------------------+
//|                      BUTTON CREATION                             |
//+------------------------------------------------------------------+
void createButton(const string objName, const int xDistance, const int yDistance,
                  const int xSize, const int ySize, const ENUM_BASE_CORNER corner,
                  const color clr, const color bgClr, const color bdClr, const int fontsize,
                  const string tooltip, const string display, const string font = "Arial")
  {
//---
   if(ObjectFind(0, objName) != -1)
      ObjectDelete(0, objName);

   ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xDistance);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yDistance);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, xSize);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, ySize);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void createDashboard(void)
  {
//---
   if(ObjectCreate(0, _REPLAY_DASHBOARD, OBJ_RECTANGLE_LABEL, 0, 0, 0))
     {
      ObjectSetInteger(0, _REPLAY_DASHBOARD, OBJPROP_XDISTANCE, 70);
      ObjectSetInteger(0, _REPLAY_DASHBOARD, OBJPROP_YDISTANCE, 50);
      ObjectSetInteger(0, _REPLAY_DASHBOARD, OBJPROP_XSIZE, 110);
      ObjectSetInteger(0, _REPLAY_DASHBOARD, OBJPROP_YSIZE, 40);
      //--- CREATE PLAYBACK, BUY, AND SELL BUTTONS
      createButton(_REPLAY_PLAY_BUTTON, 75, 45, 30, 30, CORNER_LEFT_LOWER,
                   clrWhite, clrDimGray, clrBlack, 20, "Playback Control", _PLAY_SYMBOL, "Segoe UI");
      createButton(_REPLAY_BUY_BUTTON, 110, 45, 30, 30, CORNER_LEFT_LOWER,
                   clrWhite, clrBlue, clrBlack, 8, "BUY", "BUY", "Bold");
      createButton(_REPLAY_SELL_BUTTON, 145, 45, 30, 30, CORNER_LEFT_LOWER,
                   clrWhite, clrRed, clrBlack, 8, "SELL", "SELL", "Bold");
      ChartRedraw();
     }
  }
//+------------------------------------------------------------------+
//|                   HORIZONTAL LINE CREATION                       |
//+------------------------------------------------------------------+
void createHLine(const string objName, const double price1, const color clr,
                 const string toolTip = "\n", const bool selected = true,
                 const ENUM_LINE_STYLE style = STYLE_SOLID)
  {
//---
   if(ObjectFind(0, objName) != -1)
      ObjectDelete(0, objName);

   if(ObjectCreate(0, objName, OBJ_HLINE, 0, 0, price1))
     {
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
      ChartRedraw();
     }
  }
//+------------------------------------------------------------------+
//|                      ANCHOR LINE CREATION                        |
//+------------------------------------------------------------------+
void drawAnchorLine(const string objName, const datetime vTime,
                    const string tooltip = "\n")
  {
//---
   if(ObjectFind(0, objName) != -1)
      ObjectDelete(0, objName);

   if(ObjectCreate(0, objName, OBJ_VLINE, 0, vTime, 0))
     {
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
      ChartRedraw();
     }
  }
//+------------------------------------------------------------------+
//|                  IMAGINARY REPLAY PAPER TRADE                    |
//+------------------------------------------------------------------+
void showPosition(const double entry, const bool isBuy)
  {
//---
   if(isBuy)
     {
      entryPrice = entry;
      slPrice = entry - (10000 * _Point);
      tpPrice = entry + (10000 * _Point);
      createHLine(_REPLAY_POSITION_ENTRY, entryPrice, clrBlue,
                  "Replay Entry Price", false, STYLE_DOT);
      createHLine(_REPLAY_POSITION_SL, slPrice, clrRed,
                  "Replay SL Price", true, STYLE_DASHDOT);
      createHLine(_REPLAY_POSITION_TP, tpPrice, clrLimeGreen,
                  "Replay TP Price", true, STYLE_DASHDOT);
      positionType = POSITION_TYPE_BUY;
     }
   else
     {
      entryPrice = entry;
      slPrice = entry + (10000 * _Point);
      tpPrice = entry - (10000 * _Point);
      createHLine(_REPLAY_POSITION_ENTRY, entryPrice, clrBlue,
                  "Replay Entry Price", false, STYLE_DOT);
      createHLine(_REPLAY_POSITION_SL, slPrice, clrRed,
                  "Replay SL Price", true, STYLE_DASHDOT);
      createHLine(_REPLAY_POSITION_TP, tpPrice, clrLimeGreen,
                  "Replay TP Price", true, STYLE_DASHDOT);
      positionType = POSITION_TYPE_SELL;
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//|                     TOGGLE MENU BUTTON                           |
//+------------------------------------------------------------------+
void toggleMenuButton(void)
  {
//---
   static bool isMenuOn = false;
   isMenuOn = !isMenuOn;
   if(!isMenuOn)
     {
      ObjectSetInteger(0, _MENU_BUTTON, OBJPROP_BGCOLOR, clrBlue);
      ObjectSetString(0, _MENU_BUTTON, OBJPROP_TEXT, "ON");
      ObjectSetInteger(0, _MENU_BUTTON, OBJPROP_STATE, false);
      //--- RESTORE CHART SETTINGS
      ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, false);
      ChartSetInteger(0, CHART_SHOW_ONE_CLICK, true);
      ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, false);
      //--- CLEAR AND RESTORE DEFAULT CANDLE SETTINGS
      ObjectsDeleteAll(0, _PROG_NAME + "REPLAY_");
      customCandles(true, iTime(_Symbol, PERIOD_CURRENT, 0));
      chartState.restore();
      isPositionOpen = false;
      replayMode = false;
     }
   else
     {
      ObjectSetInteger(0, _MENU_BUTTON, OBJPROP_BGCOLOR, clrRed);
      ObjectSetString(0, _MENU_BUTTON, OBJPROP_TEXT, "OFF");
      ObjectSetInteger(0, _MENU_BUTTON, OBJPROP_STATE, false);
      //--- CUSTOMIZE CHART SETTINGS
      ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
      ChartSetInteger(0, CHART_SHOW_ONE_CLICK, false);
      ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, true);
      vlineTime = getViewportMiddleTime();
      drawAnchorLine(_REPLAY_ANCHORLINE, vlineTime, "Replay Anchor");
      createDashboard();
      customCandles(true, iTime(_Symbol, PERIOD_CURRENT, 0));
      ChartRedraw();
      //--- CUSTOMIZE CHART
      customCandles(false, vlineTime);
      chartState.customize();
     }
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//|                 TOGGLE PLAYBACK BUTTON                           |
//+------------------------------------------------------------------+
void togglePlayButton(void)
  {
//---
   isPlay = !isPlay;
   if(!isPlay)
     {
      ObjectSetString(0, _REPLAY_PLAY_BUTTON, OBJPROP_TEXT, _PLAY_SYMBOL);
      ObjectSetInteger(0, _REPLAY_PLAY_BUTTON, OBJPROP_STATE, false);
      ObjectSetInteger(0, _REPLAY_ANCHORLINE, OBJPROP_SELECTED, true);
      replayMode = false;
     }
   else
     {
      ObjectSetString(0, _REPLAY_PLAY_BUTTON, OBJPROP_TEXT, _PAUSE_SYMBOL);
      ObjectSetInteger(0, _REPLAY_PLAY_BUTTON, OBJPROP_STATE, false);
      ObjectSetInteger(0, _REPLAY_ANCHORLINE, OBJPROP_SELECTED, false);
      if(ObjectFind(0, _REPLAY_POSITION_ENTRY) != -1)
        {
         //--- DESELECT TP AND SL LEVEL
         ObjectSetInteger(0, _REPLAY_POSITION_SL, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, _REPLAY_POSITION_TP, OBJPROP_SELECTED, false);
        }
      replayMode = true;
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//|                  SHOW OR HIDE CUSTOM REPLAY CANDLES              |
//+------------------------------------------------------------------+
void customCandles(const bool isRemove, const datetime anchorTime)
  {
//---
   static datetime time = 0;
   bars = iBars(_Symbol, PERIOD_CURRENT);
   stopBar = iBarShift(_Symbol, PERIOD_CURRENT, anchorTime);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, bars, myRates) > 0)
     {
      for(int w = 0; w < (lastCalculated = ArraySize(myRates) - (stopBar)) && !IsStopped(); w++)
        {
         openBuffer[w] = EMPTY_VALUE;
         highBuffer[w] = EMPTY_VALUE;
         lowBuffer[w] = EMPTY_VALUE;
         closeBuffer[w] = EMPTY_VALUE;
         colorBuffer[w] = 3;

         if(!isRemove)
           {
            openBuffer[w] = myRates[w].open;
            highBuffer[w] = myRates[w].high;
            lowBuffer[w] = myRates[w].low;
            closeBuffer[w] = myRates[w].close;
            colorBuffer[w] = (closeBuffer[w] > openBuffer[w]) ? 0 : 1;
            lastPrice = closeBuffer[w];
           }
        }
      if(!isRemove)
        {
         //--- CREATE REPLAY PRICE LINE
         createHLine(_REPLAY_PRICE, 0, chartState.getPriceColor(), "Replay Price", false);
         ChartRedraw();
        }
     }
  }
//+------------------------------------------------------------------+
//|              REVEAL ONE CUSTOM REPLAY CANDLE                     |
//+------------------------------------------------------------------+
void revealOneCandle(const int prevCalculated)
  {
//---
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, bars, myRates) > 0)
     {
      openBuffer[prevCalculated] = myRates[prevCalculated].open;
      highBuffer[prevCalculated] = myRates[prevCalculated].high;
      lowBuffer[prevCalculated] = myRates[prevCalculated].low;
      closeBuffer[prevCalculated] = myRates[prevCalculated].close;
      colorBuffer[prevCalculated] = (closeBuffer[prevCalculated] > openBuffer[prevCalculated]) ? 0 : 1;
      lastPrice = closeBuffer[prevCalculated];
      //--- MONITOR REPLAY TRADE SL AND TP HIT
      if(isPositionOpen)
        {
         switch(positionType)
           {
            case POSITION_TYPE_BUY:
               if(highBuffer[prevCalculated] >= tpPrice || lowBuffer[prevCalculated] <= slPrice)
                 {
                  ObjectsDeleteAll(0, _PROG_NAME + "REPLAY_POSITION");
                  Print("Replay buy position closed");
                  PlaySound("ok.wav");
                  isPositionOpen = false;
                 }
               ChartRedraw();
               break;
            case POSITION_TYPE_SELL:
               if(highBuffer[prevCalculated] >= slPrice || lowBuffer[prevCalculated] <= tpPrice)
                 {
                  ObjectsDeleteAll(0, _PROG_NAME + "REPLAY_POSITION");
                  PlaySound("ok.wav");
                  Print("Replay sell position closed");
                  isPositionOpen = false;
                 }
               ChartRedraw();
               break;
           }
        }
      //--- ENSURE REPLAY BAR IS IN VIEW
      int replayBar = iBarShift(_Symbol, PERIOD_CURRENT, myRates[prevCalculated].time);
      int visible = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
      ChartNavigate(0, CHART_END, -(replayBar - (visible / 4)));
      //--- UPDATE REPLAY PRICE
      ObjectMove(0, _REPLAY_PRICE, 0, 0, closeBuffer[prevCalculated]);
      ChartRedraw();
     }
  }

//+------------------------------------------------------------------+
//|                      INITIALIZATION FUNCTION                     |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   createButton(_MENU_BUTTON, 10, 50, 40, 40, CORNER_LEFT_LOWER,
                clrWhite, clrBlue, clrBlack, 10, "Menu Button", "ON");
//--- SET INDICATOR BUFFERS
   SetIndexBuffer(0, openBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, highBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, lowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, closeBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, colorBuffer, INDICATOR_COLOR_INDEX);

   ArrayInitialize(openBuffer, EMPTY_VALUE);
   ArrayInitialize(highBuffer, EMPTY_VALUE);
   ArrayInitialize(lowBuffer, EMPTY_VALUE);
   ArrayInitialize(closeBuffer, EMPTY_VALUE);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   EventSetTimer(2);// TWO SECONDS TIMER
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                    DEINITIALIZATION FUNCTION                     |
//+------------------------------------------------------------------+
void OnDeinit(const int32_t reason)
  {
//--- KILL TIMER AND RESTORE CHART SETTINGS
   EventKillTimer();
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, false);
   ChartSetInteger(0, CHART_SHOW_ONE_CLICK, true);
   ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, false);
   ObjectsDeleteAll(0, _PROG_NAME);
   chartState.restore();
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//|                         ITERATION FUNCTION                       |
//+------------------------------------------------------------------+
int OnCalculate(const int32_t rates_total,
                const int32_t prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int32_t &spread[])
  {
//--- NO OPERATION REQUIRED
   return(rates_total);
  }

//+------------------------------------------------------------------+
//|                   CHART EVENT HANDLER                            |
//+------------------------------------------------------------------+
void OnChartEvent(const int32_t id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   switch(id)
     {
      //--- OBJECT CLICK (BUTTONS)
      case CHARTEVENT_OBJECT_CLICK:
         //--- TOGGLE MENU BUTTON
         if(sparam == _MENU_BUTTON)
           {
            toggleMenuButton();
            break;
           }
         //--- TOGGLE PLAY BUTTON
         if(sparam == _REPLAY_PLAY_BUTTON)
           {
            togglePlayButton();
            break;
           }
         //--- BUY BUTTON
         if(sparam == _REPLAY_BUY_BUTTON)
           {
            ObjectSetInteger(0, _REPLAY_BUY_BUTTON, OBJPROP_STATE, false);
            //--- OPEN REPLAY BUY POSITION
            showPosition(lastPrice, true);
            PlaySound("ok.wav");
            isPositionOpen = true;
            ChartRedraw();
            break;
           }
         //--- SELL BUTTON
         if(sparam == _REPLAY_SELL_BUTTON)
           {
            ObjectSetInteger(0, _REPLAY_SELL_BUTTON, OBJPROP_STATE, false);
            //--- OPEN REPLAY SELL POSITION
            showPosition(lastPrice, false);
            PlaySound("ok.wav");
            isPositionOpen = true;
            ChartRedraw();
            break;
           }
         //--- DISABLE ANCHOR DESELECTION WHEN IN PLAY MODE
         if(!ObjectGetInteger(0, _REPLAY_ANCHORLINE, OBJPROP_SELECTED))
           {
            if(ObjectGetString(0, _REPLAY_PLAY_BUTTON, OBJPROP_TEXT) == _PLAY_SYMBOL)
               ObjectSetInteger(0, _REPLAY_ANCHORLINE, OBJPROP_SELECTED, true);
            ChartRedraw();
           }
         break;
      //--- DRAG-AND-DROP OPERATION
      case CHARTEVENT_OBJECT_DRAG:
         if(sparam == _REPLAY_ANCHORLINE)
           {
            //--- CLEAR CHART
            ObjectsDeleteAll(0, _PROG_NAME + "REPLAY_POSITION");
            customCandles(true, iTime(_Symbol, PERIOD_CURRENT, 0));
            vlineTime = (datetime)ObjectGetInteger(0, _REPLAY_ANCHORLINE, OBJPROP_TIME);
            vlineTime = (vlineTime > iTime(_Symbol, PERIOD_CURRENT, 1))
                        ? iTime(_Symbol, PERIOD_CURRENT, 1) : vlineTime;
            ObjectSetInteger(0, _REPLAY_ANCHORLINE, OBJPROP_TIME, vlineTime);
            //--- SHOW CUSTOM REPLAY CANDLES
            customCandles(false, vlineTime);
            isPlay = true;
            togglePlayButton();
            ChartRedraw();
            break;
           }
         //--- ENSURE REPLAY POSITION SL LEVEL IS PLACED CORRECTLY
         if(sparam == _REPLAY_POSITION_SL)
           {
            if(positionType == POSITION_TYPE_BUY)
              {
               if(ObjectGetDouble(0, _REPLAY_POSITION_SL, OBJPROP_PRICE) >= entryPrice)
                  ObjectMove(0, _REPLAY_POSITION_SL, 0, 0, entryPrice - (10000 * _Point));
               ChartRedraw();
              }
            else
              {
               if(ObjectGetDouble(0, _REPLAY_POSITION_SL, OBJPROP_PRICE) <= entryPrice)
                  ObjectMove(0, _REPLAY_POSITION_SL, 0, 0, entryPrice + (10000 * _Point));
               ChartRedraw();
              }
            slPrice = ObjectGetDouble(0, _REPLAY_POSITION_SL, OBJPROP_PRICE);
            break;
           }
         //--- ENSURE REPLAY POSITION TP LEVEL IS PLACED CORRECTLY
         if(sparam == _REPLAY_POSITION_TP)
           {
            if(positionType == POSITION_TYPE_BUY)
              {
               if(ObjectGetDouble(0, _REPLAY_POSITION_TP, OBJPROP_PRICE) <= entryPrice)
                  ObjectMove(0, _REPLAY_POSITION_TP, 0, 0, entryPrice + (10000 * _Point));
               ChartRedraw();
              }
            else
              {
               if(ObjectGetDouble(0, _REPLAY_POSITION_TP, OBJPROP_PRICE) >= entryPrice)
                  ObjectMove(0, _REPLAY_POSITION_TP, 0, 0, entryPrice - (10000 * _Point));
               ChartRedraw();
              }
            tpPrice = ObjectGetDouble(0, _REPLAY_POSITION_TP, OBJPROP_PRICE);
           }
         break;
      //--- OBJECT DELETION RESTORATION
      case CHARTEVENT_OBJECT_DELETE:
         if(sparam == _REPLAY_ANCHORLINE)
           {
            Print("Replay Anchor line deleted. RESTORED");
            drawAnchorLine(_REPLAY_ANCHORLINE, vlineTime, "Replay Anchor");
           }
         ChartRedraw();
         break;
     }
  }

//+------------------------------------------------------------------+
//|                         TIMER EVENT                              |
//+------------------------------------------------------------------+
void OnTimer(void)
  {
//---
   if(replayMode)
     {
      bars = iBars(_Symbol, PERIOD_CURRENT);
      //--- SAFETY BOUNDARY
      if(lastCalculated >= bars - 1)
        {
         replayMode = false;
         return;
        }
      revealOneCandle(lastCalculated);
      lastCalculated++;
     }
  }
//+------------------------------------------------------------------+
//| END OF INDICATOR                                                 |
//+------------------------------------------------------------------+
