
<#
Script Name: CreateSharedVMDK.ps1
Description: Creates an initial shared VMDK and attaches this VMDK file to the server the user inputs. This script also ZeroOut the new VMDK file.
			 
Parameters :  The script accepts the follwoing command line parameters:
			    -vcenter  -vm  -datastore  -diskpath  -disksizekb

Created by : Sammy Shuck
Owned by   : Unified Computing Group (UCG), Nordstrom IT

Date of Release: 4/16/2012

This script is intended for the use of Nordstrom, Inc for the purposes of internal use. This code is not to be distributed to third parties without consent
from its creator Sammy Shuck or owner Unified Computing Group (UCG), Nordstrom IT.
#>

Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue
Import-Module UcgModule
Disconnect-VIServer -Server $vCenter -Confirm:$false
CLS

$ArgCount = 1
$esxihost = $null
ForEach ($argument in $args)
{
	[string] $argument = $argument
	
	If($argument.ToLower() -like "*-vcenter*") {$vCenter = $args[$ArgCount]}
	If($argument.ToLower() -like "*-vm*") {$VM = $args[$ArgCount]}
	If($argument.ToLower() -like "*-datastore*") {$Datastore = $args[$ArgCount]}
	If($argument.ToLower() -like "*-diskpath*") {$DiskPath = $args[$ArgCount]}
	If($argument.ToLower() -like "*-disksizekb*") {[double]$DiskSize = $args[$ArgCount]; $dsmultiplier = "KB"}
	If($argument.ToLower() -like "*-disksizemb*") {[double]$DiskSize = $args[$ArgCount]; $dsmultiplier = "MB"}
	If($argument.ToLower() -like "*-disksizegb*") {[double]$DiskSize = $args[$ArgCount]; $dsmultiplier = "GB"}
	If($argument.ToLower() -like "*-disksizetb*") {[double]$DiskSize = $args[$ArgCount]; $dsmultiplier = "TB"}
	If($argument.ToLower() -like "*-esxihost*") {$esxihost = $args[$ArgCount]}
	$ArgCount++
}

If(($vCenter -eq $null) -or ($Datastore -eq $null) -or ($DiskPath -eq $null) -or ($DiskSize -eq $null))
{
	$syntaxEcho = "
	Proper Usage for CreateSharedVMDK.ps1.
	
	Parameters:
	-vcenter    <Virtual Center Server To Connect To>
	-esxihost   <vSphere Server to Zero Out The Disk On>
	-datastore  <The Destination Datastore to store the Shared VMDK>
	-diskpath   <The Full disk path for the new shared VMDK>
	-disksizekb <The Size you want the shared VMDK file to be in KB>
	-disksizemb <The Size you want the shared VMDK file to be in MB>
	-disksizegb <The Size you want the shared VMDK file to be in GB>
	-disksizetb <The Size you want the shared VMDK file to be in TB>
	
	Example - Create a new shared VMDK at 10GB size. Store the new VMDK file at sammyTestFolder/SammyTestVMDKFile.vmdk on the 
	          datastore win_nopci_test_vmx2201_75 and Zero the disk out on host h0319ucg04t001.
	./CreateSharedVMDK.ps1 -vcenter a0319p8k -esxihost h0319ucg04t001 -Datastore win_nopci_test_vmx2201_75 -diskpath 'sammyTestFolder/SammyTestVMDKFile.vmdk' -DiskSizeGB 10
	"
	Write-Host "
Destination Virtual Center:           $($vCenter)
Destination ESXi Host:                $($esxihost)
Destination Virtual Machine:          $($VM)
Destination Datastore:                $($Datastore)
Destination Shared VMDK Disk Path:    $($DiskPath)
Destination Shared VMDK Disk Size:    $($DiskSize) KB ~($($GB) GB)
Complete Destination VMDK Path:       $($FullDiskPath)
"
	Write-Host $syntaxEcho
	Exit 1
}

