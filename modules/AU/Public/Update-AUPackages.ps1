
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
