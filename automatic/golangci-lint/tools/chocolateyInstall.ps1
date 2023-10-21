$packageName = 'golangci-lint'
$url32       = 'https://github.com/golangci/golangci-lint/releases/download/v1.55.0/golangci-lint-1.55.0-windows-386.zip'
$url64       = 'https://github.com/golangci/golangci-lint/releases/download/v1.55.0/golangci-lint-1.55.0-windows-amd64.zip'
$checksum32  = 'bf1903d809826c54a949ae4013c3e4534417d13e77d666ef815268999b9a4409'
$checksum64  = '9be37b06047b34c0ec3c0a246743ad83c021e6484bdaf9e79e7bd5c14315c6fc'
$zipFolder32 = 'golangci-lint-1.55.0-windows-386'
$zipFolder64 = 'golangci-lint-1.55.0-windows-amd64'
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
