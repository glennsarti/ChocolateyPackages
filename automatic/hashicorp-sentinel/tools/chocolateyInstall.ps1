$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.21.1/sentinel_0.21.1_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.21.1/sentinel_0.21.1_windows_amd64.zip'
$checksum32  = '6fa949a03132cce6cbda8976c3f6be988200cbb3fd7892c2d033a02e930ef5d4'
$checksum64  = '15f5af698aa1c7bbcf5c02d0190606fdaf86b67326b71014c2d89b0026a593ef'
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
