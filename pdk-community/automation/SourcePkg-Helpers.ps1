$ErrorActionPreference = 'Stop'

$script:ChocoPackageName = 'pdk-community'

Function Get-VersionListFromWebsite() {
  $url = 'http://downloads.puppetlabs.com/windows/'
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $result = Invoke-WebRequest -URI $url -UseBasicParsing

  $result.links | ? { $_.href -match 'pdk-'} | % {
    $_.href -match 'pdk-([\d.]+)\.0-x64\.msi$' | Out-Null
    Write-Output $matches[1]
  }
}

Function Get-VersionListFromRepo($RootDir) {
  Get-ChildItem -Path "$RootDir\templates" |
    Where-Object { (!$_.PSIsContainer) -and ($_.name -like "package-$($Script:ChocoPackageName)-*") } | % {
      $dirName = $_.Name

      Write-Output ($dirName.replace("package-$($Script:ChocoPackageName)-",'').replace('-beta','').replace('.ps1',''))
    }
}

Function Invoke-CreateMissingTemplates($RootDir) {
  # Init
  $downloadDir = Join-Path -Path $RootDir -ChildPath 'automation\downloads'
  if (-not (Test-Path -Path $downloadDir)) { New-Item -Path $downloadDir -ItemType Directory | Out-Null }

  # Get Version lists
  $sourceList = Get-VersionListFromWebsite
  if ($sourceList -eq $null) { $sourceList = @() }
  if ($sourceList.GetType().ToString() -eq 'System.String') { $sourceList = @($sourceList) }
  $repoList = Get-VersionListFromRepo -RootDir $RootDir
  if ($repoList -eq $null) { $repoList = @() }

  # Find new versions
  $sourceList | ForEach-Object {
    $sourceVersion = $_
    if ($repoList -contains $sourceVersion) {
      Write-Host "$($Script:ChocoPackageName) v$($sourceVersion) is already in this repository"
    } else {
      Write-Host "Creating $($Script:ChocoPackageName) v$($sourceVersion) template..."

      $urlVersion = $sourceVersion + '.0'
      $downloadURL = "https://puppet-pdk.s3.amazonaws.com/pdk/${urlVersion}/repos/windows/pdk-${urlVersion}-x64.msi"
      $sourceFile = Join-Path -Path $downloadDir -ChildPath "source-$($urlVersion).msi"
      if (-not (Test-Path -Path $sourceFile)) {
        Write-Host "Downloading from $downloadURL ..."
        (New-Object System.Net.WebClient).DownloadFile($downloadURL, $sourceFile)
      } else {
        Write-Host "Using cached download"
      }

      Write-Host "Generating MD5 Hash..."
      $downloadHash = Get-FileHash -Path $sourceFile -Algorithm MD5

      # Generate the rest of the Package Definition
      $PackageVersion = $sourceVersion
      $TemplateName = 'pdk-community-v0.0.1'

      $templateContents = @"
`$PackageDefinition = @{
  "TemplateName" = "$($TemplateName)";
  "PackageName" = "$Script:ChocoPackageName";
  "PackageVersion" = "$($PackageVersion)";
  "DownloadURL" = "$($downloadURL)";
  "MD5Checksum" = "$($downloadHash.Hash.ToLower())";
}
"@
      $templateFile = Join-Path -Path "$($RootDir)\templates" -ChildPath "package-$($Script:ChocoPackageName)-$($PackageVersion).ps1"

      # Write out the template file
      Write-Host "Creating $templateFile ..."
      Out-File -InputObject $templateContents -FilePath $templateFile -Encoding ASCII -Force -Confirm:$false

      Write-Output "$($Script:ChocoPackageName)-$PackageVersion"
    }
  }
}
