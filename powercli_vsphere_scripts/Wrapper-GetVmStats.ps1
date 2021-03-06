Param(
  [Parameter(Mandatory=$true)]
  $vCenter,
  [Parameter(Mandatory=$false)]
  $Throttle = 15,
  [Parameter(Mandatory=$true)]
  $NumGroups = 0,
  [Parameter(Mandatory=$true)]
  $Group = 0,
  [Parameter(Mandatory=$false)]
  $FilePath = 'D:\Store_Perf\Get-VmStats.ps1'
  )

Function Get-RunspaceData {
            [cmdletbinding()]
            param(
                [switch]$Wait
            )
            Do {
                $more = $false         
                Foreach($runspace in $runspaces) {
                    If ($runspace.RunspaceHandle.isCompleted) {
                        $runspace.powershell.EndInvoke($runspace.RunspaceHandle)
                        $runspace.powershell.dispose()
                        $runspace.RunspaceHandle = $null
                        $runspace.powershell = $null
                        $Script:i++                  
                    } ElseIf ($runspace.RunspaceHandle -ne $null) {
                        $more = $true
                    }
                }
                If ($more -AND $PSBoundParameters['Wait']) {
                    Start-Sleep -Milliseconds 100
                }   
                #Clean out unused runspace jobs
                $temphash = $runspaces.clone()
                $temphash | Where {
                    $_.runspaceHandle -eq $Null
                } | ForEach {
                    Write-Verbose ("Removing {0}" -f $_.store)
                    $Runspaces.remove($_)
                }             
            } while ($more -AND $PSBoundParameters['Wait'])
        }

try{
	Import-Module UcgModule -ArgumentList vmware -ErrorAction Stop -WarningAction SilentlyContinue
	Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group)`tImporting UcgModule and Vmware Modules" -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
	
	Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group)`tCreating Constant Variables" -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
	Set-Variable -Name Produri -Value 'http://localhost:8186/write' -Option:Constant
	Set-Variable -Name NonProduri -Value 'http://localhost:8086/write' -Option:Constant
	Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group)`tProduri : $($Produri), NonProduri : $($NonProduri)" -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
	
	try{Set-PowerCLIConfiguration -DefaultVIServerMode:Multiple -Confirm:$false -ErrorAction SilentlyContinue | Out-Null}catch{}

	Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group)`tConnecting to vCenter $($vCenter)" -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
	$vi = Connect-VIServer -Server $vCenter -WarningAction SilentlyContinue

	$scriptblock = [scriptblock]::Create((Get-Content $FilePath -ErrorAction Stop | Out-String))
	
	Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group)`tCreating the Runspace pool Environment" -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
	$Script:runspaces = New-Object System.Collections.ArrayList

	$sessionstate = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
	$sessionstate.ApartmentState = 'MTA'
	[Void]$sessionstate.ImportPSModule(@('VMware.VimAutomation.Core'))
	#[Void]$sessionstate.ImportPSSnapIn('VMware.VimAutomation.Core',[ref]$Null)

	$runspacepool = $runspacepool = [runspacefactory]::CreateRunspacePool(1, $Throttle, $sessionstate, $Host)
	$runspacePool.CleanupInterval = [timespan]::FromMinutes(2)
	$runspacepool.Open()
	$DCs = Get-Datacenter
	$groupSize = $DCs.Count/$NumGroups

	($DCs | Select -Skip ($groupSize*($Group-1)) ) | Select -First $groupSize | %{ $DC = $_
	  Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group)`tCreating powershell runspace for $($DC.Name)" -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
	  $PowerShell = [powershell]::Create().AddScript($scriptblock).AddArgument($vCenter).AddArgument($DC.Name).AddArgument($vi.SessionSecret)
	  $PowerShell.Runspacepool = $runspacepool

	  $temp = "" | Select-Object PowerShell,RunspaceHandle,Store
	  $Temp.Store = $DC.Name
	  $temp.PowerShell = $powershell

	  #Save the handle output when calling BeginInvoke() that will be used later to end the runspace
	  $temp.RunspaceHandle = $powershell.BeginInvoke()
	  $runspaces.Add($temp) | Out-Null
	}
	
	Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group)`tWaiting for ALL Stores to be processed..." -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
	$ReturnData = Get-RunspaceData -Wait
	$ReturnData.MetricsString | %{ $obj = $_; try{$store = $obj.Substring(($obj.indexOf("store="))+6,4)}catch{<#Do Nothing #>}
	  Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group)`tSending InfluxDB data for Store $($store)" -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
	  try{
      ( C:\Servutls\curl-1.0.exe -i -XPOST $Produri --data-binary $obj ) | Out-Null
	    Sleep -Milliseconds 100
    }catch [System.Management.Automation.ApplicationFailedException]{
      #If the curl command fails then it is likely due to the command line being too long. so lets reduce it.
      Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group) ERROR`tUnable to POST data for store $($store) to ProdUri DB. $($_.Exception.Message)" -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
	  Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group)`tSpliting the data for store $($store) in half and trying again.." -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
	  $hsh = @{}
      $tmp = $null; $tmp = $obj.Split("`n")
      $half = [Math]::Round(($tmp.Count/2)-1)
      $hsh[1] = @((0..$half) | %{ "$($tmp[$($_)])`n" -join "" })
      $hsh[2] = @((($half+1)..($tmp.Count-1)) | %{ "$($tmp[$($_)])`n" -join "" })
      
      $hsh.Values | %{ $val = $_
        ( C:\Servutls\curl-1.0.exe -i -XPOST $Produri --data-binary $val ) | Out-Null
		Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group) SUCCESS`tRetry for store $($store) to ProdUri DB was successful." -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
        Sleep -Milliseconds 100
      }
    }
	  
    try{
	    C:\Servutls\curl-1.0.exe -i -XPOST $NonProduri --data-binary $obj | Out-Null
	    Sleep -Milliseconds 100
    }catch [System.Management.Automation.ApplicationFailedException]{
      #If the curl command fails then it is likely due to the command line being too long. so lets reduce it.
      Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group) ERROR`tUnable to POST data for store $($store) to NonProdUri DB. $($_.Exception.Message)" -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
	  Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group)`tSpliting the data for store $($store) in half and trying again.." -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
	  $hsh = @{}
      $tmp = $null; $tmp = $obj.Split("`n")
      $half = [Math]::Round(($tmp.Count/2)-1)
      $hsh[1] = @((0..$half) | %{ "$($tmp[$($_)])`n" -join "" })
      $hsh[2] = @((($half+1)..($tmp.Count-1)) | %{ "$($tmp[$($_)])`n" -join "" })
      
      $hsh.Values | %{ $val = $_
        C:\Servutls\curl-1.0.exe -i -XPOST $NonProduri --data-binary $val | Out-Null
		Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group) SUCCESS`tRetry for store $($store) to NonProdUri DB was successful." -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
        Sleep -Milliseconds 100
      }
    }
	  
	}
	Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group) SUCCESS`tComplete." -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
}catch{
  Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group) ERROR`t$($_.Exception.Message)" -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
  #Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group) ERROR`t$($_.Exception)" -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
  Write-Log -Message "`n[$(Get-Date)]`tWrapper-GetVmStats.ps1|$($Env:COMPUTERNAME)|$($Group) ERROR`t$($Error[0])" -Path "$($ScriptyServerUNC)\Ucg-Logs\Wrapper-GetVmStats.log" -ErrorAction SilentlyContinue
}
