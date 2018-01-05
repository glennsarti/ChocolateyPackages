$PackageName = 'pe-client-tools-community'
# Per-package parameters
$downloadUrl = 'https://pm.puppetlabs.com/pe-client-tools/2016.5.1/16.5.2/repos/windows/pe-client-tools-16.5.2-x64.msi'
$md5Checksum = '6750c5b7abe444ea870148c7b7f3652b'

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
