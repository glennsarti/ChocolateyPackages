$packageName = 'golangci-lint'
$url32       = 'https://github.com/golangci/golangci-lint/releases/download/v1.50.1/golangci-lint-1.50.1-windows-386.zip'
$url64       = 'https://github.com/golangci/golangci-lint/releases/download/v1.50.1/golangci-lint-1.50.1-windows-amd64.zip'
$checksum32  = '6d11fb6ed91ba3aecbf2ea8e1a95dce16cf0449d54aa77c607ac4e75cc43213a'
$checksum64  = '8c2da214884db02fb7f3d929672c515ae3b9d10defad4dd661c4ab365a316d68'
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
