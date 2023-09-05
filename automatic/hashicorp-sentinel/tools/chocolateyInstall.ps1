$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.23.0/sentinel_0.23.0_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.23.0/sentinel_0.23.0_windows_amd64.zip'
$checksum32  = '1a10989bbd8ac76db18e1956de55e9740839ca03b90c74f3e6be0f0de22ebb1e'
$checksum64  = '0d4ff3ca7c4e8825ac97f5322990592a3894b4d32a133632c4294611282c3545'
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
