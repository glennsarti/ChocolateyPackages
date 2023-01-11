$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.19.1/sentinel_0.19.1_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.19.1/sentinel_0.19.1_windows_amd64.zip'
$checksum32  = 'edf10a80132d5d063d54dca81f5f4cf73b29965f29b358cfff75d60d1203db0a'
$checksum64  = '204cfdb3cde4f08672c9ce9ed5d68e28bdb293df561c9a089649502050e1b4dc'
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
