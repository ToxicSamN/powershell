# created by sammy shuck
# this script is a mess...it works for nordy and only nordy. 
Param(
[Parameter(Mandatory=$true,Position=0)]
[Alias("vc")]
	[string]$vcenter="",
[Parameter(Mandatory=$true,Position=1)]
[Alias("vm")]
	[array]$vmserver=@(),
[Parameter(Mandatory=$true,Position=2)]
[Alias("del")]
	$CanBeDeletedOn=$null,
[Parameter(Mandatory=$false,Position=3)]
[Alias("l")]
	[string]$logfile="",
[Parameter(Mandatory=$false,Position=4)]
[Alias("e")]
	$email=$null,
[Parameter(Mandatory=$false,Position=5)]
[Alias("d")]
	[string]$description="",
[Parameter(Mandatory=$false,Position=6)]
[Alias("c")]
	[switch]$Credential
)

CLS
$Global:ScriptFileName = $MyInvocation.MyCommand.Name
$Global:ScriptDate = Get-Date -Format d
$ImpPath = '\\a0319p184\UCG-Logs\Snapshots-AutoRemove\snapshot_delete.csv'

### TESTING PURPOSES ONLY ###
#$ImpPath = '\\a0319p184\UCG-Logs\Snapshots-AutoRemove\snapshot_delete_test.csv'
#############################

$prodVcenters = @("a0319p362","a0319p364","a0864p71","a0870p01","319ProdVcenter","319VdiVcenter","864ProdVcenter","870ProdVcenter")
$nonprodVcenters = @("a0319p363","a0319t355","a0864p72","a0319p10133","319NonProdVcenter","319TestLabVcenter","864NonProdVcenter")
$storeVcenters = @("a0319p133","a0319p366","StoreVcenter", "a0319p1205", "a0319p1201", "stvc01", "a0319p1202", "stvc02", "a0319p1203", "stvc03")

### TESTING PURPOSES ONLY ###
#$prodVcenters = @("a0319p362","a0319p364","a0864p71","a0870p01","a0319p363")
#$nonprodVcenters = @("a0319t355","a0864p72")
#############################


