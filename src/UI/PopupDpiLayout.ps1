# LBS-144: a single 96-DPI logical layout contract for the tray popup.
# Static controls scale with the form; rows inserted later must scale once.
function Initialize-PopupDpiLayout {
    param([Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form)
    $Form.SuspendLayout()
    $Form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $Form.AutoScaleDimensions = [Drawing.SizeF]::new([single]96, [single]96)
}

function Complete-PopupDpiLayout {
    param([Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form)
    $Form.ResumeLayout($true)
}

function Get-PopupDpiLayoutScale {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Popup,
        [int]$DesignWidth = 390
    )
    if ($DesignWidth -le 0 -or $Popup.ClientSize.Width -le 0) {
        throw 'Popup layout width is not available.'
    }
    return ([double]$Popup.ClientSize.Width / [double]$DesignWidth)
}

function Set-PopupBootRowDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Row,
        [Parameter(Mandatory=$true)][double]$Scale,
        [Parameter(Mandatory=$true)][int]$Y
    )
    if ($Scale -le 0 -or $Scale -gt 5) { throw 'Invalid popup DPI scale.' }
    if ([Math]::Abs($Scale - 1.0) -gt 0.0001) {
        # Row children start at 96-DPI design coordinates even after popup
        # layout. Scale the whole row only once before inserting it.
        $factor = [single]$Scale
        $Row.Scale([Drawing.SizeF]::new($factor, $factor))
    }
    $Row.Location = [Drawing.Point]::new(0, $Y)
    return [int]$Row.Height
}
