$packageName = 'golangci-lint'
$url32       = 'https://github.com/golangci/golangci-lint/releases/download/v1.53.2/golangci-lint-1.53.2-windows-386.zip'
$url64       = 'https://github.com/golangci/golangci-lint/releases/download/v1.53.2/golangci-lint-1.53.2-windows-amd64.zip'
$checksum32  = 'a4ae07b2b9b96d1d08cd868e2d63abf461b5356bd7bae5d62fdbc98ee24c5e55'
$checksum64  = '7bf18716b68c4d5a99d88d3adc4aab642a7045813afa212db2aac0d56db33e97'
$zipFolder32 = 'golangci-lint-1.53.2-windows-386'
$zipFolder64 = 'golangci-lint-1.53.2-windows-amd64'
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
