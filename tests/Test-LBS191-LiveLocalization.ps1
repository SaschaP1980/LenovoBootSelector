#requires -version 5.1
# LBS-191: live localization uses existing boot facts, not a hardware refresh.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Add-Type -AssemblyName System.Drawing
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\Core\BootTargetModel.ps1')
. (Join-Path $root 'src\Application\LocalizationService.ps1')
. (Join-Path $root 'src\UI\LanguagePresentation.ps1')

# Extract the real application adapters without launching the application.
$template = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($template,[ref]$tokens,[ref]$errors)
if ($errors.Count -gt 0) { throw 'Canonical application template parse failure' }
foreach ($name in @('Get-FriendlyBootEntry','Get-FirmwareBootState','Get-EntryByGuid','Apply-FirmwareBootState')) {
    $node = $ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
    if (-not $node) { throw "Missing canonical adapter: $name" }
    . ([scriptblock]::Create($node.Extent.Text))
}
foreach ($name in @('ColorAccent','ColorBlue','ColorWarning','ColorPurple','ColorCyan','ColorSecondary')) {
    Set-Variable -Scope Script -Name $name -Value ([Drawing.Color]::Red)
}

$script:checks = 0
function Assert-Lbs191([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS191 RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS191 $Name"
}

$script:UiLocale = 'de-DE'
$script:Saved = 0
$script:Paints = 0
$script:SnapshotReads = 0
$script:AllowSnapshot = $false
$script:Popup = $null
$script:PaintedEntries = @()
function Save-AppSettings { $script:Saved++ }
function New-PopupForm {
    $form = [pscustomobject]@{ Visible=$false; IsDisposed=$false }
    $form | Add-Member ScriptMethod Hide { $this.Visible=$false }
    $form | Add-Member ScriptMethod Dispose { $this.IsDisposed=$true }
    return $form
}
function Update-AutostartUi {}
function Update-MaintenanceUi {}
function Update-ManageEntriesUiState {}
function Update-PopupRows {
    param([string]$Reason)
    $script:Paints++
    $script:PaintedEntries = @($script:CurrentEntries)
}
function Get-StorageContext { throw 'Unexpected hardware storage acquisition during localization test' }
function Start-BackgroundBootRefresh { throw 'Unexpected worker start during localization test' }
function Get-BootServiceFirmwareSnapshot {
    param([switch]$UseExistingCache,[switch]$ForceManagerRefresh)
    if (-not $script:AllowSnapshot -or -not $UseExistingCache -or $ForceManagerRefresh) { throw 'Unexpected firmware acquisition during locale switch' }
    $script:SnapshotReads++
    return $script:FixtureSnapshot
}
function Write-RuntimeDiagnosticEvent {
    param($Event,$Stage,$Success)
}
function Get-CurrentSystemFunctionsCapabilities { return [pscustomobject]@{ CanUseCachedBootState=$false } }
function Get-EntryDisplayTitle {
    param($Entry)
    return [string]$Entry.Title
}

$guids = @(
    '{11111111-1111-1111-1111-111111111111}',
    '{22222222-2222-2222-2222-222222222222}',
    '{33333333-3333-3333-3333-333333333333}',
    '{44444444-4444-4444-4444-444444444444}',
    '{55555555-5555-5555-5555-555555555555}',
    '{66666666-6666-6666-6666-666666666666}'
)
$raws = @('Boot Menu','NVMe0','NVMe1','USB HDD','Vendor raw firmware name','')
$descriptions = @{}
for ($i=0; $i -lt $guids.Count; $i++) { $descriptions[$guids[$i]] = $raws[$i] }
$script:FixtureSnapshot = [pscustomobject]@{
    Descriptions=$descriptions
    ManagerState=[pscustomobject]@{ DisplayOrder=$guids; SelectedGuid=$guids[1] }
}
$oldStorage = [pscustomobject]@{
    Disks=@([pscustomobject]@{ BusType='NVMe'; Model='Original SSD model' })
    UsbResolution='SingleBootCandidate'; UsbResolutionReason='fixture-original'
    UsbBootCandidates=@([pscustomobject]@{ Model='Original USB model' })
    UsbDisks=@([pscustomobject]@{ Model='Original USB model' })
}
$newStorage = [pscustomobject]@{
    Disks=@(); UsbResolution='Unavailable'; UsbResolutionReason='fixture-later'
    UsbBootCandidates=@(); UsbDisks=@()
}
$script:StorageContext = $oldStorage
$script:AllowSnapshot = $true
$initial = Get-FirmwareBootState -UseExistingCache
$script:AllowSnapshot = $false
$script:CurrentEntries = @($initial.Entries)
$script:SelectedGuid = $guids[1]
$script:BootNextPendingGuid = $guids[3]
$script:NextBootFirmwareReadVerified = $true
$script:DefaultGuid = $guids[0]
$script:EntryAliases = @{ $guids[1]='My custom alias' }
$script:EntryOrder = @($guids)
$script:HiddenEntryGuids = @($guids[2])
$script:IsManageEntriesMode = $true
$script:ManageEntryOrder = @($guids[3],$guids[0],$guids[1],$guids[2],$guids[4],$guids[5])
$script:ManageHiddenEntryGuids = @($guids[5])
$script:ManageEntryAliases = @{ $guids[1]='Unsaved alias' }
$script:ManageAliasEditGuid = $null

function Get-StateSignature {
    ConvertTo-Json -Compress -Depth 5 -InputObject ([ordered]@{
        Selected=$script:SelectedGuid; Pending=$script:BootNextPendingGuid
        Verified=$script:NextBootFirmwareReadVerified; Default=$script:DefaultGuid
        Order=$script:EntryOrder; Hidden=$script:HiddenEntryGuids; Aliases=$script:EntryAliases
        Manage=$script:IsManageEntriesMode; DraftOrder=$script:ManageEntryOrder
        DraftHidden=$script:ManageHiddenEntryGuids; DraftAliases=$script:ManageEntryAliases
    })
}
function Test-LocalizedEntries {
    param([object[]]$Entries,[string]$Locale,$Storage)
    if ($Entries.Count -ne $guids.Count) { return $false }
    for ($i=0; $i -lt $guids.Count; $i++) {
        $expected = Get-FriendlyBootEntryCore -Guid $guids[$i] -RawDescription $raws[$i] -StorageContext $Storage -Locale $Locale
        foreach ($field in @('Guid','Title','Subtitle','TypeTooltip','RawDescription','Symbol','Resolution','ResolutionReason')) {
            if ([string]$Entries[$i].$field -cne [string]$expected.$field) {
                Write-Host ("LBS191 mismatch {0} {1}: expected '{2}' got '{3}'" -f $Locale,$field,$expected.$field,$Entries[$i].$field)
                return $false
            }
        }
    }
    return $true
}

Assert-Lbs191 'canonical initial German projection contains existing hardware facts' (Test-LocalizedEntries -Entries $script:CurrentEntries -Locale 'de-DE' -Storage $oldStorage)
$signature = Get-StateSignature
# Model a newer storage result without replacing the displayed firmware state.
# A locale switch must not silently reinterpret the existing hardware evidence.
$script:StorageContext = $newStorage
[void](Set-LanguageFromUi -Locale 'en-US')
Assert-Lbs191 'DE to EN updates cached entry text before first rebuilt popup paint' (Test-LocalizedEntries -Entries $script:PaintedEntries -Locale 'en-US' -Storage $oldStorage)
Assert-Lbs191 'English current entries preserve original storage context and raw source' (Test-LocalizedEntries -Entries $script:CurrentEntries -Locale 'en-US' -Storage $oldStorage)
Assert-Lbs191 'language switch preserves selected pending default order hidden aliases and manage draft' ((Get-StateSignature) -ceq $signature)
Assert-Lbs191 'language switch performs no firmware snapshot read' ($script:SnapshotReads -eq 1)
[void](Set-LanguageFromUi -Locale 'de-DE')
Assert-Lbs191 'EN to DE relocalizes cached entries including empty raw description' (Test-LocalizedEntries -Entries $script:PaintedEntries -Locale 'de-DE' -Storage $oldStorage)
Assert-Lbs191 'second switch preserves boot and manage state' ((Get-StateSignature) -ceq $signature)
$paints = $script:Paints
[void](Set-LanguageFromUi -Locale 'de-DE')
Assert-Lbs191 'same locale does not recreate popup' ($script:Paints -eq $paints)
[void](Set-LanguageFromUi -Locale 'en-US')
# A refresh completed after the switch projects raw firmware and storage facts
# on the UI thread through the actual canonical active-locale adapter.
$script:AllowSnapshot = $true
$laterState = Get-FirmwareBootState -UseExistingCache
$script:AllowSnapshot = $false
Assert-Lbs191 'refresh projection uses current locale with new storage evidence' (Test-LocalizedEntries -Entries @($laterState.Entries) -Locale 'en-US' -Storage $newStorage)
Apply-FirmwareBootState -State $laterState -VerifiedFresh
Assert-Lbs191 'pending selection still defers incoming state' (Test-LocalizedEntries -Entries $script:CurrentEntries -Locale 'en-US' -Storage $oldStorage)
$script:BootNextPendingGuid = $null
Apply-FirmwareBootState -State $laterState -VerifiedFresh
Assert-Lbs191 'completed refresh replaces facts without reverting locale' (Test-LocalizedEntries -Entries $script:PaintedEntries -Locale 'en-US' -Storage $newStorage)
$script:CurrentEntries = @()
[void](Set-LanguageFromUi -Locale 'de-DE')
Assert-Lbs191 'empty cached entry list remains empty' ($script:CurrentEntries.Count -eq 0 -and $script:PaintedEntries.Count -eq 0)
Write-Host "LBS191 LIVE LOCALIZATION TOTAL $script:checks/12"
if ($script:checks -ne 12) { throw "Expected 12 LBS191 checks, got $script:checks" }
