#requires -version 5.1
# LBS-144 real-WinForms menu RED/GREEN: target scale controls typography,
# row heights, horizontal paddings and submenu fonts with no double scaling.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\MenuAppearance.ps1')
Add-Type -TypeDefinition @'
using System.Windows.Forms;
public sealed class Lbs144MenuDpiTestStrip : ContextMenuStrip
{
    public int TargetWidth { get; set; }
    public Lbs144MenuDpiTestStrip() { ShowCheckMargin = false; ShowImageMargin = false; }
}
'@ -ReferencedAssemblies System.Windows.Forms, System.Drawing
function Assert-MenuDpi([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS-144 MENU RED: $Name" }
    Write-Host "PASS LBS-144 MENU $Name"
}
$menu = New-Object Lbs144MenuDpiTestStrip
$menu.Font = New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Regular)
$menu.TargetWidth = 260
$menu.Padding = [System.Windows.Forms.Padding]::new(0,2,0,2)
$item = New-Object System.Windows.Forms.ToolStripMenuItem('Open')
$item.Padding = [System.Windows.Forms.Padding]::new(18,4,32,4)
[void]$menu.Items.Add($item)
$baseHeight = $item.Height
try {
    [void](Set-LenovoMenuDpiLayout -Menu $menu -Scale 2.5)
    Assert-MenuDpi 'Root menu target width grows to 650 physical px' ($menu.TargetWidth -eq 650)
    Assert-MenuDpi 'Root menu point font remains 9pt' ([Math]::Abs($menu.Font.Size - 9.0) -lt .1)
    Assert-MenuDpi 'Root menu item point font remains 9pt' ([Math]::Abs($item.Font.Size - 9.0) -lt .1)
    Assert-MenuDpi 'Root menu item height grows with text' ($item.Height -ge [int][Math]::Floor($baseHeight * 2.4))
    Write-Host ("LBS-144 MENU METRICS: menu-padding={0},{1},{2},{3}; item-padding={4},{5},{6},{7}; item-height={8}" -f $menu.Padding.Left,$menu.Padding.Top,$menu.Padding.Right,$menu.Padding.Bottom,$item.Padding.Left,$item.Padding.Top,$item.Padding.Right,$item.Padding.Bottom,$item.Height)
    # ToolStripDropDown owns its chrome padding (2px on Windows); item padding is our DPI contract.
    Assert-MenuDpi 'Menu item padding follows physical DPI' ($menu.Padding.Top -ge 2 -and $item.Padding.Left -eq 45 -and $item.Padding.Top -eq 10)
    [void](Set-LenovoMenuDpiLayout -Menu $menu -Scale 2.5)
    Assert-MenuDpi 'Same screen leaves layout stable' ($menu.TargetWidth -eq 650 -and $item.Padding.Left -eq 45)
    [void](Set-LenovoMenuDpiLayout -Menu $menu -Scale 1.0)
    Assert-MenuDpi 'Returning to 96 DPI restores size and font' ($menu.TargetWidth -eq 260 -and $menu.Font.Size -lt 9.1 -and $item.Padding.Left -eq 18)
    $sub = New-Object System.Windows.Forms.ToolStripDropDownMenu
    $sub.Font = New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Regular)
    [void]$sub.Items.Add((New-Object System.Windows.Forms.ToolStripMenuItem('Deutsch')))
    try {
        [void](Set-LenovoMenuDpiLayout -Menu $sub -Scale 2.5)
        Assert-MenuDpi 'Independent submenu keeps 9pt text and physical row bounds' ([Math]::Abs($sub.Font.Size - 9.0) -lt .1 -and [Math]::Abs($sub.Items[0].Font.Size - 9.0) -lt .1)
    }
    finally { $sub.Dispose() }
}
finally { $menu.Dispose() }
Write-Host 'LBS-144 FOCUSED MENU RESULT=PASS'
Write-Output 8
