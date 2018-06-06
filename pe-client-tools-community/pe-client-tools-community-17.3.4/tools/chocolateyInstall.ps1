$PackageName = 'pe-client-tools-community'
# Per-package parameters
$downloadUrl = 'https://pm.puppetlabs.com/pe-client-tools/2017.3.5/17.3.4/repos/windows/pe-client-tools-17.3.4-x64.msi'
$sha256Checksum = 'c87fb04021ffd47a33470b9041fd0ea73b5a5aa1e84f8109bb1f51620f102cc9'

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
