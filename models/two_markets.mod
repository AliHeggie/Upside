# --- sets ---
set DFFR_PRICE ordered; # DFFR price scenarios
set DA_PRICE ordered; # Day ahaead market price scenarios
set INTERVALS; # Trading intervals

# --- parameters ---
param Cost; #cost of generation
param price_R{DFFR_PRICE}; #price for scenario of DFFR
param price_DA{DA_PRICE, INTERVALS}; #price for scenario of DA

param p_R{DFFR_PRICE}; # probability of DFFR scenarios
param p_DA{DA_PRICE}; # probabilty of day ahead scenarios

param Ramp; # Ramp power limits in interval;
param Ramp_DFFR; # Ramp power limits for DFFR;

param E_price_R{i in DFFR_PRICE}= price_R[i]*sum{k in DFFR_PRICE: k>=i} p_DA[k]; # expected price conditional on our bid
param E_price_DA{j in DA_PRICE, t in INTERVALS}= sum{k in DA_PRICE: k>=j} price_DA[k,t]*p_DA[k]; # expected price conditional on our bid

param P_MAX;

# --- variables ---
var q_R >=0, <=10000000; # Quantity bid in DFFR market
var q_DA{DA_PRICE, INTERVALS} >=0, <=10000000; # Quantity bid in DFFR market
var d_R{DFFR_PRICE} binary; # bidding level in DFFR market
var d_DA{DFFR_PRICE,DA_PRICE,INTERVALS} binary;
var Q_R{DFFR_PRICE} >= 0, <=10000000; # Quantity accepted in DFFR market
var Q_DA{DFFR_PRICE,DA_PRICE,INTERVALS} >=0, <=10000000; # Quantity accepted in day ahead market
var P_Act{DFFR_PRICE,DA_PRICE,INTERVALS}>=0, <=10000000;

var Z_R{DFFR_PRICE}>=0, <=10000000;  ## auxilliary variables to  linearize delta * q for dffr
var Z_DA{DFFR_PRICE,DA_PRICE,INTERVALS}>=0, <=10000000; ## auxilliary variables to  linearize delta * q for dffr


# --- objective function ---
    maximize profit: sum{i in DFFR_PRICE} E_price_R[i] * Z_R[i] +
sum{i in DFFR_PRICE} p_R[i] * sum{j in DA_PRICE, t in INTERVALS} E_price_DA[j,t] * Z_DA[i,j,t] -
sum{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS} p_R[i] * p_DA[j] * Cost * Q_DA[i,j,t]
;

#maximize profit: sum{i in DFFR_PRICE} E_price_R[i] * q_R * d_R[i] +
#sum{i in DFFR_PRICE} p_R[i] * sum{j in DA_PRICE, t in INTERVALS} E_price_DA[j,t] * q_DA[i,t] * d_DA[i,j,t] -
#sum{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS} p_R[i] * p_DA[j] * Cost * Q_DA[i,j,t]
#;


# DFFR MARKET

# Can only bid one price in DFFR market
subject to single_bid_R:
    sum{i in DFFR_PRICE} d_R[i] = 1;

# Accepted DFFR bid
subject to accepted_R{i in DFFR_PRICE diff {first(DFFR_PRICE)}}:
    Q_R[i] >= Q_R[i-1];

#subject to accepted_R_lb{i in DFFR_PRICE}:
#    Q_R[i] >= d_R[i] * q_R;

### LINEARIZATION of accepted_R_lb
subject to DFFR_Lin1{i in DFFR_PRICE}:
    Z_R[i]<=q_R;



subject to DFFR_Lin2{i in DFFR_PRICE}:
    Z_R[i]>=q_R-(1-d_R[i])*P_MAX;

###

subject to accepted_R_ub{i in DFFR_PRICE}:
    Q_R[i] <= q_R;

# DAY AHEAD MARKET

# Expected DA price

# Can only bid one price in day ahead market per interval
subject to single_bid_DA{i in DFFR_PRICE, t in INTERVALS}:
    sum{j in DA_PRICE} d_DA[i,j,t] = 1;

# Accepted day ahead bid
subject to accepted_DA{i in DFFR_PRICE, j in DA_PRICE diff {first(DA_PRICE)},
                       t in INTERVALS}:
    Q_DA[i,j,t] >= Q_DA[i, j-1, t];

#subject to accepted_DA_lb{i in DFFR_PRICE, j in DA_PRICE , t in INTERVALS}:
#    Q_DA[i,j,t] >= d_DA[i,j,t] * q_DA[i,t];

### LINEARIZATION of accepted_DA_lb
s.t. DA_Lin1{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS}:
    Z_DA[i,j,t]<=q_DA[i,t];

s.t. DA_Lin2{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS}:
    Z_DA[i,j,t]>=q_DA[j,t]-(1-d_DA[i,j,t])*P_MAX;
    ###



subject to accepted_DA_ub{i in DFFR_PRICE, j in DA_PRICE , t in INTERVALS}:
    Q_DA[i,j,t] <= q_DA[i,t];

# COUPLING CONSTRAINTS

subject to power_ub_Limits{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS}:
    P_Act[i,j,t]<=P_MAX;

subject to potential_power{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS}:
        P_Act[i,j,t]=Q_R[i] + Q_DA[i,j,t];

subject to pDFFR_ub{i in DFFR_PRICE}:
    Q_R[i] <= Ramp_DFFR;

subject to max_Ramp_up{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS: t>=2}:
    P_Act[i,j,t]-Q_DA[i,j,t-1]<=Ramp;

subject to max_Ramp_down{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS: t>=2}:
    Q_DA[i,j,t]-P_Act[i,j,t-1]>=-Ramp;

s.t. q_R_upper_bound:
    q_R <= P_MAX;

s.t. q_DA_upper_bound{i in DA_PRICE, t in INTERVALS}:
    q_DA[i,t] <= P_MAX;