"""The complete reviewer capability surface. Operates only on sealed bytes."""
import base64

from preflight import Refusal, canonical, require, sha256, strict_json


TOOL_PARAMETERS = {
    "get_manifest": (), "get_head": (),
    "read_source": ("source_id", "offset", "length"),
    "read_evidence": ("evidence_id", "offset", "length"),
    "read_git_object": ("object_id", "offset", "length"),
    "get_hash": ("entry_id",),
}


def tool_definitions():
    return [{"name": name, "parameters": {"type": "object", "additionalProperties": False,
             "required": list(args), "properties": {
                 arg: {"type": "integer", "minimum": 0} if arg in ("offset", "length")
                 else {"type": "string"} for arg in args}}}
            for name, args in TOOL_PARAMETERS.items()]


class Broker:
    def __init__(self, snapshot, bounds):
        self._snapshot = snapshot
        self._manifest = strict_json(snapshot.manifest_bytes, 8 * 1024 * 1024)
        self._bounds = dict(bounds)
        self._log = []
        self._ranges = {}
        self._returned = 0
        self._ids = {kind: {e["id"] for e in self._manifest[field]} for kind, field in
                     (("read_source", "source_entries"), ("read_evidence", "evidence_entries"),
                      ("read_git_object", "git_objects"))}

    def dispatch(self, raw):
        """Untrusted request is bytes; no getattr, eval, dynamic import or paths."""
        event = {"request_sha256": sha256(raw) if type(raw) is bytes else None,
                 "operation": None, "status": "DENIED", "entry_id": None,
                 "offset": None, "length": 0}
        try:
            require(len(self._log) < self._bounds["max_tool_calls"], "TOOL_CALL_LIMIT")
            request = strict_json(raw, 8192, 4)
            require(type(request) is dict and set(request) == {"name", "arguments"}, "TOOL_ENVELOPE")
            name, args = request["name"], request["arguments"]
            require(type(name) is str and name in TOOL_PARAMETERS, "UNKNOWN_OPERATION")
            event["operation"] = name
            require(type(args) is dict and set(args) == set(TOOL_PARAMETERS[name]), "TOOL_ARGUMENTS")
            if name == "get_manifest":
                result = {"manifest": self._manifest, "sha256": self._snapshot.manifest_sha256}
            elif name == "get_head":
                result = {"head": self._manifest["requested_head"], "tree": self._manifest["git_tree_oid"]}
            else:
                key = TOOL_PARAMETERS[name][0]
                entry_id = args[key]
                require(type(entry_id) is str and entry_id in self._snapshot.entries, "UNKNOWN_ID")
                data = self._snapshot.entries[entry_id]
                if name == "get_hash":
                    result = {"id": entry_id, "sha256": sha256(data), "size": len(data)}
                else:
                    require(entry_id in self._ids[name], "WRONG_ID_KIND")
                    offset, length = args["offset"], args["length"]
                    require(type(offset) is int and type(length) is int, "RANGE_TYPE")
                    require(0 <= offset < len(data) and 0 < length <= self._bounds["max_read_bytes"]
                            and offset + length <= len(data), "RANGE_BOUNDS")
                    chunk = data[offset:offset + length]
                    result = {"id": entry_id, "offset": offset, "length": length,
                              "encoding": "base64", "data": base64.b64encode(chunk).decode("ascii"),
                              "sha256": sha256(chunk)}
                    event.update(entry_id=entry_id, offset=offset, length=length)
            response = canonical({"ok": True, "result": result})
            require(self._returned + len(response) <= self._bounds["max_response_bytes"], "RESPONSE_CAPACITY")
            self._returned += len(response)
            if event["entry_id"] is not None:
                self._ranges.setdefault(event["entry_id"], []).append((event["offset"], event["offset"] + event["length"]))
            event["status"] = "OK"
            event["response_sha256"] = sha256(response)
        except Refusal as exc:
            event["reason"] = str(exc)
            response = canonical({"ok": False, "error": str(exc)})
        self._log.append(event)
        return response

    @property
    def read_log(self):
        return canonical(self._log)

    @property
    def successful_evidence_reads(self):
        return sum(e["status"] == "OK" and e["operation"] == "read_evidence" and e["length"] > 0 for e in self._log)

    def covers(self, required_ids):
        if not required_ids:
            return False
        for entry_id in required_ids:
            if entry_id not in self._snapshot.entries or not self._snapshot.entries[entry_id]:
                return False
            end = 0
            for start, stop in sorted(self._ranges.get(entry_id, [])):
                if start > end:
                    break
                end = max(end, stop)
            if end != len(self._snapshot.entries[entry_id]):
                return False
        return True
