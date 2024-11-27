$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.29.0/sentinel_0.29.0_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.29.0/sentinel_0.29.0_windows_amd64.zip'
$checksum32  = 'db2c0d18400a6ba6fd4889a5689549291aebeb7839fd1e3a38f67025d59387e1'
$checksum64  = '24eed5f1641c0e5cee66097f4bc0ecbbd6b5fe1cd2bc304f26604e98748b7a5d'
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