Function SyntaxUsage([switch]$HelpOption){
Write-Host "$Global:ScriptFileName creates a snapshot of a single VM or a list of VMs.`n
$Global:ScriptFileName`n 
  REQUIRED PARAMETERS
  --------------------
  [-vcenter {vCenter Server}] alias [-vc]
  [-vmserver {server1, server2}] alias [-vm]
  [-CanBeDeletedOn {MM-DD-YYYY or DEFAULT}] alias [-del]`n
  OPTIONAL PARAMETERS
  --------------------
  [-description {Snapshot Description}(optional)] alias [-d]
  [-logfile {Path&Filename}(optional)] alias [-l]
  [-email {Email Address}(optional)]
 `n
Example1: $Global:ScriptFileName -vcenter:a0319p8k -vmserver:A0319T132 -CanBeDeletedOn:01-01-2012`n
Example2: $Global:ScriptFileName -vcenter:a0319p8k -vmserver:server1,server2,server3 -CanBeDeletedOn:01-01-2012`n
Example3: $Global:ScriptFileName -vcenter:a0319p8k -vmserver:MyServer -CanBeDeletedOn:01-01-2012 -logfile:D:\Logs\SnapshotScriptLog.log -email:myemailaddress@nordstrom.com`n`n
Parameters:                         Description:
 -vcenter:{vCenter Server}          REQUIRED - Connects to this vCenter Server 
                                    to access the VMs.`n
 -vmserver:{server1, server2,..}    REQUIRED - Used to create  
                                    snapshots of single or multiple VMs.`n 
 -CanBeDeletedOn:{MM-DD-YYYY}       REQUIRED WHEN CREATING A SNAPSHOT
                                    MUST provide a date to remove the snapshot being 
                                    created. Alternatively you may type DEFAULT and
                                    after 7 Days from the creation of the snapshot
                                    then the snapshot will be deleted.`n
 -description:{Snapshot Desc}       OPTIONAL - To add a description to the 
                                    snapshot being created.`n
 -logfile:{Path & Filename}         OPTIONAL - Use to create a Log File for
                                    Creating or Deleting a snapshot.`n
 -email:{Email Address}             OPTIONAL - Use to send an email on the 
                                    success or failure of the script.`n
`n"

If (!$HelpOption)
{ ExitCode -ExitNum 99 }

}
Function WriteLogFile($Message, $LogFileName, $ExitCodeNum, $SendToEmail, [bool[]]$WriteFile){
	If ($WriteFile)
	{
		If ($LogFileName -ne $null -and $LogFileName -ne "")
		{
			If (Test-Path $LogFileName)
			{ Add-Content -Path $LogFileName -Value $Message }
			Else
			{ $Message | Out-File -Encoding ASCII -FilePath $LogFileName -Width 255 }
		}
		
		If((Get-Item "\\a0319p184\UCG-Logs\SnapshotLogs.log").length -gt 500kb){
			$rename = "\\a0319p184\UCG-Logs\SnapshotLogs.log."+(Get-Date -Format "MMddyyyy")
			Rename-Item "\\a0319p184\UCG-Logs\SnapshotLogs.log" $rename
			Add-Content -Path "\\a0319p184\UCG-Logs\SnapshotLogs.log" -Value $Message
		}
		Else{ Add-Content -Path "\\a0319p184\UCG-Logs\SnapshotLogs.log" -Value $Message }
	}
	If ($SendToEmail -ne $null -and $SendToEmail -ne "")
	{
		$subject = $Global:ScriptFileName + " Results" + $Global:ScriptDate
		$body = $Message
		$FromAddress = $Global:ScriptFileName + "-DONOTREPLY@nordstrom.com"
		Send-MailMessage –From $FromAddress –To $SendToEmail –Subject $subject –Body $body –SmtpServer exchange.nordstrom.net
	}
}
Function ExitCode($ExitNum, $vCenter, $VM, $SnapshotName, $DataCenter, $Cluster, $LogFile, $RuntimeUser, $EmailAddress, $DateAttempt,$UserRequestDate,$AllowedDate,$UCGEngineer){
	Switch ($ExitNum)
	{
		1 {
			$LogMessage = "`nError Connecting to vCenter Server: " + $vCenter + ". 
			Exit Code: " + $ExitNum + " 
			Date: " + $Global:ScriptDate + " 
			User: " + $Env:USERNAME + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $false
			Exit $ExitNum
		  }
		2 {
			$LogMessage = "`nVirtual Server Does Not Exist. Please check the name of the server and try again.
			vCenter Server: " + $vCenter + "
			Data Center: " + $DataCenter + "
			Cluster: " + $Cluster + "
			Virtual Server: " + $VM + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		3 {
			$LogMessage = "`nDuplicate Virtual Server Found. Please Narrow your search by specifying a Data Center, Cluster or both.
			vCenter Server: " + $vCenter + "
			Data Center: " + $DataCenter + "
			Cluster: " + $Cluster + "
			Virtual Server: " + $VM + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		4 {
			$LogMessage = "`nData Center Does Not Exist. Please check the name of the Data Center and try again.
			vCenter Server: " + $vCenter + "
			Data Center: " + $DataCenter + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		5 {
			$LogMessage = "`nCluster Does Not Exist Within The Data Center. Please check the name of the Cluster and try again.
			vCenter Server: " + $vCenter + "
			Data Center: " + $DataCenter + "
			Cluster: " + $Cluster + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		6 {
			$LogMessage = "`nA Previous Snapshot Has Already Been Created. You can not create a snapshot if one already exists.
			Please delete this snapshot and try again.
			vCenter Server: " + $vCenter + "
			Data Center: " + $DataCenter + "
			Cluster: " + $Cluster + "
			Virtual Server: " + $VM + "
			Snapshot Name: " + $SnapshotName + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		7 {
		  	$LogMessage = "`nVirtual Server Does Not Exist. Please check the name of the server and try again.
			vCenter Server: " + $vCenter + "
			Data Center: " + $DataCenter + "
			Virtual Server: " + $VM + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		8 {
		  	$LogMessage = "`nDuplicate Virtual Server Found. Please Narrow your search by specifying a Cluster.
			vCenter Server: " + $vCenter + "
			Data Center: " + $DataCenter + "
			Virtual Server: " + $VM + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		9 {
		  	$LogMessage = "`nA Previous Snapshot Has Already Been Created. Please delete this snapshot before trying to create a new one.
			vCenter Server: " + $vCenter + "
			Data Center: " + $DataCenter + "
			Virtual Server: " + $VM + "
			Snapshot Name: " + $SnapshotName + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		10 {
		  	$LogMessage = "`nSnapshot Has Failed. Try again later. If this continues contact UCG Oncall.
			vCenter Server: " + $vCenter + "
			Virtual Server: " + $VM + "
			Snapshot Name: " + $SnapshotName + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		11 {
		  	$LogMessage = "`nCluster Does Not Exist. Please check the name of the Cluster and try again.
			vCenter Server: " + $vCenter + "
			Cluster: " + $Cluster + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		12 {
		  	$LogMessage = "`nDuplicate Cluster Name Found. Please Narrow your search by specifying a Data Center.
			vCenter Server: " + $vCenter + "
			Cluster: " + $Cluster + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		13 {
		  	$LogMessage = "`nVirtual Server Does Not Exist. Please check the name of the server and try again.
			vCenter Server: " + $vCenter + "
			Cluster: " + $Cluster + "
			Virtual Server: " + $VM + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		14 {
		  	$LogMessage = "`nDuplicate Virtual Server Found. Please Narrow your search by specifying a Data Center.
			vCenter Server: " + $vCenter + "
			Cluster: " + $Cluster + "
			Virtual Server: " + $VM + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		15 {
		  	$LogMessage = "`nA Previous Snapshot Has Already Been Created. Please delete this snapshot before trying to create a new one.
			vCenter Server: " + $vCenter + "
			Cluster: " + $Cluster + "
			Virtual Server: " + $VM + "
			Snapshot Name: " + $SnapshotName + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		16 {
		  	$LogMessage = "`nVirtual Server Does Not Exist. Please check the name of the server and try again.
			vCenter Server: " + $vCenter + "
			Virtual Server: " + $VM + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		17 {
		  	$LogMessage = "`nDuplicate Virtual Server Found. Please Narrow your search by specifying a Data Center, Cluster or both.
			vCenter Server: " + $vCenter + "
			Virtual Server: " + $VM + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		18 {
		  	$LogMessage = "`nA Previous Snapshot Has Already Been Created. Please delete this snapshot before trying to create a new one.
			vCenter Server: " + $vCenter + "
			Virtual Server: " + $VM + "
			Snapshot Name: " + $SnapshotName + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		19 {
		  	$LogMessage = "`nUnable To Delete ALL Snapshots.
			vCenter Server: " + $vCenter + "
			Data Center: " + $DataCenter + "
			Cluster: " + $Cluster + "
			Virtual Server: " + $VM + "
			Snapshot Name: " + $SnapshotName + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		20 {
		  	$LogMessage = "`nSnapshot Does Not Exist. Unable to delete this Snapshot
			Please delete this snapshot and try again.
			vCenter Server: " + $vCenter + "
			Data Center: " + $DataCenter + "
			Cluster: " + $Cluster + "
			Virtual Server: " + $VM + "
			Snapshot Name: " + $SnapshotName + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		21 {
		  	$LogMessage = "`nInvalid Date supplied for when the snapshot can be deleted.
			Please input a correct Date[MM-DD-YYYY] for -CanBeDeletedOn and try again.
			vCenter Server: " + $vCenter + "
			User Input Date: " + $DateAttempt + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
		22 {
			$LogMessage = "`nUser permissions to create a snapshot are Denied.
			Exit Code: " + $ExitNum + " 
			Date: " + $Global:ScriptDate + " 
			User: " + $Env:USERNAME + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $false
			Exit $ExitNum
		  }
		23 {
			$LogMessage = "`nUnable to verify the UCG Engineer that approved this non-standard Snapshot.
			vCenter Server: " + $vCenter + "
			Virtual Server: " + $VM + "
			Snapshot Name: " + $SnapshotName + "
			Requested Removal Date : " + $UserRequestDate + "
			Standard Removal Date : " + $AllowedDate + "
			Approving UCG Engineer : " + $UCGEngineer + "
			Exit Code: " + $ExitNum + "
			Runtime User: " + $RuntimeUser + "
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		   }
		90 {
		  	$LogMessage = "`nSnapshot Completed Successfully.
			vCenter Server: " + $vCenter + "
			VM Name: " + $VM + "
			Snapshot Name: " + $SnapshotName + " 
			Snapshot Removal Date: " + $UserRequestDate + "
			Standard Removal Date: " + $AllowedDate + "
			Approving UCG Engineer (if applicable): " + $UCGEngineer + "
			Runtime User: " + $RuntimeUser + " 
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			#Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
		   }
		91 {
		  	$LogMessage = "`nSnapshot Failed.
			vCenter Server: " + $vCenter + "
			VM Name: " + $VM + "
			Snapshot Name: " + $SnapshotName + " 
			Snapshot Removal Date: " + $UserRequestDate + "
			Standard Removal Date: " + $AllowedDate + "
			Approving UCG Engineer (if applicable): " + $UCGEngineer + "
			Runtime User: " + $RuntimeUser + " 
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			#Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
		   }
		99 {
		  	$LogMessage = "`nIncorrect Syntax. Please review the proper syntax and try again.
			Error Code: " + $ExitNum + " 
			Date: " + $Global:ScriptDate
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $false
			Exit $ExitNum
		  }
		0 {
		  	$LogMessage = "`nScript Completed Successfully.
			vCenter Server: " + $vCenter + "
			VM Name: " + $VM + "
			Snapshot Name: " + $SnapshotName + " 
			Snapshot Removal Date: " + $UserRequestDate + "
			Standard Removal Date: " + $AllowedDate + "
			Approving UCG Engineer (if applicable): " + $UCGEngineer + "
			Runtime User: " + $RuntimeUser + " 
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
		  }
		-1 {
		  	$LogMessage = "`nUnknown Error Occurred.
			vCenter Server: " + $vCenter + "
			VM Name: " + $VM + "
			Snapshot Name: " + $SnapshotName + " 
			Runtime User: " + $RuntimeUser + " 
			Date: " + $Global:ScriptDate + "
			***************************************************`n"
			Write-Host $LogMessage
			WriteLogFile -Message $LogMessage -LogFileName $LogFile -ExitCodeNum $ExitNum -SendToEmail $EmailAddress -WriteFile $true
			Disconnect-VIServer $vCenter -Confirm:$false
			Exit $ExitNum
		  }
	}
}
Function DateGUI($Date1, $Date2,$VM){
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 

	$x=$null
	$y=$null

	$objForm = New-Object System.Windows.Forms.Form 
	$objForm.Text = "Conflict of Dates!"
	$objForm.Size = New-Object System.Drawing.Size(400,250) 
	$objForm.StartPosition = "CenterScreen"

	$objForm.KeyPreview = $True
	$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
    	{$x=$objRadioBtn1.Checked; $y=$objRadioBtn2.Checked;$objForm.Close()}})
	$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
	    {$objForm.Close()}})
	
	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(75,150)
	$OKButton.Size = New-Object System.Drawing.Size(75,23)
	$OKButton.Text = "OK"
	$OKButton.Add_Click({$x=$objRadioBtn1.Checked; $y=$objRadioBtn2.Checked;$objForm.Close()})
	$objForm.Controls.Add($OKButton)

	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(150,150)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Cancel"
	$CancelButton.Add_Click({$objForm.Close()})
	$objForm.Controls.Add($CancelButton)

	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(10,20) 
	$objLabel.Size = New-Object System.Drawing.Size(380,75) 
	$objLabel.Text = $objLabel.Text = "There is a Conflict in Dates. `nA Previous Snapshot was taken and a date was given of $($Date1).`nYou have given a different date of $($Date2) for this snapshot.`nPlease Choose the correct Date to apply to ALL snapshots on $($oVM.Name)."
	$objForm.Controls.Add($objLabel) 

	$objRadioBtn1 = New-Object System.Windows.Forms.RadioButton
	$objRadioBtn1.Location = New-Object System.Drawing.Size(10,92) 
	$objRadioBtn1.Size = New-Object System.Drawing.Size(20,20) 
	$objForm.Controls.Add($objRadioBtn1) 

	$objLabel2 = New-Object System.Windows.Forms.Label
	$objLabel2.Location = New-Object System.Drawing.Size(30,95) 
	$objLabel2.Size = New-Object System.Drawing.Size(280,20) 
	$objLabel2.Text = $Date1
	$objForm.Controls.Add($objLabel2) 

	$objRadioBtn2 = New-Object System.Windows.Forms.RadioButton
	$objRadioBtn2.Location = New-Object System.Drawing.Size(10,112) 
	$objRadioBtn2.Size = New-Object System.Drawing.Size(20,20) 
	$objForm.Controls.Add($objRadioBtn2) 

	$objLabel3 = New-Object System.Windows.Forms.Label
	$objLabel3.Location = New-Object System.Drawing.Size(30,115) 
	$objLabel3.Size = New-Object System.Drawing.Size(280,20) 
	$objLabel3.Text = $Date2
	$objForm.Controls.Add($objLabel3) 

	$objForm.Topmost = $True

	$objForm.Add_Shown({$objForm.Activate()})
	[void] $objForm.ShowDialog()

	If ($x)
	{return 1}
	If ($y)
	{return 2}
	If (!$x -or !$y)
	{ return 0 }
}
Function Show-MsgBox {
	[CmdletBinding()]
	Param (
	
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)][AllowEmptyString()][string]$Message,
		[Parameter(Position=1)][string]$Title,
		
		[Parameter(Position=2,HelpMessage="`nAcceptable Values:`nOkOnly`nOkCancel`nAbortRetryIgnore`nYesNoCancel`nYesNo`nRetryCancel")][ValidateSet("OkOnly","OkCancel","AbortRetryIgnore","YesNoCancel","YesNo","RetryCancel")][string]$ButtonStyle="OkOnly",
		
		[Parameter(Position=3,HelpMessage="`nAcceptable Values:`nCritical`nQuestion`nExclamation`nInformation")][ValidateSet("Critical","Question","Exclamation","Information")][string]$IconStyle="ApplicationModal"
    )
	
	BEGIN{ 
		[Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic") | Out-Null
	}
	
	Process{
		return [Microsoft.VisualBasic.Interaction]::Msgbox($Message,"$ButtonStyle,$IconStyle",$Title)
	}
}
Function Confirm-Approval(){
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 

	$objForm = New-Object System.Windows.Forms.Form 
	$objForm.Text = "Approval"
	$objForm.Size = New-Object System.Drawing.Size(400,250) 
	$objForm.StartPosition = "CenterScreen"

	$objForm.KeyPreview = $True
	$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
    	{$objForm.Close()}})
	$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
	    {$objForm.Close()}})
	
	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(120,150)
	$OKButton.Size = New-Object System.Drawing.Size(75,23)
	$OKButton.Text = "OK"
	$OKButton.Add_Click({$objForm.Close()})
	$objForm.Controls.Add($OKButton)

	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(200,150)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Cancel"
	$CancelButton.Add_Click({$objText1.Text="btnCancel";$objForm.Close()})
	$objForm.Controls.Add($CancelButton)

	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(10,20) 
	$objLabel.Size = New-Object System.Drawing.Size(380,40) 
	$objLabel.Text = $objLabel.Text = "Please provide the nordstrom.net user ID of the UCG Engineer/Manager that approved this snapshot."
	$objForm.Controls.Add($objLabel) 

	$objText1 = New-Object System.Windows.Forms.TextBox
	$objText1.Location = New-Object System.Drawing.Size(10,60) 
	$objText1.Size = New-Object System.Drawing.Size(360,20) 
	$objForm.Controls.Add($objText1) 

	$objForm.Topmost = $True

	$objForm.Add_Shown({$objForm.Activate()})
	[void] $objForm.ShowDialog()
	
	return $objText1.Text
}
Function Track-Task($Task,[switch]$End){
	[bool]$Running = $true
	
  If(-not $End){
	Do{
		$currTask = $Task | ?{$_.State -ne "Success" -and $_.State -ne "Error"}
		$currTask | %{
			$thisTask = Get-Task -Id $_.Id
			$thisTask | Add-Member -MemberType NoteProperty -Name Snapshot -Value $_.Snapshot -ErrorAction SilentlyContinue
			$thisTask | Add-Member -MemberType NoteProperty -Name DeleteOn -Value $_.DeleteOn -ErrorAction SilentlyContinue
			$thisTask | Add-Member -MemberType NoteProperty -Name Production -Value $_.Production -ErrorAction SilentlyContinue
			If($thisTask.State -eq "Success" -or $thisTask.State -eq "Error"){
				#do something
				[array]$tmp = @()
				[array]$tmp += $Task | ?{$_.Id -ne $thisTask.Id}
				$tmp += $thisTask
				$Task = $tmp
				$Running = $false
			}
		}
	}While($Running)
  }
  If($End){
  	Do{
		$currTask = $Task | ?{$_.State -ne "Success" -and $_.State -ne "Error"}
		If(-not [string]::IsNullOrEmpty($currTask)){
			$currTask | %{
				$thisTask = Get-Task -Id $_.Id
				$thisTask | Add-Member -MemberType NoteProperty -Name Snapshot -Value $_.Snapshot -ErrorAction SilentlyContinue
				$thisTask | Add-Member -MemberType NoteProperty -Name DeleteOn -Value $_.DeleteOn -ErrorAction SilentlyContinue
				$thisTask | Add-Member -MemberType NoteProperty -Name Production -Value $_.Production -ErrorAction SilentlyContinue
				If($thisTask.State -eq "Success" -or $thisTask.State -eq "Error"){
					#do something
					[array]$tmp = @()
					[array]$tmp += $Task | ?{$_.Id -ne $thisTask.Id}
					$tmp += $thisTask
					$Task = $tmp
				}
			}
		}Else{ $Running = $false }
	}While($Running)
	
  }
	return $Task
}
[bool]$skipDate = $false
$usrResponse = "na"

