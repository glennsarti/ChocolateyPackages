$packageName = 'gitsign'
$url64       = 'https://github.com/sigstore/gitsign/releases/download/v0.4.1/gitsign_0.4.1_windows_amd64.exe'
$checksum64  = '381f8a30d929b25f1dd0e82158c7d321710de048c95528c324c7698554312ee0'

# Install it
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$packageArgs = @{
  PackageName    = $packageName
  FileFullPath   = "$toolsDir\gitsign.exe"
  Url64          = $url64
  Checksum64     = $checksum64
  ChecksumType64 = 'sha256'
}
Get-ChocolateyWebFile @packageArgs
