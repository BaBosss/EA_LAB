<#
deployment_status.ps1 - ORDER-944 deployment status contract.

DEPLOYMENTS.csv owns the raw lifecycle word. Monitoring must not use that one word as
both an attachment decision and a verification claim, so this library maps the closed
raw vocabulary to separate operational and verification states.

Runtime data is deliberately absent from this mapping. A collector row can prove that
data exists; it cannot prove that the attached binary/configuration was verified.

AUDIT C REPAIR, C-A2 (2026-08-20, lane M0-L1).
  The paragraph directly above was ALREADY in this file, and the table directly below
  contradicted it: 'ACTIVE' => verification_state = 'VERIFIED'. The lifecycle word was the
  entire proof. MEASURED on canonical 649207d6, from portfolio\control_room_snapshot.json:
      verification_state counter: VERIFIED=58, NOT_APPLICABLE=5, UNVERIFIED=1
      summary.attestation_ok  = 0     (no row is HASHED at high confidence)
      summary.attestation_gaps= 59
      runtime_identity records= 0     (runtime_identity_summary.state=LEGACY_UNVERIFIED)
  58 deployments were labelled VERIFIED in a document that, three sections later, states it
  holds ZERO attestation evidence and ZERO runtime identity evidence for any of them.

  THE REPAIR: no lifecycle word yields VERIFIED any more. 'ACTIVE' means ATTACHED with
  verification PENDING, and VERIFIED is reachable only through Resolve-DeploymentVerification,
  which requires evidence to be handed in. Absent evidence is PENDING, taken from the existing
  closed vocabulary -- nothing new is invented, and no LIVE/deployment semantics change.

  verification_basis is added so a consumer can tell WHY a row is PENDING, because the two
  reasons need different handling and lumping them together would just move the defect:
      'EVIDENCE'           VERIFIED, derived from supplied evidence
      'LIFECYCLE_DECLARED' the CSV itself declares a non-verified state (ACTIVE-PENDING-VERIFY,
                           PENDING_ATTACH, UNVERIFIED) -> per-row failure token, as before
      'NO_EVIDENCE'        the CSV says ACTIVE and no evidence was supplied -> the C-A2 case
      'NOT_APPLICABLE'     REMOVED
ASCII-only on purpose (Windows PowerShell 5.1 reads scripts as ANSI).
#>

$script:DeploymentStatusCatalog = [ordered]@{
    'ACTIVE' = [ordered]@{
        operational_status = 'ATTACHED'
        # C-A2: was 'VERIFIED'. The lifecycle word proves ATTACHMENT INTENT, never verification.
        verification_state = 'PENDING'
        verification_basis = 'NO_EVIDENCE'
        forward_observed   = $true
        monitoring_visible = $true
        attention          = 'NONE'
    }
    'ACTIVE-PENDING-VERIFY' = [ordered]@{
        operational_status = 'ATTACHED'
        verification_state = 'PENDING'
        verification_basis = 'LIFECYCLE_DECLARED'
        forward_observed   = $true
        monitoring_visible = $true
        attention          = 'WARNING'
    }
    'PENDING_ATTACH' = [ordered]@{
        operational_status = 'PENDING_ATTACH'
        verification_state = 'PENDING'
        verification_basis = 'LIFECYCLE_DECLARED'
        forward_observed   = $false
        monitoring_visible = $true
        attention          = 'WARNING'
    }
    'UNVERIFIED' = [ordered]@{
        operational_status = 'UNKNOWN'
        verification_state = 'UNVERIFIED'
        verification_basis = 'LIFECYCLE_DECLARED'
        forward_observed   = $false
        monitoring_visible = $true
        attention          = 'BLOCKED'
    }
    'REMOVED' = [ordered]@{
        operational_status = 'REMOVED'
        verification_state = 'NOT_APPLICABLE'
        verification_basis = 'NOT_APPLICABLE'
        forward_observed   = $false
        monitoring_visible = $true
        attention          = 'NONE'
    }
}

function Get-DeploymentStatusSpec {
    param([AllowNull()][string]$Status)

    $raw = if ($null -eq $Status) { '' } else { $Status.Trim() }
    if (-not $script:DeploymentStatusCatalog.Contains($raw)) {
        throw "Unknown deployment status '$Status'. Allowed values: $($script:DeploymentStatusCatalog.Keys -join ', ')"
    }
    $spec = $script:DeploymentStatusCatalog[$raw]
    return [pscustomobject]@{
        status             = $raw
        operational_status = $spec.operational_status
        verification_state = $spec.verification_state
        verification_basis = $spec.verification_basis
        forward_observed   = [bool]$spec.forward_observed
        monitoring_visible = [bool]$spec.monitoring_visible
        attention          = $spec.attention
    }
}

