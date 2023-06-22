$packageName = 'hashicorp-sentinel'
$url32       = 'https://releases.hashicorp.com/sentinel/0.22.1/sentinel_0.22.1_windows_386.zip'
$url64       = 'https://releases.hashicorp.com/sentinel/0.22.1/sentinel_0.22.1_windows_amd64.zip'
$checksum32  = '29471ebac72c97de16e8b4b981e6e3eea0c35e80f1652539a48e1d211c5c8494'
$checksum64  = '0de88306c5fbb28d4bd44915cd320bc9bd49f8fdeb0f02a26184ac352067a4ce'
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
