$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.20.0/sentinel_0.20.0_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.20.0/sentinel_0.20.0_windows_amd64.zip'
$checksum32  = 'ca2ab582f7c1016abd4ea1c30cf11e8c8065c6e0a6942e8b51f009c31b3a8d0f'
$checksum64  = '50ff40ca7522ca18f77fa7cbe13773356e7bd803eaa8645eee1525db0a6f5aaa'
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