### TESTING PURPOSES ONLY ###
#$Credential = $false
#$vcenter = "319TestLabVcenter"
#[array]$vmserver = @("a0319tr2","a0319tr3","a0319tr4")
#$CanBeDeletedOn = "9/1/2013"
#$email = "xpcx@nordstrom.com"
#############################


$targs = $args
$carg = 0
$args | %{ 
	$carg++
	[string]$tempstr = $_
	If ($tempstr.StartsWith("-")){
		[string]$tempvar = $_
		Switch -wildcard ($tempvar.ToLower()){
			"-force" { $skipDate = $true}
			"-f" { $skipDate = $true}
		}
	}
	Else{
		Switch ($tempstr.ToLower()){
			"?" { SyntaxUsage -HelpOption $true }
			"help" { SyntaxUsage -HelpOption $true }
			"/?" { SyntaxUsage -HelpOption $true }
		}
	}
}

$isDate = $CanBeDeletedOn -as [DateTime]
If ($help) { SyntaxUsage -HelpOption $true }
If ([string]::IsNullOrEmpty($vcenter) -or [string]::IsNullOrEmpty($vmserver)) { SyntaxUsage }
If ($isDate -lt $Global:ScriptDate -and $CanBeDeletedOn -ne "Default") { SyntaxUsage }

