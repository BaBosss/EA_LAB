[CmdletBinding()]
param([string]$ResultPath='')
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$source=Join-Path $root 'scripts/lane_registry.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Validator does not parse'}
foreach($name in @('Throw-LaneError','Test-Sha','Normalize-CriticalPath','Test-NonGitAdministrativeRecord','Test-LaneRecord')){
    $fn=@($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|Where-Object Name -ceq $name)
    if($fn.Count -ne 1){throw "Missing actual function $name"}
    . ([scriptblock]::Create($fn[0].Extent.Text))
}
$valid=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -ceq '$ValidStates'},$true))
. ([scriptblock]::Create($valid[0].Extent.Text))
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('ea_registry_admin_test_'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $scratch
$cases=@()
$parseArgs=@{}
if((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')){$parseArgs.DateKind='String'}
try{
    # Fixture policy override is isolated to this helper-test process. Full CLI
    # production/copy audits separately exercise the actual immutable policy.
    $original=[ordered]@{lane_id='fixture-admin';owner_chat='fixture-owner';worker='fixture-worker';objective='historical cleanup';state='BLOCKED';base_sha='N/A_NON_GIT_TEMP_CLEANUP';head_sha='N/A';worktree=$scratch;branch='';allowed_paths=@('fixture-path');critical_paths=@();writer=$true;dependencies=@();runtime_lane='';reviewer='';reviewed_head='';direct_consumer='fixture read';blocker_class='STALLED_NO_RETRY';updated_at='2026-10-07T14:44:27Z'}
    $preimage=Join-Path $scratch 'preimage.json';$authority=Join-Path $scratch 'authority.txt';$evidence=Join-Path $scratch 'evidence.json'
    $original|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $preimage -Encoding UTF8
    'FIXTURE_OWNER_APPROVAL_NOT_PRODUCTION'|Set-Content -LiteralPath $authority -Encoding UTF8
    '{"status":"STALLED_PARTIAL"}'|Set-Content -LiteralPath $evidence -Encoding UTF8
    $NonGitAdministrativePolicy=[ordered]@{lane_id='fixture-admin';authority_ref=$authority;authority_sha256=(Get-FileHash -LiteralPath $authority).Hash.ToLowerInvariant();preimage_ref=$preimage;preimage_sha256=(Get-FileHash -LiteralPath $preimage).Hash.ToLowerInvariant();evidence_ref=$evidence;evidence_sha256=(Get-FileHash -LiteralPath $evidence).Hash.ToLowerInvariant()}
    $admin=$original|ConvertTo-Json -Depth 30|ConvertFrom-Json @parseArgs
    $admin.base_sha=$null;$admin.head_sha=$null
    $id=[ordered]@{kind='NON_GIT_ADMINISTRATIVE_V1';operation='STALE_TEMP_CLEANUP';legacy_base_sha=$original.base_sha;legacy_head_sha=$original.head_sha}
    foreach($key in $NonGitAdministrativePolicy.Keys){if($key -ne 'lane_id'){$id[$key]=$NonGitAdministrativePolicy[$key]}}
    $admin|Add-Member source_identity ([pscustomobject]$id)
    $fixture=$admin|ConvertTo-Json -Depth 30
    $names=@('positive_admin','positive_git','untyped_markers','unknown_kind','unrelated_lane','mixed_git','empty_sha','branch_bound','branch_type','active_RUNNING','active_REVIEW','active_FROZEN','active_INTEGRATING','ready','done','forged_authority_hash','forged_preimage_hash','forged_evidence_hash','substituted_authority_ref','substituted_preimage_ref','substituted_evidence_ref','missing_binding','unknown_identity_field','non_string_hash','changed_legacy_base','changed_legacy_head','changed_owner','changed_worker','changed_scope','changed_blocker','changed_timestamp','changed_writer','changed_runtime','extra_history_field','bad_git_base','bad_git_head','missing_branch','missing_critical_paths','empty_critical_path','authority_tamper','preimage_tamper','evidence_tamper')
    foreach($name in $names){
        $r=$fixture|ConvertFrom-Json @parseArgs;$tamperPath=$null;$savedBytes=$null
        switch($name){
            'positive_git' {$r.PSObject.Properties.Remove('source_identity');$r.base_sha='a'*40;$r.head_sha='b'*40;$r.state='RUNNING';$r.branch='fixture'}
            'untyped_markers' {$r.PSObject.Properties.Remove('source_identity');$r.base_sha='N/A_NON_GIT_TEMP_CLEANUP';$r.head_sha='N/A'}
            'unknown_kind' {$r.source_identity.kind='NON_GIT_OTHER'}
            'unrelated_lane' {$r.lane_id='unapproved-admin'}
            'mixed_git' {$r.base_sha='a'*40}
            'empty_sha' {$r.head_sha=''}
            'branch_bound' {$r.branch='master'}
            'branch_type' {$r.branch=@()}
            'active_RUNNING' {$r.state='RUNNING'}
            'active_REVIEW' {$r.state='REVIEW'}
            'active_FROZEN' {$r.state='FROZEN'}
            'active_INTEGRATING' {$r.state='INTEGRATING'}
            'ready' {$r.state='READY'}
            'done' {$r.state='DONE'}
            'forged_authority_hash' {$r.source_identity.authority_sha256='0'*64}
            'forged_preimage_hash' {$r.source_identity.preimage_sha256='0'*64}
            'forged_evidence_hash' {$r.source_identity.evidence_sha256='0'*64}
            'substituted_authority_ref' {$r.source_identity.authority_ref=$evidence}
            'substituted_preimage_ref' {$r.source_identity.preimage_ref=$authority}
            'substituted_evidence_ref' {$r.source_identity.evidence_ref=$authority}
            'missing_binding' {$r.source_identity.PSObject.Properties.Remove('evidence_sha256')}
            'unknown_identity_field' {$r.source_identity|Add-Member extra 'x'}
            'non_string_hash' {$r.source_identity.evidence_sha256=123}
            'changed_legacy_base' {$r.source_identity.legacy_base_sha='a'*40}
            'changed_legacy_head' {$r.source_identity.legacy_head_sha='a'*40}
            'changed_owner' {$r.owner_chat='different'}
            'changed_worker' {$r.worker='different'}
            'changed_scope' {$r.allowed_paths=@('different')}
            'changed_blocker' {$r.blocker_class='NONE'}
            'changed_timestamp' {$r.updated_at='2026-10-08T00:00:00Z'}
            'changed_writer' {$r.writer=$false}
            'changed_runtime' {$r.runtime_lane='live'}
            'extra_history_field' {$r|Add-Member extra 'x'}
            'bad_git_base' {$r.PSObject.Properties.Remove('source_identity');$r.base_sha='N/A';$r.head_sha='a'*40}
            'bad_git_head' {$r.PSObject.Properties.Remove('source_identity');$r.base_sha='a'*40;$r.head_sha='N/A'}
            'missing_branch' {$r.PSObject.Properties.Remove('branch')}
            'missing_critical_paths' {$r.PSObject.Properties.Remove('critical_paths')}
            'empty_critical_path' {$r.critical_paths=@('')}
            'authority_tamper' {$tamperPath=$authority}
            'preimage_tamper' {$tamperPath=$preimage}
            'evidence_tamper' {$tamperPath=$evidence}
        }
        if($tamperPath){$savedBytes=[IO.File]::ReadAllBytes($tamperPath);[IO.File]::WriteAllText($tamperPath,'tampered')}
        $accepted=$true;$message=$null
        try{Test-LaneRecord $r $name}catch{$accepted=$false;$message=$_.Exception.Message}finally{if($tamperPath){[IO.File]::WriteAllBytes($tamperPath,$savedBytes)}}
        $expected=$name -in @('positive_admin','positive_git')
        $cases+=[pscustomobject]@{name=$name;expected_acceptance=$expected;actual_acceptance=$accepted;pass=($expected -eq $accepted);message=$message}
    }
    $result=[ordered]@{schema='LANE_REGISTRY_NON_GIT_ADMIN_TESTS_V1';source_sha256=(Get-FileHash -LiteralPath $source).Hash;fixtures_only=$true;total=$cases.Count;passed=@($cases|Where-Object pass).Count;cases=$cases}
    if($ResultPath){$result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ResultPath -Encoding UTF8}
    [pscustomobject]@{total=$result.total;passed=$result.passed}|ConvertTo-Json -Compress
    if($result.passed -ne $result.total){throw 'Non-Git administrative adversarial tests failed'}
}finally{
    $resolved=[IO.Path]::GetFullPath($scratch)
    $prefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if(-not $resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolved) -notlike 'ea_registry_admin_test_*'){throw 'Invalid fixture cleanup boundary'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
