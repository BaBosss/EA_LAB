<#
.SYNOPSIS
    ORDER-105 Contract D writer and diagnostic utility for the Git-tracked
    experiment event log.

.DESCRIPTION
    All mutations use one repository-wide FileStream lock. Event/month and
    evidence-manifest candidates are built completely in memory, written to a
    same-volume utility-owned temporary file, durably flushed, and atomically
    installed. The schemas under docs/memory_control/experiment_events/schema
    are the single declarative validation source used by this utility and by
    scripts/check_experiment_events.ps1.

    Event request JSON deliberately omits timestamp_utc. The utility assigns it
    after acquiring the lock. A retry with an existing event_id is compared to
    the stored event after substituting its utility-assigned timestamp.
#>
param(
    [ValidateSet('Append', 'RegisterEvidence', 'Scan', 'Disable', 'Enable', 'Recover', 'NewEventId')]
    [string]$Command = 'Scan',
    [string]$RepoRoot,
    [string]$EventJsonPath,
    [string]$ArtifactPath,
    [string]$CommitOid = 'HEAD',
    [string]$MediaType,
    [string]$Actor,
    [string]$Role,
    [string]$AuthorizationRefJsonPath,
    [string]$RecoveryFilePath,
    [string]$RecoveryMonth,
    [string]$QuarantineEvidenceId,
    [string]$RegisterEvidencePath,
    [string]$RegisterEvidenceCommitOid = 'HEAD',
    [string]$RegisterEvidenceMediaType,
    [int]$LockTimeoutSeconds = 30,
    [string]$ValidatedSnapshotDir,
    [string]$TestUtcNow,
    [ValidateSet('', 'before_temp_flush', 'after_temp_flush_before_replace', 'after_replace', 'after_manifest_install_before_event_install')]
    [string]$TestFaultPoint = ''
)

$ErrorActionPreference = 'Stop'
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false, $true)
$script:StatusNames = @('appended', 'already_appended', 'schema_invalid', 'reference_invalid', 'event_id_conflict', 'stale_prior', 'integrity_corrupt', 'clock_skew', 'disabled', 'lock_timeout')
$script:EventUtilityDefaultRepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$script:CommittedBlobCache = @{}

function New-EventLogException {
    param([string]$Status, [string]$Message)
    $e = New-Object System.Exception($Message)
    $e.Data['EventStatus'] = $Status
    return $e
}

function Throw-EventLogError {
    param([string]$Status, [string]$Message)
    throw (New-EventLogException -Status $Status -Message $Message)
}

function Write-MachineStatus {
    param([string]$Status, [string]$Operation, [int]$LockWaitCount = 0, $Details = $null)
    $row = [ordered]@{
        status = $Status
        operation = $Operation
        lock_wait_count = $LockWaitCount
    }
    if ($null -cne $Details) { $row['details'] = $Details }
    $json=($row | ConvertTo-Json -Compress -Depth 20)
    [Console]::Out.WriteLine($json)
    if($env:EA_LAB_EVENT_TEST_MODE -ceq '1' -and $env:EA_LAB_EVENT_STATUS_FILE){
        [System.IO.File]::AppendAllText($env:EA_LAB_EVENT_STATUS_FILE,$json+"`n",(New-Object System.Text.UTF8Encoding($false)))
    }
}

function Invoke-GitText {
    param([string]$Root, [string[]]$Arguments, [switch]$AllowFailure)
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -C $Root @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $saved
    }
    $text = (($output | ForEach-Object { $_.ToString() }) -join "`n").TrimEnd("`r", "`n")
    if ($code -cne 0 -and -not $AllowFailure) { throw "git $($Arguments -join ' ') failed ($code): $text" }
    return [pscustomobject]@{ ExitCode = $code; Text = $text }
}

function Resolve-RepositoryRoot {
    param([string]$RequestedRoot)
    $candidate = if ($RequestedRoot) { $RequestedRoot } else { $script:EventUtilityDefaultRepoRoot }
    $r = Invoke-GitText -Root $candidate -Arguments @('rev-parse', '--show-toplevel')
    return [System.IO.Path]::GetFullPath($r.Text)
}

