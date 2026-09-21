"""Read-only CLI. Output is JSON on stdout; no output-file/runtime option."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from .core import ROOT, Refused, parse_json, safe_read, select_asof, news_contact, macro_context, price_features
from .planning import experiment_preflight, global_readiness


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['readiness', 'preflight', 'select', 'news-contact', 'macro-context', 'price-features'])
    parser.add_argument('--input-root', required=True, type=Path)
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--raw-source', type=Path)
    parser.add_argument('--decision')
    parser.add_argument('--synthetic-mechanics', action='store_true')
    parser.add_argument('--currencies', nargs='+')
    parser.add_argument('--importance-levels', nargs='+')
    parser.add_argument('--pre-minutes', type=int)
    parser.add_argument('--post-minutes', type=int)
    parser.add_argument('--series-id')
    parser.add_argument('--classifier-sha256')
    parser.add_argument('--max-source-age-seconds', type=int)
    parser.add_argument('--instrument')
    parser.add_argument('--currency')
    parser.add_argument('--price-basis')
    parser.add_argument('--closes', type=int)
    args = parser.parse_args()
    try:
        data = parse_json(safe_read(args.input, args.input_root))
        if args.operation == 'readiness':
            result = global_readiness(data)
        elif args.operation == 'preflight':
            result = experiment_preflight(data)
        else:
            if not args.raw_source or not args.decision:
                raise Refused('RAW_SOURCE_AND_DECISION_REQUIRED')
            raw = safe_read(args.raw_source, args.input_root)
            kw = {'synthetic': args.synthetic_mechanics}
            if args.operation == 'select':
                result = select_asof(data, raw, args.decision, **kw)
            elif args.operation == 'news-contact':
                result = news_contact(data, raw, args.decision, currencies=args.currencies,
                    importance_levels=args.importance_levels,
                    pre_minutes=args.pre_minutes, post_minutes=args.post_minutes, **kw)
            elif args.operation == 'macro-context':
                result = macro_context(data, raw, args.decision, series_id=args.series_id,
                    classifier_sha256=args.classifier_sha256,
                    max_source_age_seconds=args.max_source_age_seconds, **kw)
            else:
                result = price_features(data, raw, args.decision, instrument=args.instrument,
                    currency=args.currency, price_basis=args.price_basis, closes=args.closes,
                    max_source_age_seconds=args.max_source_age_seconds, **kw)
        print(json.dumps(result, ensure_ascii=False, allow_nan=False, indent=2))
        return 1 if result.get('status') in ('REFUSED', 'BLOCKED_CONTRACT_INCOMPLETE') else 0
    except (Refused, OSError, ValueError, KeyError, TypeError, OverflowError) as exc:
        code = str(exc) if isinstance(exc, Refused) else type(exc).__name__
        print(json.dumps({'status': 'REFUSED', 'reason': code, 'can_execute': False}))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
