$packageName = 'golangci-lint'
$url32       = 'https://github.com/golangci/golangci-lint/releases/download/v1.51.1/golangci-lint-1.51.1-windows-386.zip'
$url64       = 'https://github.com/golangci/golangci-lint/releases/download/v1.51.1/golangci-lint-1.51.1-windows-amd64.zip'
$checksum32  = '6710e2f5375dc75521c1a17980a6cbbe6ff76c2f8b852964a8af558899a97cf5'
$checksum64  = '722d7b87b9cdda0a3835d5030b3fc5385c2eba4c107f63f6391cfb2ac35f051d'
$zipFolder32 = 'golangci-lint-1.51.1-windows-386'
$zipFolder64 = 'golangci-lint-1.51.1-windows-amd64'
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
