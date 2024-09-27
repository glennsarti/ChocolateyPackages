$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.28.0/sentinel_0.28.0_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.28.0/sentinel_0.28.0_windows_amd64.zip'
$checksum32  = 'bf31edd775fc4f1fee109d274f632635504fc8882ad08f3842408b21f2bda82c'
$checksum64  = '66bf77e4ad79d29803cafdd3e72d653600eb68314a3a67adfeb270e37868501a'
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
