$PackageName = 'pe-client-tools-community'
# Per-package parameters
$downloadUrl = 'https://pm.puppetlabs.com/pe-client-tools/2016.4.11/16.4.5/repos/windows/pe-client-tools-16.4.5-x64.msi'
$sha256Checksum = '2d54bcf94fa163fffd977eff359addd59b78041c7f9f6687a5830e9bf416d734'

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
