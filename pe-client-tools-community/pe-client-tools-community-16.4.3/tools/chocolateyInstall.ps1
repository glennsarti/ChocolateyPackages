$PackageName = 'pe-client-tools-community'
# Per-package parameters
$downloadUrl = 'https://pm.puppetlabs.com/pe-client-tools/2016.4.9/16.4.3/repos/windows/pe-client-tools-16.4.3-x64.msi'
$md5Checksum = '1a53171eac876598063d4f7b027621a5'

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
