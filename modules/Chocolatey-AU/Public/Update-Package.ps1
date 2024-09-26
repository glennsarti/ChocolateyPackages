# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 19-Dec-2016.

<#
.SYNOPSIS
    Update automatic package

.DESCRIPTION
    This function is used to perform necessary updates to the specified files in the package.
    It shouldn't be used on its own but must be part of the script which defines two functions:

    - au_SearchReplace
      The function should return HashTable where keys are file paths and value is another HashTable
      where keys and values are standard search and replace strings
    - au_GetLatest
      Returns the HashTable where the script specifies information about new Version, new URLs and
      any other data. You can refer to this variable as the $Latest in the script.
      While Version is used to determine if updates to the package are needed, other arguments can
      be used in search and replace patterns or for whatever purpose.

    With those 2 functions defined, calling Update-Package will:

    - Call your au_GetLatest function to get the remote version and other information.
    - If remote version is higher then the nuspec version, function will:
        - Check the returned URLs, Versions and Checksums (if defined) for validity (unless NoCheckXXX variables are specified)
        - Download files and calculate checksum(s), (unless already defined or ChecksumFor is set to 'none')
        - Update the nuspec with the latest version
        - Do the necessary file replacements
        - Pack the files into the nuget package

    You can also define au_BeforeUpdate and au_AfterUpdate functions to integrate your code into the update pipeline.
.EXAMPLE
    PS> notepad update.ps1
    # The following script is used to update the package from the github releases page.
    # After it defines the 2 functions, it calls the Update-Package.
    # Checksums are automatically calculated for 32 bit version (the only one in this case)
    import-module Chocolatey-AU

    function global:au_SearchReplace {
        ".\tools\chocolateyInstall.ps1" = @{
            "(^[$]url32\s*=\s*)('.*')"          = "`$1'$($Latest.URL32)'"
            "(^[$]checksum32\s*=\s*)('.*')"     = "`$1'$($Latest.Checksum32)'"
            "(^[$]checksumType32\s*=\s*)('.*')" = "`$1'$($Latest.ChecksumType32)'"
        }
    }

    function global:au_GetLatest {
        $download_page = Invoke-WebRequest https://github.com/hluk/CopyQ/releases -UseBasicParsing

        $re  = "copyq-.*-setup.exe"
        $url = $download_page.links | ? href -match $re | select -First 1 -expand href
        $version = $url -split '-|.exe' | select -Last 1 -Skip 2

        return @{ URL32 = $url; Version = $version }
    }

    Update-Package -ChecksumFor 32

.NOTES
    All function parameters accept defaults via global variables with prefix `au_` (example: $global:au_Force = $true).

.OUTPUTS
    PSCustomObject with type AUPackage.

.LINK
    Update-AUPackages
