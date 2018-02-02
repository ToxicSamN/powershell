# this code was lifted from the internet from https://serverfault.com/questions/704581/copy-vm-snapshot-to-a-new-vm-environment/704593 by GregL and modified by me to fit my needs
Param(
  [parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  $vCenter,
  [parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  $VMName,
  [parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
	$DestinationPath
)

Function ExportVM {
    Param(
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [PSObject]$SourceVM,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String]$DestinationPath
    )

    #Check if the destination path exists, bail out if it doesn't
    if ( -not (Test-path $DestinationPath -IsValid) ) {
        Write-Warning "Please provide a valid path for the exported VM"
        return
    }

    #Get the SourceVM, bail out if it fails
    if ($SourceVM.GetType().Name -eq "string"){
        try {
            $SourceVM = Get-VM $SourceVM -ErrorAction Stop
        }
        catch [Exception]{
            Write-Warning "VM $SourceVM does not exist"
            return
        }
    }
    elseif ($SourceVM -isnot [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]){
        Write-Warning "You did not pass a string or a VM object for 'SourceVM'"
        Return
    }

    try {
        $DestinationPath = $DestinationPath + "\"

        #Setup the required compoments to compute an MD5 hash
        $algo = [System.Security.Cryptography.HashAlgorithm]::Create("MD5")
        $md5StringBuilder = New-Object System.Text.StringBuilder 50
        $ue = New-Object System.Text.UTF8Encoding

        #Define the snapshot name
        $SnapshotName = "IT-Security Export - " + (Get-Date -UFormat "%b-%d-%Y, %R")
        #Create the snapshot
        $Snapshot = New-Snapshot -VM $SourceVM -Name $SnapshotName -Description "Snapshot for IT-Security Forensic export" -Memory -Quiesce -Confirm:$false

        $Snapshot

        #Define variables needed to create the clone
        $CloneFolder = $SourceVM.Folder
        $Datastore = Get-Datastore -RelatedObject $SourceVM
        $ResourcePool = Get-ResourcePool -VM $SourceVM
        $VMHost = Get-VMHost -VM $SourceVM

        #Build a unique name for the cloned machine based on the snapshot name
        $algo.ComputeHash($ue.GetBytes($SnapshotName)) | % { [void] $md5StringBuilder.Append($_.ToString("x2")) }
        $CloneName = $SourceVM.Name +"_ITSecExport_" + $md5StringBuilder.ToString().SubString(0,15)

        #Clone the VM
        $CloneVM = New-VM -Name $CloneName -VM $SourceVM -Location $CloneFolder -Datastore $Datastore -ResourcePool $ResourcePool -VMHost $VMHost -LinkedClone -ReferenceSnapshot $Snapshot

        #Define the name of the PSDrive, based on the Datastore name
        $DSName = "ITSecExport_" + ($Datastore.name -replace "[^a-zA-Z0-9]","")
        #Check to see if it already exists, remove if it does
        if (Get-PSDrive | Where {$_.Name -like $DSName}) {
            Remove-PSDrive $DSName
        }
        #Add the new drive
        $PSDrive = New-PSDrive -Location $Datastore -Name $DSName -Scope Script -PSProvider VimDatastore -Root "\"

        #Define variables needed to copy the SourceVM's VMX and the snapshot's VMSN
        $SnapshotID = (Get-VM $SourceVM |Get-Snapshot | where {$_.Name -like $SnapshotName}).ExtensionData.ID
        $SourceVM_VMXPath = (Get-View $SourceVM).Config.Files.VmPathName.Split(" ")[1].replace("/","\")
        $SourceVM_VMSNPath = $SourceVM_VMXPath.Replace(".vmx", "-Snapshot" + $SnapshotID + ".vmsn")
        $rootPath = ($DestinationPath+$SourceVM_VMXPath.split('\')[0])
        
        $SourceVM_VMXPath
        $SourceVM_VMSNPath
        $rootPath
        
        if ( -not (Test-path $rootPath -IsValid) ) {
          New-Item -ItemType Directory -Force -Path $rootPath
        }

        #Copy the VMSN and VMX
        Copy-DatastoreItem -Item ${DSName}:\$SourceVM_VMXPath -Destination ($DestinationPath+$SourceVM_VMXPath) -Force
        Copy-DatastoreItem -Item ${DSName}:\$SourceVM_VMSNPath -Destination ($DestinationPath+$SourceVM_VMSNPath) -Force

        #Export the VM
        $CloneVM | Export-VApp -Destination $rootPath -Force

        #Clean up
        Remove-VM -DeletePermanently $CloneVM -Confirm:$false
        Remove-Snapshot -Snapshot $Snapshot -Confirm:$false
        Remove-PSDrive -Name $DSName
    }
    catch [Exception]{
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Warning "Looks like we ran in to an error"
        Write-Warning "  $ErrorMessage"
        return
    }
}

Function Main{
  Param(
    $vCenter,
    $VMName,
	  $DestinationPath
  )
  
  $vi = Connect-VIServer -Server $vCenter -Credential (Login-vCenter)
  $VMobj = Get-VM -Name $VMName
  
  ExportVM -SourceVM $VMobj -DestinationPath $DestinationPath
  
}

Import-Module UcgModule -ArgumentList vmware -WarningAction SilentlyContinue

Main -vCenter $vCenter -VMName $VMName -DestinationPath  $DestinationPath