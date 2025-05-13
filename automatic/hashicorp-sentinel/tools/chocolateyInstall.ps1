$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.40.0/sentinel_0.40.0_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.40.0/sentinel_0.40.0_windows_amd64.zip'
$checksum32  = 'ff669db6510ec0a5c86f41da72fa974b855213cbb1332cb8eae32dc300bed241'
$checksum64  = 'b289a0f00afe15765e92833283d238183368743f75787b87ab0f5352e77634b3'
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
