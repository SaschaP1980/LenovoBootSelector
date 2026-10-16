#requires -version 5.1
# LBS-140: single-instance activation channel. No device/firmware privileges.
function Get-LbsActivationName {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($sid -notmatch '^S-1-[0-9-]+$') { throw 'Invalid current user SID for activation channel.' }
    return ('Local\LenovoBootSelector-Activate-' + $sid)
}

function New-LbsActivationEvent {
    param([string]$Name = (Get-LbsActivationName))
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $security = New-Object System.Security.AccessControl.EventWaitHandleSecurity
    $rights = [System.Security.AccessControl.EventWaitHandleRights]::Synchronize -bor
              [System.Security.AccessControl.EventWaitHandleRights]::Modify
    $rule = [System.Security.AccessControl.EventWaitHandleAccessRule]::new(
        $sid,$rights,[System.Security.AccessControl.AccessControlType]::Allow)
    $security.AddAccessRule($rule)
    $created = $false
    $event = [System.Threading.EventWaitHandle]::new(
        $false,[System.Threading.EventResetMode]::AutoReset,$Name,[ref]$created,$security)
    if (-not $created) {
        $event.Dispose()
        throw 'Activation channel already exists; refusing to adopt an unknown owner.'
    }
    return $event
}

function Send-LbsActivationRequest {
    param([string]$Name = (Get-LbsActivationName),[int]$RetryMs = 3000)
    if ($RetryMs -lt 0 -or $RetryMs -gt 10000) { throw 'Invalid activation retry interval.' }
    $deadline = [Diagnostics.Stopwatch]::StartNew()
    do {
        $event = $null
        try {
            $event = [System.Threading.EventWaitHandle]::OpenExisting(
                $Name,[System.Security.AccessControl.EventWaitHandleRights]::Modify)
            return [bool]$event.Set()
        }
        catch [System.Threading.WaitHandleCannotBeOpenedException] {
            # The mutex owner can still be setting up its signal channel.
        }
        catch [System.UnauthorizedAccessException] {
            # No cross-user/session control or broadened permissions.
            return $false
        }
        catch {
            return $false
        }
        finally {
            if ($event) { $event.Dispose() }
        }
        if ($deadline.ElapsedMilliseconds -ge $RetryMs) { return $false }
        Start-Sleep -Milliseconds 75
    } while ($true)
}

function Start-LbsActivationListener {
    param(
        [Parameter(Mandatory=$true)][System.Threading.EventWaitHandle]$Signal,
        [Parameter(Mandatory=$true)][scriptblock]$OnActivate
    )
    # The wait uses ThreadPool, not a polling timer. The callback executes on
    # the WinForms UI thread via BeginInvoke, never inside the thread-pool worker.
    if (-not ('LenovoBootSelectorActivationWaiter' -as [type])) {
        Add-Type -ReferencedAssemblies @('System.Windows.Forms.dll') -TypeDefinition @'
using System;
using System.Threading;
using System.Windows.Forms;
public sealed class LenovoBootSelectorActivationWaiter : IDisposable {
    private readonly Control host;
    private readonly Action onActivate;
    private readonly RegisteredWaitHandle registration;
    private bool disposed;
    public LenovoBootSelectorActivationWaiter(EventWaitHandle signal, Control control, Action action) {
        if (signal == null || control == null || action == null || !control.IsHandleCreated)
            throw new ArgumentException("Activation callback requires a live WinForms UI handle.");
        host = control; onActivate = action;
        registration = ThreadPool.RegisterWaitForSingleObject(signal,
            delegate(object state, bool timedOut) {
                if (disposed || host.IsDisposed || !host.IsHandleCreated) return;
                try { host.BeginInvoke(onActivate); }
                catch (ObjectDisposedException) { }
                catch (InvalidOperationException) { }
            }, null, Timeout.Infinite, false);
    }
    public void Dispose() {
        disposed = true;
        if (registration != null) registration.Unregister(null);
    }
}
'@
    }
    $hostControl = New-Object System.Windows.Forms.Control
    try {
        [void]$hostControl.Handle
        $callback = [System.Action]$OnActivate
        $waiter = [LenovoBootSelectorActivationWaiter]::new($Signal,$hostControl,$callback)
        return [pscustomobject]@{ Waiter = $waiter; Host = $hostControl }
    }
    catch {
        $hostControl.Dispose()
        throw
    }
}

function Stop-LbsActivationListener {
    param($Listener)
    if (-not $Listener) { return }
    try { $Listener.Waiter.Dispose() } finally { $Listener.Host.Dispose() }
}
