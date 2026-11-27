#requires -version 5.1
# Native raster and presentation contracts; synthetic layout scale and forced
# system-color renderer branch, not physical monitor or OS theme switching.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'Import-LenovoInteractionTestTypes.ps1')
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\UI\MaintenancePresentation.ps1')
$script:checks=0
function Assert-Lbs274([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS274 FAIL: $Name" }
    $script:checks++
    Write-Host "PASS LBS274 $Name"
}
$palette=[ordered]@{Success='#81B895';Warning='#EAB65E';Error='#F05D55';Info='#78A9E3';Busy='#B8C2CE';Unknown='#999999'}
function Get-Lbs274Raster([Drawing.Bitmap]$Bitmap,[Drawing.Color]$Background) {
    $left=$Bitmap.Width; $top=$Bitmap.Height; $right=-1; $bottom=-1
    $ink=0
    $signature=New-Object System.Text.StringBuilder
    for ($y=0;$y -lt $Bitmap.Height;$y++) {
        for ($x=0;$x -lt $Bitmap.Width;$x++) {
            $p=$Bitmap.GetPixel($x,$y)
            $delta=[Math]::Max([Math]::Abs([int]$p.R-[int]$Background.R),[Math]::Max([Math]::Abs([int]$p.G-[int]$Background.G),[Math]::Abs([int]$p.B-[int]$Background.B)))
            if ($delta -ge 35) {
                $ink++;$left=[Math]::Min($left,$x);$right=[Math]::Max($right,$x);$top=[Math]::Min($top,$y);$bottom=[Math]::Max($bottom,$y)
                [void]$signature.Append('1')
            } else { [void]$signature.Append('0') }
        }
    }
    return [pscustomobject]@{Ink=$ink;Left=$left;Top=$top;Right=$right;Bottom=$bottom;Shape=$signature.ToString()}
}
function Get-LocalizedString {
    param([string]$Key,$Values)
    Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values
}
function Get-CurrentSystemFunctionsCapabilities {
    [pscustomobject]@{State=$script:MaintenanceFixture;IsReady=($script:MaintenanceFixture -eq 'Ready');IsChecking=($script:MaintenanceFixture -eq 'Checking');CanConfigureSystemFunctions=$true}
}
function Get-MaintenanceMode { 'Setup' }
function Test-BootTargetDriftHasNewTargets { $false }
function Update-HeaderRefreshStatus {}
$script:ColorBackground=[Drawing.Color]::FromArgb(31,31,31)
$script:ColorPrimary=[Drawing.Color]::White
$script:ColorSecondary=[Drawing.Color]::FromArgb(184,184,184)
$script:ColorAccent=[Drawing.Color]::FromArgb(225,37,27)
foreach ($locale in @('de-DE','en-US')) {
    $script:Locale=$locale
    foreach ($scale in @(1.0,2.5)) {
        foreach ($size in @(16,24,40)) {
            foreach ($hc in @($false,$true)) {
                $shapes=@{}
                $hostSize=$size+8
                $physical=[int][Math]::Round($hostSize*$scale)
                foreach ($name in $palette.Keys) {
                    $kind=[LenovoStatusKind]$name
                    $expected=[Drawing.ColorTranslator]::FromHtml($palette[$name])
                    if ($hc) { $expected=[Drawing.SystemColors]::WindowText }
                    $bg=if ($hc) { [Drawing.SystemColors]::Window } else { $script:ColorBackground }
                    $label=[LenovoStatusIcon]::new($kind,$size,$hostSize)
                    $label.Size=[Drawing.Size]::new($physical,$physical)
                    $label.BackColor=$bg
                    $label.AccessibleName=Get-LocalizedString -Key 'SystemStatus.Unknown'
                    $label.AccessibleDescription=$label.AccessibleName
                    $bmp=[Drawing.Bitmap]::new($physical,$physical)
                    $graphics=[Drawing.Graphics]::FromImage($bmp)
                    try {
                        $graphics.Clear($bg)
                        [LenovoStatusIconRenderer]::Draw($graphics,$label.ClientRectangle,$size,[single]$scale,$kind,$hc)
                        $graphics.Dispose()
                        $graphics=$null
                        $raster=Get-Lbs274Raster $bmp $bg
                        $center=($physical-1)/2.0
                        $tolerance=[Math]::Max(2.0,2.0*$scale)
                        $tag="$locale/$scale/$size/$hc/$name"
                        Assert-Lbs274 "$tag exact semantic ink, bounded centered native raster" (
                            [LenovoStatusIconRenderer]::Ink($kind,$hc).ToArgb() -eq $expected.ToArgb() -and
                            $raster.Ink -gt 6 -and $raster.Left -gt 0 -and $raster.Top -gt 0 -and
                            $raster.Right -lt ($physical-1) -and $raster.Bottom -lt ($physical-1) -and
                            [Math]::Abs(($raster.Left+$raster.Right)/2.0-$center) -le $tolerance -and
                            [Math]::Abs(($raster.Top+$raster.Bottom)/2.0-$center) -le $tolerance)
                        Assert-Lbs274 "$tag accessible non-action control with correct kind and no legacy text" (
                            $label.Kind -eq $kind -and $label.DesignSize -eq $size -and
                            -not $label.TabStop -and $label.AccessibleRole -eq [Windows.Forms.AccessibleRole]::StaticText -and
                            $label.AccessibleName -and $label.AccessibleDescription -and $label.Text -eq '')
                        if ($hc -eq [Windows.Forms.SystemInformation]::HighContrast) {
                            $actual=[Drawing.Bitmap]::new($physical,$physical)
                            try {
                                $label.DrawToBitmap($actual,$label.ClientRectangle)
                                $paint=Get-Lbs274Raster $actual $bg
                                if ($paint.Shape -ne $raster.Shape) { throw "LBS274 actual control raster differs from renderer: $tag" }
                            } finally { $actual.Dispose() }
                        }
                        $shapes[$raster.Shape]=$true
                    } finally {
                        if ($graphics) { $graphics.Dispose() }
                        $bmp.Dispose()
                        $label.Dispose()
                    }
                }
                Assert-Lbs274 "$locale/$scale/$size/$hc all six shapes distinct without color" ($shapes.Count -eq 6)
            }
        }
        $script:Popup=New-Object Windows.Forms.Form
        $script:Popup.ClientSize=[Drawing.Size]::new(390,652)
        try {
            $panel=New-MaintenanceStatePanel
            $script:Popup.Controls.Add($panel)
            $glyph=$panel.Controls['MaintenanceGlyph']
            $expectedStates=[ordered]@{SetupRequired='Warning';RepairRequired='Warning';Unknown='Unknown';ReinitializeRequired='Info';Busy='Busy'}
            foreach ($state in $expectedStates.Keys) {
                $script:MaintenanceFixture=$state
                Update-MaintenanceUi
                Assert-Lbs274 "$locale/$scale maintenance $state semantic mapping" (
                    $glyph -is [LenovoStatusIcon] -and $glyph.Kind -eq [LenovoStatusKind]$expectedStates[$state] -and
                    $glyph.DesignSize -eq 40 -and $glyph.AccessibleName -and $glyph.AccessibleDescription -and
                    $panel.Controls['MaintenancePrimaryButton'].Enabled -eq ($state -ne 'Busy'))
            }
        } finally { $script:Popup.Dispose();$script:Popup=$null }
    }
}
Write-Host "LBS274 STATUS ICONS TOTAL $script:checks/332"
if ($script:checks -ne 332) { throw "Expected 332 native status assertions, got $script:checks" }
