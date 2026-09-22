"""Dependency/readiness contracts. No provider call, regime guessing or run launch."""
from __future__ import annotations
from .core import Refused, checksum, finite, sha256, stable_hash, text, utc

REGIONS = ('US', 'EUROZONE', 'UK', 'JAPAN', 'CHINA', 'INDIA', 'EM', 'GLOBAL')
AXES = ('GROWTH', 'INFLATION', 'POLICY', 'LIQUIDITY', 'CREDIT', 'EQUITY', 'CARRY')
GATES = (
    'parent_source_and_build', 'parent_home_and_config', 'source_coverage_and_vintages',
    'schedule_publication_history', 'broker_clock', 'classifier_and_calibration',
    'policy_and_pending_semantics', 'primary_metric_and_falsifier',
    'placebo_design_and_seeds', 'native_guard_parity', 'independent_gpt_scrutiny',
    'tester_reservation_and_controller',
)


def global_readiness(catalog: dict) -> dict:
    """A coverage map of proposed inputs, NEVER an inferred economic regime."""
    if not isinstance(catalog, dict) or catalog.get('schema_version') != 'news_macro_source_plan/1':
        raise Refused('SOURCE_PLAN_SCHEMA_REQUIRED')
    rows = catalog.get('sources')
    if not isinstance(rows, list):
        raise Refused('SOURCE_PLAN_LIST_REQUIRED')
    ids = set()
    groups = {}
    for row in rows:
        if not isinstance(row, dict):
            raise Refused('SOURCE_PLAN_ROW_REQUIRED')
        identity = text(row.get('source_id'))
        if identity in ids:
            raise Refused('DUPLICATE_SOURCE_ID')
        ids.add(identity)
        if row.get('region') not in REGIONS or row.get('axis') not in AXES:
            raise Refused('UNKNOWN_REGION_OR_AXIS')
        if row.get('historical_qualified') is not False:
            raise Refused('SOURCE_PLAN_CANNOT_SELF_QUALIFY')
        if row.get('status') not in ('CANDIDATE_SOURCE_REQUIRED', 'EXISTING_SOURCE_NOT_REPLAY_QUALIFIED',
                                     'BOUNDED_SELECTOR_ONLY'):
            raise Refused('SOURCE_STATUS_UNSUPPORTED')
        text(row.get('instrument_or_series')); text(row.get('dependency_group'))
        if 'value' in row or 'probability' in row or 'regime' in row:
            raise Refused('SOURCE_PLAN_MUST_NOT_CONTAIN_MARKET_OBSERVATIONS')
        groups.setdefault((row['region'], row['axis']), []).append(identity)
    cells = [{'region': region, 'axis': axis, 'regime': 'UNKNOWN',
              'source_ids': sorted(groups.get((region, axis), [])),
              'status': 'SOURCE_QUALIFICATION_REQUIRED' if (region, axis) in groups else 'NO_SOURCE_PROPOSED'}
             for region in REGIONS for axis in AXES]
    return {'schema_version': 'global_regime_readiness/1', 'classification': 'PLANNING_NOT_MARKET_STATE',
            'catalog_sha256': stable_hash(catalog), 'cells': cells, 'source_count': len(ids),
            'world_regime': 'UNKNOWN', 'probability': None, 'can_execute': False,
            'aggregation': 'NO_WEIGHTS_OR_GLOBAL_SCORE_DEFINED',
            'dependency_groups': sorted({r['dependency_group'] for r in rows})}


