import MetaTrader5 as mt5
import pandas as pd
import pandas_ta as ta
import schedule
import time
from datetime import datetime
#import datetime
import numpy as np
from scipy.signal import argrelextrema

# display data on the MetaTrader 5 package
print("MetaTrader5 package author: ",mt5.__author__)
print("MetaTrader5 package version: ",mt5.__version__)
 
# establish MetaTrader 5 connection to a specified trading account
if not mt5.initialize(login=5025221475, server="MetaQuotes-Demo",password="HmOrF!U6"):
    print("initialize() failed, error code =",mt5.last_error())
    quit()
 
# display data on connection status, server name and trading account
#print(mt5.terminal_info())
# display data on MetaTrader 5 version
#print(mt5.version())

account_info=mt5.account_info()._asdict()
print(account_info)

def bot():
    #get today's days of the week
    today =datetime.now().weekday()
    if 0<= today <=5:
        print("Running on a working day.")
        
        #account balance
        account_info=mt5.account_info()._asdict()
        print(account_info)
        #Get historical data
        symbol="EURUSD"
        # create DataFrame out of the obtained data
        #HFT narrative
        timeframe_1D =mt5.TIMEFRAME_H4
        df_1D = pd.DataFrame(mt5.copy_rates_from(symbol, timeframe_1D, datetime.now(), 45))
        # convert time in seconds into the datetime format
        df_1D['time']=pd.to_datetime(df_1D['time'], unit='s')
        #Calculate daily EMA 20
        EMA_20 =ta.ema(df_1D['close'], length=20)
        EMA_9 =ta.ema(df_1D['close'], length=9)
        
        print(df_1D)
        timeframe =mt5.TIMEFRAME_H1
        df = pd.DataFrame(mt5.copy_rates_from(symbol, timeframe, datetime.now(), 45))
        # convert time in seconds into the datetime format
        df['time']=pd.to_datetime(df['time'], unit='s')

        print(df)
        
        #calculate support and resistance levels
        df['support'] = df['close'].quantile(0.25)
        df['resistance']  = df['close'].quantile(0.75)

        df['support_2'] = df['close'].quantile(0.15)  # Optional: Add additional support levels
        df['resistance_2'] = df['close'].quantile(0.85)  # Optional: Add additional resistance levels
        print(df.tail(50))
         
        # Merge the EMA_20 column from the  1-DAY DataFrame into the  1-hour DataFrame
        df = df.join(EMA_20, how='left')
        df = df.join(EMA_9, how='left')
        #SMA crossover for HFT directional bias
        df['Trend'] =1
        df.loc[(df['EMA_9'] > df['EMA_20']),'Trend'] = 2# Long directional bias
        df.loc[(df['EMA_9'] < df['EMA_20']),'Trend'] = 3 # Short directional bias
               
        
        print(df)
        
        
        #create long and short condition
        df['long_condition'] =1
        df.loc[(df['close'] < df['support_2']) & (df['Trend'] == 2), 'long_condition'] =2 # at support
        
        df['short_condition'] =1
        df.loc[(df['close'] > df['resistance_2']) & (df['Trend'] == 3), 'short_condition'] =2 #at resistance

        
        
        # Check if there is an open trade position
        check_positions = len(mt5.positions_get()) ==0
        
        
        # get open positions on EURUSD
        positions=mt5.positions_get(symbol=symbol)
        if check_positions:
            print("No positions on EURUSD, error code={}".format(mt5.last_error()))
            # Step 6: Implement the trading strategy
            for i, row in df.iterrows():
                # Step 7: Check for signals and execute trades
                #trade parameter
                point = mt5.symbol_info(symbol).point
                symbol ='EURUSD'
                lot = 0.01
                point = mt5.symbol_info(symbol).point
                buy_price = mt5.symbol_info_tick(symbol).ask
                sell_price = mt5.symbol_info_tick(symbol).bid

                buy_order_type = mt5.ORDER_TYPE_BUY 
                sell_order_type = mt5.ORDER_TYPE_SELL 
                tp_point = 300
                sl_point = 150
                if df['long_condition'].iloc[-1] ==2:
                    
                    
                    
                    
                    
                    #create order
                    request = {
                        "action": mt5.TRADE_ACTION_DEAL,
                        "symbol": symbol,
                        "volume": lot,
                        "type": buy_order_type,
                        "price": buy_price,
                        "sl": buy_price - sl_point * point,
                        "tp": buy_price + tp_point * point,
                        "comment": "python script open",
                        "type_time": mt5.ORDER_TIME_GTC,
                        "type_filling": mt5.ORDER_FILLING_RETURN,
                    }
                
                    # send a trading request
                    order = mt5.order_send(request)
                    print(f"long order placed {order}")
                    
                    #print order
                    time.sleep(21600)
                    break
                
                elif df['short_condition'].iloc[-1] == 2:
                    request = {
                        "action": mt5.TRADE_ACTION_DEAL,
                        "symbol": symbol,
                        "volume": lot,
                        "type": sell_order_type,
                        "price": sell_price,
                        "sl": sell_price + sl_point * point,
                        "tp": sell_price - tp_point * point,
                        "comment": "python script open",
                        "type_time": mt5.ORDER_TIME_GTC,
                        "type_filling": mt5.ORDER_FILLING_RETURN,
                    }
                
                    # send a trading request
                    order = mt5.order_send(request)
                    print(f"short order placed {order}")
                    
                    #print order
                    time.sleep(21600)
                
                    break
                else:
                    print(f"checking for long and signals")
                            
                    time.sleep(60)
                    break
        else:
            print("There is already an open position.")
            print("Total positions on EURUSD =",len(positions))
            # display all open positions
            for position in positions:
                print(position)
                
            
            time.sleep(20)
    else:
        print("Not a working day. skipping.")
# Run the trading_bot function
bot()


#schedule.every(20).seconds.do(kill_switch)
schedule.every(1).minutes.do(bot)
# Call the trading_bot function every 2 minutes
while True:
    schedule.run_pending()

    time.sleep(10)
 



