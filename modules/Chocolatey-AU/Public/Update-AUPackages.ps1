
 # Author: Miodrag Milic <miodrag.milic@gmail.com>
 # Last Change: 08-May-2018

<#
.SYNOPSIS
    Update all automatic packages

.DESCRIPTION
    Function Update-AUPackages will iterate over update.ps1 scripts and execute each. If it detects
    that a package is updated it will push it to the Chocolatey community repository.

    The function will look for AU packages in the directory pointed to by the global variable au_root
    or in the current directory if mentioned variable is not set.

    For the push to work, specify your API key in the file 'api_key' in the script's directory or use
    cached nuget API key or set environment variable '$Env:api_key'.

    The function accepts many options via ordered HashTable parameter Options.

.EXAMPLE
    Update-AUPackages p* @{ Threads = 5; Timeout = 10 }

    Update all automatic packages in the current directory that start with letter 'p' using 5 threads
    and web timeout of 10 seconds.

.EXAMPLE
    $au_root = 'c:\chocolatey'; updateall @{ Force = $true }

    Force update of all automatic ackages in the given directory.

.LINK
    Update-Package

.OUTPUTS
    AUPackage[]
#>
function Update-AUPackages {
    [CmdletBinding()]
    param(
        # Filter package names. Supports globs.
        [string[]] $Name,

        <#
        Hashtable with options:
          Threads           - Number of background jobs to use, by default 10.
          Timeout           - WebRequest timeout in seconds, by default 100.
          UpdateTimeout     - Timeout for background job in seconds, by default 1200 (20 minutes).
          Force             - Force package update even if no new version is found.
          Push              - Set to true to push updated packages to Chocolatey community repository.
          PushAll           - Set to true to push all updated packages and not only the most recent one per folder.
          WhatIf            - Set to true to set WhatIf option for all packages.
          PluginPath        - Additional path to look for user plugins. If not set only module integrated plugins will work
          NoCheckChocoVersion  - Set to true to set NoCheckChocoVersion option for all packages.

          Plugin            - Any HashTable key will be treated as plugin with the same name as the option name.
                              A script with that name will be searched for in the AU module path and user specified path.
                              If script is found, it will be called with splatted HashTable passed as plugin parameters.

                              To list default AU plugins run:

                                    ls "$(Split-Path (gmo au -list).Path)\Plugins\*.ps1"
          IgnoreOn          - Array of strings, error messages that packages will get ignored on
          RepeatOn          - Array of strings, error messages that package updaters will run again on
          RepeatCount       - Number of repeated runs to do when given error occurs, by default 1
          RepeatSleep       - How long to sleep between repeast, by default 0

          BeforeEach        - User ScriptBlock that will be called before each package and accepts 2 arguments: Name & Options.
                              To pass additional arguments, specify them as Options key/values.
          AfterEach         - Similar as above.
          Script            - Script that will be called before and after everything.
        #>
        [System.Collections.Specialized.OrderedDictionary] $Options=@{},

        #Do not run plugins, defaults to global variable `au_NoPlugins`.
        [switch] $NoPlugins = $global:au_NoPlugins
    )

    $startTime = Get-Date

    if (!$Options.Threads)      { $Options.Threads       = 10 }
    if (!$Options.Timeout)      { $Options.Timeout       = 100 }
    if (!$Options.UpdateTimeout){ $Options.UpdateTimeout = 1200 }
    if (!$Options.Force)        { $Options.Force         = $false }
    if (!$Options.Push)         { $Options.Push          = $false }
    if (!$Options.PluginPath)   { $Options.PluginPath    = '' }
    if (!$Options.NoCheckChocoVersion){ $Options.NoCheckChocoVersion	= $false }

    Remove-Job * -force #remove any previously run jobs

    $tmp_dir = ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "chocolatey", "au"))
    New-Item -Type Directory  -ea 0 $tmp_dir | Out-Null
    Get-ChildItem $tmp_dir | Where-Object PSIsContainer -eq $false | Remove-Item   #clear tmp dir files

    $aup = Get-AUPackages $Name
    Write-Host 'Updating' $aup.Length  'automatic packages at' $($startTime.ToString("s") -replace 'T',' ') $(if ($Options.Force) { "(forced)" } else {})
    Write-Host 'Push is' $( if ($Options.Push) { 'enabled' } else { 'disabled' } )
    Write-Host 'NoCheckChocoVersion is' $( if ($Options.NoCheckChocoVersion) { 'enabled' } else { 'disabled' } )
    if ($Options.Force) { Write-Host 'FORCE IS ENABLED. All packages will be updated' }

    $script_err = 0
    if ($Options.Script) { try { & $Options.Script 'START' $aup | Write-Host } catch { Write-Error $_; $script_err += 1 } }

    $threads = New-Object object[] $Options.Threads
    $result  = @()
    $j = $p  = 0
    while( $p -ne $aup.length ) {

        # Check for completed jobs
        foreach ($job in (Get-Job | Where-Object state -ne 'Running')) {
            $p += 1

            if ( 'Stopped', 'Failed', 'Completed' -notcontains $job.State) { 
                Write-Host "Invalid job state for $($job.Name): " $job.State
            }
            else {
                Write-Verbose ($job.State + ' ' + $job.Name)

                if ($job.ChildJobs[0].JobStateInfo.Reason.Message) {
                    $pkg = [AUPackage]::new((Get-AuPackages $job.Name))
                    $pkg.Error = $job.ChildJobs[0].JobStateInfo.Reason.Message
                } else {
                    $pkg = $null
                    Receive-Job $job | Set-Variable pkg

                    $ignored = $pkg -eq 'ignore'
                    if ( !$pkg -or $ignored ) {
                        $pkg = [AUPackage]::new( (Get-AuPackages $($job.Name)) )

                        if ($ignored) {
                            $pkg.Result = @('ignored', '') + (Get-Content ([System.IO.Path]::Combine($tmp_dir, $pkg.Name)) -ea 0)
                            $pkg.Ignored = $true
                            $pkg.IgnoreMessage = $pkg.Result[-1]
                        } elseif ($job.State -eq 'Stopped') {
                            $pkg.Error = "Job terminated due to the $($Options.UpdateTimeout)s UpdateTimeout"
                        } else {
                            $pkg.Error = 'Job returned no object, Vector smash ?'
                        }
                    } else {
                        $pkg = [AUPackage]::new($pkg)
                    }
                }
                Remove-Job $job

                $jobseconds = ($job.PSEndTime.TimeOfDay - $job.PSBeginTime.TimeOfDay).TotalSeconds
                $message = "[$($p)/$($aup.length)] " + $pkg.Name + ' '
                $message += if ($pkg.Updated) { 'is updated to ' + $pkg.RemoteVersion } else { 'has no updates' }
                if ($pkg.Updated -and $Options.Push) {
                    $message += if (!$pkg.Pushed) { ' but push failed!' } else { ' and pushed'}
                }
                if ($pkg.Error) {
                    $message = "[$($p)/$($aup.length)] $($pkg.Name) ERROR: "
                    $message += $pkg.Error.ToString() -split "`n" | ForEach-Object { "`n" + ' '*5 + $_ }
                }
                $message+= " ({0:N2}s)" -f $jobseconds
                Write-Host '  ' $message

                $result += $pkg
            }
        }

        # Sleep a bit and check for running tasks update timeout
        $job_count = Get-Job | Measure-Object | ForEach-Object count
        if (($job_count -eq $Options.Threads) -or ($j -eq $aup.Length)) {
            Start-Sleep 1
            foreach ($job in $(Get-Job -State Running)) {
               $elapsed = ((get-date) - $job.PSBeginTime).TotalSeconds
               if ($elapsed -ge $Options.UpdateTimeout) { Stop-Job $job }
            }
            continue
        }

        # Start a new thread
        $package_path = $aup[$j++]
        $package_name = Split-Path $package_path -Leaf
        Write-Verbose "Starting $package_name"
        Start-Job -Name $package_name {         #TODO: fix laxxed variables in job for BE and AE
            function repeat_ignore([ScriptBlock] $Action) { # requires $Options
                $run_no = 0
                $run_max = if ($Options.RepeatOn) { if (!$Options.RepeatCount) { 2 } else { $Options.RepeatCount+1 } } else {1}

                :main while ($run_no -lt $run_max) {
                    $run_no++
                    try {
                        $res = & $Action 6> $out
                        break main
                    } catch {
                        if ($run_no -ne $run_max) {
                            foreach ($msg in $Options.RepeatOn) { 
                                if ($_.Exception -notlike "*${msg}*") { continue }
                                Write-Warning "Repeating $using:package_name ($run_no): $($_.Exception)"
                                if ($Options.RepeatSleep) { Write-Warning "Sleeping $($Options.RepeatSleep) seconds before repeating"; Start-Sleep $Options.RepeatSleep }
                                continue main
                            }
                        }
                        foreach ($msg in $Options.IgnoreOn) { 
                            if ($_.Exception -notlike "*${msg}*") { continue }
                            Write-Warning "Ignoring $using:package_name ($run_no): $($_.Exception)"
                            "AU ignored on: $($_.Exception)" | Out-File -Append $out
                            $res = 'ignore'
                            break main
                        }
                        $type = if ($res) { $res.GetType() }
                        if ( "$type" -eq 'AUPackage') { $res.Error = $_ } else { throw }
                    }
                }
                $res
            }

            $Options = $using:Options

            Set-Location $using:package_path
            $out = (Join-Path $using:tmp_dir $using:package_name)

            $global:au_Timeout = $Options.Timeout
            $global:au_Force   = $Options.Force
            $global:au_WhatIf  = $Options.WhatIf
            $global:au_Result  = 'pkg'
            $global:au_NoCheckChocoVersion = $Options.NoCheckChocoVersion

            if ($Options.BeforeEach) {
                $s = [Scriptblock]::Create( $Options.BeforeEach )
                . $s $using:package_name $Options
            }
            
            $pkg = repeat_ignore { ./update.ps1 }
            if (!$pkg) { throw "'$using:package_name' update script returned nothing" }
            if (($pkg -eq 'ignore') -or ($pkg[-1] -eq 'ignore')) { return 'ignore' }

            $pkg  = $pkg[-1]
            $type = $pkg.GetType()
            if ( "$type" -ne 'AUPackage') { throw "'$using:package_name' update script didn't return AUPackage but: $type" }

            if ($pkg.Updated -and $Options.Push) {
                $res = repeat_ignore { 
                    $r = Push-Package -All:$Options.PushAll
                    if ($LastExitCode -eq 0) { return $r } else { throw $r }
                }
                if (($res -eq 'ignore') -or ($res[-1] -eq 'ignore')) { return 'ignore' }

                if ($res -is [System.Management.Automation.ErrorRecord]) {
                    $pkg.Error = "Push ERROR`n" + $res
                } else {
                    $pkg.Pushed = $true 
                    $pkg.Result += $res 
                } 
            }
            
            if ($Options.AfterEach) {
                $s = [Scriptblock]::Create( $Options.AfterEach )
                . $s $using:package_name $Options
            }

            $pkg.Serialize()
        } | Out-Null
    }
    $result = $result | Sort-Object Name

    $info = get_info
    run_plugins

    if ($Options.Script) { try { & $Options.Script 'END' $info | Write-Host } catch { Write-Error $_; $script_err += 1 } }

    @('') + $info.stats + '' | Write-Host

    $result
}

