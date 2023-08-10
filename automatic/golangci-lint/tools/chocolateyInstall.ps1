$packageName = 'golangci-lint'
$url32       = 'https://github.com/golangci/golangci-lint/releases/download/v1.54.0/golangci-lint-1.54.0-windows-386.zip'
$url64       = 'https://github.com/golangci/golangci-lint/releases/download/v1.54.0/golangci-lint-1.54.0-windows-amd64.zip'
$checksum32  = 'f371e1f10e1c9727e412686243c0b785bced160dfdbf28a164263e5c6b33dc45'
$checksum64  = '8ff567bfe2add55764b983826ca83a9ef9cf063075f36f4818ddc1c73ed62e6d'
$zipFolder32 = 'golangci-lint-1.54.0-windows-386'
$zipFolder64 = 'golangci-lint-1.54.0-windows-amd64'
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
