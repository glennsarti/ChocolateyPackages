$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.19.3/sentinel_0.19.3_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.19.3/sentinel_0.19.3_windows_amd64.zip'
$checksum32  = 'b6020e77bce31d1d7089b85ac4469256cdc2851eec7c7b03e2e292b240520ac0'
$checksum64  = '9f7ba7217d5100f857664126e001ed73615b6be2eaf4ec29e2dd7048b96380b4'
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
