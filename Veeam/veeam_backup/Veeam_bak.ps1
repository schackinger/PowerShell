param(
    [ValidateSet("day", "week", "month")]
    $backupJob = "day"
)

#region Config
$guests = @(Get-Content -Path "C:\veeam_backup\$backupJob.txt")
$viServer = "VCENTER002000.avmb.local"
$destination = "v:\Backup\$backupJob"
$logFile = "C:\veeam_backup\log\$((Get-Date).ToString('yyyy-MM-dd HHmmss'))_$backupJob.txt"
$compressionLevel = 9
$enableQuiescence = $true
$retention = "Never"
#endregion Config

$logArray = @()
if (!(Get-PSSnapin -Name VeeamPSSnapin -ErrorAction SilentlyContinue)) {
    if (!(Add-PSSnapin -PassThru VeeamPSSnapin)) {
        # Error out if loading fails
        $logArray += "[ERROR] Cannot load the Veeam Snapin. Is the Veeam installed"
        $logArray >> "$logFile"
        Exit
    }
}

if (!($viServer = Get-VBRServer -name $viServer -ErrorAction SilentlyContinue)) {
    $logArray += "[ERROR] $($error[0]) "
    $logArray >> "$logFile"
    Exit    
} else {
    $logArray += "[SUCCESS] Connected to $($viServer.Name)"
}

foreach ($guest in $guests) {
    if (!($vm = Find-VBRViEntity -Name $guest -Server $viServer -ErrorAction SilentlyContinue)) {
        $logArray += "[ERROR] $guest : $($error[0])"
        continue
    } else {
        $logArray += "[INFO] Connected to $guest"
    }

    if (!($ZIPSession = Start-VBRZip -Entity $vm -Folder $destination -Compression $compressionLevel -DisableQuiesce:(!$enableQuiescence) -AutoDelete $retention -ErrorAction SilentlyContinue)) {
        $logArray += "[ERROR] $guest : $($error[0])"
        continue
    } else {
        $logArray += "[INFO] Starting Backup of $guest"
    }

    $TaskSessions = $ZIPSession.GetTaskSessions().logger.getlog().updatedrecords
    $FailedSessions =  $TaskSessions | where {$_.status -eq "EWarning" -or $_.Status -eq "EFailed"}
    
    if ($FailedSessions -ne $Null) {
        $info = ($ZIPSession | Select-Object @{n="Name";e={($_.name).Substring(0, $_.name.LastIndexOf("("))}} ,@{n="StartTime";e={$_.CreationTime}},@{n="EndTime";e={$_.EndTime}},Result,@{n="Details";e={$FailedSessions.Title}})
        $logArray += "[ERROR] VM $($info.Name)"
        $logArray += "[INFO] Start    : $($info.StartTime)"
        $logArray += "[INFO] End      : $($info.EndTime)"
        $logArray += "[INFO] Result   : $($info.Result)"
        $logArray += "[INFO] Details  : $($info.Details)"
    } else {
        $info = $($ZIPSession | Select-Object @{n="Name";e={($_.name).Substring(0, $_.name.LastIndexOf("("))}} ,@{n="StartTime";e={$_.CreationTime}},@{n="EndTime";e={$_.EndTime}},Result,@{n="Details";e={($TaskSessions | sort creationtime -Descending | select -first 1).Title}})
        $logArray += "[SUCCESS] $($info.Name)"
        $logArray += "[INFO] Start    : $($info.StartTime)"
        $logArray += "[INFO] End      : $($info.EndTime)"
        $logArray += "[INFO] Result   : $($info.Result)"
        $logArray += "[INFO] Details  : $($info.Details)"
    }
}

$logArray += "[INFO] Bakup Job Done..."
$logArray >> "$logFile" | Out-Null