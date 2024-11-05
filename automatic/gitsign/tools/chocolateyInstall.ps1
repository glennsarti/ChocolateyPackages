$packageName = 'gitsign'
$url64       = 'https://github.com/sigstore/gitsign/releases/download/v0.11.0/gitsign_0.11.0_windows_amd64.exe'
$checksum64  = '519e267a48dbe4db5544877b2f6aa986f54497848aea1acd4387f5f983f64135'

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
