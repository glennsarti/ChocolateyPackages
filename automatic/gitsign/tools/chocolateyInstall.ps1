$packageName = 'gitsign'
$url64       = 'https://github.com/sigstore/gitsign/releases/download/v0.12.0/gitsign_0.12.0_windows_amd64.exe'
$checksum64  = '4b111b65e44ba10609dc6e614ddb00155e3f13182d2bf2557a282cbbd3e7e653'

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
