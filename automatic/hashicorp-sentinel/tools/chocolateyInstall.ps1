$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.23.1/sentinel_0.23.1_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.23.1/sentinel_0.23.1_windows_amd64.zip'
$checksum32  = 'a5b6a6d0fa3e37aabae8db092b8c0d47d29665a3f7ea4fbe2f6ecf3d330304a3'
$checksum64  = 'a2732b0e10f7bde9c596a7c2bc2c7e0dc0605cc366c980a6a522ac49d84aacbd'
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
