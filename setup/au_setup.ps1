if ($PSVersionTable.PSVersion.Major -lt 7) {
  Throw "Only supported on PowerShell 7"
  Exit 1
}

$refreshenv = Get-Command refreshenv -ea SilentlyContinue
if ($refreshenv -ne $null -and $refreshenv.CommandType -ne 'Application') {
  refreshenv # You need the Chocolatey profile installed for this to work properly (Choco v0.9.10.0+).
} else {
  Write-Warning "We detected that you do not have the Chocolatey PowerShell profile installed, which is necessary for 'refreshenv' to work in PowerShell."
}

Write-Host "Installing au module..."
Install-Module au -Scope CurrentUser -Force -ErrorAction 'Stop' -Confirm:$false

Write-Host "Module installed."
Get-Module au -ListAvailable | ForEach-Object {
  Write-Host "Name: $($_.Name)  Version: $($_.Version)" -ForegroundColor Green
}
