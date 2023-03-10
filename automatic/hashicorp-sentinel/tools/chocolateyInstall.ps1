$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.21.0/sentinel_0.21.0_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.21.0/sentinel_0.21.0_windows_amd64.zip'
$checksum32  = '9d9382802f24172658ebd4ca79a26a8d21975ba5d2ec2426880deee516e31c89'
$checksum64  = 'a2f4f43874c4bb04f0b988effa2b5b8e0b33cf4d2081050432d1d92b8fd5074e'
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
