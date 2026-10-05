function Save-RuntimeDiagnosticsFromUi {
    try {
        $path = Export-RuntimeDiagnosticPackage -Reason 'manual-ui'
        $revealPath = $path
        $revealAction = { Show-DiagnosticPackageInExplorer -Path $revealPath }.GetNewClosure()
        Show-LenovoNoticeDialog -Title 'Diagnose gespeichert' -Heading 'Das Diagnosepaket wurde erstellt.' -Message ("Speicherort:`r`n{0}" -f $path) -Kind Info -SecondaryButtonText 'Im Ordner anzeigen' -SecondaryAction $revealAction
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_EXPORT_FAILED' -Stage 'diagnostics' -Success $false -ErrorRecord $_ -Level error
        Show-LenovoNoticeDialog -Title 'Diagnose nicht gespeichert' -Heading 'Das Diagnosepaket konnte nicht erstellt werden.' -Message 'Bitte versuche es erneut.' -Kind Error
    }
}
