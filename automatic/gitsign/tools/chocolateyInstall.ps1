$packageName = 'gitsign'
$url64       = 'https://github.com/sigstore/gitsign/releases/download/v0.5.2/gitsign_0.5.2_windows_amd64.exe'
$checksum64  = '53d4c9f65b864e492695d1aa2f32bbc439ce8cc5a4caa53c013b9b6e39fb405b'

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
