$PackageName = 'pe-client-tools-community'
# Per-package parameters
$downloadUrl = 'https://pm.puppetlabs.com/pe-client-tools/2017.2.5/17.2.4/repos/windows/pe-client-tools-17.2.4-x64.msi'
$md5Checksum = '5b59bdf58a438209f63ece8d9e26f08c'

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
