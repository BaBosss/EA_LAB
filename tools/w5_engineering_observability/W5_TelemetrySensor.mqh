//+------------------------------------------------------------------+
//|                                        W5_TelemetrySensor.mqh    |
//|               W5 Build6230 Option B: Engineering Observability   |
//|                    MQL5 Sensor Specification & Telemetry Hook V3 |
//+------------------------------------------------------------------+
#property copyright "EA_LAB Track E Engineering-Only"
#property link      "https://github.com/patip/EA_LAB"
#property strict

// Structural schema version
#define W5_OBS_SCHEMA_VERSION  "W5_ENG_OBS_V3_0"
#define W5_OBS_LINEAGE_ID      "ENGINEERING_ONLY_TRACK_E"
#define W5_OBS_DEFAULT_DOMAIN  "SYNTHETIC_FIXTURE_TEST_ONLY"

struct W5_Event
{
   string   schema_version;
   string   lineage_id;
   string   trust_domain;
   string   event_id;
   string   parent_event_id;
   string   parent_event_ids_pipe; // Canonical IDs separated by | (never part of an ID)
   string   run_id;
   string   stream_id;
   int      emitter_generation;
   string   event_type;
   ulong    local_counter;
   datetime recorded_utc;
   datetime strategy_bar_time;

   // Call site
   string   call_file;
   string   call_function;
   int      call_line;

   // Sensor payload
   string   symbol;
   int      timeframe;
   string   indicator_kind;
   int      period;
   string   handle_id;
   int      handle_generation;
   int      buffer_id;
   int      start_pos;
   int      requested_count;
   int      returned_count;
   double   raw_value;
   int      error_code;

   // Causality link
   bool     consumed_in_decision;
   string   decision_id;
   string   edge_type; // BAR_ASSOCIATION, DECISION_DEPENDENCY, OBSERVATION_ONLY

   // Assurance class
   bool     trace_internal_closed;
   bool     static_scope_instrumented;
   string   actual_api_calls_witnessed; // UNKNOWN, CONFIRMED_EXTERNAL_WITNESS

   string   prev_event_digest;
};

// Global sensor state for Track E probe
string g_w5_run_id              = "RUN01";
string g_w5_stream_id           = "MAIN";
int    g_w5_emitter_generation  = 0;
ulong  g_w5_local_counter       = 0;
string g_w5_last_digest         = "0000000000000000000000000000000000000000000000000000000000000000";

//+------------------------------------------------------------------+
//| Initialize Sensor                                                |
//+------------------------------------------------------------------+
void W5_InitSensor(const string run_id, const string stream_id, const int emitter_gen = 0)
{
   g_w5_run_id             = run_id;
   g_w5_stream_id          = stream_id;
   g_w5_emitter_generation = emitter_gen;
   g_w5_local_counter      = 0;
   g_w5_last_digest        = "0000000000000000000000000000000000000000000000000000000000000000";
}

//+------------------------------------------------------------------+
//| Format datetime into strict ISO 8601 UTC (Q06)                   |
//+------------------------------------------------------------------+
string W5_TimeToISO8601UTC(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ", dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
}

//+------------------------------------------------------------------+
//| JSON escape helper for string fields (Q06)                       |
//+------------------------------------------------------------------+
string W5_EscapeJSONString(const string s)
{
   string out = "";
   int len = StringLen(s);
   for(int i = 0; i < len; i++)
   {
      ushort c = StringGetCharacter(s, i);
      if(c == '"')
         out += "\\\"";
      else if(c == '\\')
         out += "\\\\";
      else if(c == '\b')
         out += "\\b";
      else if(c == '\f')
         out += "\\f";
      else if(c == '\n')
         out += "\\n";
      else if(c == '\r')
         out += "\\r";
      else if(c == '\t')
         out += "\\t";
      else if(c < 0x20 || (c >= 0xD800 && c <= 0xDFFF))
         out += StringFormat("\\u%04X", (int)c);
      else
         out += ShortToString(c);
   }
   return out;
}

//+------------------------------------------------------------------+
//| Helper: Generate Canonical Event ID                              |
//+------------------------------------------------------------------+
string W5_FormatRawValueJSON(const double value)
{
   if(!MathIsValidNumber(value))
      return "null";
   // 17 significant digits preserve a binary64 round-trip on ordinary values.
   // No signature or chain digest is claimed without independent RFC8785 JCS.
   return StringFormat("%.17g", value);
}

