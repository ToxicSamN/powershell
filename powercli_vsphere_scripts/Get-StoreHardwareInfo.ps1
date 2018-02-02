
function Get-VMHostNetworkAdapterCDP {
<#
 .SYNOPSIS
 Function to retrieve the Network Adapter CDP info of a vSphere host.

 .DESCRIPTION
 Function to retrieve the Network Adapter CDP info of a vSphere host.

 .PARAMETER VMHost
 A vSphere ESXi Host object

.INPUTS
 System.Management.Automation.PSObject.

.OUTPUTS
 System.Management.Automation.PSObject.

.EXAMPLE
 PS> Get-VMHostNetworkAdapterCDP -VMHost ESXi01,ESXi02

 .EXAMPLE
 PS> Get-VMHost ESXi01,ESXi02 | Get-VMHostNetworkAdapterCDP

#>
[CmdletBinding()][OutputType('System.Management.Automation.PSObject')]

Param
 (

[parameter(Mandatory=$true,ValueFromPipeline=$true)]
 [ValidateNotNullOrEmpty()]
 [PSObject[]]$VMHost
 )

begin {

 $ErrorActionPreference = 'Stop'
 Write-Debug $MyInvocation.MyCommand.Name
 $CDPObject = @()
 }

process{

try {
 foreach ($ESXiHost in $VMHost){

if ($ESXiHost.GetType().Name -eq "string"){

 try {
 $ESXiHost = Get-VMHost $ESXiHost -ErrorAction Stop
 }
 catch [Exception]{
 Write-Warning "VMHost $ESXiHost does not exist"
 }
 }

$ConfigManagerView = Get-View $ESXiHost.ConfigManager.NetworkSystem
 $PNICs = $ConfigManagerView.NetworkInfo.Pnic

foreach ($PNIC in $PNICs){

$PhysicalNicHintInfo = $ConfigManagerView.QueryNetworkHint($PNIC.Device)

if ($PhysicalNicHintInfo.ConnectedSwitchPort){

$Connected = $true
 }
 else {
 $Connected = $false
 }

$hash = @{

 VMHost = $ESXiHost.Name
 NIC = $PNIC.Device
 Connected = $Connected
 Switch = $PhysicalNicHintInfo.ConnectedSwitchPort.DevId
 HardwarePlatform = $PhysicalNicHintInfo.ConnectedSwitchPort.HardwarePlatform
 SoftwareVersion = $PhysicalNicHintInfo.ConnectedSwitchPort.SoftwareVersion
 MangementAddress = $PhysicalNicHintInfo.ConnectedSwitchPort.MgmtAddr
 PortId = $PhysicalNicHintInfo.ConnectedSwitchPort.PortId

}
 $Object = New-Object PSObject -Property $hash
 $CDPObject += $Object
 }
 }
 }
 catch [Exception] {

 return $null #throw "Unable to retrieve CDP info for $($ESXiHost.Name)"
 }
 }
 end {

 Write-Output $CDPObject
 }
}

Add-PSSnapin VM*
Import-Module UcgModule

cls

@("a0319p1201","a0319p1202","a0319p1203") | %{ $vc = $_
Connect-VIServer -Server $vc -Credential (Login-vCenter)

Get-View -ViewType HostSystem | %{ $esxi = $_; $esxi.Name
	#$cdpinfo = $esxi | Get-VMHostNetworkAdapterCDP
  if($esxi.Hardware.SystemInfo.Model){}
	$pso = New-Object PSObject -Property @{
		VMHost = $esxi.Name
		Model = $esxi.Hardware.SystemInfo.Model
		CPUModel = $esxi.Hardware.CpuPkg[0].Description
		CPUCores = ($esxi.Hardware.CpuInfo.NumCpuCores -as [int]) / ($esxi.Hardware.CpuInfo.NumCpuPackages -as [int])
		Memory = ($esxi.Hardware.MemorySize -as [float]) / 1073741824
	}
	[array]$report += $pso
}
Disconnect-VIServer -Server * -Confirm:$false -Force:$true
}
$report | Select VMHost,Model,CPUModel,CPUCores,Memory| Export-Csv C:\temp\store_hardware_profile_new_08232016.csv -NoTypeInformation