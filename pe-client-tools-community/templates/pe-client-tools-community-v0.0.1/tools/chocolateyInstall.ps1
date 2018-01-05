$PackageName = '{{PackageName}}'
# Per-package parameters
$downloadUrl = '{{DownloadURL}}'
$md5Checksum = '{{MD5Checksum}}'

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
