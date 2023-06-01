$packageName = 'gitsign'
$url64       = 'https://github.com/sigstore/gitsign/releases/download/v0.7.1/gitsign_0.7.1_windows_amd64.exe'
$checksum64  = 'a3e64bbc3df2a4b084f6f01920bd101660fe1e17128ece7d314cb6014125d05b'

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