function run_plugins() {
    if ($NoPlugins) { return }

    Remove-Item -Force -Recurse (Join-Path $tmp_dir 'plugins') -ea ig
    New-Item -Type Directory -Force (Join-Path $tmp_dir 'plugins') | Out-Null
    foreach ($key in $Options.Keys) {
        $params = $Options.$key
        if ($params -isnot [HashTable]) { continue }

        $plugin_path = "$PSScriptRoot/../Plugins/$key.ps1"
        if (!(Test-Path $plugin_path)) {
            if([string]::IsNullOrWhiteSpace($Options.PluginPath)) { continue }

            $plugin_path = $Options.PluginPath + "/$key.ps1"
            if(!(Test-Path $plugin_path)) { continue }
        }

        try {
            Write-Host "`nRunning $key"
            & $plugin_path $Info @params *>&1 | Tee-Object ([System.IO.Path]::Combine($tmp_dir, 'plugins', $key)) | Write-Host
            $info.plugin_results.$key += Get-Content ([System.IO.Path]::Combine($tmp_dir, 'plugins', $key)) -ea ig
        } catch {
            $err_lines = $_.ToString() -split "`n"
            Write-Host "  ERROR: " $(foreach ($line in $err_lines) { "`n" + ' '*4 + $line })
            $info.plugin_errors.$key = $_.ToString()
        }
    }
}


