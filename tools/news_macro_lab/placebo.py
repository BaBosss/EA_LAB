from __future__ import annotations

import hashlib
from datetime import timedelta
from typing import Any

from .core import Refused, count, text, utc

_EVENT_FIELDS = {"event_id", "scheduled_at_utc", "currency", "importance"}
_ALLOWED_IMPORTANCE = {"High", "Medium", "Low"}


def _event_window(stamp, pre_minutes: int, post_minutes: int):
    return (stamp - timedelta(minutes=pre_minutes),
            stamp + timedelta(minutes=post_minutes))


def _overlap(a, b) -> bool:
    return a[0] < b[1] and b[0] < a[1]


def build_week_shift_placebos(
    events: list[dict[str, Any]], *,
    coverage_start_utc: str, coverage_end_utc: str,
    pre_minutes: int, post_minutes: int,
    seeds: list[int], allowed_shift_weeks: list[int],
) -> dict[str, Any]:
    """Create all preregistered placebo schedules without choosing a winner.

    Whole-week shifts preserve UTC weekday and clock time. Candidates colliding
    with any real contact window or an already-assigned placebo window refuse.
    """
    count(pre_minutes); count(post_minutes)
    if pre_minutes + post_minutes == 0:
        raise Refused("EMPTY_CONTACT_WINDOW")
    start, end = utc(coverage_start_utc), utc(coverage_end_utc)
    if start >= end:
        raise Refused("COVERAGE_ORDER_INVALID")
    if (not isinstance(seeds, list) or not seeds or
            any(type(s) is not int or s < 0 for s in seeds) or
            len(set(seeds)) != len(seeds)):
        raise Refused("EXPLICIT_UNIQUE_PLACEBO_SEEDS_REQUIRED")
    if (not isinstance(allowed_shift_weeks, list) or not allowed_shift_weeks or
            any(type(w) is not int or w == 0 for w in allowed_shift_weeks) or
            len(set(allowed_shift_weeks)) != len(allowed_shift_weeks)):
        raise Refused("EXPLICIT_UNIQUE_NONZERO_SHIFTS_REQUIRED")
    if not isinstance(events, list) or not events:
        raise Refused("PLACEBO_EVENTS_REQUIRED")

    normalized = []
    ids = set()
    for row in events:
        if not isinstance(row, dict) or set(row) != _EVENT_FIELDS:
            raise Refused("PLACEBO_EVENT_SCHEMA_MISMATCH")
        event_id = text(row["event_id"])
        if event_id in ids:
            raise Refused("DUPLICATE_PLACEBO_EVENT_ID")
        ids.add(event_id)
        stamp = utc(row["scheduled_at_utc"])
        if row["importance"] not in _ALLOWED_IMPORTANCE:
            raise Refused("INVALID_EVENT_IMPORTANCE")
        if not isinstance(row["currency"], str) or len(row["currency"]) != 3 or not row["currency"].isupper():
            raise Refused("INVALID_EVENT_CURRENCY")
        window = _event_window(stamp, pre_minutes, post_minutes)
        if window[0] < start or window[1] > end:
            raise Refused("REAL_EVENT_WINDOW_OUTSIDE_COVERAGE")
        normalized.append((event_id, stamp, row["currency"], row["importance"], window))

    real_windows = [x[4] for x in normalized]
    schedules = []
    for seed in seeds:
        used = []
        assigned = []
        for event_id, stamp, currency, importance, _ in sorted(normalized):
            ordered_shifts = sorted(
                allowed_shift_weeks,
                key=lambda w: hashlib.sha256(f"{seed}:{event_id}:{w}".encode()).hexdigest(),
            )
            chosen = None
            for shift in ordered_shifts:
                candidate = stamp + timedelta(weeks=shift)
                window = _event_window(candidate, pre_minutes, post_minutes)
                if window[0] < start or window[1] > end:
                    continue
                if any(_overlap(window, rw) for rw in real_windows):
                    continue
                if any(_overlap(window, pw) for pw in used):
                    continue
                chosen = (shift, candidate, window)
                break
            if chosen is None:
                raise Refused("PLACEBO_CONSTRUCTION_INFEASIBLE")
            shift, candidate, window = chosen
            used.append(window)
            assigned.append({
                "placebo_event_id": f"P{seed}:{event_id}",
                "source_event_id": event_id,
                "scheduled_at_utc": candidate.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "currency": currency,
                "importance": importance,
                "shift_weeks": shift,
            })
        schedules.append({"seed": seed, "events": assigned})

    return {
        "schema_version": "guard_placebo_schedule/1",
        "classification": "PLACEBO_SCHEDULE_PREPARATION_ONLY",
        "coverage_start_utc": coverage_start_utc,
        "coverage_end_utc": coverage_end_utc,
        "pre_minutes": pre_minutes,
        "post_minutes": post_minutes,
        "allowed_shift_weeks": list(allowed_shift_weeks),
        "schedules": schedules,
        "all_seeds_retained": True,
        "selection_performed": False,
        "can_execute": False,
        "performance": "NOT_RUN",
    }
