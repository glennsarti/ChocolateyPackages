import-module Chocolatey-AU

$GitHubOrg = 'sigstore'
$GitHubRepo = 'gitsign'

function global:au_SearchReplace {
  @{
    'tools\chocolateyInstall.ps1' = @{
      "(^[$]url64\s*=\s*)('.*')"      = "`$1'$($Latest.URL64)'"
      "(^[$]checksum64\s*=\s*)('.*')" = "`$1'$($Latest.Checksum64)'"
    }
  }
}

function global:au_GetLatest {
  $streams = [ordered]@{}
  # We strictly do not take alpha or beta releases
  $VersionRegEx = '^v(\d+\.\d+\.\d+)$'

  $Header = @{
    "Accept" = "application/vnd.github.v3+json"
  }

  # We only care about the first 30 releases.
  $Page = 1
  $Url = "https://api.github.com/repos/$GitHubOrg/$GitHubRepo/releases?per_page=30&page=$Page"

  $result = Invoke-RestMethod -Uri $Url -Method 'GET' -Headers $Header

  $result | ForEach-Object {
    Write-Host $_.Name
    if ($matches.count -gt 0) { [void]$matches.clear }
    if ($_.Name -match $VersionRegEx) {
      Write-Output ([PSCustomObject]@{
        Version = [System.Version]$matches[1]
        Name = $_.Name
      })
    }
  } |
  Sort-Object -Descending -Property Version |
  ForEach-Object {
      $ver = $_.Version
      $minorVer = $ver.ToString(2)
      if (!$streams.Contains($minorVer)) {
        $download64 = "https://github.com/$GitHubOrg/$GitHubRepo/releases/download/$($_.Name)/gitsign_$($ver)_windows_amd64.exe"
        $streams.$minorVer = @{ URL64 = $download64;
                                Version = $ver.ToString()
        }
      }
  }

  @{ Streams = $streams }
}


# gitsign is a 64bit only package
update -ChecksumFor 64
