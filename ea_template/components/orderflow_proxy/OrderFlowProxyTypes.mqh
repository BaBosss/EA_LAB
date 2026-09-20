//+------------------------------------------------------------------+
//| OrderFlowProxyTypes.mqh                                          |
//| Typed, order-free MT5 activity/quote proxy research contract.    |
//+------------------------------------------------------------------+
#ifndef EA_LAB_ORDERFLOW_PROXY_TYPES_MQH
#define EA_LAB_ORDERFLOW_PROXY_TYPES_MQH

enum ENUM_OFP_VARIANT
{
   OFP_VARIANT_INVALID = 0,
   OFPR_00_PROFILE_PRICE_CONTROL = 100,
   OFPR_01_TICK_ACTIVITY = 101,
   OFPR_02_QUOTE_IMBALANCE = 102,
   OFPC_00_PROFILE_PRICE_CONTROL = 200,
   OFPC_01_TICK_ACTIVITY = 201,
   OFPC_02_QUOTE_IMBALANCE = 202
};

enum ENUM_OFP_DIRECTION
{
   OFP_DIRECTION_SHORT = -1,
   OFP_DIRECTION_NONE  = 0,
   OFP_DIRECTION_LONG  = 1
};

enum ENUM_OFP_DECISION
{
   OFP_DECISION_NONE      = 0,
   OFP_DECISION_SIGNAL    = 1,
   OFP_DECISION_CANCELLED = 2,
   OFP_DECISION_EXPIRED   = 3,
   OFP_DECISION_REJECTED  = 4,
   OFP_DECISION_INVALID   = 5
};

enum ENUM_OFP_PHASE
{
   OFP_PHASE_IDLE         = 0,
   OFPR_PHASE_TRIGGER     = 101,
   OFPC_PHASE_SECOND      = 201,
   OFPC_PHASE_RETEST      = 202,
   OFPC_PHASE_CONFIRM     = 203
};

struct OFPDataContract
{
   string data_identity;
   string profile_identity;
   string imbalance_identity;
   string profile_recipe_id;
   string session_id;
   string signal_instrument_id;
   string signal_source_id;
};

struct OFPD1Record
{
   string   record_id;
   string   instrument_id;
   string   source_id;
   ulong    sequence;
   datetime open_time;
   datetime available_at;
   bool     completed;
};

struct OFPQuoteTick
{
   string instrument_id;
   string source_id;
   long   time_msc;
   double bid;
   double ask;
   double last;
   ulong  volume;
   double volume_real;
   uint   flags;
};

struct OFPProfile
{
   string   record_id;
   string   instrument_id;
   string   source_id;
   string   profile_identity;
   string   profile_recipe_id;
   string   session_id;
   string   previous_d1_record_id;
   ulong    previous_d1_sequence;
   datetime previous_d1_open_time;
   string   current_d1_record_id;
   ulong    current_d1_sequence;
   datetime current_d1_open_time;
   datetime session_start;
   datetime session_end;
   datetime available_at;
   bool     completed;
   double   bin_size;
   string   bin_size_source;
   long     poc_bin_index;
   long     val_bin_index;
   long     vah_outer_bin_index;
   double   val;
   double   poc;
   double   vah;
   ulong    total_activity;
   ulong    value_area_activity;
};

struct OFPContextBar
{
   string   record_id;
   string   instrument_id;
   string   source_id;
   string   d1_record_id;
   ulong    d1_sequence;
   datetime d1_open_time;
   ulong    sequence;
   int      period_seconds;
   datetime open_time;
   datetime close_time;
   datetime available_at;
   bool     completed;
   double   close;
};

struct OFPBar
{
   string   record_id;
   string   instrument_id;
   string   source_id;
   string   d1_record_id;
   ulong    d1_sequence;
   datetime d1_open_time;
   ulong    sequence;
   int      period_seconds;
   datetime open_time;
   datetime close_time;
   datetime available_at;
   bool     completed;
   double   open;
   double   high;
   double   low;
   double   close;
   long     tick_volume;
   long     quote_up_count;
   long     quote_down_count;
   long     quote_unchanged_count;
   bool     quote_proxy_valid;
};

struct OFPProspectiveQuote
{
   string   record_id;
   string   instrument_id;
   string   source_id;
   string   d1_record_id;
   ulong    d1_sequence;
   datetime d1_open_time;
   datetime observed_at;
   datetime available_at;
   double   bid;
   double   ask;
   double   all_in_cost_price;
};

struct OFPDecisionEnvelope
{
   datetime evaluation_time;
   string   current_closed_bar_record_id;
   datetime current_closed_bar_close_time;
};

struct OFPGeometry
{
   int      direction;
   double   prospective_entry;
   double   stop_price;
   double   target_price;
   double   gross_risk;
   double   net_risk;
   double   net_reward;
   double   net_rr;
   datetime setup_time;
   datetime trigger_time;
   int      retest_window_completed_m5_bars;
   int      confirmation_window_completed_m5_bars;
   int      consumer_time_exit_m5_bars_after_fill;
   bool     prospective_quote_not_fill;
   bool     fill_simulated;
};

struct OFPDecision
{
   ENUM_OFP_DECISION decision;
   string            code;
   string            detail;
   ENUM_OFP_VARIANT  variant;
   OFPGeometry       geometry;
};

struct OFPState
{
   ENUM_OFP_PHASE phase;
   int            direction;
   int            first_index;
   int            setup_index;
   int            retest_index;
   int            outside_close_count;
   double         edge;
   double         frozen_atr14;
   double         frozen_buffer;
   double         test_low;
   double         test_high;
   double         retest_low;
   double         retest_high;
};

void OFP_ClearGeometry(OFPGeometry &geometry)
{
   geometry.direction = OFP_DIRECTION_NONE;
   geometry.prospective_entry = 0.0;
   geometry.stop_price = 0.0;
   geometry.target_price = 0.0;
   geometry.gross_risk = 0.0;
   geometry.net_risk = 0.0;
   geometry.net_reward = 0.0;
   geometry.net_rr = 0.0;
   geometry.setup_time = 0;
   geometry.trigger_time = 0;
   geometry.retest_window_completed_m5_bars = 0;
   geometry.confirmation_window_completed_m5_bars = 0;
   geometry.consumer_time_exit_m5_bars_after_fill = 0;
   geometry.prospective_quote_not_fill = true;
   geometry.fill_simulated = false;
}

void OFP_SetDecision(OFPDecision &out,
                     const ENUM_OFP_DECISION decision,
                     const ENUM_OFP_VARIANT variant,
                     const string code,
                     const string detail)
{
   out.decision = decision;
   out.variant = variant;
   out.code = code;
   out.detail = detail;
   OFP_ClearGeometry(out.geometry);
}

void OFP_ResetState(OFPState &state)
{
   state.phase = OFP_PHASE_IDLE;
   state.direction = OFP_DIRECTION_NONE;
   state.first_index = -1;
   state.setup_index = -1;
   state.retest_index = -1;
   state.outside_close_count = 0;
   state.edge = 0.0;
   state.frozen_atr14 = 0.0;
   state.frozen_buffer = 0.0;
   state.test_low = 0.0;
   state.test_high = 0.0;
   state.retest_low = 0.0;
   state.retest_high = 0.0;
}

#endif // EA_LAB_ORDERFLOW_PROXY_TYPES_MQH
