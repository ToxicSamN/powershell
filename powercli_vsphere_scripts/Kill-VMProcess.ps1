<#
.SYNOPSIS
    Forcibly shuts down the virtual machine
.DESCRIPTION
    In some cases, virtual machines do not respond to the normal shutdown or stop commands. In these cases, 
	it might be necessary to forcibly shut down the virtual machines. Forcibly shutting down a virtual machine 
	might result in guest operating system data loss and is similar to pulling the power cable on a physical 
	machine.
	You can forcibly stop virtual machines that are not responding to normal stop operation with the 
	esxcli vm process kill command.
.PARAMETER vCenter
    MANDATORY
	String parameter that specifies the IP address or DNS name of the vCenter you want to connect.
.PARAMETER Cluster
    MANDATORY
	String parameter that specifies the name of the cluster to search.
.PARAMETER VM
	MANDATORY
    String parameter that specifies the name of the virtual machine to search for.
.PARAMETER Soft
    Switch paramter that specifies the esxcli vm process kill --type as SOFT. Gives the VMX process a chance to shut down cleanly.
.PARAMETER Hard
	Switch paramter that specifies the esxcli vm process kill --type as HARD. Stops the VMX process immediately.
.PARAMETER Force
	Switch paramter that specifies the esxcli vm process kill --type as FORCE. Stops the VMX process when other options do not work.
.PARAMETER Confirm
	Boolean. prompts the user for permission before performing any action that modifies the system.
.EXAMPLE
    C:\PS> .\Kill-VMProcess.ps1 -vCenter y0319t1919 -Cluster cl0319ucg04t001 -VM "New Virtual Machine" -Soft -Confirm:$false
		Locates the VM process for VM 'New Virtual Machine' and stops it with --type option SOFT to attempt to shut down cleanly while supressing any confirmation messages.
.EXAMPLE
	C:\PS> .\Kill-VMProcess.ps1 -vCenter y0319t1919 -Cluster cl0319ucg04t001 -VM "New Virtual Machine" -Force -Confirm
		Locates the VM process for VM 'New Virtual Machine' and stops it with --type option FORCE to attempt to shut down immediately while prompting for confirmation.
.NOTES
    Author: Sammy Shuck
    Date:   June 13, 2016
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true,Position=1,HelpMessage="Specifies the IP address or DNS name of the vCenter you want to connect.")]
	[string]$vCenter,
	[Parameter(Mandatory=$true,Position=2,HelpMessage="Specifies the name of the cluster to search.")]
	[string]$Cluster,
	[Parameter(Mandatory=$true,Position=3,HelpMessage="Specifies the name of the virtual machine to search for.")]
	[string]$VM,
	[Parameter(Mandatory=$false,HelpMessage="Specifies the esxcli vm process kill --type as SOFT. Gives the VMX process a chance to shut down cleanly.")]
	[Alias("s")]
	[switch]$Soft,
	[Parameter(Mandatory=$false,HelpMessage="Specifies the esxcli vm process kill --type as HARD. Stops the VMX process immediately.")]
	[Alias("h")]
	[switch]$Hard,
	[Parameter(Mandatory=$false,HelpMessage="Specifies the esxcli vm process kill --type as FORCE. Stops the VMX process when other options do not work.")]
	[Alias("f")]
	[switch]$Force,
	[Parameter(Mandatory=$false,HelpMessage="Boolean. prompts the user for permission before performing any action that modifies the system.")]
	[switch]$Confirm=$true
)

