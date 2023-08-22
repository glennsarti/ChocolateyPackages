$packageName = 'golangci-lint'
$url32       = 'https://github.com/golangci/golangci-lint/releases/download/v1.54.2/golangci-lint-1.54.2-windows-386.zip'
$url64       = 'https://github.com/golangci/golangci-lint/releases/download/v1.54.2/golangci-lint-1.54.2-windows-amd64.zip'
$checksum32  = '2e1a11787b08137ba16c3be6ab87de3ef5de470758b7a42441497f259e8e5a1d'
$checksum64  = 'ce17d122f3f93e0a9e52009d2c03cc1c1a1ae28338c2702a1f53eccd10a1afa3'
$zipFolder32 = 'golangci-lint-1.54.2-windows-386'
$zipFolder64 = 'golangci-lint-1.54.2-windows-amd64'
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