function Quote-ProcessArgument {
    param([string]$Value)
    if ($Value -cnotmatch '[\s"]') { return $Value }
    return '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

function Invoke-GitRawBytes {
    param([string]$Root, [string[]]$Arguments)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git.exe'
    $allArgs = @('-C', $Root) + $Arguments
    $psi.Arguments = (($allArgs | ForEach-Object { Quote-ProcessArgument $_ }) -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    if (-not $p.Start()) { throw 'unable to start git.exe' }
    $memory = New-Object System.IO.MemoryStream
    $p.StandardOutput.BaseStream.CopyTo($memory)
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $code = $p.ExitCode
    $p.Dispose()
    if ($code -cne 0) { throw "git $($Arguments -join ' ') failed ($code): $stderr" }
    # A zero-byte blob is a valid Git object.  Prevent PowerShell from
    # collapsing the empty byte array into "no pipeline value".
    Write-Output -NoEnumerate $memory.ToArray()
}

function Get-Sha256Hex {
    param([byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join '') }
    finally { $sha.Dispose() }
}

function Test-ByteArrayEqual {
    param([byte[]]$A, [byte[]]$B)
    if ($null -ceq $A -or $null -ceq $B -or $A.Length -cne $B.Length) { return $false }
    for ($i = 0; $i -lt $A.Length; $i++) { if ($A[$i] -cne $B[$i]) { return $false } }
    return $true
}

function Get-ObjectPropertyNames {
    param($Object)
    if ($null -ceq $Object) { return @() }
    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Get-ExactProperty {
    param($Object, [string]$Name)
    if ($null -ceq $Object) { return $null }
    # PSObject's indexed lookup is fast but case-insensitive.  Use it only to
    # find the candidate, then require the stored name to match Ordinally.
    $property=$Object.PSObject.Properties[$Name]
    if ($null -cne $property -and [string]::Equals([string]$property.Name, $Name, [System.StringComparison]::Ordinal)) { return $property }
    return $null
}

function Test-HasProperty {
    param($Object, [string]$Name)
    return ($null -cne (Get-ExactProperty -Object $Object -Name $Name))
}

function Get-PropertyValue {
    param($Object, [string]$Name)
    $p = Get-ExactProperty -Object $Object -Name $Name
    if ($null -ceq $p) { return $null }
    return ,$p.Value
}

function ConvertTo-OrderedBySchema {
    param($Value, [string[]]$Order, [string[]]$ArtifactOrder, [string[]]$OwnerOrder)
    if ($null -ceq $Value) { return $null }
    if ($Value -is [System.Array]) {
        $items = @()
        foreach ($item in $Value) { $items += ,(ConvertTo-OrderedBySchema -Value $item -Order @() -ArtifactOrder $ArtifactOrder -OwnerOrder $OwnerOrder) }
        return ,$items
    }
    if ($Value -is [pscustomobject] -or $Value -is [System.Collections.IDictionary]) {
        $names = @(Get-ObjectPropertyNames $Value)
        $selectedOrder = $Order
        if ($names.Count -ceq 5 -and (@($ArtifactOrder | Where-Object { $names -ccontains $_ }).Count -ceq 5)) { $selectedOrder = $ArtifactOrder }
        elseif ($names -ccontains 'owner_type') { $selectedOrder = $OwnerOrder }
        elseif ($selectedOrder.Count -ceq 0) { $selectedOrder = $names }
        $ordered = [ordered]@{}
        foreach ($name in $selectedOrder) {
            if (Test-HasProperty $Value $name) {
                $ordered[$name] = ConvertTo-OrderedBySchema -Value (Get-PropertyValue $Value $name) -Order @() -ArtifactOrder $ArtifactOrder -OwnerOrder $OwnerOrder
            }
        }
        foreach ($name in $names) {
            if (-not $ordered.Contains($name)) {
                $ordered[$name] = ConvertTo-OrderedBySchema -Value (Get-PropertyValue $Value $name) -Order @() -ArtifactOrder $ArtifactOrder -OwnerOrder $OwnerOrder
            }
        }
        return [pscustomobject]$ordered
    }
    return $Value
}

function ConvertTo-CanonicalJsonBytes {
    param($Object, $Schema)
    $rules = $Schema.'x-ea-lab-rules'
    $ordered = ConvertTo-OrderedBySchema -Value $Object -Order @($rules.canonical_order) -ArtifactOrder @($rules.artifact_order) -OwnerOrder @($rules.owner_ref_order)
    $json = $ordered | ConvertTo-Json -Compress -Depth 20
    Write-Output -NoEnumerate $script:Utf8NoBom.GetBytes($json)
}

function ConvertFrom-StrictJsonBytes {
    param([byte[]]$Bytes, [string]$Context)
    if ($Bytes.Length -ge 3 -and $Bytes[0] -ceq 0xEF -and $Bytes[1] -ceq 0xBB -and $Bytes[2] -ceq 0xBF) { throw "$Context contains a UTF-8 BOM" }
    try { $text = $script:Utf8NoBom.GetString($Bytes) } catch { throw "$Context is not valid UTF-8: $($_.Exception.Message)" }
    try { $value = $text | ConvertFrom-Json } catch { throw "$Context is malformed JSON: $($_.Exception.Message)" }
    if ($null -ceq $value -or $value -is [System.Array] -or -not ($value -is [pscustomobject])) { throw "$Context must contain one JSON object" }
    return $value
}

function Resolve-SchemaRef {
    param($Schema, [string]$Ref)
    if ($Ref -ceq '#/$defs/owner_ref') { return $Schema.'$defs'.owner_ref }
    throw "unsupported schema ref '$Ref'"
}

function Test-JsonType {
    param($Value, [string]$Type)
    switch ($Type) {
        'null' { return $null -ceq $Value }
        'string' { return $Value -is [string] }
        'integer' { return ($Value -is [int] -or $Value -is [long] -or $Value -is [int16] -or $Value -is [byte]) }
        'object' { return ($null -cne $Value -and ($Value -is [pscustomobject] -or $Value -is [System.Collections.IDictionary])) }
        'array' { return $Value -is [System.Array] }
        'boolean' { return $Value -is [bool] }
        default { return $false }
    }
}

function Test-ValueAgainstDefinition {
    param($Value, $Definition, $RootSchema, [string]$Path, [System.Collections.Generic.List[string]]$Errors)
    if (Test-HasProperty $Definition '$ref') { $Definition = Resolve-SchemaRef -Schema $RootSchema -Ref $Definition.'$ref' }
    $types = @($Definition.type)
    if ($types.Count -gt 0) {
        $typeOk = $false
        foreach ($type in $types) { if (Test-JsonType -Value $Value -Type ([string]$type)) { $typeOk = $true; break } }
        if (-not $typeOk) { $Errors.Add("$Path has wrong type"); return }
    }
    if ($null -ceq $Value) { return }
    if ((Test-HasProperty $Definition 'const') -and $Value -cne $Definition.const) { $Errors.Add("$Path does not equal the required constant") }
    if ((Test-HasProperty $Definition 'enum') -and -not (@($Definition.enum) -ccontains $Value)) { $Errors.Add("$Path is outside its enum") }
    if ($Value -is [string]) {
        if ((Test-HasProperty $Definition 'maxLength') -and $Value.Length -gt [int]$Definition.maxLength) { $Errors.Add("$Path exceeds maxLength") }
        # A CR/LF/control char in a string field defeats the token patterns below:
        # .NET regex `$` matches before a trailing newline, so `^token$` accepts
        # "token`n". Reject control characters outright for every patterned/enum
        # string so no field (anchor/reason_ref/trial_family/ids/hashes) can smuggle
        # a line break past `-cmatch` (review round 2 finding 3).
        if ((Test-HasProperty $Definition 'pattern') -and (($Value -cnotmatch ([string]$Definition.pattern)) -or ($Value -match '[\x00-\x1f]'))) { $Errors.Add("$Path does not match its pattern") }
    }
    if (Test-JsonType $Value 'integer') {
        if ((Test-HasProperty $Definition 'minimum') -and $Value -lt [long]$Definition.minimum) { $Errors.Add("$Path is below minimum") }
        if ((Test-HasProperty $Definition 'maximum') -and $Value -gt [long]$Definition.maximum) { $Errors.Add("$Path exceeds maximum") }
    }
    if ($Value -is [System.Array]) {
        if ((Test-HasProperty $Definition 'minItems') -and $Value.Count -lt [int]$Definition.minItems) { $Errors.Add("$Path has too few items") }
        if ((Test-HasProperty $Definition 'maxItems') -and $Value.Count -gt [int]$Definition.maxItems) { $Errors.Add("$Path has too many items") }
        if ($Definition.uniqueItems -ceq $true) {
            $seen = @{}
            foreach ($item in $Value) {
                $key = $item | ConvertTo-Json -Compress -Depth 20
                if ($seen.ContainsKey($key)) { $Errors.Add("$Path contains duplicate items"); break }
                $seen[$key] = $true
            }
        }
        if (Test-HasProperty $Definition 'items') {
            for ($i = 0; $i -lt $Value.Count; $i++) { Test-ValueAgainstDefinition -Value $Value[$i] -Definition $Definition.items -RootSchema $RootSchema -Path "$Path[$i]" -Errors $Errors }
        }
    }
    if (Test-JsonType $Value 'object') {
        $names = @(Get-ObjectPropertyNames $Value)
        foreach ($required in @($Definition.required)) { if (-not ($names -ccontains [string]$required)) { $Errors.Add("$Path is missing required field '$required'") } }
        if ($Definition.additionalProperties -ceq $false) {
            $allowed = @(Get-ObjectPropertyNames $Definition.properties)
            foreach ($name in $names) { if (-not ($allowed -ccontains $name)) { $Errors.Add("$Path has unknown field '$name'") } }
        }
        foreach ($name in $names) {
            $childDef = Get-ExactProperty -Object $Definition.properties -Name $name
            if ($null -cne $childDef) { Test-ValueAgainstDefinition -Value (Get-PropertyValue $Value $name) -Definition $childDef.Value -RootSchema $RootSchema -Path "$Path.$name" -Errors $Errors }
        }
    }
}

function Test-TimestampExact {
    param([string]$Timestamp)
    $parsed = [datetime]::MinValue
    $ok = [datetime]::TryParseExact($Timestamp, 'yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal, [ref]$parsed)
    return [pscustomobject]@{ IsValid = $ok; Value = $parsed }
}

function Test-EventAgainstSchema {
    param($Event, $Schema)
    $errors = New-Object System.Collections.Generic.List[string]
    Test-ValueAgainstDefinition -Value $Event -Definition $Schema -RootSchema $Schema -Path '$' -Errors $errors
    if ($errors.Count -gt 0) { return $errors.ToArray() }
    $rules = $Schema.'x-ea-lab-rules'
    $eventType = [string]$Event.event_type
    $ruleProp = Get-ExactProperty -Object $rules.event_rules -Name $eventType
    if ($null -ceq $ruleProp) { $errors.Add("event_type '$eventType' has no v1 rule"); return $errors.ToArray() }
    $rule = $ruleProp.Value
    $names = @(Get-ObjectPropertyNames $Event)
    foreach ($name in $names) { if (-not (@($rule.allowed_fields) -ccontains $name)) { $errors.Add("event_type '$eventType' does not allow field '$name'") } }
    foreach ($forbidden in @($rules.forbidden_fields_case_insensitive)) {
        foreach ($name in $names) { if ($name.ToLowerInvariant() -ceq ([string]$forbidden).ToLowerInvariant()) { $errors.Add("forbidden ownership/narrative field '$name'") } }
    }
    $actorProperty = Get-ExactProperty -Object $rules.actor_roles -Name ([string]$Event.actor)
    $roleList = if ($null -cne $actorProperty) { @($actorProperty.Value) } else { @() }
    if (-not ($roleList -ccontains [string]$Event.role)) { $errors.Add("actor '$($Event.actor)' cannot use role '$($Event.role)'") }
    if ((Test-HasProperty $rule 'authorized_actors') -and -not (@($rule.authorized_actors) -ccontains [string]$Event.actor)) { $errors.Add("actor '$($Event.actor)' is not authorized for $eventType") }
    $ts = Test-TimestampExact -Timestamp ([string]$Event.timestamp_utc)
    if (-not $ts.IsValid) { $errors.Add('timestamp_utc is not a real fixed-millisecond UTC timestamp') }
    if ($rule.prior -ceq 'null') {
        if ($null -cne $Event.prior_event_id -or $null -cne $Event.prior_event_sha256) { $errors.Add("$eventType requires null prior fields") }
    } else {
        if ($null -ceq $Event.prior_event_id -or $null -ceq $Event.prior_event_sha256) { $errors.Add("$eventType requires both prior fields") }
    }
    if ($rule.trial -ceq 'null') {
        if ($null -cne $Event.trial_family -or $null -cne $Event.trial_count) { $errors.Add("$eventType requires null trial fields") }
    } else {
        if ($null -ceq $Event.trial_family -or $null -ceq $Event.trial_count) { $errors.Add("$eventType requires trial_family and trial_count") }
    }
    $hashValues = @($Event.artifact_hashes.ea, $Event.artifact_hashes.source, $Event.artifact_hashes.set, $Event.artifact_hashes.data, $Event.artifact_hashes.tester)
    if ($rule.artifacts -ceq 'all_null' -and @($hashValues | Where-Object { $null -cne $_ }).Count -cne 0) { $errors.Add("$eventType requires all artifact hashes to be null") }
    if ($rule.artifacts -ceq 'source_required') {
        if ($null -ceq $Event.artifact_hashes.source) { $errors.Add("$eventType requires artifact_hashes.source") }
        if (@($Event.artifact_hashes.ea, $Event.artifact_hashes.set, $Event.artifact_hashes.data, $Event.artifact_hashes.tester | Where-Object { $null -cne $_ }).Count -cne 0) { $errors.Add("$eventType permits only the source artifact hash") }
    }
    if ($rule.artifacts -ceq 'all_required' -and @($hashValues | Where-Object { $null -ceq $_ }).Count -cne 0) { $errors.Add("$eventType requires all five artifact hashes") }
    if (-not (@($rule.reason_codes) -ccontains [string]$Event.reason_code)) { $errors.Add("reason_code '$($Event.reason_code)' is not allowed for $eventType") }
    foreach ($owner in @($Event.owner_refs)) {
        if (-not (@($rule.owner_types) -ccontains [string]$owner.owner_type)) { $errors.Add("owner_type '$($owner.owner_type)' is not allowed for $eventType") }
        $pathRule = Get-ExactProperty -Object $rules.owner_path_patterns -Name ([string]$owner.owner_type)
        if ($null -ceq $pathRule -or [string]$owner.path -cnotmatch [string]$pathRule.Value) { $errors.Add("owner path '$($owner.path)' does not match owner_type '$($owner.owner_type)'") }
    }
    if ((Test-HasProperty $rule 'evidence_min') -and @($Event.evidence_ids).Count -lt [int]$rule.evidence_min) { $errors.Add("$eventType requires at least $($rule.evidence_min) evidence ID") }
    if ($eventType -cin @('AMENDMENT_ADDED', 'TOMBSTONE_ADDED')) {
        if (-not (Test-HasProperty $Event 'target_event_id') -or -not (Test-HasProperty $Event 'target_event_sha256')) { $errors.Add("$eventType requires target_event_id and target_event_sha256") }
        if ($Event.target_event_id -ceq $Event.event_id) { $errors.Add("$eventType cannot target itself") }
    }
    if ($Event.reason_code -ceq 'physical_recovery') {
        if (-not (@('user', 'claude') -ccontains [string]$Event.actor)) { $errors.Add('physical_recovery requires user or claude') }
        if (-not (Test-HasProperty $Event 'recovery_target_month')) { $errors.Add('physical_recovery requires recovery_target_month') }
    } elseif (Test-HasProperty $Event 'recovery_target_month') {
        $errors.Add('recovery_target_month is allowed only for physical_recovery')
    }
    return $errors.ToArray()
}

function Get-SchemaObjects {
    param([string]$Root)
    $eventPath = Join-Path $Root 'docs\memory_control\experiment_events\schema\event-v1.schema.json'
    $evidencePath = Join-Path $Root 'docs\memory_control\experiment_events\schema\evidence-v1.schema.json'
    if (-not (Test-Path -LiteralPath $eventPath) -or -not (Test-Path -LiteralPath $evidencePath)) { Throw-EventLogError 'schema_invalid' 'required v1 schema file is missing' }
    try {
        $event = ConvertFrom-StrictJsonBytes -Bytes ([System.IO.File]::ReadAllBytes($eventPath)) -Context 'event-v1.schema.json'
        $evidence = ConvertFrom-StrictJsonBytes -Bytes ([System.IO.File]::ReadAllBytes($evidencePath)) -Context 'evidence-v1.schema.json'
    } catch { Throw-EventLogError 'schema_invalid' $_.Exception.Message }
    if ($null -ceq $event.'x-ea-lab-rules' -or $null -ceq $evidence.'x-ea-lab-rules') { Throw-EventLogError 'schema_invalid' 'schema is missing x-ea-lab-rules' }
    return [pscustomobject]@{ Event = $event; Evidence = $evidence }
}

function Assert-RepoRelativePath {
    param([string]$Path)
    if (-not $Path -or [System.IO.Path]::IsPathRooted($Path) -or $Path -cmatch '\\' -or $Path -cmatch '(^|/)\.\.(/|$)' -or $Path -cnotmatch '^[A-Za-z0-9._/-]+$') { throw "path '$Path' is not a normalized repo-relative path" }
}

function Get-CommittedBlobRecord {
    param([string]$Root, [string]$Commit, [string]$Path, [string]$Anchor, [switch]$RequireAnchor)
    Assert-RepoRelativePath $Path
    if ($Commit -cnotmatch '^[0-9a-f]{40}$') { throw 'commit OID must be a full lowercase 40-hex object ID' }
    $cacheKey=([System.IO.Path]::GetFullPath($Root).ToLowerInvariant()+'|'+$Commit+'|'+$Path+'|'+[string]$RequireAnchor.IsPresent+'|'+$Anchor)
    if($script:CommittedBlobCache.ContainsKey($cacheKey)){return $script:CommittedBlobCache[$cacheKey]}
    $resolved = Invoke-GitText -Root $Root -Arguments @('rev-parse', "$Commit^{commit}") -AllowFailure
    if ($resolved.ExitCode -cne 0 -or $resolved.Text -cne $Commit) { throw "commit '$Commit' does not resolve exactly" }
    $tree = Invoke-GitText -Root $Root -Arguments @('ls-tree', $Commit, '--', $Path) -AllowFailure
    if ($tree.ExitCode -cne 0 -or -not $tree.Text) { throw "path '$Path' is absent at commit '$Commit'" }
    $parts = $tree.Text -split "`t", 2
    if ($parts.Count -cne 2 -or $parts[1] -cne $Path) { throw "path '$Path' has a case or identity mismatch at commit '$Commit'" }
    $meta = $parts[0] -split ' '
    if ($meta.Count -lt 3 -or $meta[1] -cne 'blob' -or $meta[0] -ceq '120000') { throw "path '$Path' is not a regular Git blob" }
    $blob = $meta[2]
    $bytes = Invoke-GitRawBytes -Root $Root -Arguments @('cat-file', 'blob', $blob)
    if ($RequireAnchor) {
        if (-not $Anchor) { throw 'owner reference anchor is required' }
        try { $text = $script:Utf8NoBom.GetString($bytes) } catch { throw "owner blob '$Path' is not strict UTF-8" }
        $count = 0; $offset = 0
        while (($index = $text.IndexOf($Anchor, $offset, [System.StringComparison]::Ordinal)) -ge 0) { $count++; $offset = $index + $Anchor.Length }
        if ($count -cne 1) { throw "anchor '$Anchor' occurs $count times in '$Path' (exactly one required)" }
    }
    $record=[pscustomobject]@{ Path = $Path; CommitOid = $Commit; BlobOid = $blob; Bytes = $bytes; RawSha256 = Get-Sha256Hex $bytes; ByteLength = $bytes.Length }
    $script:CommittedBlobCache[$cacheKey]=$record
    return $record
}

function Test-EvidenceAgainstSchema {
    param($Evidence, $Schema, [string]$Root, [switch]$ResolveReference)
    $errors = New-Object System.Collections.Generic.List[string]
    Test-ValueAgainstDefinition -Value $Evidence -Definition $Schema -RootSchema $Schema -Path '$' -Errors $errors
    if ($errors.Count -ceq 0 -and $Evidence.evidence_id -cne ('evd_sha256_' + $Evidence.raw_sha256)) { $errors.Add('evidence_id is not derived from raw_sha256') }
    if ($errors.Count -ceq 0 -and $ResolveReference) {
        try {
            $blob = Get-CommittedBlobRecord -Root $Root -Commit $Evidence.commit_oid -Path $Evidence.path
            if ($blob.BlobOid -cne $Evidence.blob_oid) { $errors.Add('evidence blob_oid mismatch') }
            if ($blob.RawSha256 -cne $Evidence.raw_sha256) { $errors.Add('evidence raw_sha256 mismatch') }
            if ($blob.ByteLength -cne [long]$Evidence.byte_length) { $errors.Add('evidence byte_length mismatch') }
        } catch { $errors.Add($_.Exception.Message) }
    }
    return $errors.ToArray()
}

function Test-OwnerReference {
    param($Owner, [string]$Root)
    $errors = New-Object System.Collections.Generic.List[string]
    try {
        $blob = Get-CommittedBlobRecord -Root $Root -Commit $Owner.commit_oid -Path $Owner.path -Anchor $Owner.anchor -RequireAnchor
        if ($blob.BlobOid -cne $Owner.blob_oid) { $errors.Add('owner blob_oid mismatch') }
        if ($blob.RawSha256 -cne $Owner.raw_sha256) { $errors.Add('owner raw_sha256 mismatch') }
    } catch { $errors.Add($_.Exception.Message) }
    return $errors.ToArray()
}

function Split-JsonlBytes {
    param([byte[]]$Bytes, [string]$Path, [int]$MaxLineBytes)
    $lines = New-Object System.Collections.Generic.List[object]
    $fileErrors = New-Object System.Collections.Generic.List[object]
    if ($Bytes.Length -ceq 0) { return [pscustomobject]@{ Lines = @(); Errors = @() } }
    if ($Bytes.Length -ge 3 -and $Bytes[0] -ceq 0xEF -and $Bytes[1] -ceq 0xBB -and $Bytes[2] -ceq 0xBF) { $fileErrors.Add([pscustomobject]@{ Path=$Path; Line=1; Code='bom'; Detail='UTF-8 BOM is forbidden' }) }
    if ($Bytes[$Bytes.Length - 1] -cne 0x0A) { $fileErrors.Add([pscustomobject]@{ Path=$Path; Line=0; Code='missing_final_lf'; Detail='non-empty JSONL must end with LF' }) }
    $start = 0; $lineNo = 1
    for ($i = 0; $i -lt $Bytes.Length; $i++) {
        if ($Bytes[$i] -cne 0x0A) { continue }
        $len = $i - $start
        $raw = New-Object byte[] $len
        if ($len -gt 0) { [System.Array]::Copy($Bytes, $start, $raw, 0, $len) }
        if ($len -ceq 0) { $fileErrors.Add([pscustomobject]@{ Path=$Path; Line=$lineNo; Code='blank_line'; Detail='blank JSONL line is forbidden' }) }
        if ($len -gt $MaxLineBytes) { $fileErrors.Add([pscustomobject]@{ Path=$Path; Line=$lineNo; Code='oversized_line'; Detail="line exceeds $MaxLineBytes bytes" }) }
        if ([System.Array]::IndexOf($raw, [byte]0x0D) -ge 0) { $fileErrors.Add([pscustomobject]@{ Path=$Path; Line=$lineNo; Code='crlf'; Detail='CR bytes are forbidden' }) }
        $lines.Add([pscustomobject]@{ Number=$lineNo; Bytes=$raw })
        $start = $i + 1; $lineNo++
    }
    return [pscustomobject]@{ Lines=$lines.ToArray(); Errors=$fileErrors.ToArray() }
}

function Read-JsonlRecords {
    param([byte[]]$Bytes, [string]$Path, $Schema, [ValidateSet('Event','Evidence')][string]$Kind, [string]$Root, [switch]$ResolveReferences, [switch]$RequireCanonical)
    $max = [int]$Schema.'x-ea-lab-rules'.line_max_bytes
    $split = Split-JsonlBytes -Bytes $Bytes -Path $Path -MaxLineBytes $max
    $errors = New-Object System.Collections.Generic.List[object]
    foreach ($e in $split.Errors) { $errors.Add($e) }
    $records = New-Object System.Collections.Generic.List[object]
    $goodIds = New-Object System.Collections.Generic.List[string]
    foreach ($line in $split.Lines) {
        if ($line.Bytes.Length -ceq 0 -or $line.Bytes.Length -gt $max -or [System.Array]::IndexOf($line.Bytes, [byte]0x0D) -ge 0) { continue }
        try { $obj = ConvertFrom-StrictJsonBytes -Bytes $line.Bytes -Context "$Path line $($line.Number)" }
        catch { $errors.Add([pscustomobject]@{ Path=$Path; Line=$line.Number; Code='json_invalid'; Detail=$_.Exception.Message }); continue }
        $validation = if ($Kind -ceq 'Event') { @(Test-EventAgainstSchema -Event $obj -Schema $Schema) } else { @(Test-EvidenceAgainstSchema -Evidence $obj -Schema $Schema -Root $Root -ResolveReference:$ResolveReferences) }
        if ($validation.Count -gt 0) { $errors.Add([pscustomobject]@{ Path=$Path; Line=$line.Number; Code='schema_invalid'; Detail=($validation -join '; ') }); continue }
        $canonical = ConvertTo-CanonicalJsonBytes -Object $obj -Schema $Schema
        if ($RequireCanonical -and -not (Test-ByteArrayEqual $canonical $line.Bytes)) { $errors.Add([pscustomobject]@{ Path=$Path; Line=$line.Number; Code='noncanonical'; Detail='line is not compact fixed-order canonical JSON' }); continue }
        $id = if ($Kind -ceq 'Event') { [string]$obj.event_id } else { [string]$obj.evidence_id }
        $goodIds.Add($id)
        $records.Add([pscustomobject]@{ Object=$obj; Bytes=$line.Bytes; Sha256=(Get-Sha256Hex $line.Bytes); Path=$Path; Line=$line.Number })
    }
    return [pscustomobject]@{ Records=$records.ToArray(); Errors=$errors.ToArray(); GoodIds=$goodIds.ToArray() }
}

function Get-LiveSnapshotBytes {
    param([string]$Root)
    $dir = Join-Path $Root 'docs\memory_control\experiment_events'
    $events = @{}
    if (Test-Path $dir) {
        foreach ($file in @(Get-ChildItem -LiteralPath $dir -File -Filter 'events-*.jsonl' | Sort-Object Name)) {
            if ($file.Name -cnotmatch '^events-[0-9]{4}-(0[1-9]|1[0-2])\.jsonl$') { continue }
            $events[('docs/memory_control/experiment_events/' + $file.Name)] = [System.IO.File]::ReadAllBytes($file.FullName)
        }
    }
    $manifestPath = Join-Path $dir 'evidence-manifest.jsonl'
    $manifest = if (Test-Path $manifestPath) { [System.IO.File]::ReadAllBytes($manifestPath) } else { New-Object byte[] 0 }
    return [pscustomobject]@{ EventFiles=$events; ManifestBytes=$manifest }
}

function Invoke-ValidateEventSnapshot {
    param([hashtable]$EventFiles, [byte[]]$ManifestBytes, $EventSchema, $EvidenceSchema, [string]$Root, [switch]$ResolveReferences)
    $errors = New-Object System.Collections.Generic.List[object]
    $manifestRead = Read-JsonlRecords -Bytes $ManifestBytes -Path 'docs/memory_control/experiment_events/evidence-manifest.jsonl' -Schema $EvidenceSchema -Kind Evidence -Root $Root -ResolveReferences:$ResolveReferences -RequireCanonical
    foreach ($e in $manifestRead.Errors) { $errors.Add($e) }
    $evidenceById = @{}; $evidenceHashSet = @{}
    foreach ($record in $manifestRead.Records) {
        $id = [string]$record.Object.evidence_id
        if ($evidenceById.ContainsKey($id)) { $errors.Add([pscustomobject]@{ Path=$record.Path; Line=$record.Line; Code='duplicate_evidence_id'; Detail="duplicate evidence ID '$id'" }) }
        else { $evidenceById[$id]=$record; $evidenceHashSet[[string]$record.Object.raw_sha256]=$true }
    }
    $allRecords = New-Object System.Collections.Generic.List[object]
    $goodIds = New-Object System.Collections.Generic.List[string]
    foreach ($path in @($EventFiles.Keys | Sort-Object)) {
        if ($path -cnotmatch '^docs/memory_control/experiment_events/events-([0-9]{4}-(0[1-9]|1[0-2]))\.jsonl$') { $errors.Add([pscustomobject]@{Path=$path;Line=0;Code='bad_filename';Detail='event filename is not events-YYYY-MM.jsonl'}); continue }
        $month = $Matches[1]
        $read = Read-JsonlRecords -Bytes $EventFiles[$path] -Path $path -Schema $EventSchema -Kind Event -Root $Root -RequireCanonical
        foreach ($e in $read.Errors) { $errors.Add($e) }
        foreach ($id in $read.GoodIds) { $goodIds.Add($id) }
        foreach ($record in $read.Records) {
            if ([string]$record.Object.timestamp_utc -cnotmatch ('^' + [regex]::Escape($month))) { $errors.Add([pscustomobject]@{Path=$path;Line=$record.Line;Code='month_mismatch';Detail='event timestamp does not match monthly filename'}) }
            $allRecords.Add($record)
        }
    }
    $eventById=@{}; $tailByExp=@{}; $coreIndexByExp=@{}; $tombstoned=@{}
    $core=@($EventSchema.'x-ea-lab-rules'.core_lifecycle)
    foreach ($record in $allRecords) {
        $event=$record.Object; $id=[string]$event.event_id; $exp=[string]$event.experiment_id; $type=[string]$event.event_type
        if ($eventById.ContainsKey($id)) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='duplicate_event_id';Detail="duplicate event ID '$id'"}); continue }
        $eventById[$id]=$record
        if ($type -ceq 'IDEA_CREATED') {
            if ($tailByExp.ContainsKey($exp)) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='duplicate_experiment_id';Detail="duplicate IDEA_CREATED for '$exp'"}) }
            $tailByExp[$exp]=$record; $coreIndexByExp[$exp]=1
        } else {
            if (-not $tailByExp.ContainsKey($exp)) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='missing_prior';Detail="experiment '$exp' has no preceding IDEA_CREATED"}) }
            else {
                $tail=$tailByExp[$exp]
                if ($event.prior_event_id -ceq $id) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='self_link';Detail='event links to itself'}) }
                elseif (-not $eventById.ContainsKey([string]$event.prior_event_id)) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='missing_prior';Detail="prior event '$($event.prior_event_id)' is missing or forward"}) }
                elseif ($eventById[[string]$event.prior_event_id].Object.experiment_id -cne $exp) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='cross_experiment_prior';Detail='prior event belongs to another experiment'}) }
                elseif ($tail.Object.event_id -cne $event.prior_event_id) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='stale_prior';Detail='prior event is not the experiment tail'}) }
                elseif ($tail.Sha256 -cne $event.prior_event_sha256) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='wrong_prior_hash';Detail='prior_event_sha256 mismatch'}) }
                $tailByExp[$exp]=$record
            }
            $corePos=[array]::IndexOf($core,$type)
            if ($corePos -ge 0) {
                $expected = if ($coreIndexByExp.ContainsKey($exp)) { [int]$coreIndexByExp[$exp] } else { 0 }
                if ($corePos -cne $expected) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='lifecycle';Detail="out-of-order or duplicate core event '$type'"}) }
                else { $coreIndexByExp[$exp]=$expected+1 }
            }
        }
        foreach ($evd in @($event.evidence_ids)) { if (-not $evidenceById.ContainsKey([string]$evd)) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='dangling_evidence';Detail="evidence '$evd' is absent from manifest"}) } }
        foreach ($hash in @($event.artifact_hashes.ea,$event.artifact_hashes.source,$event.artifact_hashes.set,$event.artifact_hashes.data,$event.artifact_hashes.tester)) { if ($null -cne $hash -and -not $evidenceHashSet.ContainsKey([string]$hash)) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='dangling_artifact_hash';Detail="artifact hash '$hash' is absent from durable manifest"}) } }
        if ($ResolveReferences) {
            foreach ($owner in @($event.owner_refs)) { foreach ($detail in @(Test-OwnerReference -Owner $owner -Root $Root)) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='owner_reference';Detail=$detail}) } }
        }
        if ($type -cin @('AMENDMENT_ADDED','TOMBSTONE_ADDED')) {
            $target=[string]$event.target_event_id
            if (-not $eventById.ContainsKey($target) -or $target -ceq $id) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='bad_target';Detail="target '$target' is missing, forward, or self"}) }
            else {
                $targetRecord=$eventById[$target]
                if ($targetRecord.Object.experiment_id -cne $exp) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='bad_target';Detail='target belongs to another experiment'}) }
                if ($targetRecord.Sha256 -cne $event.target_event_sha256) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='bad_target_hash';Detail='target_event_sha256 mismatch'}) }
            }
            if ($type -ceq 'TOMBSTONE_ADDED') {
                if ($tombstoned.ContainsKey($target)) { $errors.Add([pscustomobject]@{Path=$record.Path;Line=$record.Line;Code='double_tombstone';Detail="target '$target' was already tombstoned"}) } else { $tombstoned[$target]=$true }
            }
        }
    }
    return [pscustomobject]@{ IsValid=($errors.Count -ceq 0); Errors=$errors.ToArray(); Events=$allRecords.ToArray(); Evidence=$manifestRead.Records; GoodEventIds=$goodIds.ToArray(); EventById=$eventById; TailByExperiment=$tailByExp }
}

