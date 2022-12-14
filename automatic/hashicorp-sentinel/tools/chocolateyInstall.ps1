$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.17.4/sentinel_0.17.4_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.17.4/sentinel_0.17.4_windows_amd64.zip'
$checksum32  = 'e3b0d82d6293746cbb556c628d1bde1a12321efbb23777c2525d4822ca06110e'
$checksum64  = 'bd11c266e72e39d7938f502bb74dee7b67669e580c8b846544057f4544565d4a'
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
