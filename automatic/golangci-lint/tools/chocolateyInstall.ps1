$packageName = 'golangci-lint'
$url32       = 'https://github.com/golangci/golangci-lint/releases/download/v1.50.1/golangci-lint-1.50.1-windows-386.zip'
$url64       = 'https://github.com/golangci/golangci-lint/releases/download/v1.50.1/golangci-lint-1.50.1-windows-amd64.zip'
$checksum32  = ''
$checksum64  = ''
$zipFolder32 = 'golangci-lint-1.50.1-windows-386'
$zipFolder64 = 'golangci-lint-1.50.1-windows-amd64'
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
