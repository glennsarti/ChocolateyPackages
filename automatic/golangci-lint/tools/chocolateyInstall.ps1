$packageName = 'golangci-lint'
$url32       = 'https://github.com/golangci/golangci-lint/releases/download/v1.52.2/golangci-lint-1.52.2-windows-386.zip'
$url64       = 'https://github.com/golangci/golangci-lint/releases/download/v1.52.2/golangci-lint-1.52.2-windows-amd64.zip'
$checksum32  = '40a2645b4c7bd94c16618eb0f12b32cd54c17e5620f761cf477b256d3622f299'
$checksum64  = '40b40002e07db81628d94108265525052c58fc9ce358bef26a36d27f0aea3d87'
$zipFolder32 = 'golangci-lint-1.52.2-windows-386'
$zipFolder64 = 'golangci-lint-1.52.2-windows-amd64'
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