function Get-PrivateGitPath {
    param([string]$Root, [string]$Name)
    $r=Invoke-GitText -Root $Root -Arguments @('rev-parse','--git-path',$Name)
    if ([System.IO.Path]::IsPathRooted($r.Text)) { return [System.IO.Path]::GetFullPath($r.Text) }
    return [System.IO.Path]::GetFullPath((Join-Path $Root $r.Text))
}

function Enter-EventLock {
    param([string]$Root,[int]$TimeoutSeconds)
    $path=Get-PrivateGitPath -Root $Root -Name 'ea-lab-experiment-events.lock'
    $parent=Split-Path -Parent $path
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $watch=[System.Diagnostics.Stopwatch]::StartNew(); $waits=0; $random=New-Object System.Random
    while ($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        try {
            $stream=[System.IO.File]::Open($path,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
            return [pscustomobject]@{Stream=$stream;Path=$path;WaitCount=$waits}
        } catch [System.IO.IOException] {
            $waits++; Start-Sleep -Milliseconds (50 + $random.Next(0,26))
        }
    }
    Throw-EventLogError 'lock_timeout' "exclusive event lock timed out after $TimeoutSeconds seconds"
}

function Remove-UtilityOrphanTemps {
    param([string]$Root)
    $dir=Join-Path $Root 'docs\memory_control\experiment_events'
    if (-not (Test-Path $dir)) { return }
    foreach($file in @(Get-ChildItem -LiteralPath $dir -File -Filter '.ea-lab-events-tmp-*.tmp')) {
        if ($file.Name -cmatch '^\.ea-lab-events-tmp-[0-9a-f]{32}\.tmp$') { Remove-Item -LiteralPath $file.FullName -Force }
    }
    foreach($file in @(Get-ChildItem -LiteralPath $dir -File -Filter '.ea-lab-events-backup-*.tmp')) {
        if ($file.Name -cmatch '^\.ea-lab-events-backup-[0-9a-f]{32}\.tmp$') { Remove-Item -LiteralPath $file.FullName -Force }
    }
}

function Install-AtomicBytes {
    param([string]$Target,[byte[]]$Bytes,[string]$FaultPoint)
    $dir=Split-Path -Parent $Target
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $temp=Join-Path $dir ('.ea-lab-events-tmp-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup=Join-Path $dir ('.ea-lab-events-backup-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $fs=[System.IO.File]::Open($temp,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None)
        try {
            if ($FaultPoint -ceq 'before_temp_flush') { throw 'TEST-FAULT:before_temp_flush' }
            $fs.Write($Bytes,0,$Bytes.Length); $fs.Flush($true)
            if ($FaultPoint -ceq 'after_temp_flush_before_replace') { throw 'TEST-FAULT:after_temp_flush_before_replace' }
        } finally { $fs.Dispose() }
        if (Test-Path -LiteralPath $Target) { [System.IO.File]::Replace($temp,$Target,$backup) } else { [System.IO.File]::Move($temp,$Target) }
        if ($FaultPoint -ceq 'after_replace') { throw 'TEST-FAULT:after_replace' }
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue }
    }
}

