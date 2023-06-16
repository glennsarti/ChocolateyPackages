$packageName = 'golangci-lint'
$url32       = 'https://github.com/golangci/golangci-lint/releases/download/v1.53.3/golangci-lint-1.53.3-windows-386.zip'
$url64       = 'https://github.com/golangci/golangci-lint/releases/download/v1.53.3/golangci-lint-1.53.3-windows-amd64.zip'
$checksum32  = '33e70b307af34701938d6ff2cd8485d0829c71eb0a744a76e308d9d498f7c57a'
$checksum64  = 'bd23cc509f00990eecebeb2f1a12ba1b07f395c53313a27da969fad99b686ceb'
$zipFolder32 = 'golangci-lint-1.53.3-windows-386'
$zipFolder64 = 'golangci-lint-1.53.3-windows-amd64'
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
