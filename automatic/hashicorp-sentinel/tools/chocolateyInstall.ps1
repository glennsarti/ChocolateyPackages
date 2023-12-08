$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.24.0/sentinel_0.24.0_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.24.0/sentinel_0.24.0_windows_amd64.zip'
$checksum32  = '5014edfba5174389e5a8b0b7cbd551fd4f747d0304cf9bf26c47c8eb47b0b80f'
$checksum64  = '17c78a8384292af5631cc37b55f16070638b0e93b32a7bf2c1f74df7db49203e'
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