function Resolve-DeploymentVerification {
    <#
      C-A2. DERIVES the verification state for one deployment key from EVIDENCE, never from the
      lifecycle word. Returns State / Basis / Evidence(one human line).

      $Evidence is a hashtable keyed "account|magic". A key with no entry, or an entry whose legs
      do not both prove out, stays PENDING. Both legs are required and each answers a different
      question:
        attestation_state / attestation_confidence  -- do the APPROVED artifact bytes match?
        runtime_identity_state                      -- is the thing actually running the identity
                                                       we think it is?
      Neither is inferred and neither is fabricated: this function only reads what the caller
      collected from the snapshot's own attestation / runtime_identity sections. An absent
      hashtable therefore produces zero VERIFIED rows, which is the honest answer for a repo that
      holds zero of either (measured: attestation_ok=0, runtime identity records=0).
    #>
    param(
        [Parameter(Mandatory = $true)]$Spec,
        [string]$Key = '',
        $Evidence = $null
    )
    if ($Spec.verification_basis -eq 'NOT_APPLICABLE') {
        return [pscustomobject]@{ State = $Spec.verification_state; Basis = 'NOT_APPLICABLE'; Evidence = 'removed deployment - verification does not apply' }
    }
    if ($Spec.verification_basis -eq 'LIFECYCLE_DECLARED') {
        return [pscustomobject]@{ State = $Spec.verification_state; Basis = 'LIFECYCLE_DECLARED'; Evidence = "DEPLOYMENTS.csv declares status '$($Spec.status)' - the file itself states this row is not verified" }
    }
    # verification_basis is NO_EVIDENCE at this point (an ACTIVE row). Only evidence can move it.
    if ($null -eq $Evidence -or $Key -eq '') {
        return [pscustomobject]@{ State = 'PENDING'; Basis = 'NO_EVIDENCE'; Evidence = 'no verification evidence was supplied to this reader' }
    }
    $e = $null
    if ($Evidence -is [System.Collections.IDictionary]) {
        if ($Evidence.Contains($Key)) { $e = $Evidence[$Key] }
    }
    if ($null -eq $e) {
        return [pscustomobject]@{ State = 'PENDING'; Basis = 'NO_EVIDENCE'; Evidence = "no attestation or runtime-identity evidence for $Key" }
    }
    $att = "$($e.attestation_state)"
    $conf = "$($e.attestation_confidence)"
    $rid = "$($e.runtime_identity_state)"
    $missing = @()
    if ($att -ne 'HASHED') { $missing += "attestation=$(if ($att -eq '') { 'ABSENT' } else { $att })" }
    elseif ($conf -ne 'high') { $missing += "attestation_confidence=$(if ($conf -eq '') { 'ABSENT' } else { $conf })" }
    if ($rid -ne 'PASS') { $missing += "runtime_identity=$(if ($rid -eq '') { 'ABSENT' } else { $rid })" }
    if ($missing.Count -gt 0) {
        return [pscustomobject]@{ State = 'PENDING'; Basis = 'NO_EVIDENCE'; Evidence = "evidence incomplete for $Key -- " + ($missing -join ', ') }
    }
    return [pscustomobject]@{ State = 'VERIFIED'; Basis = 'EVIDENCE'; Evidence = "attestation HASHED/high + runtime_identity PASS for $Key" }
}

function Get-DeploymentMonitoringRows {
    param(
        [AllowNull()][object[]]$Rows,
        # C-A2: optional evidence table keyed "account|magic". Omitted = no row can be VERIFIED.
        $Evidence = $null
    )

    foreach ($row in @($Rows)) {
        if ($null -eq $row) { continue }
        $spec = Get-DeploymentStatusSpec "$($row.status)"
        $key = "$($row.account)|$($row.magic)"
        $ver = Resolve-DeploymentVerification -Spec $spec -Key $key -Evidence $Evidence
        $copy = $row.PSObject.Copy()
        Add-Member -InputObject $copy -MemberType NoteProperty -Name 'operational_status' -Value $spec.operational_status -Force
        Add-Member -InputObject $copy -MemberType NoteProperty -Name 'verification_state' -Value $ver.State -Force
        Add-Member -InputObject $copy -MemberType NoteProperty -Name 'verification_basis' -Value $ver.Basis -Force
        Add-Member -InputObject $copy -MemberType NoteProperty -Name 'verification_evidence' -Value $ver.Evidence -Force
        Add-Member -InputObject $copy -MemberType NoteProperty -Name 'forward_observed' -Value $spec.forward_observed -Force
        Add-Member -InputObject $copy -MemberType NoteProperty -Name 'monitoring_visible' -Value $spec.monitoring_visible -Force
        Add-Member -InputObject $copy -MemberType NoteProperty -Name 'attention' -Value $spec.attention -Force
        Write-Output $copy
    }
}
