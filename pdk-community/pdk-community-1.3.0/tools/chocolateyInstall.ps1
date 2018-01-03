$PackageName = 'pdk-community'
# Per-package parameters
$downloadUrl = 'https://puppet-pdk.s3.amazonaws.com/pdk/1.3.0.0/repos/windows/pdk-1.3.0.0-x64.msi'
$md5Checksum = '13f012573cc9a41839717df09e4234e2'

$packageArgs = @{
  packageName   = $PackageName
  fileType      = 'MSI'
  url64bit      = $downloadUrl
  Checksum64    = $md5Checksum
  checksumType64 = 'md5'
  silentArgs    = "/qn /norestart"
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
