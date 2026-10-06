function Save-RuntimeDiagnosticsFromUi {
    try {
        $path = Export-RuntimeDiagnosticPackage -Reason 'manual-ui'
        $revealPath = $path
        $revealAction = { Show-DiagnosticPackageInExplorer -Path $revealPath }.GetNewClosure()
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.SavedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.SavedHeading') -Message (Get-LocalizedString -Key 'Diagnostics.Location' -Values @{ Path=$path }) -Kind Info -SecondaryButtonText (Get-LocalizedString -Key 'Diagnostics.ShowFolder') -SecondaryAction $revealAction
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_EXPORT_FAILED' -Stage 'diagnostics' -Success $false -ErrorRecord $_ -Level error
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.NotSavedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.NotSavedHeading') -Message (Get-LocalizedString -Key 'Common.TryAgain') -Kind Error
    }
}
