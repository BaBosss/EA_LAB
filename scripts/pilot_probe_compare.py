# -*- coding: utf-8 -*-
"""ORDER-1230 (slice S13). Decide whether a flat-lot probe actually PROBED anything.

WHY THIS EXISTS. B14-H01's pre-registered falsifier is "flat-lot variant PF >= escalated PF (edge
is in the signal, not the engine)". Read literally, two arms that produce the SAME PF satisfy it.
But on the pilot's pinned config the first run of the matrix produced arms that matched in every
digit -- PF 3.05, 180 trades, 9.39% DD, both -- and the reason was not that the edge lives in the
signal. It was that `_41_FixedLot=0.01` on a 0.01-step broker quantizes the LOG-power progression
away: `lot = firstLot * 1.3^ln(orderN)` first rounds up to 0.02 at orderN=5, and the baskets only
ever reach L2. The escalation engine never ran, in either arm.

So the honest verdict for that cell is UNTESTED, not "falsifier satisfied". This repo's standing
rule says the same thing about guards -- a guard with zero observed fires is UNTESTED and must not
be written up as passed -- and an escalation engine that never escalates is the same shape. Calling
it a falsification would be the most expensive possible misreading, because it would retire H01's
causal claim on evidence that the mechanism was never exercised.

WHAT IT MEASURES, and why it is the trade lists and not the summary. Identical PF with DIFFERENT
trade lists is two different strategies agreeing on one window (memory inert-axis-fake-plateau, and
design 5.5's whole argument). Identical TRADE LISTS is the lever doing nothing. Only the second is
inertness, and only comparing the lists can tell them apart.

The Deals/Orders tables are read through `parity.py`'s parser rather than a new one here. That
module already owns this format, including the rule that a row is real only when its first cell is
a timestamp -- without which the tester's unlabelled TOTALS row makes every deal list non-empty and
an emptiness test can never fire. A second parser would be free to drift from the first
(memory guard-checks-the-wrong-surface).

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3): PURE. Reads two report files, writes a verdict to
stdout. Opens no terminal and runs no tester.

Usage:  pilot_probe_compare.py <escalated.htm> <flatlot.htm>
Exit 0 always -- this reports a state, it does not gate. The caller records what it says.
"""
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '_triage', 'factory_os'))
import parity  # noqa: E402  -- path is set immediately above

LEVEL = re.compile(r'\bL(\d+)\b')

# Deals-table column indices on the MT5 report layout parity.py already parses.
VOLUME_COL = 5
COMMENT_COL = -1


def read(path):
    return io.open(path, encoding='utf-16', errors='replace').read()


def describe(path):
    """-> (deals, {level: set(volumes)}, set(all volumes), deepest level)."""
    html = read(path)
    deals = parity._table(html, 'Deals')
    if deals is None:
        return None, {}, set(), None
    by_level = {}
    volumes = set()
    for d in deals:
        if len(d) <= VOLUME_COL:
            continue
        vol = d[VOLUME_COL]
        # '0.00' is the closing side of a paired deal on this layout, not a traded size.
        if vol and vol != '0.00':
            volumes.add(vol)
        m = LEVEL.search(d[COMMENT_COL])
        if m:
            by_level.setdefault(int(m.group(1)), set()).add(vol)
    deepest = max(by_level) if by_level else None
    return deals, by_level, volumes, deepest


def main(argv):
    if len(argv) != 2:
        sys.stderr.write('usage: pilot_probe_compare.py <escalated.htm> <flatlot.htm>\n')
        return 2
    esc_path, flat_path = argv

    esc_deals, esc_levels, esc_vols, esc_deep = describe(esc_path)
    flat_deals, flat_levels, flat_vols, flat_deep = describe(flat_path)

    out = {
        'escalated_report': esc_path,
        'flatlot_report': flat_path,
        'escalated_deepest_level': esc_deep,
        'flatlot_deepest_level': flat_deep,
        'escalated_distinct_volumes': sorted(esc_vols),
        'flatlot_distinct_volumes': sorted(flat_vols),
        'escalated_levels': dict((str(k), sorted(v)) for k, v in sorted(esc_levels.items())),
    }

    if esc_deals is None or flat_deals is None:
        out['probe_state'] = 'UNREADABLE'
        out['why'] = ('one side has no Deals table at all, so nothing about this probe is known. '
                      'This is REFUSED rather than skipped: an unreadable input must not be '
                      'reported as an absence of difference.')
        print(json.dumps(out, indent=1))
        return 0

    identical = (esc_deals == flat_deals)
    # The escalation is EXERCISED only if the escalated arm ever placed a size other than its
    # smallest. One distinct traded volume means every level got the same lot, which is exactly
    # what flat-lot does -- the two arms are then the same EA and the comparison is vacuous.
    escalated_sizes = len(esc_vols)

    if identical:
        out['probe_state'] = 'UNTESTED-INERT'
        out['why'] = (
            'the two arms produced IDENTICAL trade lists, so LotProg changed nothing that happened. '
            'This is NOT the falsifier being satisfied -- the escalation engine never ran, and a '
            'mechanism with zero fires is UNTESTED, never passed and never failed. Comparing the '
            'PFs of these two runs compares an EA with itself.')
        if escalated_sizes <= 1:
            out['why'] += (
                ' Cause: the escalated arm placed exactly one distinct volume (%s). With '
                'lot = firstLot * factor^ln(orderN), a firstLot at the broker minimum is rounded '
                'back to the minimum until the multiplier reaches 1.5, so the progression is '
                'quantized away at every level the basket actually reaches (deepest observed: L%s).'
                % (', '.join(sorted(esc_vols)) or 'none', esc_deep))
    elif escalated_sizes <= 1:
        out['probe_state'] = 'UNTESTED-INERT'
        out['why'] = (
            'the escalated arm placed only one distinct volume, so the progression produced no '
            'escalation to measure, even though the trade lists differ for some other reason. '
            'The falsifier cannot be evaluated from this pair.')
    else:
        out['probe_state'] = 'EXERCISED'
        out['why'] = ('the escalated arm placed %d distinct volumes and the trade lists differ, so '
                      'the progression did something the flat-lot arm did not. The falsifier '
                      'comparison is meaningful for this cell -- which is a statement about the '
                      'MEASUREMENT being valid, not about the outcome.' % escalated_sizes)

    print(json.dumps(out, indent=1))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
