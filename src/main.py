"""
This python script runs the same model as the notebook `upside.ipynb`. To
execute this, move to the root directory of this project and issue the
command below.

```
python3 src/main.py
```
"""

from amplpy import AMPL, DataFrame
import pandas as pd
import numpy as np
import os

## Load the ample model ##
# It might be great idea to separate configs to another file, e.g. JSON?
ampl           = AMPL()
modelDirectory = 'models'
modelName      = 'two_markets.mod'
mod_path       = os.path.join(modelDirectory, modelName)
dataDirectory  = 'data/balanced/'
ampl.read(mod_path)

## Assign set data ##
def assign_set_data(name,data):
    """Method to assign set data taking set name and a list as arguments"""
    df = DataFrame(name)
    df.setColumn(name,data)
    ampl.setData(df,name)

intervals = pd.read_csv(os.path.join(dataDirectory, 'intervals.csv'),
                        skipinitialspace=True)
dffr      = pd.read_csv(os.path.join(dataDirectory, 'dffr.csv'),
                        skipinitialspace=True)
da        = pd.read_csv(os.path.join(dataDirectory, 'da.csv'),
                        skipinitialspace=True)

assign_set_data('INTERVALS', intervals.values[:,0])
assign_set_data('DFFR_PRICE', dffr.DFFR_PRICE.values)
assign_set_data('DA_PRICE',  da.DA_PRICE.unique())

## Assign parameter data ##
ampl.getParameter('Cost').set(0)
ampl.getParameter('Ramp').set(999999)
ampl.getParameter('Ramp_DFFR').set(9999999)
ampl.getParameter('P_MAX').set(2)

n_DFFR_PRICE = len(dffr.DFFR_PRICE.unique())
n_DA_PRICE   = len(da.DA_PRICE.unique())
n_INTERVAL   = len(intervals)

df = pd.DataFrame([1/n_DFFR_PRICE] * n_DFFR_PRICE,
                  columns=['p_R'], index=dffr.DFFR_PRICE.values)
ampl.setData(DataFrame.fromPandas(df))

df = pd.DataFrame([1/n_DA_PRICE] * n_DA_PRICE,
                  columns=['p_DA'], index=da.DA_PRICE.unique())
ampl.setData(DataFrame.fromPandas(df))

df = dffr.set_index('DFFR_PRICE')
ampl.setData(DataFrame.fromPandas(df))

df = da.set_index(['DA_PRICE','INTERVALS'])
ampl.setData(DataFrame.fromPandas(df))

## Solve the model ##
# Set ampl options
settings = {
    'solver'         : 'cplexamp',
    'knitro_options' : 'outlev = 0 mip_outlevel = 0',
    'cplex_options'  : 'outlev = 0 mipdisplay = 0 mipgap = .005'
}
# For debug. Make Cplex more verbose.
# settings = {
#     'solver'         : 'cplexamp',
#     'knitro_options' : 'outlev = 1 mip_outlevel = 1',
#     'cplex_options'  : 'mipdisplay = 2 mipgap = .005'
# }

for key in settings:
    ampl.setOption(key, settings[key])

ampl.solve()

## Extract solution ##
d_R  = ampl.getVariable('d_R' ).getValues().toPandas()
d_DA = ampl.getVariable('d_DA').getValues().toPandas()
q_R  = ampl.getVariable('q_R' ).getValues().toPandas()
q_DA = ampl.getVariable('q_DA').getValues().toPandas()
Q_R  = ampl.getVariable('Q_R' ).getValues().toPandas()
Q_DA = ampl.getVariable('Q_DA').getValues().toPandas()

# The level and amount of bit for each market. Be aware of the 0-based indexes.
bid_level_R   = np.where(d_R['d_R.val']==1)[0][0]           # 0-BASED INDEX.
bid_amount_R  = np.sum(q_R)
bid_level_DA  = np.zeros((n_DFFR_PRICE, n_INTERVAL), int)   # 0-BASED INDEX.
bid_amount_DA = np.zeros((n_DFFR_PRICE, n_INTERVAL))

for i in d_DA.index:
    bid_amount = q_DA.at[i, 'q_DA.val']
    if bid_amount > 1e-5:
        bid_level_DA[ int(i[0]-1), int(i[2]-1)] = int(i[1]-1)
        bid_amount_DA[int(i[0]-1), int(i[2]-1)] = bid_amount

print('\n- DFFR')
print('bid level: %2d, bid amount: %6.2f' % (bid_level_R+1, bid_amount_R))
                                                       # └ 0-BASED INDEX!!

print('\n- DA')
print('%6s %6s %11s %11s' % ('DFFR', 'time', 'bid level', 'bid amount'))
for i in range(n_DFFR_PRICE):
    for t in range(n_INTERVAL):
        print('%6d %6d %11d %11.2f' %
              (i+1, t+1, bid_level_DA[i, t]+1, bid_amount_DA[i, t]))
              #  └────┴─────────────────────┴── 0-BASED INDEX!!

# # For debug. Print when the bids are accepted.
# print('\n- Accepted bid in DFFR')
# print(Q_R.loc[Q_R['Q_R.val'] >= 1e-5])
#
# print('\n- Accepted bid in DA:')
# print(Q_DA.loc[Q_DA['Q_DA.val'] >= 1e-5])
