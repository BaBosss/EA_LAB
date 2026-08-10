<#
deployment_status.ps1 - ORDER-944 deployment status contract.

DEPLOYMENTS.csv owns the raw lifecycle word. Monitoring must not use that one word as
both an attachment decision and a verification claim, so this library maps the closed
raw vocabulary to separate operational and verification states.

Runtime data is deliberately absent from this mapping. A collector row can prove that
data exists; it cannot prove that the attached binary/configuration was verified.
ASCII-only on purpose (Windows PowerShell 5.1 reads scripts as ANSI).
#>

$script:DeploymentStatusCatalog = [ordered]@{
    'ACTIVE' = [ordered]@{
        operational_status = 'ATTACHED'
        verification_state = 'VERIFIED'
        forward_observed   = $true
        monitoring_visible = $true
        attention          = 'NONE'
    }
    'ACTIVE-PENDING-VERIFY' = [ordered]@{
        operational_status = 'ATTACHED'
        verification_state = 'PENDING'
        forward_observed   = $true
        monitoring_visible = $true
        attention          = 'WARNING'
    }
    'PENDING_ATTACH' = [ordered]@{
        operational_status = 'PENDING_ATTACH'
        verification_state = 'PENDING'
        forward_observed   = $false
        monitoring_visible = $true
        attention          = 'WARNING'
    }
    'UNVERIFIED' = [ordered]@{
        operational_status = 'UNKNOWN'
        verification_state = 'UNVERIFIED'
        forward_observed   = $false
        monitoring_visible = $true
        attention          = 'BLOCKED'
    }
    'REMOVED' = [ordered]@{
        operational_status = 'REMOVED'
        verification_state = 'NOT_APPLICABLE'
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
        forward_observed   = [bool]$spec.forward_observed
        monitoring_visible = [bool]$spec.monitoring_visible
        attention          = $spec.attention
    }
}

function Get-DeploymentMonitoringRows {
    param([AllowNull()][object[]]$Rows)

    foreach ($row in @($Rows)) {
        if ($null -eq $row) { continue }
        $spec = Get-DeploymentStatusSpec "$($row.status)"
        $copy = $row.PSObject.Copy()
        Add-Member -InputObject $copy -MemberType NoteProperty -Name 'operational_status' -Value $spec.operational_status -Force
        Add-Member -InputObject $copy -MemberType NoteProperty -Name 'verification_state' -Value $spec.verification_state -Force
        Add-Member -InputObject $copy -MemberType NoteProperty -Name 'forward_observed' -Value $spec.forward_observed -Force
        Add-Member -InputObject $copy -MemberType NoteProperty -Name 'monitoring_visible' -Value $spec.monitoring_visible -Force
        Add-Member -InputObject $copy -MemberType NoteProperty -Name 'attention' -Value $spec.attention -Force
        Write-Output $copy
    }
}
