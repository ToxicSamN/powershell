# Import-ScheduledTask
#
# Implies that the Get-ScheduledTask.ps1 script was used to pull the tasks
#
Param(
	$File = "C:\Temp\scht_tasks.csv"
)
cls

Function Import-ScheduledTask{
	Param(
		[Parameter(Position=0,ValueFromPipeline=$TRUE,Mandatory=$TRUE)]
		$TaskObject=$null
	)
	
	Process{
		try{
			Write-Host "Creating Scheduled Task $($_.TaskName)"
			$rp = $userCred[$_.RunAs].GetNetworkCredential().Password
			$xmlFile = "C:\Temp\tmpxml.xml"
			$_.Xml | Out-File $xmlFile
			schtasks /CREATE /XML "$($xmlFile)" /tn $_.TaskName /RU $_.RunAs /RP $rp
		}catch{
			Write-Error $_.Exception.Message
		}
		Finally{
			Remove-Item $xmlFile -ErrorAction SilentlyContinue -Confirm:$false -Force:$true | Out-Null
		}
	}
	End{
		return
	}
}

$winOS = (Get-WmiObject -class Win32_OperatingSystem).Caption
$psVersion = [System.Convert]::ToInt32($PSVersionTable.PSVersion.Major)

$currTask = @{}
[array]$getTask = (.\Get-ScheduledTasks.ps1 -Subfolders -ExcludeSystemTasks)
$getTask | Select -Index 0,1,2 | %{ $currTask.Add($_.TaskName,$_) }

#import the list of tasks that are needed excluding any tasks that are already created
[array]$importTasks = @()
[array]$importTasks = Import-Csv $File | ?{$currTask.Keys -notcontains $_.TaskName -and $_.RunAs -ne "SYSTEM"}

If($importTasks.Count -gt 0){
	$userCred = @{}
	$importTasks | Select -Property RunAs -Unique | ?{$_.RunAs -ne "SYSTEM"} | %{
		If($psVersion -eq 2){
			$userCred.Add($_.RunAs,(Get-Credential -Credential $_.RunAs ))
		}ElseIf($psVersion -gt 2){
			$userCred.Add($_.RunAs,(Get-Credential -User $_.RunAs -Message "Please provide the password for the user $($_.RunAs)" ))
		}
	}
	
	#create the scheduled tasks now
	try{ $importTasks | Import-ScheduledTask }catch{}
}
