$PackageName = 'pe-client-tools-community'
# Per-package parameters
$downloadUrl = 'https://pm.puppetlabs.com/pe-client-tools/2016.4.5/16.4.2/repos/windows/pe-client-tools-16.4.2-x64.msi'
$md5Checksum = '64dfda786db490b21efbd2f552e461ce'

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
