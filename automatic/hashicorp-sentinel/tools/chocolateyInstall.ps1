$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.19.2/sentinel_0.19.2_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.19.2/sentinel_0.19.2_windows_amd64.zip'
$checksum32  = '6a97fe519568d6aac5486f8e7aaee2c81b9110d2c23da5e64f141aa39a47e5ae'
$checksum64  = '95326cf0734f4af1835037a2e2957850c7c58db72f84d3390f3c1554f86b5a30'
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