#>
function Update-Package {
    [CmdletBinding()]
    param(
        #Do not check URL and version for validity.
        [switch] $NoCheckUrl,

        #Do not check if latest returned version already exists in the Chocolatey community feed.
        #Ignored when Force is specified.
        [switch] $NoCheckChocoVersion,

        #Specify for which architectures to calculate checksum - all, 32 bit, 64 bit or none.
        [ValidateSet('all', '32', '64', 'none')]
        [string] $ChecksumFor='all',

        #Timeout for all web operations, by default 100 seconds.
        [int]    $Timeout,

        #Streams to process, either a string or an array. If ommitted, all streams are processed.
        #Single stream required when Force is specified.
        $IncludeStream,

        #Force package update even if no new version is found.
        #For multi streams packages, most recent stream is checked by default when Force is specified.
        [switch] $Force,

        #Do not show any Write-Host output.
        [switch] $NoHostOutput,

        #Output variable.
        [string] $Result,

        #Backup and restore package.
        [switch] $WhatIf, 

        #Disable automatic update of nuspec description from README.md files with first 2 lines skipped.
        [switch] $NoReadme
    )

    function check_urls() {
        "URL check" | result
        $Latest.Keys | Where-Object {$_ -like 'url*' } | ForEach-Object {
            $url = $Latest[ $_ ]
            if ($res = check_url $url -Options $Latest.Options) { throw "${res}:$url" } else { "  $url" | result }
        }
    }

    function get_checksum()
    {
        function invoke_installer() {
            if (!(Test-Path tools\chocolateyInstall.ps1)) { "  aborted, chocolateyInstall not found for this package" | result; return }

            Import-Module "$choco_tmp_path\helpers\chocolateyInstaller.psm1" -Force -Scope Global

            if ($ChecksumFor -eq 'none') { "Automatic checksum calculation is disabled"; return }
            if ($ChecksumFor -eq 'all')  { $arch = '32','64' } else { $arch = $ChecksumFor }

            $Env:ChocolateyPackageFolder = [System.IO.Path]::GetFullPath("$Env:TEMP\chocolatey\$($package.Name)") #https://github.com/majkinetor/au/issues/32
            $pkg_path = Join-Path $Env:ChocolateyPackageFolder $global:Latest.Version
            New-Item -Type Directory -Force $pkg_path | Out-Null

            $Env:ChocolateyPackageName         = "chocolatey\$($package.Name)"
            $Env:ChocolateyPackageVersion      = $global:Latest.Version.ToString()
            $Env:ChocolateyAllowEmptyChecksums = 'true'
            foreach ($a in $arch) {
                $Env:chocolateyForceX86 = if ($a -eq '32') { 'true' } else { '' }
                try {
                    #rm -force -recurse -ea ignore $pkg_path
                    .\tools\chocolateyInstall.ps1 | result
                } catch {
                    if ( "$_" -notlike 'au_break: *') { throw $_ } else {
                        $filePath = "$_" -replace 'au_break: '
                        if (!(Test-Path $filePath)) { throw "Can't find file path to checksum" }

                        $item = Get-Item $filePath
                        $type = if ($global:Latest.ContainsKey('ChecksumType' + $a)) { $global:Latest.Item('ChecksumType' + $a) } else { 'sha256' }
                        $hash = (Get-FileHash $item -Algorithm $type | ForEach-Object Hash).ToLowerInvariant()

                        if (!$global:Latest.ContainsKey('ChecksumType' + $a)) { $global:Latest.Add('ChecksumType' + $a, $type) }
                        if (!$global:Latest.ContainsKey('Checksum' + $a)) {
                            $global:Latest.Add('Checksum' + $a, $hash)
                            "Package downloaded and hash calculated for $a bit version" | result
                        } else {
                            $expected = $global:Latest.Item('Checksum' + $a)
                            if ($hash -ne $expected) { throw "Hash for $a bit version mismatch: actual = '$hash', expected = '$expected'" }
                            "Package downloaded and hash checked for $a bit version" | result
                        }
                    }
                }
            }
        }

        function fix_choco {
            Start-Sleep -Milliseconds (Get-Random 500) #reduce probability multiple updateall threads entering here at the same time (#29)

            # Copy choco modules once a day
            if (Test-Path $choco_tmp_path) {
                $ct = Get-Item $choco_tmp_path | ForEach-Object creationtime
                if (((get-date) - $ct).Days -gt 1) { Remove-Item -recurse -force $choco_tmp_path } else { Write-Verbose 'Chocolatey copy is recent, aborting monkey patching'; return }
            }

            Write-Verbose "Monkey patching chocolatey in: '$choco_tmp_path'"
            Copy-Item -recurse -force $Env:ChocolateyInstall\helpers $choco_tmp_path\helpers
            if (Test-Path $Env:ChocolateyInstall\extensions) { Copy-Item -recurse -force $Env:ChocolateyInstall\extensions $choco_tmp_path\extensions }

            $fun_path = "$choco_tmp_path\helpers\functions\Get-ChocolateyWebFile.ps1"
            (Get-Content $fun_path) -replace '^\s+return \$fileFullPath\s*$', '  throw "au_break: $fileFullPath"' | Set-Content $fun_path -ea ignore
        }

        "Automatic checksum started" | result

        # Copy choco powershell functions to TEMP dir and monkey patch the Get-ChocolateyWebFile function
        $choco_tmp_path = "$Env:TEMP\chocolatey\au\chocolatey"
        fix_choco

        # This will set the new URLs before the files are downloaded but will replace checksums to empty ones so download will not fail
        #  because checksums are at that moment set for the previous version.
        # SkipNuspecFile is passed so that if things fail here, nuspec file isn't updated; otherwise, on next run
        #  AU will think that package is the most recent. 
        #
        # TODO: This will also leaves other then nuspec files updated which is undesired side effect (should be very rare)
        #
        $global:Silent = $true

        $c32 = $global:Latest.Checksum32; $c64 = $global:Latest.Checksum64          #https://github.com/majkinetor/au/issues/36
        $global:Latest.Remove('Checksum32'); $global:Latest.Remove('Checksum64')    #  -||-
        update_files -SkipNuspecFile | out-null
        if ($c32) {$global:Latest.Checksum32 = $c32}
        if ($c64) {$global:Latest.Checksum64 = $c64}                                #https://github.com/majkinetor/au/issues/36

        $global:Silent = $false

        # Invoke installer for each architecture to download files
        invoke_installer
    }

    function process_stream() {
        $package.Updated = $false

        if (!(is_version $package.NuspecVersion)) {
            Write-Warning "Invalid nuspec file Version '$($package.NuspecVersion)' - using 0.0"
            $global:Latest.NuspecVersion = $package.NuspecVersion = '0.0'
        }
        if (!(is_version $Latest.Version)) { throw "Invalid version: $($Latest.Version)" }
        $package.RemoteVersion = $Latest.Version

        # For set_fix_version to work propertly, $Latest.Version's type must be assignable from string.
        # If not, then cast its value to string.
        if (!('1.0' -as $Latest.Version.GetType())) {
            $Latest.Version = [string] $Latest.Version
        }

        if (!$NoCheckUrl) { check_urls }

        "nuspec version: " + $package.NuspecVersion | result
        "remote version: " + $package.RemoteVersion | result

        $script:is_forced = $false
        if ([AUVersion] $Latest.Version -gt [AUVersion] $Latest.NuspecVersion) {
            if (!($NoCheckChocoVersion -or $Force)) {
                if ( !$au_GalleryPackageRootUrl ) { 
                    $au_GalleryPackageRootUrl = if ($env:au_GalleryPackageRootUrl) { $env:au_GalleryPackageRootUrl } else { 
                            if ($au_GalleryUrl) { "$au_GalleryUrl/packages" } else { 'https://chocolatey.org/packages' }
                    }
                }
                $choco_url = "$au_GalleryPackageRootUrl/{0}/{1}" -f $global:Latest.PackageName, $package.RemoteVersion
                try {
                    request $choco_url $Timeout | out-null
                    "New version is available but it already exists in the Chocolatey community feed (disable using `$NoCheckChocoVersion`):`n  $choco_url" | result
                    return
                } catch { }
            }
        } else {
            if (!$Force) {
                'No new version found' | result
                return
            }
            else { 'No new version found, but update is forced' | result; set_fix_version }
        }

        'New version is available' | result

        $match_url = ($Latest.Keys | Where-Object { $_ -match '^URL*' } | Select-Object -First 1 | ForEach-Object { $Latest[$_] } | split-Path -Leaf) -match '(?<=\.)[^.]+$'
        if ($match_url -and !$Latest.FileType) { $Latest.FileType = $Matches[0] }

        if ($ChecksumFor -ne 'none') { get_checksum } else { 'Automatic checksum skipped' | result }

        if ($WhatIf) { $package.Backup() }
        try {
            if (Test-Path Function:\au_BeforeUpdate) { 'Running au_BeforeUpdate' | result; au_BeforeUpdate $package | result }
            if (!$NoReadme -and (Test-Path (Join-Path $package.Path 'README.md'))) { Set-DescriptionFromReadme $package -SkipFirst 2 | result }        
            update_files
            if (Test-Path Function:\au_AfterUpdate) { 'Running au_AfterUpdate' | result; au_AfterUpdate $package | result }
        
            choco pack --limit-output | result
            if ($LastExitCode -ne 0) { throw "Choco pack failed with exit code $LastExitCode" }
        } finally {
            if ($WhatIf) {
                $save_dir = $package.SaveAndRestore() 
                Write-Warning "Package restored and updates saved to: $save_dir"
            }
        }

        $package.Updated = $true
    }

    function set_fix_version() {
        $script:is_forced = $true

        if ($global:au_Version) {
            "Overriding version to: $global:au_Version" | result
            $package.RemoteVersion = $global:au_Version
            if (!(is_version $global:au_Version)) { throw "Invalid version: $global:au_Version" }
            $global:Latest.Version = $package.RemoteVersion
            $global:au_Version = $null
            return
        }

        $date_format = 'yyyyMMdd'
        $d = (get-date).ToString($date_format)
        $nuspecVersion = [AUVersion] $Latest.NuspecVersion
        $v = $nuspecVersion.Version
        $rev = $v.Revision.ToString()
        try { $revdate = [DateTime]::ParseExact($rev, $date_format,[System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None) } catch {}
        if (($rev -ne -1) -and !$revdate) { return }

        $build = if ($v.Build -eq -1) {0} else {$v.Build}
        $v = [version] ('{0}.{1}.{2}.{3}' -f $v.Major, $v.Minor, $build, $d)
        $package.RemoteVersion = $nuspecVersion.WithVersion($v).ToString()
        $Latest.Version = $package.RemoteVersion -as $Latest.Version.GetType()
    }

    function set_latest( [HashTable] $latest, [string] $version, $stream ) {
        if (!$latest.NuspecVersion) { $latest.NuspecVersion = $version }
        if ($stream -and !$latest.Stream) { $latest.Stream = $stream }
        $package.NuspecVersion = $latest.NuspecVersion

        $global:Latest = $global:au_Latest
        $latest.Keys | ForEach-Object { $global:Latest.Remove($_) }
        $global:Latest += $latest
    }

    function update_files( [switch]$SkipNuspecFile )
    {
        'Updating files' | result
        '  $Latest data:' | result;  ($global:Latest.keys | Sort-Object | ForEach-Object { $v=$global:Latest[$_]; "    {0,-25} {1,-12} {2}" -f $_, "($( if ($v) { $v.GetType().Name } ))", $v }) | result

        if (!$SkipNuspecFile) {
            "  $(Split-Path $package.NuspecPath -Leaf)" | result

            "    setting id: $($global:Latest.PackageName)" | result
            $package.NuspecXml.package.metadata.id = $package.Name = $global:Latest.PackageName.ToString()

            $msg = "    updating version: {0} -> {1}" -f $package.NuspecVersion, $package.RemoteVersion
            if ($script:is_forced) {
                if ($package.RemoteVersion -eq $package.NuspecVersion) {
                    $msg = "    version not changed as it already uses 'revision': {0}" -f $package.NuspecVersion
                } else {
                    $msg = "    using Chocolatey fix notation: {0} -> {1}" -f $package.NuspecVersion, $package.RemoteVersion
                }
            }
            $msg | result

            $package.NuspecXml.package.metadata.version = $package.RemoteVersion.ToString()
            $package.SaveNuspec()
            if ($global:Latest.Stream) {
                $package.UpdateStream($global:Latest.Stream, $package.RemoteVersion)
            }
        }

        $sr = au_SearchReplace
        $sr.Keys | ForEach-Object {
            $fileName = $_
            "  $fileName" | result

            # If not specifying UTF8 encoding, then UTF8 without BOM encoded files
            # is detected as ANSI
            $fileContent = Get-Content $fileName -Encoding UTF8
            $sr[ $fileName ].GetEnumerator() | ForEach-Object {
                ('    {0,-35} = {1}' -f $_.name, $_.value) | result
                if (!($fileContent -match $_.name)) { throw "Search pattern not found: '$($_.name)'" }
                $fileContent = $fileContent -replace $_.name, $_.value
            }

            $useBomEncoding = if ($fileName.EndsWith('.ps1')) { $true } else { $false }
            $encoding = New-Object System.Text.UTF8Encoding($useBomEncoding)
            $output = $fileContent | Out-String
            [System.IO.File]::WriteAllText((Get-Item $fileName).FullName, $output, $encoding)
        }
    }

    function result() {
        if ($global:Silent) { return }

        $input | ForEach-Object {
            $package.Result += $_
            if (!$NoHostOutput) { Write-Host $_ }
        }
    }

    if ($PSCmdlet.MyInvocation.ScriptName -eq '') {
        Write-Verbose 'Running outside of the script'
        if (!(Test-Path update.ps1)) { return "Current directory doesn't contain ./update.ps1 script" } else { return ./update.ps1 }
    } else { Write-Verbose 'Running inside the script' }

    # Assign parameters from global variables with the prefix `au_` if they are bound
    (Get-Command $PSCmdlet.MyInvocation.InvocationName).Parameters.Keys | ForEach-Object {
        if ($PSBoundParameters.Keys -contains $_) { return }
        $value = Get-Variable "au_$_" -Scope Global -ea Ignore | ForEach-Object Value
        if ($value -ne $null) {
            Set-Variable $_ $value
            Write-Verbose "Parameter $_ set from global variable au_${_}: $value"
        }
    }

    if ($WhatIf) {  Write-Warning "WhatIf passed - package files will not be changed" }

    $package = [AUPackage]::new( $pwd )
    if ($Result) { Set-Variable -Scope Global -Name $Result -Value $package }

    $global:Latest = @{PackageName = $package.Name}

    if ($PSVersionTable.PSVersion.major -ge 6) {
        $AvailableTls = [enum]::GetValues('Net.SecurityProtocolType') | Where-Object { $_ -ge 'Tls' } # PowerShell 6+ does not support SSL3, so use TLS minimum
    } else {
        # https://github.com/majkinetor/au/issues/206
        $AvailableTls = [enum]::GetValues('Net.SecurityProtocolType') # This way we do not try to add something that is not supported on every version of Windows like Tls13
        #$AvailableTls = [enum]::GetValues('Net.SecurityProtocolType') | Where-Object { $_ -ge 'Tls' } If we want to enforce a minimum version
    }

    $AvailableTls.ForEach({[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $_})
    

    
    $module = $MyInvocation.MyCommand.ScriptBlock.Module
    "{0} - checking updates using {1} version {2}" -f $package.Name, $module.Name, $module.Version | result
    try {
        $res = au_GetLatest | Select-Object -Last 1
        $global:au_Latest = $global:Latest
        if ($res -eq $null) { throw 'au_GetLatest returned nothing' }

        if ($res -eq 'ignore') { return $res }

        $res_type = $res.GetType()
        if ($res_type -ne [HashTable]) { throw "au_GetLatest doesn't return a HashTable result but $res_type" }

        if ($global:au_Force) { $Force = $true }
        if ($global:au_IncludeStream) { $IncludeStream = $global:au_IncludeStream }
    } catch {
        throw "au_GetLatest failed`n$_"
    }

    if ($res.ContainsKey('Streams')) {
        if (!$res.Streams) { throw "au_GetLatest's streams returned nothing" }
        if ($res.Streams -isnot [System.Collections.Specialized.OrderedDictionary] -and $res.Streams -isnot [HashTable]) {
            throw "au_GetLatest doesn't return an OrderedDictionary or HashTable result for streams but $($res.Streams.GetType())"
        }

        # Streams are expected to be sorted starting with the most recent one
        $streams = @($res.Streams.Keys)
        # In case of HashTable (i.e. not sorted), let's sort streams alphabetically descending
        if ($res.Streams -is [HashTable]) { $streams = $streams | Sort-Object -Descending }

        if ($IncludeStream) {
            if ($IncludeStream -isnot [string] -and $IncludeStream -isnot [double] -and $IncludeStream -isnot [Array]) {
                throw "`$IncludeStream must be either a String, a Double or an Array but is $($IncludeStream.GetType())"
            }
            if ($IncludeStream -is [double]) { $IncludeStream = $IncludeStream -as [string] }
            if ($IncludeStream -is [string]) { 
                # Forcing type in order to handle case when only one version is included
                [Array] $IncludeStream = $IncludeStream -split ',' | ForEach-Object { $_.Trim() }
            }
        } elseif ($Force) {
            # When forcing update, a single stream is expected
            # By default, we take the first one (i.e. the most recent one)
            $IncludeStream = @($streams | Select-Object -First 1)
        }
        if ($Force -and (!$IncludeStream -or $IncludeStream.Length -ne 1)) { throw 'A single stream must be included when forcing package update' }

        if ($IncludeStream) { $streams = @($streams | Where-Object { $_ -in $IncludeStream }) }
        # Let's reverse the order in order to process streams starting with the oldest one
        [Array]::Reverse($streams)

        $res.Keys | Where-Object { $_ -ne 'Streams' } | ForEach-Object { $global:au_Latest.Remove($_) }
        $global:au_Latest += $res

        $allStreams = [System.Collections.Specialized.OrderedDictionary] @{}
        $streams | ForEach-Object {
            $stream = $res.Streams[$_]

            '' | result
            "*** Stream: $_ ***" | result

            if ($stream -eq $null) { throw "au_GetLatest's $_ stream returned nothing" }
            if ($stream -eq 'ignore') {
                $stream | result
                return
            }
            if ($stream -isnot [HashTable]) { throw "au_GetLatest's $_ stream doesn't return a HashTable result but $($stream.GetType())" }

            if ($package.Streams.$_.NuspecVersion -eq 'ignore') {
                'Ignored' | result
                return
            }

            set_latest $stream $package.Streams.$_.NuspecVersion $_
            process_stream

            $allStreams.$_ = if ($package.Streams.$_) { $package.Streams.$_.Clone() } else { @{} }
            $allStreams.$_.NuspecVersion = $package.NuspecVersion
            $allStreams.$_ += $package.GetStreamDetails()
        }
        $package.Updated = $false
        $package.Streams = $allStreams
        $package.Streams.Values | Where-Object { $_.Updated } | ForEach-Object {
            $package.NuspecVersion = $_.NuspecVersion
            $package.RemoteVersion = $_.RemoteVersion
            $package.Updated = $true
        }
    } else {
        '' | result
        set_latest $res $package.NuspecVersion
        process_stream
    }

    if ($package.Updated) {
        '' | result
        'Package updated' | result
    }

    return $package
}

Set-Alias update Update-Package

# SIG # Begin signature block
# MIIjgQYJKoZIhvcNAQcCoIIjcjCCI24CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDdJtFm7f7CinlV
# 4ppgBazTXrK+p9xBkbCTTZ9VdyNr+aCCHXowggUwMIIEGKADAgECAhAECRgbX9W7
# ZnVTQ7VvlVAIMA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMzEwMjIxMjAwMDBa
# Fw0yODEwMjIxMjAwMDBaMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lD
# ZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQD407Mcfw4Rr2d3B9MLMUkZz9D7RZmxOttE9X/l
# qJ3bMtdx6nadBS63j/qSQ8Cl+YnUNxnXtqrwnIal2CWsDnkoOn7p0WfTxvspJ8fT
# eyOU5JEjlpB3gvmhhCNmElQzUHSxKCa7JGnCwlLyFGeKiUXULaGj6YgsIJWuHEqH
# CN8M9eJNYBi+qsSyrnAxZjNxPqxwoqvOf+l8y5Kh5TsxHM/q8grkV7tKtel05iv+
# bMt+dDk2DZDv5LVOpKnqagqrhPOsZ061xPeM0SAlI+sIZD5SlsHyDxL0xY4PwaLo
# LFH3c7y9hbFig3NBggfkOItqcyDQD2RzPJ6fpjOp/RnfJZPRAgMBAAGjggHNMIIB
# yTASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAK
# BggrBgEFBQcDAzB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHow
# eDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJl
# ZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBPBgNVHSAESDBGMDgGCmCGSAGG/WwA
# AgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAK
# BghghkgBhv1sAzAdBgNVHQ4EFgQUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHwYDVR0j
# BBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDQYJKoZIhvcNAQELBQADggEBAD7s
# DVoks/Mi0RXILHwlKXaoHV0cLToaxO8wYdd+C2D9wz0PxK+L/e8q3yBVN7Dh9tGS
# dQ9RtG6ljlriXiSBThCk7j9xjmMOE0ut119EefM2FAaK95xGTlz/kLEbBw6RFfu6
# r7VRwo0kriTGxycqoSkoGjpxKAI8LpGjwCUR4pwUR6F6aGivm6dcIFzZcbEMj7uo
# +MUSaJ/PQMtARKUT8OZkDCUIQjKyNookAv4vcn4c10lFluhZHen6dGRrsutmQ9qz
# sIzV6Q3d9gEgzpkxYz0IGhizgZtPxpMQBvwHgfqL2vmCSfdibqFT+hKUGIUukpHq
# aGxEMrJmoecYpJpkUe8wggU5MIIEIaADAgECAhAKudMQ+yEr6IyBs9LC6M5RMA0G
# CSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0
# IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwHhcNMjEwNDI3MDAwMDAw
# WhcNMjQwNDMwMjM1OTU5WjB3MQswCQYDVQQGEwJVUzEPMA0GA1UECBMGS2Fuc2Fz
# MQ8wDQYDVQQHEwZUb3Bla2ExIjAgBgNVBAoTGUNob2NvbGF0ZXkgU29mdHdhcmUs
# IEluYy4xIjAgBgNVBAMTGUNob2NvbGF0ZXkgU29mdHdhcmUsIEluYy4wggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQChcaeNqeO3O3hzbDYYMcxvv/QNSPE4
# fpI+NGECR+FYdDO2utX9/SPxRCzWBrsgntPs/7IPk/uFZk/yTIiNoXO+cqJE45L9
# 2Ldfn6gAcwjGna/j2f/bbSFSeXW9z9lM3DJecFwXQleWR/8OKCnD+d1ZmHB0BA5v
# 0bQCfU8ZT7S0u9+KAKqyqgZrJyQiPfBVqXes9RSua7+0SVXmaBrJf9njHAf5KNFY
# /TEgm1r1zYwxfcsuE5eYdr2/suytUJpN18m9DmAdYm72va0KMxoKIBGuQy9DnaDI
# +nMiegsdhkL9sIysIin7Pcwjkwx9lRmtIqJA27Hfgb1MaL0OnkpwRY+VAgMBAAGj
# ggHEMIIBwDAfBgNVHSMEGDAWgBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAdBgNVHQ4E
# FgQUTvMFGF2V6ylQalFt+afRXjSaBIMwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQM
# MAoGCCsGAQUFBwMDMHcGA1UdHwRwMG4wNaAzoDGGL2h0dHA6Ly9jcmwzLmRpZ2lj
# ZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3JsMDWgM6Axhi9odHRwOi8vY3Js
# NC5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDBLBgNVHSAERDBC
# MDYGCWCGSAGG/WwDATApMCcGCCsGAQUFBwIBFhtodHRwOi8vd3d3LmRpZ2ljZXJ0
# LmNvbS9DUFMwCAYGZ4EMAQQBMIGEBggrBgEFBQcBAQR4MHYwJAYIKwYBBQUHMAGG
# GGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBOBggrBgEFBQcwAoZCaHR0cDovL2Nh
# Y2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3VyZWRJRENvZGVTaWdu
# aW5nQ0EuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggEBAKFxncHA
# zDFesUJXaM21qMRk5+nIZcDuISfGgJcDjMHsRLw7na5Yn7IhiNY+OsKnPVkfPhL/
# MNXSHG6on+IpxiB2/Bry9thqKvpQdPBe8mFN0ctJDgrSceyRC5SA9EiO22J3YNe0
# yVEKAG+Yk2A/WhKBzCCpRskMlRr7KeLm6DvAgvDsMfkKtePMl2PraON+tFNpc2b1
# LTKT4okiU5uAWpjYAt9sYBsKTeZb5NJt0ZQ3akEEIAQs63/mSDAZlzMOJMWNK/yv
# 4NU5CiPVcohJ0WjUJUIrAMmAVlZ2h8NhCXJOv28cHWEgPks/zqdDdIhJfDF+ALd1
# 0JTBrwCNcYQG68AwggWNMIIEdaADAgECAhAOmxiO+dAt5+/bUOIIQBhaMA0GCSqG
# SIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFz
# c3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBaFw0zMTExMDkyMzU5NTla
# MGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsT
# EHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9v
# dCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL/mkHNo3rvkXUo8
# MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3EMB/zG6Q4FutWxpdtHauy
# efLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKyunWZanMylNEQRBAu34Lz
# B4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsFxl7sWxq868nPzaw0QF+x
# embud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU15zHL2pNe3I6PgNq2kZhA
# kHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJBMtfbBHMqbpEBfCFM1Lyu
# GwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObURWBf3JFxGj2T3wWmIdph2
# PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6nj3cAORFJYm2mkQZK37A
# lLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxBYKqxYxhElRp2Yn72gLD7
# 6GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5SUUd0viastkF13nqsX40/
# ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+xq4aLT8LWRV+dIPyhHsXA
# j6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIBNjAPBgNVHRMBAf8EBTAD
# AQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwPTzAfBgNVHSMEGDAWgBRF
# 66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMCAYYweQYIKwYBBQUHAQEE
# bTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYB
# BQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3Vy
# ZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0aHR0cDovL2NybDMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDARBgNVHSAECjAI
# MAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0NcVec4X6CjdBs9thbX979X
# B72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnovLbc47/T/gLn4offyct4k
# vFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65ZyoUi0mcudT6cGAxN3J0TU
# 53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFWjuyk1T3osdz9HNj0d1pc
# VIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPFmCLBsln1VWvPJ6tsds5v
# Iy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9ztwGpn1eqXijiuZQwggau
# MIIElqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0GCSqGSIb3DQEBCwUAMGIxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAe
# Fw0yMjAzMjMwMDAwMDBaFw0zNzAzMjIyMzU5NTlaMGMxCzAJBgNVBAYTAlVTMRcw
# FQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3Rl
# ZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQDGhjUGSbPBPXJJUVXHJQPE8pE3qZdRodbSg9Ge
# TKJtoLDMg/la9hGhRBVCX6SI82j6ffOciQt/nR+eDzMfUBMLJnOWbfhXqAJ9/UO0
# hNoR8XOxs+4rgISKIhjf69o9xBd/qxkrPkLcZ47qUT3w1lbU5ygt69OxtXXnHwZl
# jZQp09nsad/ZkIdGAHvbREGJ3HxqV3rwN3mfXazL6IRktFLydkf3YYMZ3V+0VAsh
# aG43IbtArF+y3kp9zvU5EmfvDqVjbOSmxR3NNg1c1eYbqMFkdECnwHLFuk4fsbVY
# TXn+149zk6wsOeKlSNbwsDETqVcplicu9Yemj052FVUmcJgmf6AaRyBD40NjgHt1
# biclkJg6OBGz9vae5jtb7IHeIhTZgirHkr+g3uM+onP65x9abJTyUpURK1h0QCir
# c0PO30qhHGs4xSnzyqqWc0Jon7ZGs506o9UD4L/wojzKQtwYSH8UNM/STKvvmz3+
# DrhkKvp1KCRB7UK/BZxmSVJQ9FHzNklNiyDSLFc1eSuo80VgvCONWPfcYd6T/jnA
# +bIwpUzX6ZhKWD7TA4j+s4/TXkt2ElGTyYwMO1uKIqjBJgj5FBASA31fI7tk42Pg
# puE+9sJ0sj8eCXbsq11GdeJgo1gJASgADoRU7s7pXcheMBK9Rp6103a50g5rmQzS
# M7TNsQIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU
# uhbZbU2FL3MpdpovdYxqII+eyG8wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6
# mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcGCCsG
# AQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# MEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3Js
# My5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNVHSAE
# GTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAH1Z
# jsCTtm+YqUQiAX5m1tghQuGwGC4QTRPPMFPOvxj7x1Bd4ksp+3CKDaopafxpwc8d
# B+k+YMjYC+VcW9dth/qEICU0MWfNthKWb8RQTGIdDAiCqBa9qVbPFXONASIlzpVp
# P0d3+3J0FNf/q0+KLHqrhc1DX+1gtqpPkWaeLJ7giqzl/Yy8ZCaHbJK9nXzQcAp8
# 76i8dU+6WvepELJd6f8oVInw1YpxdmXazPByoyP6wCeCRK6ZJxurJB4mwbfeKuv2
# nrF5mYGjVoarCkXJ38SNoOeY+/umnXKvxMfBwWpx2cYTgAnEtp/Nh4cku0+jSbl3
# ZpHxcpzpSwJSpzd+k1OsOx0ISQ+UzTl63f8lY5knLD0/a6fxZsNBzU+2QJshIUDQ
# txMkzdwdeDrknq3lNHGS1yZr5Dhzq6YBT70/O3itTK37xJV77QpfMzmHQXh6OOmc
# 4d0j/R0o08f56PGYX/sr2H7yRp11LB4nLCbbbxV7HhmLNriT1ObyF5lZynDwN7+Y
# AN8gFk8n+2BnFqFmut1VwDophrCYoCvtlUG3OtUVmDG0YgkPCr2B2RP+v6TR81fZ
# vAT6gt4y3wSJ8ADNXcL50CN/AAvkdgIm2fBldkKmKYcJRyvmfxqkhQ/8mJb2VVQr
# H4D6wPIOK+XW+6kvRBVK5xMOHds3OBqhK/bt1nz8MIIGwjCCBKqgAwIBAgIQBUSv
# 85SdCDmmv9s/X+VhFjANBgkqhkiG9w0BAQsFADBjMQswCQYDVQQGEwJVUzEXMBUG
# A1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQg
# RzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMB4XDTIzMDcxNDAwMDAw
# MFoXDTM0MTAxMzIzNTk1OVowSDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMSAwHgYDVQQDExdEaWdpQ2VydCBUaW1lc3RhbXAgMjAyMzCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKNTRYcdg45brD5UsyPgz5/X5dLn
# XaEOCdwvSKOXejsqnGfcYhVYwamTEafNqrJq3RApih5iY2nTWJw1cb86l+uUUI8c
# IOrHmjsvlmbjaedp/lvD1isgHMGXlLSlUIHyz8sHpjBoyoNC2vx/CSSUpIIa2mq6
# 2DvKXd4ZGIX7ReoNYWyd/nFexAaaPPDFLnkPG2ZS48jWPl/aQ9OE9dDH9kgtXkV1
# lnX+3RChG4PBuOZSlbVH13gpOWvgeFmX40QrStWVzu8IF+qCZE3/I+PKhu60pCFk
# cOvV5aDaY7Mu6QXuqvYk9R28mxyyt1/f8O52fTGZZUdVnUokL6wrl76f5P17cz4y
# 7lI0+9S769SgLDSb495uZBkHNwGRDxy1Uc2qTGaDiGhiu7xBG3gZbeTZD+BYQfvY
# sSzhUa+0rRUGFOpiCBPTaR58ZE2dD9/O0V6MqqtQFcmzyrzXxDtoRKOlO0L9c33u
# 3Qr/eTQQfqZcClhMAD6FaXXHg2TWdc2PEnZWpST618RrIbroHzSYLzrqawGw9/sq
# hux7UjipmAmhcbJsca8+uG+W1eEQE/5hRwqM/vC2x9XH3mwk8L9CgsqgcT2ckpME
# tGlwJw1Pt7U20clfCKRwo+wK8REuZODLIivK8SgTIUlRfgZm0zu++uuRONhRB8qU
# t+JQofM604qDy0B7AgMBAAGjggGLMIIBhzAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0T
# AQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAgBgNVHSAEGTAXMAgGBmeB
# DAEEAjALBglghkgBhv1sBwEwHwYDVR0jBBgwFoAUuhbZbU2FL3MpdpovdYxqII+e
# yG8wHQYDVR0OBBYEFKW27xPn783QZKHVVqllMaPe1eNJMFoGA1UdHwRTMFEwT6BN
# oEuGSWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFJT
# QTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcmwwgZAGCCsGAQUFBwEBBIGDMIGA
# MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wWAYIKwYBBQUH
# MAKGTGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRH
# NFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcnQwDQYJKoZIhvcNAQELBQAD
# ggIBAIEa1t6gqbWYF7xwjU+KPGic2CX/yyzkzepdIpLsjCICqbjPgKjZ5+PF7SaC
# inEvGN1Ott5s1+FgnCvt7T1IjrhrunxdvcJhN2hJd6PrkKoS1yeF844ektrCQDif
# XcigLiV4JZ0qBXqEKZi2V3mP2yZWK7Dzp703DNiYdk9WuVLCtp04qYHnbUFcjGnR
# uSvExnvPnPp44pMadqJpddNQ5EQSviANnqlE0PjlSXcIWiHFtM+YlRpUurm8wWkZ
# us8W8oM3NG6wQSbd3lqXTzON1I13fXVFoaVYJmoDRd7ZULVQjK9WvUzF4UbFKNOt
# 50MAcN7MmJ4ZiQPq1JE3701S88lgIcRWR+3aEUuMMsOI5ljitts++V+wQtaP4xeR
# 0arAVeOGv6wnLEHQmjNKqDbUuXKWfpd5OEhfysLcPTLfddY2Z1qJ+Panx+VPNTwA
# vb6cKmx5AdzaROY63jg7B145WPR8czFVoIARyxQMfq68/qTreWWqaNYiyjvrmoI1
# VygWy2nyMpqy0tg6uLFGhmu6F/3Ed2wVbK6rr3M66ElGt9V/zLY4wNjsHPW2obhD
# LN9OTH0eaHDAdwrUAuBcYLso/zjlUlrWrBciI0707NMX+1Br/wd3H3GXREHJuEbT
# bDJ8WC9nR2XlG3O2mflrLAZG70Ee8PBf4NvZrZCARK+AEEGKMYIFXTCCBVkCAQEw
# gYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UE
# CxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1
# cmVkIElEIENvZGUgU2lnbmluZyBDQQIQCrnTEPshK+iMgbPSwujOUTANBglghkgB
# ZQMEAgEFAKCBhDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJ
# AzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8G
# CSqGSIb3DQEJBDEiBCD/JVWku8tUYGVR3N2UUoIe1frqgQXFzT2qNaYmCL/RHTAN
# BgkqhkiG9w0BAQEFAASCAQAETJcPwQNLixqOJW7UYPCf85L6L9bw/cpe1+eWIi8+
# UTbtq3zME7m5r2aSsF3cmdyz/46FeWABnyi7B1AH1frxLnTLDg4eiyLV4ql/KKDN
# M7iFkp/VpofIX12gIRHPhmkgM7A3xr3mdwS80rw+94PVtvKGm9PlUnZoLltRipEM
# w/l7ACCyErw/aJM1HHpN3Xpn095Yce8eNUpHxXmYxyEeWTTreNh6Whf69ePHScse
# c9BWXBb0c10H/qMJXwXnNI3a70fdYAOdv9O0nZ14FYl3k8zUSdmiZkLy6x/7qVHT
# egp8BXyH2rEMFfZgpyCFneqbNoe3a4djGZQ6D70wuT6VoYIDIDCCAxwGCSqGSIb3
# DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYg
# U0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQBUSv85SdCDmmv9s/X+VhFjANBglghkgB
# ZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkF
# MQ8XDTI0MDMxMTE3NDMzN1owLwYJKoZIhvcNAQkEMSIEIBgaLikfjXh1Yvqg+w0G
# PCd+UzPBlitWj6lIMgcZhdFrMA0GCSqGSIb3DQEBAQUABIICADss4aC5vMp7V14D
# EFhuEtxKZxWXnWkYRb74oAfCDkN8cQ81lyAG5/aD2ve0SEzKbo+p4z0RInZQRaK+
# HyMYZqeMqLK8xPgoVtgljrfI/MlksEinmvFzksQ2z/ik7j9M5aOnMv7o9KXuzykO
# 65AVrnxJxRMK1U1xfzEOUfCk6GeREywW91wSAiHp7LQQ5SrPsnlEANsVCXVNc9Mr
# jVJ2Re1zV80cyNyJjCs6hi/MEJYwUJpMiGp4bmlgDMagWA5Kvsqcokj7AnCgH51N
# uZbqiM0wKELmrQw/sXKpR1KjOrabwwJdoP/PmSgdNWaUgobiQW1zsFG/EyX+5xDT
# mya7EN86H6LzLwmt0/jGi68j7+YnGh48DpV+RQ0TA3R8emsldgyRUOOU+3724PMN
# Gje4uAzSvuJCWu3lu4X5kcPQ5fXIZQvhKgVpaEinzNPxvKrGNRM4T8fWYiKKkyRZ
# 3zlANv8GbLco/DY/j4oX9EQM6glcrsQDqirBYGhVfmIcyILD8DHzwdpNlJxinUea
# fKoXytSsHL2Lf5glTdbBCuOWnt1DYpfR2YAGHBLH/ajd032gfpEFqFXFu4Kajz/R
# qIMRLRZFZOEe8V7k16ezF7Z2KEK2UIC5X2mOCBDQuJo5S8FPIcKF6wqFaIG6T0tt
# 8G3bDW7slZQzt7qXWp+XwGxdL1Vm
# SIG # End signature block
