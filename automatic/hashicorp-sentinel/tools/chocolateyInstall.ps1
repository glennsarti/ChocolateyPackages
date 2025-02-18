$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.30.0/sentinel_0.30.0_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.30.0/sentinel_0.30.0_windows_amd64.zip'
$checksum32  = '7e9f3fb6791a936387a432dfde4df9f8670c80ff63934296187576a7b4e2abfa'
$checksum64  = 'cefe646b9fba66fb6f9d57856a2203f868ae613012bb4196a7d5d0c5441da0c9'
$installDir = Split-Path $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = $packageName
  url            = $url32
  url64bit       = $url64
  UnzipLocation  = $installDir
  checksum       = $checksum32
  checksum64     = $checksum64
  checksumType   = 'sha256'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