function get_info {
    $errors = $result | Where-Object { $_.Error }
    $info = [PSCustomObject]@{
        result = [PSCustomObject]@{
            all     = $result
            ignored = $result | Where-Object Ignored
            errors  = $errors
            ok      = $result | Where-Object { !$_.Error }
            pushed  = $result | Where-Object Pushed
            updated = $result | Where-Object Updated
        }

        error_count = [PSCustomObject]@{
            update  = $errors | Where-Object {!$_.Updated} | Measure-Object | ForEach-Object count
            push    = $errors | Where-Object {$_.Updated -and !$_.Pushed} | Measure-Object | ForEach-Object count
            total   = $errors | Measure-Object | ForEach-Object count
        }
        error_info  = ''

        packages  = $aup
        startTime = $startTime
        minutes   = ((Get-Date) - $startTime).TotalMinutes.ToString('#.##')
        pushed    = $result | Where-Object Pushed  | Measure-Object | ForEach-Object count
        updated   = $result | Where-Object Updated | Measure-Object | ForEach-Object count
        ignored   = $result | Where-Object Ignored | Measure-Object | ForEach-Object count
        stats     = ''
        options   = $Options
        plugin_results = @{}
        plugin_errors = @{}
    }
    $info.PSObject.TypeNames.Insert(0, 'AUInfo')

    $info.stats = get-stats
    $info.error_info = $errors | ForEach-Object {
        "`nPackage: " + $_.Name + "`n"
        $_.Error
    }

    $info
}

