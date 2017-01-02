param($PackageVersion)

$ErrorActionPreference = 'Stop'

$packageDir = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ChildPath $PackageVersion
$templateDir = $PSScriptRoot
$tempDir = Join-Path -Path $templateDir -ChildPath 'temp'
$downloadDir = Join-Path -Path $templateDir -ChildPath 'download'

Write-Verbose "Using package directory $packageDir"

# Filesystem Init
If (Test-Path -Path $tempDir) {
  Write-Verbose "Cleaning temp area..."
  Remove-Item -Path $tempDir -Recurse -Force -Confirm:$false | Out-Null
}
New-Item -Path $tempDir -ItemType Directory | Out-Null
If (-not (Test-Path -Path $downloadDir)) {
  New-Item -Path $downloadDir -ItemType Directory | Out-Null
}

# Download artifacts
$portTgz = Join-Path -Path $downloadDir -ChildPath "portainer-${PackageVersion}.tgz"
$nssmZip = Join-Path -Path $downloadDir -ChildPath 'nssm.zip'
if (-not (Test-Path -Path $portTgz)) {
  Write-Verbose "Downloading portainer ${PackageVersion} ..."
  Invoke-WebRequest -Uri "https://github.com/portainer/portainer/releases/download/${PackageVersion}/portainer-${PackageVersion}-windows-amd64.tar.gz" -OutFile $portTgz | Out-Null
}
if (-not (Test-Path -Path $nssmZip)) {
  Write-Verbose "Downloading nssm..."
  Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile $nssmZip | Out-Null
}