string W5_ParentIDsToJSON(const string parents)
{
   string fields[];
   int count = StringSplit(parents, '|', fields);
   string result = "[";
   for(int i = 0; i < count; i++)
   {
      if(i > 0) result += ",";
      result += StringFormat("\"%s\"", W5_EscapeJSONString(fields[i]));
   }
   return result + "]";
}

string W5_GenerateEventID(const string event_kind, const ulong counter)
{
   return StringFormat("%s:%s:%d:%s:%I64u", g_w5_run_id, g_w5_stream_id, g_w5_emitter_generation, event_kind, counter);
}

//+------------------------------------------------------------------+
//| Format Event into JSON string matching schema_v3.json (Q06)      |
//+------------------------------------------------------------------+
string W5_FormatEventJSON(const W5_Event &ev)
{
   string json = "{";
   json += StringFormat("\"schema_version\":\"%s\",", ev.schema_version);
   json += StringFormat("\"lineage_id\":\"%s\",", ev.lineage_id);
   json += StringFormat("\"trust_domain\":\"%s\",", ev.trust_domain);
   json += StringFormat("\"event_id\":\"%s\",", W5_EscapeJSONString(ev.event_id));

   if(StringLen(ev.parent_event_id) > 0)
      json += StringFormat("\"parent_event_id\":\"%s\",", W5_EscapeJSONString(ev.parent_event_id));
   else
      json += "\"parent_event_id\":null,";
   if(StringLen(ev.parent_event_ids_pipe) > 0)
      json += StringFormat("\"parent_event_ids\":%s,", W5_ParentIDsToJSON(ev.parent_event_ids_pipe));

   json += StringFormat("\"run_id\":\"%s\",", W5_EscapeJSONString(ev.run_id));
   json += StringFormat("\"stream_id\":\"%s\",", W5_EscapeJSONString(ev.stream_id));
   json += StringFormat("\"emitter_generation\":%d,", ev.emitter_generation);
   json += StringFormat("\"event_type\":\"%s\",", W5_EscapeJSONString(ev.event_type));
   json += StringFormat("\"local_counter\":%I64u,", ev.local_counter);

   // Strict ISO 8601 UTC formatting (Q06)
   json += StringFormat("\"recorded_utc\":\"%s\",", W5_TimeToISO8601UTC(ev.recorded_utc));
   if(ev.strategy_bar_time == 0)
      json += "\"strategy_bar_time\":null,";
   else
      json += StringFormat("\"strategy_bar_time\":\"%s\",", W5_TimeToISO8601UTC(ev.strategy_bar_time));

   // call_site
   json += StringFormat("\"call_site\":{\"file\":\"%s\",\"function\":\"%s\",\"line\":%d},",
                        W5_EscapeJSONString(ev.call_file), W5_EscapeJSONString(ev.call_function), ev.call_line);

   // sensor_payload
   json += StringFormat("\"sensor_payload\":{\"symbol\":\"%s\",\"timeframe\":%d,\"indicator_kind\":\"%s\",\"period\":%d,\"handle_id\":\"%s\",\"handle_generation\":%d,\"buffer_id\":%d,\"start_pos\":%d,\"requested_count\":%d,\"returned_count\":%d,\"raw_value\":%s,\"error_code\":%d},",
                        W5_EscapeJSONString(ev.symbol), ev.timeframe, W5_EscapeJSONString(ev.indicator_kind), ev.period, W5_EscapeJSONString(ev.handle_id), ev.handle_generation,
                        ev.buffer_id, ev.start_pos, ev.requested_count, ev.returned_count, W5_FormatRawValueJSON(ev.raw_value), ev.error_code);

   // causality_link
   json += StringFormat("\"causality_link\":{\"consumed_in_decision\":%s,\"decision_id\":%s,\"edge_type\":\"%s\"},",
                        ev.consumed_in_decision ? "true" : "false",
                        StringLen(ev.decision_id) > 0 ? StringFormat("\"%s\"", W5_EscapeJSONString(ev.decision_id)) : "null",
                        W5_EscapeJSONString(ev.edge_type));

   // assurance_class
   json += StringFormat("\"assurance_class\":{\"trace_internal_closed\":%s,\"static_scope_instrumented\":%s,\"actual_api_calls_witnessed\":\"%s\"},",
                        ev.trace_internal_closed ? "true" : "false",
                        ev.static_scope_instrumented ? "true" : "false",
                        W5_EscapeJSONString(ev.actual_api_calls_witnessed));

   json += StringFormat("\"prev_event_digest\":\"%s\"", W5_EscapeJSONString(ev.prev_event_digest));
   json += "}";
   return json;
}
