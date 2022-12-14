import-module au

function global:au_SearchReplace {
  @{
    'tools\chocolateyInstall.ps1' = @{
      "(^[$]url64\s*=\s*)('.*')"      = "`$1'$($Latest.URL64)'"
      "(^[$]url32\s*=\s*)('.*')"      = "`$1'$($Latest.URL32)'"
      "(^[$]checksum32\s*=\s*)('.*')" = "`$1'$($Latest.Checksum32)'"
      "(^[$]checksum64\s*=\s*)('.*')" = "`$1'$($Latest.Checksum64)'"
    }
  }
}

function global:au_GetLatest {
  $streams = [ordered]@{}
  $VersionRegEx = '/sentinel/(\d+\.\d+\.\d+)/'

  # We only care about the first 30 releases.
  $RootUrl = "https://releases.hashicorp.com"
  $Url = "${RootUrl}/sentinel/"

  $result = Invoke-WebRequest -Uri $Url -Method 'GET' -UseBasicParsing

  $result.links | ForEach-Object {
    if ($matches.count -gt 0) { [void]$matches.clear }
    if ($_.href -match $VersionRegEx) {
      Write-Output ([PSCustomObject]@{
        Version = [System.Version]$matches[1]
        Name = $_.href
      })
    }
  } |
  Sort-Object -Descending -Property Version |

  ForEach-Object {
      $ver = $_.Version
      $minorVer = $ver.ToString(2)
      if (!$streams.Contains($minorVer)) {
        $download64 = "${RootUrl}$($_.Name)sentinel_${ver}_windows_amd64.zip"
        $download32 = "${RootUrl}$($_.Name)sentinel_${ver}_windows_386.zip"
        $streams.$minorVer = @{ URL64 = $download64;
                                URL32 = $download32;
                                Version = $ver.ToString()
        }
      }
  }

  @{ Streams = $streams }
}

update
