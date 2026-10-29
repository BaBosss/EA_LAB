import json, pathlib, copy, unittest, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "tools" / "w5_b6230_v4"))
from gate import assess_historical, assess_prospective, CHANGED
p=pathlib.Path(__file__).parent
H=json.loads((p/'w5_b6230_historical_receipt_fixture.json').read_text())
F=json.loads((p/'w5_b6230_SYNTHETIC_DO_NOT_USE_FOR_NATIVE.json').read_text())

class TestHistorical(unittest.TestCase):
    def mutate(self, f, code):
        d=copy.deepcopy(H);f(d);r=assess_historical(d)
        self.assertEqual(r['historical_verdict'],'POSTCONDITION_FAIL')
        self.assertIn(code,r['reasons'])
        self.assertFalse(r['native_acceptance'])
    def test_actual_receipts_consistent_but_fail(self):
        r=assess_historical(H);self.assertTrue(r['receipt_consistent']);self.assertEqual(r['historical_verdict'],'POSTCONDITION_FAIL');self.assertFalse(r['native_acceptance'])
    def test_historic_relabel_denied(self):self.mutate(lambda d:d.update(historical_postcondition='PASS'),'OLD_FAIL_RELABELED')
    def test_drift_count_spoof_denied(self):self.mutate(lambda d:d.update(drift_count=0),'AUDIT_COUNTS_CHANGED')
    def test_missing_2026_change_denied(self):self.mutate(lambda d:d['drifts'].pop(0),'AUDIT_THREE_PATHS_CHANGED')
    def test_noop_sha_denied(self):self.mutate(lambda d:d['drifts'][0].update(post_sha256=d['drifts'][0]['pre_sha256']),'DRIFT_SHA_INVALID_'+CHANGED[0])
    def test_main_year_changed_denied(self):self.mutate(lambda d:d['source_years']['2023'].update(post_sha256='f'*64),'M1_YEAR_CHANGED_2023')
    def test_bwd_year_changed_denied(self):self.mutate(lambda d:d['source_years']['2021'].update(post_sha256='e'*64),'M1_YEAR_CHANGED_2021')
    def test_missing_2020_denied(self):self.mutate(lambda d:d['source_years'].pop('2020'),'SOURCE_YEAR_INVENTORY_INCOMPLETE')
    def test_wrong_ex5_denied(self):self.mutate(lambda d:d['identity'].update(ex5_off_sha256='0'*64),'IDENTITY_MISMATCH_EX5_OFF_SHA256')
    def test_wrong_build_denied(self):self.mutate(lambda d:d['identity'].update(terminal_sha256='0'*64),'IDENTITY_MISMATCH_TERMINAL_SHA256')
    def test_wrong_set_denied(self):self.mutate(lambda d:d['identity'].update(set_sha256='0'*64),'IDENTITY_MISMATCH_SET_SHA256')
    def test_wrong_model_denied(self):self.mutate(lambda d:d['identity'].update(model=2),'IDENTITY_MISMATCH_MODEL')
    def test_false_cell_claim_denied(self):self.mutate(lambda d:d.update(executed_cells=['MAIN_OFF','MAIN_ON']),'HISTORICAL_CELL_COUNT_MISMATCH')
    def test_holdout_claim_denied(self):self.mutate(lambda d:d.update(holdout_executed=True),'HOLDOUT_STATUS_NOT_PROVEN')