def experiment_preflight(proposal: dict) -> dict:
    """Check completeness/structure, never authenticate a receipt or grant MT5."""
    if not isinstance(proposal, dict) or proposal.get('schema_version') != 'guard_experiment_proposal/1':
        raise Refused('EXPERIMENT_SCHEMA_REQUIRED')
    if proposal.get('can_execute') is not False:
        raise Refused('PROPOSAL_CANNOT_GRANT_EXECUTION')
    if proposal.get('optimization') != 'NONE' or proposal.get('bwd_role') != 'VALIDATION_ONLY':
        raise Refused('SEARCH_OR_BWD_RETUNING_REFUSED')
    if proposal.get('holdout_policy') != 'SEPARATE_OWNER_GATE_NO_USE':
        raise Refused('HOLDOUT_AUTHORITY_REFUSED')
    missing, reasons = [], []
    changes = proposal.get('changed_dimensions')
    if not isinstance(changes, list) or len(changes) != 1 or not isinstance(changes[0], str):
        raise Refused('ONE_LOGICAL_CHANGE_REQUIRED')
    if changes[0] not in ('NEWS_FIXED_WINDOW', 'MACRO_FROZEN_RULES', 'NEWS_TEXT_SHADOW', 'GLOBAL_MACRO_SHADOW'):
        raise Refused('UNKNOWN_PROSPECTIVE_CHANGE')
    gates = proposal.get('gate_receipt_sha256')
    if not isinstance(gates, dict) or set(gates) != set(GATES):
        raise Refused('EXACT_GATE_SET_REQUIRED')
    for gate in GATES:
        if gates[gate] is None:
            missing.append(gate)
        else:
            checksum(gates[gate])
    windows = proposal.get('windows')
    if not isinstance(windows, dict) or set(windows) != {'MAIN', 'BWD'}:
        raise Refused('EXACT_MAIN_BWD_REQUIRED')
    intervals = []
    for name in ('MAIN', 'BWD'):
        w = windows[name]
        if w is None:
            missing.append(name + '_WINDOW_FREEZE')
            continue
        if not isinstance(w, dict) or set(w) != {'start_utc', 'end_utc'}:
            raise Refused('EXACT_WINDOW_SCHEMA_REQUIRED')
        start, end = utc(w['start_utc']), utc(w['end_utc'])
        if start >= end:
            raise Refused('WINDOW_ORDER_INVALID')
        intervals.append((start, end))
    if len(intervals) == 2 and max(x[0] for x in intervals) < min(x[1] for x in intervals):
        raise Refused('MAIN_BWD_OVERLAP')
    seeds = proposal.get('placebo_seeds')
    if seeds is None:
        missing.append('PLACEBO_SEEDS_FREEZE')
    elif (not isinstance(seeds, list) or not seeds or
          any(type(x) is not int or x < 0 for x in seeds) or len(set(seeds)) != len(seeds)):
        raise Refused('EXPLICIT_UNIQUE_PLACEBO_SEEDS_REQUIRED')
    if proposal.get('evaluation_unit') not in (None, 'TRADE', 'BASKET_EPISODE'):
        raise Refused('UNKNOWN_EVALUATION_UNIT')
    if proposal.get('evaluation_unit') is None:
        missing.append('EVALUATION_UNIT_FREEZE')
    reasons.append('RECEIPT_HASH_PRESENCE_IS_NOT_RECEIPT_ACCEPTANCE')
    return {'schema_version': 'guard_experiment_preflight/1', 'proposal_sha256': stable_hash(proposal),
            'status': 'BLOCKED_CONTRACT_INCOMPLETE' if missing else 'DECLARED_FIELDS_COMPLETE_REVIEW_REQUIRED',
            'missing_gates': sorted(missing), 'reason_codes': reasons,
            'can_execute': False, 'native_runs': 0, 'performance': 'NOT_RUN',
            'holdout_used': False, 'historical_dataset_qualified': False}


def validate_shadow_annotation(annotation: dict, *, labels: tuple[str, ...],
                               source_available_at_utc: str, input_raw: bytes, model_sha256: str,
                               prompt_sha256: str, label_spec_sha256: str) -> dict:
    """Validate a provider-neutral text annotation; probabilities remain scores.

    Historical model-training contamination cannot be solved by timestamp checks.
    All labels/scores are unqualified annotations, never risk or win probabilities.
    """
    fields = {'schema_version', 'decision_at_utc', 'input_sha256', 'model_sha256',
              'prompt_sha256', 'label_spec_sha256', 'abstain', 'scores'}
    if not isinstance(annotation, dict) or set(annotation) != fields:
        raise Refused('SHADOW_SCHEMA_MISMATCH')
    if annotation['schema_version'] != 'news_text_annotation/1':
        raise Refused('SHADOW_SCHEMA_MISMATCH')
    if not labels or len(set(labels)) != len(labels) or any(not isinstance(x, str) or not x for x in labels):
        raise Refused('FROZEN_LABEL_SET_REQUIRED')
    checksum(annotation['input_sha256'])
    if not isinstance(input_raw, bytes) or not input_raw or sha256(input_raw) != annotation['input_sha256']:
        raise Refused('SHADOW_INPUT_HASH_MISMATCH')
    for key, expected in [('model_sha256', model_sha256), ('prompt_sha256', prompt_sha256),
                          ('label_spec_sha256', label_spec_sha256)]:
        checksum(expected)
        if annotation[key] != expected:
            raise Refused('MODEL_PROMPT_OR_LABEL_BINDING_MISMATCH')
    if utc(annotation['decision_at_utc']) < utc(source_available_at_utc):
        raise Refused('ANNOTATION_PRECEDES_SOURCE')
    if type(annotation['abstain']) is not bool:
        raise Refused('EXPLICIT_ABSTENTION_REQUIRED')
    scores = annotation['scores']
    if annotation['abstain']:
        if scores is not None:
            raise Refused('ABSTENTION_REQUIRES_NULL_SCORES')
    else:
        if not isinstance(scores, dict) or set(scores) != set(labels):
            raise Refused('SHADOW_LABEL_SET_MISMATCH')
        values = [finite(x) for x in scores.values()]
        if any(x < 0 or x > 1 for x in values) or abs(sum(values) - 1) > 1e-6:
            raise Refused('SHADOW_SCORE_SIMPLEX_INVALID')
    return {'schema_version': 'shadow_annotation_validation/1',
            'annotation_sha256': stable_hash(annotation), 'status': 'TYPED_ANNOTATION_ONLY',
            'calibrated': False, 'historical_predictive_oos_qualified': False,
            'source_binding': 'INPUT_BYTES_VERIFIED_NOT_SOURCE_CERTIFIED',
            'provider_invoked': False, 'can_execute': False, 'ea_actions': []}
