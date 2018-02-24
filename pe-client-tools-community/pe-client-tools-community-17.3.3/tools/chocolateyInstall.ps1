$PackageName = 'pe-client-tools-community'
# Per-package parameters
$downloadUrl = 'https://pm.puppetlabs.com/pe-client-tools/2017.3.4/17.3.3/repos/windows/pe-client-tools-17.3.3-x64.msi'
$sha256Checksum = '433918a21425b71a5208f90a797074e3d22e95a451dfc326b70d48906e48f319'

$packageArgs = @{
  packageName   = $PackageName
  fileType      = 'MSI'
  url64bit      = $downloadUrl
  Checksum64    = $sha256Checksum
  checksumType64 = 'sha256'
  silentArgs    = "/qn /norestart"
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
