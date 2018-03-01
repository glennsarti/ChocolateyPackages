$PackageName = 'pdk-community'
# Per-package parameters
$downloadUrl = 'https://puppet-pdk.s3.amazonaws.com/pdk/1.4.1.1/repos/windows/pdk-1.4.1.1-x64.msi'
$shaChecksum = 'ee2aec42192b4dba9d58dad2bc3ecc71a315ef10b3605b1379d3e8c2b9f30c5e'

$packageArgs = @{
  packageName   = $PackageName
  fileType      = 'MSI'
  url64bit      = $downloadUrl
  Checksum64    = $shaChecksum
  checksumType64 = 'sha256'
  silentArgs    = "/qn /norestart"
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
