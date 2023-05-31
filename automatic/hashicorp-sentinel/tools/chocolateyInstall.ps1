$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.22.0/sentinel_0.22.0_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.22.0/sentinel_0.22.0_windows_amd64.zip'
$checksum32  = '5e8cbae5c4fef698516f8e3dd50160eca91537c427c88cba3ccfe9e932e63f95'
$checksum64  = '9fa25af9e9f26bb5b94c8b4c41b9e28a0f4f496f455ac0b16ee2c9c555b84c52'
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
