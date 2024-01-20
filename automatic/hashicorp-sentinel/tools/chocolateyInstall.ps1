$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.24.1/sentinel_0.24.1_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.24.1/sentinel_0.24.1_windows_amd64.zip'
$checksum32  = 'db5332c20126c59fb343e0b0d57ee744ec743f68f33e2af7b3b60374d7a4e558'
$checksum64  = '2874aca7bd9c35f423d0876148100c4f823bf933783bec98dd282adcfe46e192'
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