function get-stats {
    "Finished {0} packages after {1} minutes.  " -f $info.packages.length, $info.minutes
    "{0} updated, {1} pushed, {2} ignored  " -f $info.updated, $info.pushed, $info.ignored
    "{0} errors - {1} update, {2} push.  " -f $info.error_count.total, $info.error_count.update, $info.error_count.push
}


Set-Alias updateall Update-AuPackages

# SIG # Begin signature block
# MIIjgQYJKoZIhvcNAQcCoIIjcjCCI24CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB9ZnVrj7G1GdNT
# yXxCmK4RZeyMh7M59Nf/9wnKh2RwzaCCHXowggUwMIIEGKADAgECAhAECRgbX9W7
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
# CSqGSIb3DQEJBDEiBCDXEh4lf5iIkHuWhgAUPNhJdbZW2/kP/HepMNjovsFKVDAN
# BgkqhkiG9w0BAQEFAASCAQCSjM4VqJebV4LErFj/bY/nU/OEfQIcgp4HjqKye4i6
# 1a1WoKV13dw7djPZCZfSjX3ckzqKs5iT8bsyurYqpYNpaluP3+vl1dBHEOG/tImP
# YRvuAL5IAN7tncQ33i1d4A3bWQz/W2ixRf7sx99hg9usgONuLt+7I1TPHBUwTRjC
# er8iV9G7UITmmEXuHvzNodsMJc5U7I8hNXFbV2ZipCQvK37ov8P4GXo0ty9PC+BC
# E5LfSHpBAzfZeAIcbeODVPi6QQeyXR4i5vG0qyaS4widTB+PBGFdJ7dZxibSGEYU
# 3TGoGeK9TnClsNSissZAB1vLp5K/kCX/eVZdI160ICx2oYIDIDCCAxwGCSqGSIb3
# DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYg
# U0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQBUSv85SdCDmmv9s/X+VhFjANBglghkgB
# ZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkF
# MQ8XDTI0MDMxMTE3NDMzN1owLwYJKoZIhvcNAQkEMSIEIChiUkN0XjdtZqDijfHu
# Df96ZRH8VVaw/ihVpfJbkAUCMA0GCSqGSIb3DQEBAQUABIICAHSCPw6dx/NFLxBQ
# kdFfB5TryPcYDx2PyANfxnJHa58ENyp/7COPv1eKvaF4Nnhvk0mRvRB6EbG6smwX
# 1Vr9/2qmZJIHFPIAA/Kayq7VqBmwJd5LURJjekX7DvJSSc9dKA02Lmmgmm9y5Ynk
# 72oLeCPh/f3lm+HsUfALl1C5BFAoASchuN0/NZa0HLU4AsbzlTHz+Px7bmd+c1Kq
# oBl+gYwkX1xWYQZrpiQmSvMi7OOsCIXLZTN4DRPdkMC1Vi07EBYlycfvCgNi4gWB
# /Cpr3kyJInh8t+BwYSIhV6DyJ4EaHKyEbhBOU1khKz2PbdZyQFUgenHpSen5AT/p
# moWQy/T5AzXgWJghOMuDVQNGQ8eHXlsEIDMBuZk0oCtln5Q+HqUY72BqqrQmjNCe
# T1n5xaqdlYLPWq8C2z3m63smY0wP9nPqwoOWpyUSytTzLFh1GPSLzJRmt4ZaRK5T
# XpEOKJxNlaJA+qkG1rIGO9lv6YciJ9jvH3xslrtwrJluc1lSTdlOJ6bFCSOooBtk
# fm5LZKR1DZYm5gvlRDrIiChnwl96KAfsF3+GvCVMJnhpEJuRRjsul1AVHLe4iKZ5
# O0PW+A3XWzrVN0dxvRgCO3bDZMgZIhPshAV7rB6Ht0WDIEhpy8C17BgNTU8CWO0t
# o5B1SEDMuqgiLsA6N3A/DP46MQBD
# SIG # End signature block