Write-Host "Loading the Script..."
Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue
Import-Module UcgModule -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
Import-Module ActiveDirectory -Force:$true -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
CLS

### ROLE VERIFICATION ###
Write-Host " Verifying User Permissions..."
$tmpEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
[bool]$changeBack = $false
If($Credential){
	$pscred = Get-Credential; cls
	If($vcenter -eq "a0319p133"){ $vcenter = "a0319p366"; [bool]$changeBack = $true }
	$vi = Connect-VIServer -Server $vcenter -Credential $pscred -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
}Else{ 
	If($vcenter -eq "a0319p133"){ $vcenter = "a0319p366"; [bool]$changeBack = $true }
	$vi = Connect-VIServer -Server $vcenter -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 
}
If($changeBack){ $vcenter = "a0319p133" }

$RuntimeUser = $vi.User

Write-Host "Verifying the user $($vi.User) is allowed to run this script..."

$userChk = Get-ADGroupMember -Identity "CN=vCenterSnapshotAdmins,OU=Groups,OU=Accounts,DC=nordstrom,DC=net" -Recursive -Server "nordstrom.net" | ?{$_.SamAccountName -eq ($RuntimeUser.Replace("NORD\","")) }
If([string]::IsNullOrEmpty($userChk)){ 
	$userChk = Get-ADGroupMember -Identity "CN=vCenterSnapshotTemp,OU=Groups,OU=Accounts,DC=nordstrom,DC=net" -Recursive -Server "nordstrom.net" | ?{$_.SamAccountName -eq ($RuntimeUser.Replace("NORD\","")) }
	If([string]::IsNullOrEmpty($userChk)){
		[array]$arr = @(); [array]$newvmlist = @()
		$vmserver | %{ 
			$thisVM = $_
			$permission = Get-VM -Name $_ | Get-VIPermission | ?{($_.Role -eq "tempSnapshotAdmin" -or $_.Role -eq "VMUserLevelandSnapshot") -and $_.Principal -eq $RuntimeUser}
			If([string]::IsNullOrEmpty($permission)){ Write-Host "Access denied for VM $($thisVM)"; [array]$arr += $thisVM }
			Else{ [array]$newvmlist += $thisVM }
		}
		[array]$vmserver = $newvmlist
	}
}
If([string]::IsNullOrEmpty($userChk)){
	$verifyVM = Get-VM -Name "snapshotverify-NeverDelete" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	$snap = Get-Snapshot -VM $verifyVM -Name "snapshotVerifyOnly" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	$verify = Set-VM -VM $verifyVM -Snapshot $snap -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	If([string]::IsNullOrEmpty($verify)){ [bool]$Verified = $true }Else{ [bool]$Verified = $false }
}Else{ [bool]$Verified = $true }	

Disconnect-VIServer -Server $vi.Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -Force:$true
$ErrorActionPreference = $tmpEAP

If($Verified){ Write-Host "`nUser $($vi.User) is permitted to create a snapshot." }
Else{ Write-Host "User $($vi.User) is not permitted to create a snapshot."; ExitCode -ExitNum 22 -vCenter $vcenter -LogFile $logfile -EmailAddress $email }

Write-Host "`nConnecting to $($vcenter)`n"; $vi = Connect-VIServer -Server $vcenter -Credential (Login-vCenter) -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
###########################

If ([string]::IsNullOrEmpty($vi)){ Write-Verbose "Unable to connect to vCenter";ExitCode -ExitNum 1 -vCenter $vcenter -LogFile $logfile -EmailAddress $email }

$RunningUser = $RuntimeUser
$RunningUser = $RunningUser.ToUpper()
If ($RunningUser.StartsWith("NORD\"))
{ $RunningUser = $RunningUser.Replace("NORD\","") }

If (-not [string]::IsNullOrEmpty($vmserver)){ [int]$serverCount = 0; [array]$taskList = @()
	$vmserver | %{ $vmservername = $_
		Write-Verbose $vmservername -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
		[bool]$prod = $false
		[bool]$nonprod = $false
		[bool]$storeprod = $false
		[int]$serverCount = $serverCount + 1
		
		$thisVM = $null
		$thisVM = Get-VM -Name $_ -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
		Write-Verbose "thisVM : $($thisVM.Name)"; Write-Verbose $thisVM -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
		If(-not [string]::IsNullOrEmpty($thisVM)){
			Write-Host "Analyzing $($thisVM.Name)"
			$existingSnaps = Get-Snapshot -VM $thisVM -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
			#Write-Verbose "Existing Snapshots : ";Write-Verbose $existingSnaps -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
			$datacenter = $thisVM | Get-Datacenter; Write-Verbose "VM Datacenter location : $($datacenter.Name)"
			If($nonprodVcenters -contains $vcenter) { [bool]$nonprod = $true }
			ElseIf($prodVcenters -contains $vcenter){ [bool]$prod = $true }
			ElseIf($vcenter -eq "a0319p8k"){
				If($datacenter.Name -eq "0319" -or $datacenter.Name -eq "0870" -or $datacenter.Name -eq "DMZ"){ [bool]$prod = $true }
				ElseIf($datacenter.Name -eq "0864"){ 
					$resPool = $thisVM | Get-ResourcePool
					If($resPool.Name -eq "non-prod"){ [bool]$nonprod = $true }
					ElseIf($resPool.Name -eq "prod" -or $resPool.Name -eq "exchange") { [bool]$prod = $true }
					Else{ [bool]$nonprod = $true }
				}
			}
			ElseIf($storeVcenters -contains $vcenter){ [bool]$storeprod = $true }
			
			If($storeprod){ $production = "STORE" }
			ElseIf($prod){ $production = "TRUE" }
			ElseIf(((-not $prod) -and (-not $storeprod)) -or $nonprod){ $production = "FALSE" }
						
			$datetime = $datetime = Get-Date -Format s
			$FullSnapshotName = $RunningUser + "_" + $datetime; $FullSnapshotName = $FullSnapshotName.ToLower()
			
			[string]$reqDelDate = $CanBeDeletedOn
			
			If($reqDelDate.ToLower() -eq "default" -or $reqDelDate.ToLower() -eq ""){
			###  $reqDelDate is replacing $exDate  ###
				$delDate = Get-Date -Format d
				If($prod){ $delDate = $delDate.AddDays(2) }
				ElseIf($nonprod){ $delDate = $delDate.AddDays(7) }
				ElseIf($storeprod){ $delDate = $delDate.AddDays(7) }
				
				[string]$reqDelDate = $delDate
				[string]$strtmp = $delDate; [DateTime]$userDate = $strtmp; [DateTime]$chkDate = $strtmp
			}
			Else{
				$tmp = Get-Date -Format d; [string]$strtmp = $tmp; [DateTime]$chkDate = $strtmp
				If($prod){ $chkDate = $chkDate.AddDays(2) }
				ElseIf($nonprod){ $chkDate = $chkDate.AddDays(7) }
				ElseIf($storeprod){ $chkDate = $chkDate.AddDays(7) }
				
				[DateTime]$userDate = $reqDelDate
			}
				If($userDate -gt $chkDate){
					#If($prod){
						$msg = "You have indicated a Snapshot Removal Date of $($reqDelDate) `nwhich is longer than the allowable time of $($chkDate).`nWas this time approved by UCG?"
						$usrResponse = Show-MsgBox -Title "Confirmation" -Message $msg -ButtonStyle YesNo -IconStyle Exclamation
						
						If($usrResponse -eq "Yes"){
							$usrConfirm = Confirm-Approval
							If($usrConfirm -eq "" -or $usrConfirm -eq $null -or $usrConfirm -eq "btnCancel"){
								ExitCode -ExitNum 23 -vCenter $vcenter -VM $thisVM -SnapshotName $FullSnapshotName -UserRequestDate $userDate -AllowedDate $chkDate -UCGEngineer $usrConfirm -LogFile $logfile -EmailAddress $email -RuntimeUser $RuntimeUser
							}
							Else{
								If($usrConfirm -notlike "nord\"){ $UCGEngineer = "NORD\"+$usrConfirm }Else{ $UCGEngineer = $usrConfirm }
								$tmpEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
								
								$itucgChk = Get-ADGroupMember -Identity "CN=IT UCG,OU=Groups,OU=Accounts,DC=nordstrom,DC=net" -Recursive -Server "nordstrom.net" | ?{$_.SamAccountName -eq ($UCGengineer.Replace("NORD\","")) }
								If($itucgChk -ne $null -and $itucgChk -ne ""){ $UCGEngineer = $itucgChk.Name; $usremail = $itucgChk.SamAccountName }
								Else{
									$itucgCsv = Import-Csv "\\nord\dr\Software\VMware\Reports\ITUCG.csv"
									$itucgChk = $itucgCsv | ?{$_.SamAccountName -eq ($UCGengineer.Replace("NORD\","")) }
									If($itucgChk -ne $null -and $itucgChk -ne ""){ $UCGEngineer = $itucgChk.Name; $usremail = $itucgChk.SamAccountName }
									Else{
										#ExitCode -ExitNum 23 -vCenter $vcenter -VM $thisVM -SnapshotName $FullSnapshotName -UserRequestDate $userDate -AllowedDate $chkDate -UCGEngineer $usrConfirm -LogFile $logfile -EmailAddress $email -RuntimeUser $RuntimeUser
										#It is optional to go ahead and allow the script to continue and emailing all of IT UCG, but I am choosing to exit the script
										$UCGEngineer = $usrConfirm+" (unconfirmed)"; $usremail = "itucg"; $emsg = "A non-standard snapshot is being requested and the user $($RuntimeUser) has provided an invalid UCG Engineer for approval. The UCG oncall should contact the requestor about this snapshot.`n`n" }
								}
								
								$ErrorActionPreference = $tmpEAP
								
$emsg = $emsg+"`nA Snapshot is being created and $($UCGEngineer) is identified as the UCG Engineer that approved this snapshot.`nIf this is not the case please contact the requestor.`n
	vCenter Server: " + $vcenter + "
	Virtual Server: " + $thisVM.Name + "
	Snapshot Name: " + $FullSnapshotName + "
	Requested Removal Date : " + $userDate + "
	Standard Removal Date : " + $chkDate + "
	Requesting User: " + $RuntimeUser + "
	Approving UCG Engineer: " + $UCGEngineer + "
	Date: " + $Global:ScriptDate + "
****************************************************************************************`n"
								$SendTo = $usremail + "@nordstrom.com"
								$Cc = "itucg@nordstrom.com"
								$SendFrom = $RuntimeUser.Replace("NORD\","")+"@nordstrom.com"
								$subject = "Non-Standard Snapshot"
								$etmp = Send-MailMessage -From $SendFrom -To $SendTo -Cc $Cc -Subject $subject -Body $emsg -SmtpServer "exchange.nordstrom.net" -Priority High
							}
						}
					#}						
				}
				Else{
					If($prod){
						$msg = "You have requested to take a snapshot of a Production VM.`nWas this task approved by UCG?"
						$usrResponse = Show-MsgBox -Title "Confirmation" -Message $msg -ButtonStyle YesNo -IconStyle Exclamation
						
						If($usrResponse -eq "Yes"){
							$usrConfirm = Confirm-Approval
							If($usrConfirm -eq "" -or $usrConfirm -eq $null -or $usrConfirm -eq "btnCancel"){
								ExitCode -ExitNum 23 -vCenter $vcenter -VM $thisVM -SnapshotName $FullSnapshotName -UserRequestDate $userDate -AllowedDate $chkDate -UCGEngineer $usrConfirm -LogFile $logfile -EmailAddress $email -RuntimeUser $RuntimeUser
							}
							Else{
								If($usrConfirm -notlike "nord\"){ $UCGEngineer = "NORD\"+$usrConfirm }Else{ $UCGEngineer = $usrConfirm }
								$tmpEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
								
								$itucgChk = Get-ADGroupMember -Identity "CN=IT UCG,OU=Groups,OU=Accounts,DC=nordstrom,DC=net" -Recursive -Server "nordstrom.net" | ?{$_.SamAccountName -eq ($UCGengineer.Replace("NORD\","")) }
								If($itucgChk -ne $null -and $itucgChk -ne ""){ $UCGEngineer = $itucgChk.Name; $usremail = $itucgChk.SamAccountName }
								Else{
									$itucgCsv = Import-Csv "\\nord\dr\Software\VMware\Reports\ITUCG.csv"
									$itucgChk = $itucgCsv | ?{$_.SamAccountName -eq ($UCGengineer.Replace("NORD\","")) }
									If($itucgChk -ne $null -and $itucgChk -ne ""){ $UCGEngineer = $itucgChk.Name; $usremail = $itucgChk.SamAccountName }
									Else{
										#ExitCode -ExitNum 23 -vCenter $vcenter -VM $thisVM -SnapshotName $FullSnapshotName -UserRequestDate $userDate -AllowedDate $chkDate -UCGEngineer $usrConfirm -LogFile $logfile -EmailAddress $email -RuntimeUser $RuntimeUser
										#It is optional to go ahead and allow the script to continue and emailing all of IT UCG, but I am choosing to exit the script
										$UCGEngineer = $usrConfirm+" (unconfirmed)"; $usremail = "itucg"; $emsg = "A non-standard snapshot is being requested and the user $($RuntimeUser) has provided an invalid UCG Engineer for approval. The UCG oncall should contact the requestor about this snapshot.`n`n" }
								}
								
								$ErrorActionPreference = $tmpEAP
								
$emsg = $emsg+"`nA Snapshot is being created and $($UCGEngineer) is identified as the UCG Engineer that approved this snapshot.`nIf this is not the case please contact the requestor.`n
	vCenter Server: " + $vcenter + "
	Virtual Server: " + $thisVM.Name + "
	Snapshot Name: " + $FullSnapshotName + "
	Requested Removal Date : " + $userDate + "
	Standard Removal Date : " + $chkDate + "
	Requesting User: " + $RuntimeUser + "
	Approving UCG Engineer: " + $UCGEngineer + "
	Date: " + $Global:ScriptDate + "
****************************************************************************************`n"
								$SendTo = $usremail + "@nordstrom.com"
								$Cc = "itucg@nordstrom.com"
								$SendFrom = $RuntimeUser.Replace("NORD\","")+"@nordstrom.com"
								$subject = "Production Snapshot"
								$etmp = Send-MailMessage -From $SendFrom -To $SendTo -Cc $Cc -Subject $subject -Body $emsg -SmtpServer "exchange.nordstrom.net" -Priority High
							}
						}
					}
				}
			#}
			
		If($usrResponse -eq "Yes" -or $usrResponse -eq "na"){
			$exImport = Import-Csv $ImpPath
			
			Write-Host "`nTaking Snapshot $($FullSnapshotName) for Server $($thisVM.Name) ...`n"
			$description = "`n`n   Should be deleted on $($reqDelDate)"
			$newSnapshot_task = $thisVM | New-Snapshot -Name $FullSnapshotName -Confirm:$false -Description $description -Memory:$false -Quiesce:$true -RunAsync -ErrorAction SilentlyContinue
			If([string]::IsNullOrEmpty($newSnapshot_task)){ $newSnapshot_task = Get-Task | ?{$_.ObjectId -eq $thisVM.Id -and $_.State -eq "Running" -and $_.Name -eq "CreateSnapshot_Task"}}
			#Write-Verbose "Snapshot Task : ";Write-Verbose $newSnapshot_task -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
			$newSnapshot_task | Add-Member -MemberType NoteProperty -Name Snapshot -Value $FullSnapshotName -ErrorAction SilentlyContinue
			$newSnapshot_task | Add-Member -MemberType NoteProperty -Name DeleteOn -Value $reqDelDate -ErrorAction SilentlyContinue
			$newSnapshot_task | Add-Member -MemberType NoteProperty -Name Production -Value $production -ErrorAction SilentlyContinue
			[array]$taskList += $newSnapshot_task
			$tsks = $taskList | ?{$_.State -ne "Success" -and $_.State -ne "Error"}
			If($tsks.Count -eq 4){ 
				[array]$taskList = Track-Task $taskList
			}
			If($serverCount -eq $vmserver.Count){
				[array]$taskList = Track-Task $taskList -End
				[array]$taskList | ?{$_.State -eq "Success"} | %{ $thisTask = $_
					#$vm = Get-View -Id $_.ObjectId
					$snap = (Get-VM -Id $thisTask.ObjectId) | Get-Snapshot -Name $thisTask.Snapshot
					Write-Host "Success Creating snapshot for $($snap.VM)"
					ExitCode -ExitNum 90 -vCenter $vcenter -VM $snap.VM -SnapshotName $snap.Name -UserRequestDate $userDate -AllowedDate $chkDate -UCGEngineer $UCGEngineer -LogFile $logfile -EmailAddress $email -RuntimeUser $RuntimeUser
					
					$tmp = "" | Select Server,Uuid,Snapshot,SnapshotId,CanBeDeletedOn,Production
					$tmp.Server = $snap.VM
					$tmp.Uuid = $snap.VMId
					$tmp.Snapshot = $snap.Name
					$tmp.SnapshotId = $snap.Id
					$tmp.CanBeDeletedOn = $thisTask.DeleteOn
					$tmp.Production = $thisTask.Production
					#this is the Write Sequence
					[System.Collections.ArrayList]$err = $null; $openwrite = $false
					$tmpEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
					Do{ #need to loop in case I can't open or edit the file because it is being used by something else
						[array]$tmpImp = Import-Csv $ImpPath -ErrorAction SilentlyContinue -ErrorVariable err
						If([string]::IsNullOrEmpty($err)){
						$tmpImp += $tmp
						$tmpImp = $tmpImp | Sort Server,Snapshot
						$tmpImp | Export-Csv -Path $ImpPath -NoTypeInformation -ErrorAction SilentlyContinue -ErrorVariable err
						If([string]::IsNullOrEmpty($err)){ $openwrite = $true }
						}
					}While(-not $openwrite)
				}
				$taskList | ?{$_.State -eq "Error"} | %{
					$vm = Get-View -Id $_.ObjectId
					$snap = $_.Snapshot
					Write-Host "Error Creating snapshot for $($vm.Name)" -ForegroundColor Red
					ExitCode -ExitNum 91 -vCenter $vcenter -VM $vm.Name -SnapshotName $snap -UserRequestDate $userDate -AllowedDate $chkDate -UCGEngineer $UCGEngineer -LogFile $logfile -EmailAddress $email -RuntimeUser $RuntimeUser 
				}
			}
			
			$ErrorActionPreference = $tmpEAP
			$exAry = $null
		}
	}
	}
	
	Disconnect-VIServer -Server $vcenter -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue			
	#ExitCode -ExitNum 0 -vCenter $vcenter -VM $thisVM -SnapshotName $FullSnapshotName -UserRequestDate $userDate -AllowedDate $chkDate -UCGEngineer $UCGEngineer -LogFile $logfile -EmailAddress $email -RuntimeUser $RuntimeUser 
}

$tmpEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
Disconnect-VIServer -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
$ErrorActionPreference = $tmpEAP
exit 0
