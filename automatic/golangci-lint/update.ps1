import-module au

$GitHubOrg = 'golangci'
$GitHubRepo = 'golangci-lint'

function global:au_SearchReplace {
  @{
    'tools\chocolateyInstall.ps1' = @{
      "(^[$]url64\s*=\s*)('.*')"      = "`$1'$($Latest.URL64)'"
      "(^[$]url32\s*=\s*)('.*')"      = "`$1'$($Latest.URL32)'"
      "(^[$]checksum32\s*=\s*)('.*')" = "`$1'$($Latest.Checksum32)'"
      "(^[$]checksum64\s*=\s*)('.*')" = "`$1'$($Latest.Checksum64)'"
      "(^[$]zipFolder32\s*=\s*)('.*')" = "`$1'$($Latest.ZipFolder32)'"
      "(^[$]zipFolder64\s*=\s*)('.*')" = "`$1'$($Latest.ZipFolder64)'"
    }
  }
}

function global:au_GetLatest {
  $streams = [ordered]@{}
  $VersionRegEx = 'v(\d+\.\d+\.\d+)'

  $Header = @{
    "Accept" = "application/vnd.github.v3+json"
  }

  # We only care about the first 30 releases.
  $Page = 1
  $Url = "https://api.github.com/repos/$GitHubOrg/$GitHubRepo/releases?per_page=30&page=$Page"

  $result = Invoke-RestMethod -Uri $Url -Method 'GET' -Headers $Header

  $result | ForEach-Object {
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
        $download64 = "https://github.com/$GitHubOrg/$GitHubRepo/releases/download/$($_.Name)/golangci-lint-$ver-windows-amd64.zip"
        $download32 = "https://github.com/$GitHubOrg/$GitHubRepo/releases/download/$($_.Name)/golangci-lint-$ver-windows-386.zip"
        $streams.$minorVer = @{ URL64 = $download64;
                                URL32 = $download32;
                                ZipFolder64 ="golangci-lint-$ver-windows-amd64"
                                ZipFolder32 ="golangci-lint-$ver-windows-386"
                                Version = $ver.ToString()
        }
      }
  }

  @{ Streams = $streams }
}

update
