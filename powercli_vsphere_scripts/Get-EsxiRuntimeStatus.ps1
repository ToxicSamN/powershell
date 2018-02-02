# created by sammy
# autodeploy was implemented to auto build esxi and then host profiles are used to cache to stateful drives
# the esxi host should not be running stateless but instead off the local HDD but sometimes this does happen
# so a notification is required if this is the case.
Param(
	$vCenter = @()
)
cls

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
Import-Module UcgModule -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
cls

[array]$report = @()

$vCenter | %{ $vc = $_
	Connect-VIServer -Server $vc

	$SI = Get-View ServiceInstance
	$CFM = Get-View $SI.Content.CustomFieldsManager
	$esxRuntime = $CFM.Field | ?{$_.ManagedObjectType -eq "HostSystem" -and $_.Name -eq "Stateless Runtime"}

	Get-View -ViewType HostSystem | %{ $esxi = $_
		$tmp = $esxi.CustomValue | ?{$_.Key -eq $esxRuntime.Key}
		If($tmp.Value -eq "TRUE"){
			$report += New-Object PSObject -Property @{Type="VMHost";"ESXi Version"="$($esxi.Summary.Config.Product.FullName)";Name="$($esxi.Name)";"Stateless Runtime"="TRUE"}
		}
	}
	Disconnect-VIServer * -Confirm:$false
}

If($report.Count -gt 0){
	$html = Get-HtmlHeader `
		-Message "Esxi Host running in a statless boot configuration. These hosts need to be restarted and boot from hard disk" `
		-Title "ESXi Stateless Runtime Report" `
		-ResultCount $report.Count

	$html += $report | Select Type,"Esxi Version",Name,"Stateless Runtime" | ConvertTo-Html -Fragment | Set-HtmlTableFormat

	$html += Get-HtmlFooter -Message "This report was generated from A0319P184 by script Get-EsxiRuntimeStatus.ps1"
	
	#region Send email
		Send-MailMessage -SmtpServer "exchange.nordstrom.net" -To $email -From "sammy.shuck@nordstrom.com" -Subject "Cluster Compute Status Report" -BodyAsHtml $html
		[string[]]$email = "sammy.d.shuck@nordstrom.com"
	#endregion
	
	#$html | Out-File "C:\temp\testhtml_generator.html"
	#Invoke-Expression "C:\temp\testhtml_generator.html"
}