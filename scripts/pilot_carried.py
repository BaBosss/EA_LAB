# -*- coding: utf-8 -*-
"""ORDER-1230 (slice S13). The loss a report's profit factor cannot see.

Under `SL_NONE` plus a money-denominated basket TP -- which is exactly B14-H01's architecture -- a
basket is closed only when it reaches its money target. A basket that never gets there is carried
to the end of the window, where the tester force-closes it and writes a deal commented
`end of test`. Those deals are NOT part of the closed-trade statistics the report computes PF from.

So a cell can show a high PF, or a 100% win rate, while holding an unrealized loss that never
entered the ratio. Measured on the first pilot matrix run: XAUUSD H1 reported PF 3.05 on net 2315.52
while carrying -433.34 in force-closed positions -- about 19% of the net, invisible in the headline.
This is the same family as the repo's standing rule that a PF must be read with its trade count and
drawdown (memory bar-cleared-by-non-participation): the headline number is not wrong so much as
incomplete in a direction that always flatters.

Reads the Deals table through `parity.py`'s parser, which already owns this format -- including the
rule that a row is real only when its first cell is a timestamp. A second parser here would be free
to drift from that one (memory guard-checks-the-wrong-surface).

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3): PURE. Reads a report, prints JSON. Opens nothing.

Usage:  pilot_carried.py <report.htm>
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '_triage', 'factory_os'))
import parity  # noqa: E402  -- path is set immediately above

PROFIT_COL = -3   # per-deal profit on this report layout


def main(argv):
    if len(argv) != 1:
        sys.stderr.write('usage: pilot_carried.py <report.htm>\n')
        return 2
    path = argv[0]
    html = io.open(path, encoding='utf-16', errors='replace').read()
    deals = parity._table(html, 'Deals')
    if deals is None:
        # REFUSE rather than report zero. "I could not read the Deals table" and "there was nothing
        # carried" are different facts, and collapsing them would report an unreadable input as a
        # clean one (memory unreadable-input-must-refuse-not-skip).
        print(json.dumps({'readable': False, 'carried_count': None, 'carried_profit': None,
                          'why': 'no Deals table could be parsed from this report, so nothing is '
                                 'known about carried positions -- this is NOT a report of zero'}))
        return 0

    carried = [d for d in deals if d and d[-1].strip() == 'end of test']
    total = 0.0
    unparsed = 0
    for d in carried:
        try:
            total += float(d[PROFIT_COL].replace(' ', '').replace(' ', ''))
        except (ValueError, IndexError):
            unparsed += 1

    out = {
        'readable': True,
        'carried_count': len(carried),
        'carried_profit': round(total, 2),
        'unparsed_rows': unparsed,
    }
    if carried:
        out['why'] = ('%d position(s) were force-closed when the window ended, for a summed %.2f. '
                      'This is NOT in the report profit factor: under SL_NONE a basket closes only '
                      'in profit, so an unresolved one is carried and its result never enters the '
                      'closed-trade statistics.' % (len(carried), total))
    else:
        out['why'] = ('nothing was carried: every basket resolved inside the window, so the profit '
                      'factor is not hiding an unrealized position here. That is a property of '
                      'THIS window, not a property of the strategy.')
    print(json.dumps(out))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