Function Kill-VMProcess{
<#
.SYNOPSIS
    Forcibly shuts down the virtual machine
.DESCRIPTION
    In some cases, virtual machines do not respond to the normal shutdown or stop commands. In these cases, 
	it might be necessary to forcibly shut down the virtual machines. Forcibly shutting down a virtual machine 
	might result in guest operating system data loss and is similar to pulling the power cable on a physical 
	machine.
	You can forcibly stop virtual machines that are not responding to normal stop operation with the 
	esxcli vm process kill command.
.PARAMETER vCenter
    MANDATORY
	String parameter that specifies the IP address or DNS name of the vCenter you want to connect.
.PARAMETER Cluster
    MANDATORY
	String parameter that specifies the name of the cluster to search.
.PARAMETER VM
	MANDATORY
    String parameter that specifies the name of the virtual machine to search for.
.PARAMETER Soft
    Switch paramter that specifies the esxcli vm process kill --type as SOFT. Gives the VMX process a chance to shut down cleanly.
.PARAMETER Hard
	Switch paramter that specifies the esxcli vm process kill --type as HARD. Stops the VMX process immediately.
.PARAMETER Force
	Switch paramter that specifies the esxcli vm process kill --type as FORCE. Stops the VMX process when other options do not work.
.PARAMETER Confirm
	Boolean. prompts the user for permission before performing any action that modifies the system.
.EXAMPLE
    C:\PS> .\Kill-VMProcess.ps1 -vCenter y0319t1919 -Cluster cl0319ucg04t001 -VM "New Virtual Machine" -Soft -Confirm:$false
		Locates the VM process for VM 'New Virtual Machine' and stops it with --type option SOFT to attempt to shut down cleanly while supressing any confirmation messages.
    C:\PS> .\Kill-VMProcess.ps1 -vCenter y0319t1919 -Cluster cl0319ucg04t001 -VM "New Virtual Machine" -Force -Confirm
		Locates the VM process for VM 'New Virtual Machine' and stops it with --type option FORCE to attempt to shut down immediately while prompting for confirmation.
.NOTES
    Author: Sammy Shuck
    Date:   June 13, 2016
#>
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true,Position=2,HelpMessage="Specifies the name of the cluster to search.")]
		[string]$Cluster,
		[Parameter(Mandatory=$true,Position=3,HelpMessage="Specifies the name of the virtual machine to search for.")]
		[string]$VM,
		[Parameter(Mandatory=$false,HelpMessage="Specifies the esxcli vm process kill --type as SOFT. Gives the VMX process a chance to shut down cleanly.")]
		[switch]$Soft,
		[Parameter(Mandatory=$false,HelpMessage="Specifies the esxcli vm process kill --type as HARD. Stops the VMX process immediately.")]
		[switch]$Hard,
		[Parameter(Mandatory=$false,HelpMessage="Specifies the esxcli vm process kill --type as FORCE. Stops the VMX process when other options do not work.")]
		[switch]$Force,
		[Parameter(Mandatory=$false,HelpMessage="Boolean. prompts the user for permission before performing any action that modifies the system.")]
		[switch]$Confirm
	)
	Begin{
		try{
			$clObj = Get-VmCluster -Name $Cluster -ErrorAction Stop
			$cl = Get-View $clObj
		}catch{
			Write-Error $_.Exception.Message
			throw $_
		}
	}
	Process{
		try{
			$cl.Host | %{
				$esxi = Get-VIObjectByVIView -MORef $_ -ErrorAction Stop
				$esxcli = Get-EsxCli -VMHost $esxi -ErrorAction Stop
				$vmProcess = $null
				$vmProcess = $esxcli.vm.process.list() | ?{$_.DisplayName -eq $VM}
				If(-not [string]::IsNullOrEmpty($vmProcess)){
					$vmProcess
					Write-Host "Found the VM Process on VMHost $($esxi.Name)" -ForegroundColor Cyan -BackgroundColor Black
					[char]$confirmAns = "y"
					If($Soft){
						If($Confirm){
							Write-Host "`nPlease confirm you want to terminate this VM Process with --Type=SOFT  (y/n) " -ForegroundColor Yellow -BackgroundColor Black
							[char]$confirmAns = Read-Host -ErrorAction Stop
						}
						If($confirmAns -eq "y"){
							Write-Host "`nStopping VM Process for VM $($vmProcess.DisplayName) WorldID $($vmProcess.WorldID)"
							#esxcli vm process kill --type=[soft,hard,force] --worl-id=[vm-world-id]
							$esxcli.vm.process.kill("soft",$vmProcess.WorldID)
						}
					}ElseIf($Hard){
						If($Confirm){
							Write-Host "`nPlease confirm you want to terminate this VM Process with --Type=HARD  (y/n) " -ForegroundColor Yellow -BackgroundColor Black
							[char]$confirmAns = Read-Host -ErrorAction Stop
						}
						If($confirmAns -eq "y"){
							Write-Host "`nStopping VM Process for VM $($vmProcess.DisplayName) WorldID $($vmProcess.WorldID)"
							#esxcli vm process kill --type=[soft,hard,force] --worl-id=[vm-world-id]
							$esxcli.vm.process.kill("hard",$vmProcess.WorldID)
						}
					}ElseIf($Force){
						If($Confirm){
							Write-Host "`nPlease confirm you want to terminate this VM Process with --Type=FORCE  (y/n) " -ForegroundColor Yellow -BackgroundColor Black
							[char]$confirmAns = Read-Host -ErrorAction Stop
						}
						If($confirmAns -eq "y"){
							Write-Host "`nStopping VM Process for VM $($vmProcess.DisplayName) WorldID $($vmProcess.WorldID)"
							#esxcli vm process kill --type=[soft,hard,force] --worl-id=[vm-world-id]
							$esxcli.vm.process.kill("force",$vmProcess.WorldID)
						}
					}
					break;
				}
			}
		}catch{
			Write-Error $_.Exception.Message
			throw $_
		}
	}
}
function Get-InstallPath {
#Function provided by VMware used by PowerCLI to initialize Snapins
# Initialize-PowerCLIEnvironment.ps1
   $regKeys = Get-ItemProperty "hklm:\software\VMware, Inc.\VMware vSphere PowerCLI" -ErrorAction SilentlyContinue
   
   #64bit os fix
   if($regKeys -eq $null){
      $regKeys = Get-ItemProperty "hklm:\software\wow6432node\VMware, Inc.\VMware vSphere PowerCLI"  -ErrorAction SilentlyContinue
   }

   return $regKeys.InstallPath
}
function LoadSnapins(){
   [xml]$xml = Get-Content ("{0}\vim.psc1" -f (Get-InstallPath))
   $snapinList = Select-Xml  "//PSSnapIn" $xml |%{$_.Node.Name }

   $loaded = Get-PSSnapin -Name $snapinList -ErrorAction SilentlyContinue | % {$_.Name}
   $registered = Get-PSSnapin -Name $snapinList -Registered -ErrorAction SilentlyContinue  | % {$_.Name}
   $notLoaded = $registered | ? {$loaded -notcontains $_}
   
   foreach ($snapin in $registered) {
      if ($loaded -notcontains $snapin) {
         Add-PSSnapin $snapin -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
      }

      # Load the Intitialize-<snapin_name_with_underscores>.ps1 file
      # File lookup is based on install path instead of script folder because the PowerCLI
      # shortuts load this script through dot-sourcing and script path is not available.
      $filePath = "{0}Scripts\Initialize-{1}.ps1" -f (Get-InstallPath), $snapin.ToString().Replace(".", "_")
      if (Test-Path $filePath) {
         & $filePath
      }
   }
}
function LoadModules(){
   [xml]$xml = Get-Content ("{0}\vim.psc1" -f (Get-InstallPath))
   $moduleList = Select-Xml  "//PSModule" $xml |%{$_.Node.Name }

   $loaded = Get-Module -Name $moduleList -ErrorAction SilentlyContinue | % {$_.Name}
   $registered = Get-Module -Name $moduleList -ListAvailable -ErrorAction SilentlyContinue  | % {$_.Name}
   $notLoaded = $registered | ? {$loaded -notcontains $_}
   
   foreach ($module in $registered) {
      if ($loaded -notcontains $module) {
         Import-Module $module -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
      }
   }
}
LoadSnapins
LoadModules
Import-Module UcgModule -ErrorAction Stop -WarningAction SilentlyContinue
cls
Connect-VIServer -Server $vCenter -ErrorAction Stop
If(-not $Soft -and -not $Hard -and -not $Force){ 
	Write-Error "Unable to determine the process kill type option [Soft,Hard,Force].`nPlease use Get-Help $($MyInvocation.MyCommand.Definition) for more details."
	Get-Command -CommandType:ExternalScript -Name $MyInvocation.MyCommand.Definition -Syntax
}Else{
	Kill-VMProcess -Cluster $Cluster -VM $VM -Soft:$Soft.IsPresent -Hard:$Hard.IsPresent -Force:$Force.IsPresent -Confirm:$Confirm.IsPresent
}
Disconnect-VIServer * -Confirm:$false -ErrorAction SilentlyContinue