//+------------------------------------------------------------------+
//| OrderFlowTypes.mqh                                               |
//| Typed, order-free contract for OF01/OF02 research components.    |
//| No symbol/session/profile policy is selected in this file.       |
//+------------------------------------------------------------------+
#ifndef EA_LAB_ORDERFLOW_TYPES_MQH
#define EA_LAB_ORDERFLOW_TYPES_MQH

enum ENUM_OF_DATA_IDENTITY
{
   OF_DATA_IDENTITY_INVALID            = 0,
   OF_DATA_IDENTITY_TRUE_ORDERFLOW     = 1,
   OF_DATA_IDENTITY_PRICE_ACTION_PROXY = 2
};

enum ENUM_OF_RECORD_CLASS
{
   OF_RECORD_CLASS_INVALID   = 0,
   OF_RECORD_CLASS_QUALIFIED = 1,
   OF_RECORD_CLASS_FIXTURE   = 2
};

enum ENUM_OF_VOLUME_PROVENANCE
{
   OF_VOLUME_INVALID                 = 0,
   OF_VOLUME_EXECUTED_ASK_BID        = 1,
   OF_VOLUME_TICK_COUNT_PROXY        = 2,
   OF_VOLUME_UP_DOWN_TICK_PROXY      = 3
};

enum ENUM_OF_DIRECTION
{
   OF_DIRECTION_SHORT = -1,
   OF_DIRECTION_NONE  = 0,
   OF_DIRECTION_LONG  = 1
};

enum ENUM_OF_DECISION
{
   OF_DECISION_NONE      = 0,
   OF_DECISION_ARMED     = 1,
   OF_DECISION_SIGNAL    = 2,
   OF_DECISION_CANCELLED = 3,
   OF_DECISION_EXPIRED   = 4,
   OF_DECISION_REJECTED  = 5,
   OF_DECISION_INVALID   = 6
};

enum ENUM_OF_PHASE
{
   OF_PHASE_IDLE             = 0,
   OF01_PHASE_WAIT_TRIGGER   = 101,
   OF02_PHASE_WAIT_SECOND    = 201,
   OF02_PHASE_WAIT_RETEST    = 202,
   OF02_PHASE_WAIT_CONFIRM   = 203
};

struct OFDataContract
{
   string                    dataset_id;
   string                    source_id;
   string                    source_revision;
   string                    signal_instrument_id;
   string                    profile_instrument_id;
   string                    instrument_mapping_id;
   bool                      instrument_mapping_qualified;
   string                    session_definition_id;
   string                    timezone_ruleset_id;
   string                    profile_algorithm_id;
   string                    value_area_algorithm_id;
   string                    volume_provenance_id;
   bool                      source_qualified;
   ENUM_OF_DATA_IDENTITY     data_identity;
   ENUM_OF_VOLUME_PROVENANCE volume_provenance;
   ENUM_OF_RECORD_CLASS      record_class;
};

// Freshness is consumer-owned and must be supplied explicitly.  There are no
// defaults because session boundaries, DST and broker clocks are not selected
// by these components.
struct OFFreshnessPolicy
{
   long                 max_m5_age_seconds;
   long                 max_m15_age_seconds;
   long                 max_profile_age_seconds;
   long                 max_quote_age_seconds;
   ENUM_OF_RECORD_CLASS required_record_class;
};

struct OFProfile
{
   string   record_id;
   string   profile_id;
   string   profile_revision;
   string   source_revision;
   datetime session_start;
   datetime session_end;
   datetime available_at;
   bool     completed;
   double   val;
   double   poc;
   double   vah;
};

struct OFContextBar
{
   string   record_id;
   string   source_revision;
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
};

struct OFBar
{
   string   record_id;
   string   source_revision;
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
   double   executed_ask_volume;
   double   executed_bid_volume;
   double   total_executed_volume;
};

// Quote is a prospective, observed quote only.  It is never represented as a
// fill.  all_in_cost_price is a caller-supplied round-trip price-distance cost.
struct OFQuote
{
   string   record_id;
   string   source_id;
   string   source_revision;
   datetime observed_at;
   datetime available_at;
   double   bid;
   double   ask;
   double   all_in_cost_price;
};

struct OFGeometry
{
   int      direction;
   double   prospective_entry;
   double   stop_price;
   double   target_price;
   double   gross_risk;
   double   net_reward;
   double   net_risk;
   double   net_rr;
   datetime setup_time;
   datetime trigger_time;
   int      retest_window_completed_m5_bars;
   int      confirmation_window_completed_m5_bars;
   int      consumer_time_exit_m5_bars_after_fill;
   string   quote_record_id;
   bool     prospective_quote_not_fill;
};

struct OFDecision
{
   ENUM_OF_DECISION decision;
   string           code;
   string           detail;
   OFGeometry       geometry;
};

struct OFState
{
   ENUM_OF_PHASE phase;
   int           direction;
   int           setup_index;
   int           retest_index;
   int           elapsed_bars;
   int           outside_close_count;
   double        edge;
   double        frozen_atr14;
   double        frozen_buffer;
   double        test_low;
   double        test_high;
   double        retest_low;
   double        retest_high;
   string        dataset_id;
   string        source_revision;
   string        profile_id;
   string        profile_revision;
   string        context_record_id;
};

void OF_ClearGeometry(OFGeometry &g)
{
   g.direction                 = OF_DIRECTION_NONE;
   g.prospective_entry         = 0.0;
   g.stop_price                = 0.0;
   g.target_price              = 0.0;
   g.gross_risk                = 0.0;
   g.net_reward                = 0.0;
   g.net_risk                  = 0.0;
   g.net_rr                    = 0.0;
   g.setup_time                = 0;
   g.trigger_time              = 0;
   g.retest_window_completed_m5_bars = 0;
   g.confirmation_window_completed_m5_bars = 0;
   g.consumer_time_exit_m5_bars_after_fill = 0;
   g.quote_record_id           = "";
   g.prospective_quote_not_fill = true;
}

void OF_SetDecision(OFDecision &out,
                    const ENUM_OF_DECISION decision,
                    const string code,
                    const string detail)
{
   out.decision = decision;
   out.code     = code;
   out.detail   = detail;
   OF_ClearGeometry(out.geometry);
}

void OF_ResetState(OFState &state)
{
   state.phase               = OF_PHASE_IDLE;
   state.direction           = OF_DIRECTION_NONE;
   state.setup_index         = -1;
   state.retest_index        = -1;
   state.elapsed_bars        = 0;
   state.outside_close_count = 0;
   state.edge                = 0.0;
   state.frozen_atr14        = 0.0;
   state.frozen_buffer       = 0.0;
   state.test_low            = 0.0;
   state.test_high           = 0.0;
   state.retest_low          = 0.0;
   state.retest_high         = 0.0;
   state.dataset_id          = "";
   state.source_revision     = "";
   state.profile_id          = "";
   state.profile_revision    = "";
   state.context_record_id   = "";
}

#endif // EA_LAB_ORDERFLOW_TYPES_MQH
