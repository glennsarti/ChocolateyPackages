$packageName = 'golangci-lint'
$url32       = 'https://github.com/golangci/golangci-lint/releases/download/v1.51.2/golangci-lint-1.51.2-windows-386.zip'
$url64       = 'https://github.com/golangci/golangci-lint/releases/download/v1.51.2/golangci-lint-1.51.2-windows-amd64.zip'
$checksum32  = '5513ebc938dec5dc7d227ee35dbc30539a4b0dedd293c31a85a4fb8d11746845'
$checksum64  = 'aac163d9bf3f79457399c2852cfae550cd250f23df9b324966f9c54e767ff42d'
$zipFolder32 = 'golangci-lint-1.51.2-windows-386'
$zipFolder64 = 'golangci-lint-1.51.2-windows-amd64'
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
