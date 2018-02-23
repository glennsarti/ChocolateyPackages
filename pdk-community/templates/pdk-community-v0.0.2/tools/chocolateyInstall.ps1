$PackageName = '{{PackageName}}'
# Per-package parameters
$downloadUrl = '{{DownloadURL}}'
$shaChecksum = '{{SHA256Checksum}}'

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
