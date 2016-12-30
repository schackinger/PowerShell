# Stop ServerManager process
Get-Process ServerManager | Stop-Process -Force -ErrorAction SilentlyContinue
# Get the XML server list
$file = Get-Item “$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\ServerManager\ServerList.xml”
# Backup the old server list
Copy-Item -Path $file -Destination "$file-$((Get-Date).ToString('yyyy-MM-dd'))_backup" -Force

$xml = [xml] (Get-Content $file )

# File with a server list (one record for each line, use FQDN)
$servers = Get-Content -Path "$env:USERPROFILE\Documents\Servers.txt"

# foreach that server that doesn't exist add it to the config
foreach ($server in $servers) {
    if (@($xml.ServerList.ServerInfo.name).Contains($server) -eq $false) {
        $newserver = @($xml.ServerList.ServerInfo)[0].clone()
        $newserver.name = $server.ToString()
        $newserver.lastUpdateTime = “0001-01-01T00:00:00”
        $newserver.status = “2”
        $xml.ServerList.AppendChild($newserver)
    }
}

# Save the config 
$xml.Save($file.FullName)

# Start Server Manager again
Start-Process -FilePath $env:SystemRoot\System32\ServerManager.exe –WindowStyle Maximized -ErrorAction SilentlyContinue