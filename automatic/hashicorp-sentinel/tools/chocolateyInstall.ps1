$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.19.5/sentinel_0.19.5_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.19.5/sentinel_0.19.5_windows_amd64.zip'
$checksum32  = '0b160cfd059d069975a79c7edb7cb35d90adc9d2f03d966c207b8324deaa101c'
$checksum64  = 'b601dfd390f9298373bf4abf05485bcc4088ef99a35332325a48bc02272d887b'
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
