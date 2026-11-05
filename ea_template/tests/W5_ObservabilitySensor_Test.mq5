//+------------------------------------------------------------------+
//|                                  W5_ObservabilitySensor_Test.mq5 |
//|               W5 Build6230 Option B: Engineering Observability   |
//|                    Reference MQL5 Sensor Test Probe (Scope D)    |
//+------------------------------------------------------------------+
#property copyright "EA_LAB Track E Engineering-Only"
#property link      "https://github.com/patip/EA_LAB"
#property version   "3.00"
#property script_show_inputs
#property strict

#include "../../tools/w5_engineering_observability/W5_TelemetrySensor.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== [W5_OBS] Starting Track E Engineering Observability Sensor Test ===");

   // 1. Initialize Sensor
   W5_InitSensor("RUN_PROBE_01", "STREAM_MAIN", 0);
   Print("Sensor initialized for run RUN_PROBE_01");

   // 2. Mock Event 1: HANDLE_CREATE
   W5_Event ev_hnd;
   ev_hnd.schema_version              = W5_OBS_SCHEMA_VERSION;
   ev_hnd.lineage_id                  = W5_OBS_LINEAGE_ID;
   ev_hnd.trust_domain                = W5_OBS_DEFAULT_DOMAIN;
   ev_hnd.run_id                      = "RUN_PROBE_01";
   ev_hnd.stream_id                   = "STREAM_MAIN";
   ev_hnd.emitter_generation          = 0;
   ev_hnd.event_type                  = "HANDLE_CREATE";
   ev_hnd.local_counter               = 1;
   ev_hnd.event_id                    = W5_GenerateEventID("HND_CREATE", ev_hnd.local_counter);
   ev_hnd.parent_event_id             = "";
   ev_hnd.parent_event_ids_pipe       = "";
   ev_hnd.recorded_utc                = TimeGMT(); // UTC, not broker TimeCurrent
   ev_hnd.strategy_bar_time           = 0; // No bar association observed

   ev_hnd.call_file                   = "W5_ObservabilitySensor_Test.mq5";
   ev_hnd.call_function               = "OnStart";
   ev_hnd.call_line                   = 35;

   ev_hnd.symbol                      = _Symbol;
   ev_hnd.timeframe                   = (int)Period();
   ev_hnd.indicator_kind              = "ATR";
   ev_hnd.period                      = 14;
   ev_hnd.handle_id                   = "HND_ATR_01";
   ev_hnd.handle_generation           = 1;
   ev_hnd.buffer_id                   = 0;
   ev_hnd.start_pos                   = 0;
   ev_hnd.requested_count             = 1;
   ev_hnd.returned_count              = 1;
   ev_hnd.raw_value                   = 0.0;
   ev_hnd.error_code                  = 0;

   ev_hnd.consumed_in_decision        = false;
   ev_hnd.decision_id                 = "";
   ev_hnd.edge_type                   = "OBSERVATION_ONLY";

   ev_hnd.trace_internal_closed       = false; // No causal trace with one mock event
   ev_hnd.static_scope_instrumented   = false; // No source coverage proven
   ev_hnd.actual_api_calls_witnessed  = "UNKNOWN";
   ev_hnd.prev_event_digest           = "0000000000000000000000000000000000000000000000000000000000000000";

   string json1 = W5_FormatEventJSON(ev_hnd);
   PrintFormat("[W5_OBS] Emitted Event 1: %s", json1);

   // No second chained event is emitted here. Computing a valid chained
   // prev_event_digest requires RFC 8785 canonicalization and SHA-256 of the
   // actual dynamic event 1 bytes, not a hard-coded SHA or placeholder.
   // This is a ONE-EVENT synthetic JSON-format probe only.
   Print("=== [W5_OBS] One-event JSON-format probe; chain NOT_VERIFIED; MQL5 compile NOT_RUN ===");
}
//+------------------------------------------------------------------+