function Join-LineToFileBytes {
    param([byte[]]$Existing,[byte[]]$Line)
    $result=New-Object byte[] ($Existing.Length+$Line.Length+1)
    if($Existing.Length -gt 0){[array]::Copy($Existing,0,$result,0,$Existing.Length)}
    [array]::Copy($Line,0,$result,$Existing.Length,$Line.Length); $result[$result.Length-1]=0x0A
    return $result
}

function Get-UtilityUtcNow {
    param([string]$Override,[string]$Root)
    if ($Override) {
        if ($env:EA_LAB_EVENT_TEST_MODE -cne '1') { Throw-EventLogError 'schema_invalid' 'test clock is disabled outside EA_LAB_EVENT_TEST_MODE=1' }
        $tempRoot=[System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
        if (-not ([System.IO.Path]::GetFullPath($Root).StartsWith($tempRoot,[System.StringComparison]::OrdinalIgnoreCase))) { Throw-EventLogError 'schema_invalid' 'test clock is permitted only in a TEMP repository' }
        $parsed=Test-TimestampExact $Override
        if(-not $parsed.IsValid){Throw-EventLogError 'schema_invalid' 'invalid test UTC clock value'}
        return $parsed.Value
    }
    return [datetime]::UtcNow
}

function Format-UtilityTimestamp {
    param([datetime]$Value)
    return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ',[System.Globalization.CultureInfo]::InvariantCulture)
}

function Read-RequestObject {
    param([string]$Path,[int]$MaxBytes,[string]$Context)
    if(-not $Path -or -not (Test-Path -LiteralPath $Path)){Throw-EventLogError 'schema_invalid' "$Context path is missing"}
    $bytes=[System.IO.File]::ReadAllBytes($Path)
    if($bytes.Length -gt $MaxBytes){Throw-EventLogError 'schema_invalid' "$Context exceeds $MaxBytes bytes"}
    try{return ConvertFrom-StrictJsonBytes -Bytes $bytes -Context $Context}catch{Throw-EventLogError 'schema_invalid' $_.Exception.Message}
}

function New-EvidenceRecord {
    param([string]$Root,[string]$Path,[string]$Commit,[string]$Type,$EvidenceSchema)
    if(-not $Type){Throw-EventLogError 'schema_invalid' 'MediaType is required'}
    try{
        if($Commit -ceq 'HEAD'){$fullCommit=(Invoke-GitText -Root $Root -Arguments @('rev-parse','HEAD^{commit}')).Text}
        elseif($Commit -cmatch '^[0-9a-f]{40}$'){$fullCommit=$Commit}
        else{throw 'commit OID input must be HEAD or a full lowercase 40-hex object ID'}
        $blob=Get-CommittedBlobRecord -Root $Root -Commit $fullCommit -Path $Path
    }catch{Throw-EventLogError 'reference_invalid' $_.Exception.Message}
    $record=[pscustomobject][ordered]@{schema_version=1;evidence_id=('evd_sha256_'+$blob.RawSha256);path=$Path;commit_oid=$blob.CommitOid;blob_oid=$blob.BlobOid;raw_sha256=$blob.RawSha256;byte_length=[long]$blob.ByteLength;media_type=$Type}
    $problems=@(Test-EvidenceAgainstSchema -Evidence $record -Schema $EvidenceSchema -Root $Root -ResolveReference)
    if($problems.Count -gt 0){Throw-EventLogError 'reference_invalid' ($problems -join '; ')}
    return $record
}

function Add-EvidenceUnderLock {
    param([string]$Root,$Record,$Schemas,$Snapshot,[string]$FaultPoint)
    $manifestPath=Join-Path $Root 'docs\memory_control\experiment_events\evidence-manifest.jsonl'
    $line=ConvertTo-CanonicalJsonBytes -Object $Record -Schema $Schemas.Evidence
    foreach($existing in $Snapshot.Evidence){
        if($existing.Object.evidence_id -ceq $Record.evidence_id){
            if(Test-ByteArrayEqual $existing.Bytes $line){return [pscustomobject]@{Status='already_appended';Snapshot=$Snapshot}}
            Throw-EventLogError 'reference_invalid' "evidence ID '$($Record.evidence_id)' already has a different canonical locator"
        }
    }
    $live=Get-LiveSnapshotBytes -Root $Root
    $candidate=Join-LineToFileBytes -Existing $live.ManifestBytes -Line $line
    Install-AtomicBytes -Target $manifestPath -Bytes $candidate -FaultPoint $(if($FaultPoint -ceq 'after_manifest_install_before_event_install'){''}else{$FaultPoint})
    $live2=Get-LiveSnapshotBytes -Root $Root
    $manifestRead=Read-JsonlRecords -Bytes $live2.ManifestBytes -Path 'docs/memory_control/experiment_events/evidence-manifest.jsonl' -Schema $Schemas.Evidence -Kind Evidence -Root $Root -ResolveReferences -RequireCanonical
    if($manifestRead.Errors.Count -gt 0){Throw-EventLogError 'integrity_corrupt' ('manifest installation produced invalid manifest: '+(($manifestRead.Errors|ForEach-Object{$_.Detail}) -join '; '))}
    # Preserve the caller's event diagnostic state. Physical-recovery workflow
    # must be able to register quarantined corrupt bytes while normal event
    # append remains blocked by those event errors.
    $updated=[pscustomobject]@{IsValid=$Snapshot.IsValid;Errors=$Snapshot.Errors;Events=$Snapshot.Events;Evidence=$manifestRead.Records;GoodEventIds=$Snapshot.GoodEventIds;EventById=$Snapshot.EventById;TailByExperiment=$Snapshot.TailByExperiment}
    return [pscustomobject]@{Status='appended';Snapshot=$updated}
}

function Test-DisabledSentinel {
    param([string]$Root)
    return Test-Path -LiteralPath (Get-PrivateGitPath -Root $Root -Name 'ea-lab-experiment-events.disabled')
}

function Assert-AuthorizedControl {
    param([string]$ControlActor,[string]$ControlRole)
    if(-not (($ControlActor -ceq 'user' -and $ControlRole -ceq 'owner') -or ($ControlActor -ceq 'claude' -and $ControlRole -ceq 'lead_judge'))){Throw-EventLogError 'reference_invalid' 'control operation requires user/owner or claude/lead_judge'}
}

function Assert-ControlAuthorizationReference {
    param([string]$Root,[string]$Path)
    $auth=Read-RequestObject -Path $Path -MaxBytes 4096 -Context 'control authorization reference'
    $problems=@(Test-OwnerReference -Owner $auth -Root $Root)
    if($auth.owner_type -cne 'recovery_authorization' -or $problems.Count -gt 0){Throw-EventLogError 'reference_invalid' ('invalid control authorization reference: '+($problems -join '; '))}
    return $auth
}

function Add-TimestampToRequest {
    param($Request,[string]$Timestamp,$EventSchema)
    if(Test-HasProperty $Request 'timestamp_utc'){Throw-EventLogError 'schema_invalid' 'caller-supplied timestamp_utc is forbidden'}
    $values=[ordered]@{}
    foreach($name in @($EventSchema.'x-ea-lab-rules'.canonical_order)){
        if($name -ceq 'timestamp_utc'){$values[$name]=$Timestamp}
        elseif(Test-HasProperty $Request $name){$values[$name]=Get-PropertyValue $Request $name}
    }
    foreach($name in @(Get-ObjectPropertyNames $Request)){if(-not $values.Contains($name)){$values[$name]=Get-PropertyValue $Request $name}}
    return [pscustomobject]$values
}

function Assert-AppendCandidate {
    param($Event,$Schemas,$Snapshot,[string]$Root)
    $problems=@(Test-EventAgainstSchema -Event $Event -Schema $Schemas.Event)
    if($problems.Count -gt 0){Throw-EventLogError 'schema_invalid' ($problems -join '; ')}
    foreach($owner in @($Event.owner_refs)){ $refProblems=@(Test-OwnerReference -Owner $owner -Root $Root); if($refProblems.Count -gt 0){Throw-EventLogError 'reference_invalid' ($refProblems -join '; ')} }
    foreach($evd in @($Event.evidence_ids)){if(-not @($Snapshot.Evidence|Where-Object{$_.Object.evidence_id -ceq $evd}).Count){Throw-EventLogError 'reference_invalid' "evidence '$evd' is not registered"}}
    foreach($hash in @($Event.artifact_hashes.ea,$Event.artifact_hashes.source,$Event.artifact_hashes.set,$Event.artifact_hashes.data,$Event.artifact_hashes.tester)){if($null -cne $hash -and -not @($Snapshot.Evidence|Where-Object{$_.Object.raw_sha256 -ceq $hash}).Count){Throw-EventLogError 'reference_invalid' "artifact hash '$hash' is not registered"}}
}

function Assert-RecoveryPreservesTarget {
    # The recovered target file must keep every independently-valid event of the
    # current target file, in order (no omit/reorder). Shared by the fresh and the
    # interrupted-resume recovery paths so both enforce identical preservation.
    param($Snapshot,$Base,[string]$TargetRel)
    $verifiedCurrent=@($Snapshot.Events|Where-Object{$_.Path -ceq $TargetRel})
    $candidateEvents=@($Base.Events|Where-Object{$_.Path -ceq $TargetRel})
    $cursor=0
    foreach($verified in $verifiedCurrent){
        $found=$false
        while($cursor -lt $candidateEvents.Count){
            if(Test-ByteArrayEqual $verified.Bytes $candidateEvents[$cursor].Bytes){$found=$true;$cursor++;break}
            $cursor++
        }
        if(-not $found){Throw-EventLogError 'reference_invalid' "recovery candidate omits or reorders independently verified event '$($verified.Object.event_id)'"}
    }
}

function Add-EventUnderLock {
    param([string]$Root,$Request,$Schemas,$Snapshot,[datetime]$Now,[string]$FaultPoint)
    $existing=@($Snapshot.Events|Where-Object{$_.Object.event_id -ceq $Request.event_id})
    if($existing.Count -gt 0){
        $retry=Add-TimestampToRequest -Request $Request -Timestamp $existing[0].Object.timestamp_utc -EventSchema $Schemas.Event
        $retryProblems=@(Test-EventAgainstSchema -Event $retry -Schema $Schemas.Event)
        if($retryProblems.Count -ceq 0){$retryBytes=ConvertTo-CanonicalJsonBytes -Object $retry -Schema $Schemas.Event;if(Test-ByteArrayEqual $retryBytes $existing[0].Bytes){return [pscustomobject]@{Status='already_appended';Event=$existing[0].Object}}}
        Throw-EventLogError 'event_id_conflict' "event ID '$($Request.event_id)' already exists with different canonical payload"
    }
    $timestamp=Format-UtilityTimestamp $Now
    if($Snapshot.Events.Count -gt 0){
        $latest=@($Snapshot.Events|Sort-Object {$_.Object.timestamp_utc} -Descending)[0].Object.timestamp_utc
        if($timestamp -lt $latest){Throw-EventLogError 'clock_skew' "utility clock '$timestamp' is earlier than latest event '$latest'"}
    }
    $event=Add-TimestampToRequest -Request $Request -Timestamp $timestamp -EventSchema $Schemas.Event
    Assert-AppendCandidate -Event $event -Schemas $Schemas -Snapshot $Snapshot -Root $Root
    $line=ConvertTo-CanonicalJsonBytes -Object $event -Schema $Schemas.Event
    if($line.Length -gt [int]$Schemas.Event.'x-ea-lab-rules'.line_max_bytes){Throw-EventLogError 'schema_invalid' 'canonical event line exceeds size cap'}
    $month=$timestamp.Substring(0,7)
    $latestMonth=$null
    $live=Get-LiveSnapshotBytes -Root $Root
    if($live.EventFiles.Count -gt 0){$latestMonth=@($live.EventFiles.Keys|ForEach-Object{if($_ -cmatch 'events-([0-9]{4}-[0-9]{2})\.jsonl$'){$Matches[1]}}|Sort-Object -Descending)[0]}
    if($latestMonth -and $month -lt $latestMonth){Throw-EventLogError 'clock_skew' "month '$month' would reopen closed month '$latestMonth'"}
    $rel='docs/memory_control/experiment_events/events-'+$month+'.jsonl'
    $existingBytes=if($live.EventFiles.ContainsKey($rel)){$live.EventFiles[$rel]}else{New-Object byte[] 0}
    $candidate=Join-LineToFileBytes -Existing $existingBytes -Line $line
    $candidateMap=@{};foreach($k in $live.EventFiles.Keys){$candidateMap[$k]=$live.EventFiles[$k]};$candidateMap[$rel]=$candidate
    $validation=Invoke-ValidateEventSnapshot -EventFiles $candidateMap -ManifestBytes $live.ManifestBytes -EventSchema $Schemas.Event -EvidenceSchema $Schemas.Evidence -Root $Root -ResolveReferences
    if(-not $validation.IsValid){
        $codes=@($validation.Errors|ForEach-Object{$_.Code})
        $status=if($codes -ccontains 'stale_prior'){'stale_prior'}elseif(@($codes|Where-Object{$_ -cmatch 'prior|lifecycle|target|experiment'}).Count -gt 0){'stale_prior'}elseif(@($codes|Where-Object{$_ -cmatch 'evidence|owner|artifact'}).Count -gt 0){'reference_invalid'}else{'schema_invalid'}
        Throw-EventLogError $status (($validation.Errors|ForEach-Object{"$($_.Path):$($_.Line) $($_.Detail)"}) -join '; ')
    }
    $target=Join-Path $Root ($rel -replace '/','\')
    Install-AtomicBytes -Target $target -Bytes $candidate -FaultPoint $FaultPoint
    return [pscustomobject]@{Status='appended';Event=$event}
}

function Invoke-EventUtilityMain {
    $root=Resolve-RepositoryRoot -RequestedRoot $RepoRoot
    if($Command -ceq 'NewEventId'){Write-MachineStatus -Status 'appended' -Operation 'new_event_id' -Details ([ordered]@{event_id=('evt_'+[guid]::NewGuid().ToString().ToLowerInvariant());experiment_id=('exp_'+[guid]::NewGuid().ToString().ToLowerInvariant())});return 0}
    $schemas=Get-SchemaObjects -Root $root
    $lock=$null
    try{
        $lock=Enter-EventLock -Root $root -TimeoutSeconds $LockTimeoutSeconds
        Remove-UtilityOrphanTemps -Root $root
        if($Command -cnotin @('Enable','Scan','Disable','Recover') -and (Test-DisabledSentinel -Root $root)){Throw-EventLogError 'disabled' 'event utility is disabled'}
        $live=Get-LiveSnapshotBytes -Root $root
        $snapshot=Invoke-ValidateEventSnapshot -EventFiles $live.EventFiles -ManifestBytes $live.ManifestBytes -EventSchema $schemas.Event -EvidenceSchema $schemas.Evidence -Root $root -ResolveReferences
        if($Command -ceq 'Scan'){
            if(-not $snapshot.IsValid){Write-MachineStatus -Status 'integrity_corrupt' -Operation 'scan' -LockWaitCount $lock.WaitCount -Details ([ordered]@{bad_lines=@($snapshot.Errors);good_event_ids=@($snapshot.GoodEventIds)});return 1}
            $details=[ordered]@{event_count=$snapshot.Events.Count;evidence_count=$snapshot.Evidence.Count;good_event_ids=@($snapshot.GoodEventIds)}
            if($ValidatedSnapshotDir){
                if(Test-Path -LiteralPath $ValidatedSnapshotDir){if((Get-ChildItem -LiteralPath $ValidatedSnapshotDir -Force|Measure-Object).Count){Throw-EventLogError 'integrity_corrupt' 'validated snapshot directory must be empty'}}else{New-Item -ItemType Directory -Force -Path $ValidatedSnapshotDir|Out-Null}
                $files=@();foreach($rel in @($live.EventFiles.Keys|Sort-Object)+@('evidence-manifest.jsonl')){$bytes=if($rel -ceq 'evidence-manifest.jsonl'){$live.ManifestBytes}else{$live.EventFiles[$rel]};$dest=Join-Path $ValidatedSnapshotDir $rel;New-Item -ItemType Directory -Force -Path (Split-Path $dest)|Out-Null;[IO.File]::WriteAllBytes($dest,$bytes);$files+=[ordered]@{path=$rel;byte_length=$bytes.Length;sha256=(Get-BytesSha256 $bytes)}}
                $mb=[Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $files -Compress));[IO.File]::WriteAllBytes((Join-Path $ValidatedSnapshotDir 'validated-snapshot-manifest.json'),$mb);$details.validated_snapshot=[ordered]@{manifest_sha256=(Get-BytesSha256 $mb);file_count=$files.Count}
            }
            Write-MachineStatus -Status 'appended' -Operation 'scan' -LockWaitCount $lock.WaitCount -Details $details;return 0
        }
        if($Command -ceq 'Disable'){
            Assert-AuthorizedControl -ControlActor $Actor -ControlRole $Role
            [void](Assert-ControlAuthorizationReference -Root $root -Path $AuthorizationRefJsonPath)
            $sentinel=Get-PrivateGitPath -Root $root -Name 'ea-lab-experiment-events.disabled'
            if(Test-Path $sentinel){Write-MachineStatus -Status 'already_appended' -Operation 'disable' -LockWaitCount $lock.WaitCount;return 0}
            $bytes=$script:Utf8NoBom.GetBytes(("disabled_by={0}/{1}`nutc={2}`nauthorization_ref={3}`n" -f $Actor,$Role,(Format-UtilityTimestamp ([datetime]::UtcNow)),$AuthorizationRefJsonPath))
            $fs=[System.IO.File]::Open($sentinel,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None);try{$fs.Write($bytes,0,$bytes.Length);$fs.Flush($true)}finally{$fs.Dispose()}
            Write-MachineStatus -Status 'appended' -Operation 'disable' -LockWaitCount $lock.WaitCount;return 0
        }
        if($Command -ceq 'Enable'){
            Assert-AuthorizedControl -ControlActor $Actor -ControlRole $Role
            [void](Assert-ControlAuthorizationReference -Root $root -Path $AuthorizationRefJsonPath)
            $sentinel=Get-PrivateGitPath -Root $root -Name 'ea-lab-experiment-events.disabled'
            if(-not (Test-Path $sentinel)){Write-MachineStatus -Status 'already_appended' -Operation 'enable' -LockWaitCount $lock.WaitCount;return 0}
            Remove-Item -LiteralPath $sentinel -Force
            Write-MachineStatus -Status 'appended' -Operation 'enable' -LockWaitCount $lock.WaitCount;return 0
        }
        if($Command -ceq 'RegisterEvidence'){
            $manifestErrors=@($snapshot.Errors|Where-Object{$_.Path -ceq 'docs/memory_control/experiment_events/evidence-manifest.jsonl'})
            if($manifestErrors.Count -gt 0){Throw-EventLogError 'integrity_corrupt' 'existing evidence manifest is invalid'}
            $record=New-EvidenceRecord -Root $root -Path $ArtifactPath -Commit $CommitOid -Type $MediaType -EvidenceSchema $schemas.Evidence
            $added=Add-EvidenceUnderLock -Root $root -Record $record -Schemas $schemas -Snapshot $snapshot -FaultPoint $TestFaultPoint
            Write-MachineStatus -Status $added.Status -Operation 'register_evidence' -LockWaitCount $lock.WaitCount -Details $record;return 0
        }
        if($Command -ceq 'Append'){
            if(-not $snapshot.IsValid){Throw-EventLogError 'integrity_corrupt' (($snapshot.Errors|ForEach-Object{"$($_.Path):$($_.Line) $($_.Detail)"}) -join '; ')}
            $request=Read-RequestObject -Path $EventJsonPath -MaxBytes 32768 -Context 'event request'
            # physical_recovery events are produced ONLY by the Recover command, which
            # enforces disabled state + authorization + quarantine binding. A normal
            # Append must never mint one, or those preconditions are avoidable
            # (review round 2 finding 1).
            if([string]$request.reason_code -ceq 'physical_recovery'){Throw-EventLogError 'schema_invalid' 'physical_recovery reason_code is only valid through the Recover command'}
            if(Test-HasProperty $request 'recovery_target_month'){Throw-EventLogError 'schema_invalid' 'recovery_target_month is only valid through the Recover command'}
            if($RegisterEvidencePath){
                $record=New-EvidenceRecord -Root $root -Path $RegisterEvidencePath -Commit $RegisterEvidenceCommitOid -Type $RegisterEvidenceMediaType -EvidenceSchema $schemas.Evidence
                $added=Add-EvidenceUnderLock -Root $root -Record $record -Schemas $schemas -Snapshot $snapshot -FaultPoint ''
                $snapshot=$added.Snapshot
                if($TestFaultPoint -ceq 'after_manifest_install_before_event_install'){throw 'TEST-FAULT:after_manifest_install_before_event_install'}
            }
            $now=Get-UtilityUtcNow -Override $TestUtcNow -Root $root
            $addedEvent=Add-EventUnderLock -Root $root -Request $request -Schemas $schemas -Snapshot $snapshot -Now $now -FaultPoint $TestFaultPoint
            Write-MachineStatus -Status $addedEvent.Status -Operation 'append' -LockWaitCount $lock.WaitCount -Details ([ordered]@{event_id=$addedEvent.Event.event_id;experiment_id=$addedEvent.Event.experiment_id;timestamp_utc=$addedEvent.Event.timestamp_utc});return 0
        }
        if($Command -ceq 'Recover'){
            # Recovery is a small state machine keyed on the target month. Exactly ONE
            # recovery occurrence may exist per target month (pinned #27/#30). The FIRST
            # Recover mints the occurrence; the same stable event_id may retry it
            # (completed = idempotent, interrupted = resume); a byte-different retry or a
            # second event_id for the same target is a conflict. This keeps the utility's
            # accepted states exactly congruent with what the staged checker will commit.
            Assert-AuthorizedControl -ControlActor $Actor -ControlRole $Role
            if(-not (Test-DisabledSentinel -Root $root)){Throw-EventLogError 'reference_invalid' 'physical recovery requires logging to be disabled until authorized re-enable'}
            if(-not $RecoveryMonth -or $RecoveryMonth -cnotmatch '^[0-9]{4}-(0[1-9]|1[0-2])$'){Throw-EventLogError 'schema_invalid' 'RecoveryMonth must be YYYY-MM'}
            [void](Assert-ControlAuthorizationReference -Root $root -Path $AuthorizationRefJsonPath)
            if(-not $RecoveryFilePath -or -not (Test-Path $RecoveryFilePath)){Throw-EventLogError 'reference_invalid' 'recovery candidate file is missing'}
            $recovered=[System.IO.File]::ReadAllBytes($RecoveryFilePath)
            $rel='docs/memory_control/experiment_events/events-'+$RecoveryMonth+'.jsonl'
            if(-not $live.EventFiles.ContainsKey($rel)){Throw-EventLogError 'reference_invalid' 'recovery target month does not exist in the current snapshot'}
            $request=Read-RequestObject -Path $EventJsonPath -MaxBytes 32768 -Context 'recovery event request'
            $recoveriesForTarget=@($snapshot.Events|Where-Object{[string]$_.Object.reason_code -ceq 'physical_recovery' -and [string]$_.Object.recovery_target_month -ceq $RecoveryMonth})
            if($recoveriesForTarget.Count -ge 1){
                # A recovery occurrence for this target already exists.
                $recordedRecovery=$recoveriesForTarget[0]
                if([string]$recordedRecovery.Object.event_id -cne [string]$request.event_id){
                    # ...under a DIFFERENT event id. A second occurrence is a state the
                    # staged checker rejects ("exactly one recovery event") -- reject it
                    # here too (review round 5 finding 2).
                    Throw-EventLogError 'event_id_conflict' "a recovery occurrence for month '$RecoveryMonth' already exists under a different event id"
                }
                # Same target + same event id: classify by byte-identity (pinned #15).
                $retryRecord=Add-TimestampToRequest -Request $request -Timestamp $recordedRecovery.Object.timestamp_utc -EventSchema $schemas.Event
                if(@(Test-EventAgainstSchema -Event $retryRecord -Schema $schemas.Event).Count -cne 0 -or -not (Test-ByteArrayEqual (ConvertTo-CanonicalJsonBytes -Object $retryRecord -Schema $schemas.Event) $recordedRecovery.Bytes)){Throw-EventLogError 'event_id_conflict' "recovery event ID '$($request.event_id)' already exists with a different payload"}
                if($snapshot.IsValid){
                    # COMPLETED: occurrence recorded (byte-identical request) AND the live
                    # snapshot already validates -> the transaction finished; idempotent
                    # success, NO mutation. Completion is judged from the LIVE state alone,
                    # never from the retry's candidate file -- otherwise a retry carrying a
                    # different-but-valid candidate would fall into the resume path and
                    # reinstall a completed target (review round 6 finding 1; the
                    # after_replace fault leaves exactly this completed state, round 5).
                    Write-MachineStatus -Status 'already_appended' -Operation 'recover' -LockWaitCount $lock.WaitCount -Details ([ordered]@{event_id=$request.event_id;target_month=$RecoveryMonth;resumed=$true});return 0
                }
                # INTERRUPTED: occurrence recorded, target not yet restored -> finish the
                # target install only (record installed first, target second; review round 2).
                $candidateMap=@{};foreach($k in $live.EventFiles.Keys){$candidateMap[$k]=$live.EventFiles[$k]};$candidateMap[$rel]=$recovered
                $resumeBase=Invoke-ValidateEventSnapshot -EventFiles $candidateMap -ManifestBytes $live.ManifestBytes -EventSchema $schemas.Event -EvidenceSchema $schemas.Evidence -Root $root -ResolveReferences
                if(-not $resumeBase.IsValid){Throw-EventLogError 'reference_invalid' ('resumed recovery transaction is invalid: '+(($resumeBase.Errors|ForEach-Object{$_.Detail}) -join '; '))}
                Assert-RecoveryPreservesTarget -Snapshot $snapshot -Base $resumeBase -TargetRel $rel
                Install-AtomicBytes -Target (Join-Path $root ($rel -replace '/','\')) -Bytes $recovered -FaultPoint $TestFaultPoint
                Write-MachineStatus -Status 'appended' -Operation 'recover' -LockWaitCount $lock.WaitCount -Details ([ordered]@{event_id=$request.event_id;target_month=$RecoveryMonth;event_month=($recordedRecovery.Path -replace '^.*events-|\.jsonl$','');resumed=$true});return 0
            }
            # No recovery occurrence for this target yet. The event_id must be new (pinned
            # #15: a collision with any other recorded event is a conflict).
            if(@($snapshot.Events|Where-Object{[string]$_.Object.event_id -ceq [string]$request.event_id}).Count -ge 1){Throw-EventLogError 'event_id_conflict' "event ID '$($request.event_id)' already exists and is not a recovery occurrence for month '$RecoveryMonth'"}
            # FRESH recovery: requires an integrity-corrupt current state + quarantine.
            if($snapshot.IsValid){Throw-EventLogError 'reference_invalid' 'physical recovery requires an integrity-corrupt current state'}
            $quarantine=@($snapshot.Evidence|Where-Object{$_.Object.evidence_id -ceq $QuarantineEvidenceId})
            if($quarantine.Count -cne 1){Throw-EventLogError 'reference_invalid' 'quarantined-byte evidence is not registered uniquely'}
            $corruptHash=Get-Sha256Hex $live.EventFiles[$rel]
            if($quarantine[0].Object.raw_sha256 -cne $corruptHash -or [long]$quarantine[0].Object.byte_length -cne [long]$live.EventFiles[$rel].Length){Throw-EventLogError 'reference_invalid' 'quarantined-byte evidence does not identify the corrupt monthly file bytes'}
            $candidateMap=@{};foreach($k in $live.EventFiles.Keys){$candidateMap[$k]=$live.EventFiles[$k]};$candidateMap[$rel]=$recovered
            $base=Invoke-ValidateEventSnapshot -EventFiles $candidateMap -ManifestBytes $live.ManifestBytes -EventSchema $schemas.Event -EvidenceSchema $schemas.Evidence -Root $root -ResolveReferences
            if(-not $base.IsValid){Throw-EventLogError 'reference_invalid' ('recovery candidate is invalid: '+(($base.Errors|ForEach-Object{$_.Detail}) -join '; '))}
            Assert-RecoveryPreservesTarget -Snapshot $snapshot -Base $base -TargetRel $rel
            if($request.reason_code -cne 'physical_recovery' -or $request.recovery_target_month -cne $RecoveryMonth -or -not (@($request.evidence_ids) -ccontains $QuarantineEvidenceId) -or -not @($request.owner_refs|Where-Object{$_.owner_type -ceq 'recovery_authorization'}).Count){Throw-EventLogError 'reference_invalid' 'recovery event must carry the target month and link authorization plus quarantine evidence'}
            $now=Get-UtilityUtcNow -Override $TestUtcNow -Root $root
            $timestamp=Format-UtilityTimestamp $now
            $latestRecordedTimestamp=$null
            if($base.Events.Count -gt 0){$latestRecordedTimestamp=@($base.Events|Sort-Object {$_.Object.timestamp_utc} -Descending)[0].Object.timestamp_utc}
            if($latestRecordedTimestamp -and $timestamp -lt $latestRecordedTimestamp){Throw-EventLogError 'clock_skew' "utility clock '$timestamp' is earlier than latest event '$latestRecordedTimestamp'"}
            $eventMonth=$timestamp.Substring(0,7)
            $latestExistingMonth=@($candidateMap.Keys|ForEach-Object{if($_ -cmatch 'events-([0-9]{4}-[0-9]{2})\.jsonl$'){$Matches[1]}}|Sort-Object -Descending)[0]
            if($latestExistingMonth -and $eventMonth -lt $latestExistingMonth){Throw-EventLogError 'clock_skew' "recovery event month '$eventMonth' would reopen month before '$latestExistingMonth'"}
            $final=Add-TimestampToRequest -Request $request -Timestamp $timestamp -EventSchema $schemas.Event
            Assert-AppendCandidate -Event $final -Schemas $schemas -Snapshot $base -Root $root
            $line=ConvertTo-CanonicalJsonBytes -Object $final -Schema $schemas.Event
            $eventRel='docs/memory_control/experiment_events/events-'+$eventMonth+'.jsonl'
            $eventExisting=if($eventRel -ceq $rel){$recovered}elseif($candidateMap.ContainsKey($eventRel)){$candidateMap[$eventRel]}else{New-Object byte[] 0}
            $eventFinalBytes=Join-LineToFileBytes -Existing $eventExisting -Line $line
            $candidateMap[$eventRel]=$eventFinalBytes
            $finalValidation=Invoke-ValidateEventSnapshot -EventFiles $candidateMap -ManifestBytes $live.ManifestBytes -EventSchema $schemas.Event -EvidenceSchema $schemas.Evidence -Root $root -ResolveReferences
            if(-not $finalValidation.IsValid){Throw-EventLogError 'reference_invalid' ('final recovery transaction is invalid: '+(($finalValidation.Errors|ForEach-Object{$_.Detail}) -join '; '))}
            if($eventRel -ceq $rel){
                # Same-month recovery: one atomic single-file install (record + rewrite together).
                Install-AtomicBytes -Target (Join-Path $root ($rel -replace '/','\')) -Bytes $eventFinalBytes -FaultPoint $TestFaultPoint
            } else {
                # Two-file recovery: install the RECORD (event month) first so the recovery
                # occurrence is durable, then rewrite the target month. A fault before the
                # second install leaves a corrupt target + a present record -> the resume
                # path above completes it on retry; the recovery is never silently lost.
                Install-AtomicBytes -Target (Join-Path $root ($eventRel -replace '/','\')) -Bytes $eventFinalBytes -FaultPoint ''
                Install-AtomicBytes -Target (Join-Path $root ($rel -replace '/','\')) -Bytes $recovered -FaultPoint $TestFaultPoint
            }
            Write-MachineStatus -Status 'appended' -Operation 'recover' -LockWaitCount $lock.WaitCount -Details ([ordered]@{event_id=$final.event_id;target_month=$RecoveryMonth;event_month=$eventMonth});return 0
        }
        Throw-EventLogError 'schema_invalid' "unsupported command '$Command'"
    } catch {
        $status=if($_.Exception.Data.Contains('EventStatus')){[string]$_.Exception.Data['EventStatus']}else{'integrity_corrupt'}
        if(-not ($script:StatusNames -ccontains $status)){$status='integrity_corrupt'}
        $waitCount=if($lock){$lock.WaitCount}else{0}
        Write-MachineStatus -Status $status -Operation $Command.ToLowerInvariant() -LockWaitCount $waitCount -Details ([ordered]@{message=$_.Exception.Message})
        return 1
    } finally {if($lock -and $lock.Stream){$lock.Stream.Dispose()}}
}

if($MyInvocation.InvocationName -cne '.'){
    $exitCode=Invoke-EventUtilityMain
    exit $exitCode
}
