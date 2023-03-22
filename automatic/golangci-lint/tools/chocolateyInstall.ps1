$packageName = 'golangci-lint'
$url32       = 'https://github.com/golangci/golangci-lint/releases/download/v1.52.1/golangci-lint-1.52.1-windows-386.zip'
$url64       = 'https://github.com/golangci/golangci-lint/releases/download/v1.52.1/golangci-lint-1.52.1-windows-amd64.zip'
$checksum32  = 'db5d186246f44820c80ab725b5babf4198cff0c183f2184b8dd34ac983f2b899'
$checksum64  = 'a6fe8a6b7d76b7a1f19ab7359cf93ab9efc6dad7e625c39a5a505310d06721ca'
$zipFolder32 = 'golangci-lint-1.52.1-windows-386'
$zipFolder64 = 'golangci-lint-1.52.1-windows-amd64'
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