class TestProspective(unittest.TestCase):
    def mutate(self,f,code):
        d=copy.deepcopy(F);f(d);r=assess_prospective(d)
        self.assertEqual(r['classification'],'BLOCKED');self.assertIn(code,r['reasons']);self.assertFalse(r['native_acceptance'])
    def test_complete_mock_not_native_acceptance(self):
        r=assess_prospective(F);self.assertEqual(r['classification'],'OFFLINE_STRUCTURAL_READY_NOT_NATIVE_ACCEPTED');self.assertFalse(r['native_acceptance'])
    def test_unreviewed_denied(self):self.mutate(lambda d:d.update(independent_method_review='PENDING'),'INDEPENDENT_REVIEW_MISSING')
    def test_no_t3_denied(self):self.mutate(lambda d:d.update(owner_t3='NONE'),'OWNER_T3_MISSING')
    def test_no_lease_denied(self):self.mutate(lambda d:d.update(exclusive_resource_lease='UNKNOWN'),'LEASE_UNVERIFIED')
    def test_prior_fail_erased_denied(self):self.mutate(lambda d:d.update(prior_fail_preserved=False),'OLD_FAIL_NOT_PRESERVED')
    def test_enum_daily_mislabel_denied(self):self.mutate(lambda d:d.update(basket_tf_label='PERIOD_D1'),'TIMEFRAME_ENUM_ERROR')
    def test_missing_S1_denied(self):self.mutate(lambda d:d['checkpoints'].pop(1),'S0_S1_S2_S3_MISSING_OR_UNORDERED')
    def test_nonmonotone_timestamps_denied(self):self.mutate(lambda d:d['checkpoints'][1].update(asof_utc='2026-10-31T00:00:00Z'),'CHECKPOINT_TIMESTAMP_INVALID')
    def test_actor_drift_denied(self):self.mutate(lambda d:d['checkpoints'][2].update(resource_identity='wrong-terminal'),'CHECKPOINT_ACTOR_MISMATCH')
    def test_selected_dat_missing_sha_denied(self):self.mutate(lambda d:d['mutable_artifacts'][CHANGED[2]].pop('full_preimage_sha256'),'MUTABLE_PREPOST_UNBOUND_'+CHANGED[2])
    def test_selected_dat_changes_unproven_denied(self):self.mutate(lambda d:d['mutable_artifacts'][CHANGED[2]].update(full_postimage_sha256='b'*64),'UNCLASSIFIED_MUTATION_'+CHANGED[2])
    def test_daily_changes_unproven_denied(self):self.mutate(lambda d:d['mutable_artifacts'][CHANGED[1]].update(full_postimage_sha256='b'*64),'UNCLASSIFIED_MUTATION_'+CHANGED[1])
    def test_2026_changes_unproven_denied(self):self.mutate(lambda d:d['mutable_artifacts'][CHANGED[0]].update(full_postimage_sha256='b'*64),'UNCLASSIFIED_MUTATION_'+CHANGED[0])
    def test_unsigned_economics_denied(self):self.mutate(lambda d:d['economics'].update(producer_authenticated=False),'ECONOMICS_PRODUCER_NOT_AUTHENTICATED')
    def test_unknown_agent_economics_denied(self):self.mutate(lambda d:d['economics'].update(agent_effective_proven=False),'AGENT_EFFECTIVE_ECONOMICS_UNKNOWN')
    def test_extra_economics_field_missing_denied(self):self.mutate(lambda d:d['economics']['pre']['economics'].pop('spread_mode'),'BROKER_ECON_FIELD_MISSING_spread_mode')
    def test_account_leverage_diff_denied(self):self.mutate(lambda d:d['economics']['post']['account_configuration'].update(leverage=200),'ACCOUNT_FIELD_CHANGED_leverage')
    def test_commission_mode_diff_denied(self):self.mutate(lambda d:d['economics']['post']['economics'].update(commission_type=1),'BROKER_ECON_CHANGED_commission_type')
    def test_agent_cache_preimage_denied(self):self.mutate(lambda d:d['agent'].update(pre_manifest_sha256='UNKNOWN'),'AGENT_PREPOST_MISSING')
    def test_agent_cache_transition_not_predeclared_denied(self):self.mutate(lambda d:d['agent'].update(allowed_changes_predeclared=False),'AGENT_ALLOWED_TRANSITIONS_UNDEFINED')
    def test_agent_consumed_history_unbound_denied(self):self.mutate(lambda d:d['agent'].update(consumed_history_source_bound=False),'AGENT_CONSUMPTION_UNPROVEN')
    def test_history_trace_missing_denied(self):self.mutate(lambda d:d['effective_history'].update(indicator_timeframes_consumed_bound=False),'EFFECTIVE_PRICE_OR_HTF_TRACE_UNPROVEN')
    def test_missing_report_denied(self):self.mutate(lambda d:d.update(native_report_and_trades_bound=False),'NATIVE_REPORT_INCOMPLETE')
    def test_missing_process_pid_denied(self):self.mutate(lambda d:d.update(tester_process_pid_creation_exe_proven=False),'TESTER_PROCESS_PROVENANCE_MISSING')
    def test_holdout_denied(self):self.mutate(lambda d:d.update(holdout_executed=True),'HOLDOUT_SCOPE_VIOLATION_OR_UNKNOWN')
    def test_bwd_2019_warmup_denied(self):
        def f(d):d.update(cell='BWD_OFF',range=['2020.01.01','2022.12.31'],prior_cell_accepted=True,pre2020_warmup_reachability='UNKNOWN')
        self.mutate(f,'BWD_2019_WARMUP_UNPROVEN')
    def test_main_on_early_denied(self):self.mutate(lambda d:d.update(cell='MAIN_ON'),'PREVIOUS_CELL_NOT_ACCEPTED')
    def test_wrong_window_denied(self):self.mutate(lambda d:d.update(range=['2024.01.01','2025.12.31']),'WINDOW_MISMATCH')

if __name__=='__main__':unittest.main(verbosity=2)
