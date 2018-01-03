$PackageName = 'pdk-community'
# Per-package parameters
$downloadUrl = 'https://puppet-pdk.s3.amazonaws.com/pdk/1.1.0.0/repos/windows/pdk-1.1.0.0-x64.msi'
$md5Checksum = 'c8fbd60961b48fb536588b78d944e70c'

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
