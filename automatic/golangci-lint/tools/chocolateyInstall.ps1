$packageName = 'golangci-lint'
$url32       = 'https://github.com/golangci/golangci-lint/releases/download/v1.55.1/golangci-lint-1.55.1-windows-386.zip'
$url64       = 'https://github.com/golangci/golangci-lint/releases/download/v1.55.1/golangci-lint-1.55.1-windows-amd64.zip'
$checksum32  = 'aec36fb10bfc10d8c645364911e8380aab56e07dcebd03f92c0e38b52004590e'
$checksum64  = '3a92f369cf8402ea163436e5550a8c03ba536b5a0e76e0ab145208abeb14b938'
$zipFolder32 = 'golangci-lint-1.55.1-windows-386'
$zipFolder64 = 'golangci-lint-1.55.1-windows-amd64'
$installDir = Split-Path $MyInvocation.MyCommand.Definition

$zipFolder = $zipFolder64
if ([System.IntPtr]::Size -eq 4) {
  Write-Host "Using 32bit Folder"
  $zipFolder = $zipFolder32
} else {
  Write-Host "Using 64bit Folder"
}

$packageArgs = @{
  packageName    = $packageName
  url            = $url32
  url64bit       = $url64
  UnzipLocation  = $installDir
  SpecificFolder = $zipFolder
  checksum       = $checksum32
  checksum64     = $checksum64
  checksumType   = 'sha256'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
