$packageName = 'golangci-lint'
$url32       = 'https://github.com/golangci/golangci-lint/releases/download/v1.53.1/golangci-lint-1.53.1-windows-386.zip'
$url64       = 'https://github.com/golangci/golangci-lint/releases/download/v1.53.1/golangci-lint-1.53.1-windows-amd64.zip'
$checksum32  = '261bbde18022ade02889b1335c91ab8177e1ea08b7ec55250f39567e0c24c6c8'
$checksum64  = '8dfd46aded7b21f30fe1ba9a35a01fb58cec74be61cee2a27d76656c53270c8c'
$zipFolder32 = 'golangci-lint-1.53.1-windows-386'
$zipFolder64 = 'golangci-lint-1.53.1-windows-amd64'
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
