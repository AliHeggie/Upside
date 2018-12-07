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


# --- variables ---
var q_R >=0; # Quantity bid in DFFR market
var d_R{DFFR_PRICE} binary; # bidding level in DFFR market
var d_DA{DFFR_PRICE,DA_PRICE,INTERVALS} binary;
var Q_R{DFFR_PRICE} >= 0; # Quantity accepted in DFFR market
#var q_DA; # Quantity bid in day ahead market
#var d_DA{DA_PRICE, INTERVALS} binary; # bidding level in day ahead market
#var Q_DA{DA_PRICE}; # Quantity accepted in day ahead market
#var E_price_DA{DA_PRICE, INTERVALS}; # expected price conditional on our bid

# --- objective function ---
maximize profit: sum{i in DFFR_PRICE} E_price_R[i] * q_R * d_R[i] +
sum{i in DFFR_PRICE} p_R[i] * sum{j in DA_PRICE, t in INTERVALS} E_price_DA[j,t] * q_DA[i,t] * d_DA[i,j,t] -
sum{i in DFFR_PRICE, j in DA_PRICE, t in INTERVALS} p_R[i] * p_DA[j,t] * Cost * Q_DA[i,j,t]
;

# DFFR MARKET

# Expected DFFR price
subject to expected_DFFR_price{i in DFFR_PRICE}:
    E_price_R[i] = price_R[i] * sum{ii in DFFR_PRICE: ii>=i} p_R[i];

# Can only bid one price in DFFR market
subject to single_bid_R:
    sum{i in DFFR_PRICE} d_R[i] = 1;

# Accepted DFFR bid
subject to accepted_R{i in DFFR_PRICE diff {first(DFFR_PRICE)}}:
    Q_R[i] >= Q_R[i-1];
subject to accepted_R_lb{i in DFFR_PRICE}:
    Q_R[i] >= d_R[i] * q_R;
subject to accepted_R_ub{i in DFFR_PRICE}:
    Q_R[i] <= q_R;

# DAY AHEAD MARKET

# Expected DA price
#subject to expected_DA_price{j in DA_PRICE, t in INTERVALS}:
#    E_price_DA[i] = sum{jj in DA_PRICE: jj>=j} p_DA[];

# Can only bid one price in day ahead market per interval
#subject to single_bid_DA{t in INTERVALS}:
#    sum{j in DA_PRICE} d_DA[i,t] = 1;


# Accepted day ahead bid
#subject to accepted_DA{i in DFFR_PRICE, j in DA_PRICE diff {first(DA_PRICE)},
#                       t in INTERVALS}:
#    Q_DA[i,J,T] >= Q_DA[i, j-1, t];
#subject to accepted_DA_lb{i in DFFR_PRICE, j in DA_PRICE , t in INTERVALS}:
#    Q_DA[i,j,t] >= d_DA[i,j,t] * q_DA[i,t];
#subject to accepted_R_ub{i in DFFR_PRICE, j in DA_PRICE , t in INTERVALS}:
#    Q_DA[i,j,t] <= q_DA[i,t];