$FullDiskPath = "[" + $Datastore + "] " + $DiskPath
Switch ($dsmultiplier)
{
	#1024KB/MB;  1024MB/GB;  1024GB/TB;  1024*1024 = 1048576KB/GB;   1048576*1024 = 1073741824KB/TB
	"KB" {$DiskSize = $DiskSize}
	"MB" {$DiskSize = $DiskSize*1024 }
	"GB" {$DiskSize = ($DiskSize*1024)*1024}
	"TB" {$DiskSize = (($DiskSize*1024)*1024)*1024 }
}
$GB = ($DiskSize/1048576)

Write-Host "
Destination Virtual Center:           $($vCenter)
Destination ESXi Host:                $($esxihost)
Destination Datastore:                $($Datastore)
Destination Shared VMDK Disk Path:    $($DiskPath)
Destination Shared VMDK Disk Size:    $($DiskSize) KB ~($($GB) GB)
Complete Destination VMDK Path:       $($FullDiskPath)
`n"

If($esxihost -eq $null){ Write-Host "`nWARNING: An ESXi Host was NOT specified. The VMDK will not Zero Out.`n`n" -ForegroundColor Yellow}

Write-Host "Please Provide your Credentials to login to the ESXi Host`n"
$psCred = Get-Credential -ErrorAction SilentlyContinue

Write-Host "Connecting to vCenter $($vCenter) ...`n`n"
$hVIClient = Connect-VIServer -Server $vCenter -WarningAction SilentlyContinue

$gDatastore = Get-Datastore -VM VMDKShare
$vmdkVM = Get-VM -Name VMDKShare -Datastore $gDatastore
#$gRootDisk = Get-HardDisk -Datastore $gDatastore -DatastorePath "[$($gDataStore.Name)] VMDKShare/VMDKShare.vmdk" -WarningAction SilentlyContinue

Write-Host "`nCreating the Shared VMDK File $($FullDiskPath)"
$newDisk = New-HardDisk -VM $vmdkVM -Datastore $gDatastore -CapacityKB 1024 -StorageFormat Thick -Confirm:$false
$newDisk | Copy-HardDisk -DestinationPath $FullDiskPath -Force -Confirm:$false
$newDisk | Remove-HardDisk -DeletePermanently:$true -Confirm:$false

#$gVM = Get-VM -Name $VM -Datastore $Datastore
$gDatastore = Get-Datastore -Name $Datastore

Write-Host "`nSetting the Disk file for the size of $($GB) GB"
$getNewDisk = Get-HardDisk -DatastorePath $FullDiskPath -Datastore $gDatastore | Set-HardDisk -CapacityKB $DiskSize -Confirm:$false

#Write-Host "`nAdding a new Disk to VM $($VM) and pointing to $($FullDiskPath)"
#$gVM | New-HardDisk -DiskPath $FullDiskPath
Disconnect-VIServer -Server $vCenter -Confirm:$false

Write-Host "`nZeroing Out the new shared VMDK $($DiskPath)"
If($esxihost){
$esxi = Connect-VIServer -Server $esxihost -Credential $psCred -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	If($esxi -eq $null){
	$esxi = Connect-VIServer -Server $esxihost -User:(Decrypt-String -Encrypted '4MshSnoFJW8lPwUFyfv2pg==' -Passkey (Import-Csv D:\Local-Script-Repository\UCS-Key-Files\ucsSessionHandle.xml | Decrypt-UcsLogin)) -Password:(Decrypt-String -Encrypted '36F8n6uPfNnSD1CdkfJHiw==' -Passkey (Import-Csv D:\Local-Script-Repository\UCS-Key-Files\ucsSessionHandle.xml | Decrypt-UcsLogin)) -WarningAction SilentlyContinue
	}
Get-HardDisk -DatastorePath $FullDiskPath -Datastore (Get-Datastore -Name $Datastore) | Set-HardDisk -ZeroOut -Confirm:$false
Disconnect-VIServer -Server $esxi.Name -Confirm:$false
}
