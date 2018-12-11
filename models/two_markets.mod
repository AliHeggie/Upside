# --- sets ---

set DFFR_PRICE ordered; # DFFR price scenarios
set DA_PRICE ordered;   # Day ahaead market price scenarios
set INTERVALS;          # Trading intervals


# --- parameters ---

param Cost;                          # Cost of generation
param price_R{DFFR_PRICE};           # Price for scenario of DFFR
param price_DA{DA_PRICE, INTERVALS}; # Price for scenario of DA

param p_R{DFFR_PRICE};               # Probability of DFFR scenarios
param p_DA{DA_PRICE};                # Probabilty of day ahead scenarios

param Ramp;                          # Ramp power limits in interval
param Ramp_DFFR;                     # Ramp power limits for DFFR

# Expected price
param E_price_R{i in DFFR_PRICE} =
    price_R[i] * sum{k in DFFR_PRICE: k >= i} p_DA[k];
param E_price_DA{j in DA_PRICE, t in INTERVALS} =
    sum{k in DA_PRICE: k >= j} price_DA[k, t] * p_DA[k];

param P_MAX;


# --- variables ---

# q_R[i] = the amount of bid in DFFR market for i s.t. d_R[i] = 1 (namely,
# the bid is at level i). q_R[i] = 0 otherwise.
var q_R{DFFR_PRICE} >= 0, <=10000000;

# For each DFFR price scenario i,
# q_DA[i, j, t] = the amount of bid in DA market at time interval t for
# j s.t. d_R[i, j, t] = 1 (namely, the bid is at level j).
# q_DA[i, j, t] = 0 otherwise.
var q_DA{DA_PRICE, DFFR_PRICE, INTERVALS} >= 0, <=10000000;

# Hence, for example, if we bit at the 2nd price level in DFFR market, q_R looks
# like;
#        [             0 ]     ┐
# q_r =  [ amount of bid ]     │ We have 4 scenarios for DFFR. And q_r indicates
#        [             0 ]     │ in which level we bid and how much.
#        [             0 ]     ┘
#

# bidding level in each market
var d_R{DFFR_PRICE} binary;
var d_DA{DFFR_PRICE, DA_PRICE, INTERVALS} binary;

# Quantity accepted in each market
var Q_R{DFFR_PRICE} >= 0, <=10000000;
var Q_DA{DFFR_PRICE, DA_PRICE, INTERVALS} >= 0, <=10000000;

# Quantity to be researved for DFFR + quantity sold in DA.
var P_Act{DFFR_PRICE, DA_PRICE, INTERVALS} >= 0, <=10000000;


# --- objective function ---

maximize profit:
    sum{i in DFFR_PRICE} E_price_R[i] * q_R[i]               # profit of DFFR
    + sum{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS}
        p_R[i] * E_price_DA[j, t] * q_DA[i, j, t]            # profit of DA
    - sum{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS}
        p_R[i] * p_DA[j] * Cost * Q_DA[i, j, t]              # cost of DA
;


# --- constraints ---

# DFFR MARKET

# Can only bid one price in DFFR market
subject to single_bid_R:
    sum{i in DFFR_PRICE} d_R[i] = 1;

# Force q_R[i] = 0 when d_R[i] = 0.
subject to single_bid_q_R{i in DFFR_PRICE}:
    q_R[i] <= d_R[i] * P_MAX;

# Accepted DFFR bid
subject to accepted_R{i in DFFR_PRICE diff {first(DFFR_PRICE)}}:
    Q_R[i] >= Q_R[i-1];

subject to accepted_R_lb{i in DFFR_PRICE}:
    Q_R[i] >= q_R[i];


# DAY AHEAD MARKET

# Can only bid one price in day ahead market per interval
subject to single_bid_DA{i in DFFR_PRICE, t in INTERVALS}:
    sum{j in DA_PRICE} d_DA[i, j, t] = 1;

# Force q_DA[i, j, t] = 0 when d_R[i, j, t] = 0.
subject to single_bid_q_DA{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS}:
    q_DA[i, j, t] <= d_DA[i, j, t] * P_MAX;

# Accepted day ahead bid
subject to accepted_DA{i in DFFR_PRICE, j in DA_PRICE diff {first(DA_PRICE)},
                       t in INTERVALS}:
    Q_DA[i, j, t] >= Q_DA[i, j-1, t];

subject to accepted_DA_lb{i in DFFR_PRICE, j in DA_PRICE , t in INTERVALS}:
    Q_DA[i, j, t] >= q_DA[i, j, t];


# COUPLING CONSTRAINTS

subject to power_ub_Limits{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS}:
    P_Act[i, j, t] <= P_MAX;

subject to potential_power{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS}:
    P_Act[i, j, t] = Q_R[i] + Q_DA[i, j, t];

subject to pDFFR_ub{i in DFFR_PRICE}:
    Q_R[i] <= Ramp_DFFR;

subject to max_Ramp_up{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS: t>=2}:
    P_Act[i, j, t] - Q_DA[i, j, t-1] <= Ramp;

subject to max_Ramp_down{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS: t>=2}:
    Q_DA[i, j, t] - P_Act[i, j, t-1] >= -Ramp;

