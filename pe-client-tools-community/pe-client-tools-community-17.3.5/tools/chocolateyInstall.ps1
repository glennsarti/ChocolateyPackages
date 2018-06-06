$PackageName = 'pe-client-tools-community'
# Per-package parameters
$downloadUrl = 'https://pm.puppetlabs.com/pe-client-tools/2017.3.6/17.3.5/repos/windows/pe-client-tools-17.3.5-x64.msi'
$sha256Checksum = 'fc90163ce1498a4eef117e72cb4d0406526487b732eaac5a16ddd482eccde0d9'

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
