# Loads the real interaction types for isolated fixtures that do not compile
# the complete embedded WinForms source. Never execute application startup.
if (-not ('LenovoInteractionPalette' -as [type])) {
    $interactionTemplate = [IO.File]::ReadAllText((Join-Path (Split-Path -Parent $PSScriptRoot) 'src\App\LenovoBootSelector.template.ps1'))
    $interactionStart = $interactionTemplate.IndexOf('public static class LenovoInteractionPalette',[StringComparison]::Ordinal)
    $interactionEnd = $interactionTemplate.IndexOf('public sealed class LenovoMenuRenderer',$interactionStart,[StringComparison]::Ordinal)
    if ($interactionStart -lt 0 -or $interactionEnd -le $interactionStart) { throw 'Canonical interaction types missing' }
    Add-Type -TypeDefinition ('using System; using System.Drawing; using System.Windows.Forms;' + [Environment]::NewLine + $interactionTemplate.Substring($interactionStart,$interactionEnd-$interactionStart)) -ReferencedAssemblies System.Windows.Forms,System.Drawing,Accessibility -ErrorAction Stop
}
