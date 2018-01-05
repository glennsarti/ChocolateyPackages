$ErrorActionPreference = 'Stop'

$script:ChocoPackageName = 'pe-client-tools-community'

Function Get-VersionListFromWebsite() {
  $versions = @{}
  $prev_url = 'https://puppet.com/misc/pe-files/previous-releases'
  $result = Invoke-WebRequest -URI $prev_url -UseBasicParsing

  $result.links | ? { $_.href -match '/pe-files/previous-releases/'} | % {
    $release_URI = 'https://puppet.com' + $_.href

    # Example address https://pm.puppetlabs.com/pe-client-tools/2017.2.5/17.2.4/repos/windows/pe-client-tools-17.2.4-x64.msi
    $files = Invoke-WebRequest -URI $release_URI -UseBasicParsing

    $pe_link = ''
    $files.links | ? { $_.href -match 'pe-client-tools-.+-x64\.msi'} | % {
      $pe_link = $_.href
    }

    if ($pe_link -ne '') {
      $pe_link -match 'pe-client-tools-(.+)-x64\.msi$' | Out-Null
      $versions[$matches[1]] = $pe_link
    }
  }
  $versions
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
  if ($sourceList -eq $null) { $sourceList = @{} }
  $repoList = Get-VersionListFromRepo -RootDir $RootDir
  if ($repoList -eq $null) { $repoList = @() }

  # Find new versions
  $sourceList.Keys | ForEach-Object {
    $sourceVersion = $_
    $sourceURI = $sourceList[$SourceVersion]
    if ($repoList -contains $sourceVersion) {
      Write-Host "$($Script:ChocoPackageName) v$($sourceVersion) is already in this repository"
    } else {
      Write-Host "Creating $($Script:ChocoPackageName) v$($sourceVersion) template..."

      $urlVersion = $sourceVersion + '.0'
      $downloadURL = $sourceURI
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
      $TemplateName = 'pe-client-tools-community-v0.0.1'

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
