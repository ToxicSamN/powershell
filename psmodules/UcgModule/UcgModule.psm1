<# 
.SYNOPSIS  
	Custom Nordstrom UCG Module for various functions that are used often in many scripts
.DESCRIPTION  
	Imports Custom Functions for Nordstrom Unified Computing Group
.NOTES  
	Module Name  	: UcgModule 
	Author     		: Sammy Shuck
	Requires   		: Minimum of PowerShell V3
.EXAMPLE  
	Import-Module UcgModule
.EXAMPLE  
	Import UcgModule with VMware Snapins/Modules and CiscoUcsPS Modules
	Import-Module UcgModule -ArgumentList vmware,cisco
#> 
Param(
  [ValidateSet($null,'VMware','Cisco','HP','Dell','Nutanix','EMC','NetApp','vCommander')]
    [string]$param1 = $null,
  [ValidateSet($null,'VMware','Cisco','HP','Dell','Nutanix','EMC','NetApp','vCommander')]
    [string]$param2 = $null,
  [ValidateSet($null,'VMware','Cisco','HP','Dell','Nutanix','EMC','NetApp','vCommander')]
    [string]$param3 = $null,
  [ValidateSet($null,'VMware','Cisco','HP','Dell','Nutanix','EMC','NetApp','vCommander')]
    [string]$param4 = $null,
  [ValidateSet($null,'VMware','Cisco','HP','Dell','Nutanix','EMC','NetApp','vCommander')]
    [string]$param5 = $null,
  [ValidateSet($null,'VMware','Cisco','HP','Dell','Nutanix','EMC','NetApp','vCommander')]
    [string]$param6 = $null,
  [ValidateSet($null,'VMware','Cisco','HP','Dell','Nutanix','EMC','NetApp','vCommander')]
    [string]$param7 = $null,
  [ValidateSet($null,'VMware','Cisco','HP','Dell','Nutanix','EMC','NetApp','vCommander')]
    [string]$param8 = $null,
  [ValidateSet($null,'VMware','Cisco','HP','Dell','Nutanix','EMC','NetApp','vCommander')]
    [string]$param9 = $null,
  [ValidateSet($null,'VMware','Cisco','HP','Dell','Nutanix','EMC','NetApp','vCommander')]
    [string]$param10 = $null
)


# Lets supress errors until this module is loaded
$EAP = $ErrorActionPreference
$WP = $WarningPreference
$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
[Reflection.Assembly]::LoadWithPartialName("System.Security")

#Setting some global variables for the scripty/log server and the standard log paths
$global:ScriptyServer = "a0319p184"
$global:ScriptyServerUNC = "\\$($ScriptyServer)"
$global:UcgLogPath = "$($ScriptyServerUNC)\Ucg-Logs"
$global:dr_root_path = "\\cigshare\cig_data"
$global:vcenter_list_path = "$($dr_root_path)\vmware\docs\vcenterlist.txt"
$global:vmware_report_path = "$($dr_root_path)\vmware\reports"
$global:ucs_list_path = "$($dr_root_path)\cisco\docs\ucs\ucslist.txt"
$global:ucs_report_path = "$($dr_root_path)\cisco\reports\ucs"
$module_log = "$($UcgLogPath)\UcgModule.log"
$module_path = $PSScriptRoot
$_get_credential_file = "$($module_path)\_get_credential.ps1"

# Import-Module Encryption -Scope Global -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# Global Exception trap
trap {
	# Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
	throw $_
}

#When running a script as a different user from a Scheduled task the Mapped network Drive doesn't exist
# this ensures it exists for the Powershell session being ran
If(-not (Test-Path "G:\")){
	Net Use G: \\A0319P184\Git-UCG /persistent:yes /y
	New-PSDrive -Name G -PSProvider FileSystem -root "$($ScriptyServerUNC)\Git-UCG"
}

#region Function Declarations
Function Evaluate-Parameters{
	Param ( $lPSBoundParameters )
	#Loading Modules/Snapins if the user chooses to load additional Modules/Snapins via -ArgumentList on Import-Module
	If($lPSBoundParameters.Count -gt 0){
		If($lPSBoundParameters.Values.toLower().Contains("vmware")){
		  LoadVMwareModules
		  LoadVMwareSnapins
		  Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore -Confirm:$false | Out-Null
		}
		If($lPSBoundParameters.Values.toLower().Contains("cisco")){
		  LoadCiscoUcsPsModules
		}
		If($lPSBoundParameters.Values.toLower().Contains("hp")){
		  LoadHpModules
		}
		If($lPSBoundParameters.Values.toLower().Contains("dell")){
		  LoadDellModules
		}
		If($lPSBoundParameters.Values.toLower().Contains("nutanix")){
		  LoadNutanixModules
		}
		If($lPSBoundParameters.Values.toLower().Contains("emc")){
		  LoadEmcModules
		}
		If($lPSBoundParameters.Values.toLower().Contains("netapp")){
		  LoadNetAppModules
		}
		If($lPSBoundParameters.Values.toLower().Contains("vcommander")){
		  LoadVcommanderModules
		}
	}
}
Function LoadHpModules(){
	#Insert Import-Module or Add-PSSnapin for HP
}
Function LoadDellModules(){
	#Insert Import-Module or Add-PSSnapin for Dell
}
Function LoadNutanixModules(){
	#Insert Import-Module or Add-PSSnapin for Nutanix
}
Function LoadEmcModules(){
	#Insert Import-Module or Add-PSSnapin for EMC
}
Function LoadNetAppModules(){
	#Insert Import-Module or Add-PSSnapin for Netapp
}
Function LoadVcommanderModules(){
	#Insert Import-Module or Add-PSSnapin for vcommander
}
function LoadVMwareModules(){
   $loaded = Get-Module -ErrorAction Ignore | ?{$_.Name -like "VMware*"} | % {$_.Name}
   $registered = Get-Module -ListAvailable -ErrorAction Ignore | ?{$_.Name -like "VMware*"} | % {$_.Name}
   $notLoaded = $registered | ? {$loaded -notcontains $_}
   foreach ($module in $registered) {
      if ($loaded -notcontains $module) {
		    Import-Module $module -Scope Global -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
      }
   }
}
function LoadVMwareSnapins(){
   $loaded = Get-PSSnapin -ErrorAction SilentlyContinue | ?{$_.Name -like "VMware*"} | %{ $_.Name }
   $registered = Get-PSSnapin -Registered -ErrorAction SilentlyContinue | ?{$_.Name -like "VMware*"} | %{ $_.Name }
   $registered | ?{$loaded -notcontains $_} | %{ $pssnap = $_
    If($loaded -notcontains $pssnap){
      Add-PSSnapin $pssnap -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | out-Null
	  $loaded = Get-PSSnapin -ErrorAction SilentlyContinue | ?{$_.Name -like "VMware*"} | %{ $_.Name }
    }
  }
}
function LoadCiscoUcsPSModules(){
  Import-Module CiscoUcsPs -Scope Global -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
}
function ConvertTo-DottedDecimalIP {
  <#
    .Synopsis
      Returns a dotted decimal IP address from either an unsigned 32-bit integer or a dotted binary string.
    .Description
      ConvertTo-DottedDecimalIP uses a regular expression match on the input string to convert to an IP address.
    .Parameter IPAddress
      A string representation of an IP address from either UInt32 or dotted binary.
  #>
  # Function provided by http://www.indented.co.uk/2010/01/23/powershell-subnet-math/
  [CmdLetBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [String]$IPAddress
  )
  
  process {
    Switch -RegEx ($IPAddress) {
      "([01]{8}.){3}[01]{8}" {
        return [String]::Join('.', $( $IPAddress.Split('.') | ForEach-Object { [Convert]::ToUInt32($_, 2) } ))
      }
      "\d" {
        $IPAddress = [UInt32]$IPAddress
        $DottedIP = $( For ($i = 3; $i -gt -1; $i--) {
          $Remainder = $IPAddress % [Math]::Pow(256, $i)
          ($IPAddress - $Remainder) / [Math]::Pow(256, $i)
          $IPAddress = $Remainder
         } )
       
        return [String]::Join('.', $DottedIP)
      }
      default {
        Write-Error "Cannot convert this format"
      }
    }
  }
}
function Get-NetworkAddress {
  <#
    .Synopsis
      Takes an IP address and subnet mask then calculates the network address for the range.
    .Description
      Get-NetworkAddress returns the network address for a subnet by performing a bitwise AND 
      operation against the decimal forms of the IP address and subnet mask. Get-NetworkAddress 
      expects both the IP address and subnet mask in dotted decimal format.
    .Parameter IPAddress
      Any IP address within the network range.
    .Parameter SubnetMask
      The subnet mask for the network.
  #>
  # Function provided by http://www.indented.co.uk/2010/01/23/powershell-subnet-math/
  [CmdLetBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [Net.IPAddress]$IPAddress,
    
    [Parameter(Mandatory = $true, Position = 1)]
    [Alias("Mask")]
    [Net.IPAddress]$SubnetMask
  )
 
  process {
    return ConvertTo-DottedDecimalIP ((ConvertTo-DecimalIP $IPAddress) -band (ConvertTo-DecimalIP $SubnetMask))
  }
}
function ConvertTo-DecimalIP {
  <#
    .Synopsis
      Converts a Decimal IP address into a 32-bit unsigned integer.
    .Description
      ConvertTo-DecimalIP takes a decimal IP, uses a shift-like operation on each octet and returns a single UInt32 value.
    .Parameter IPAddress
      An IP Address to convert.
  #>
  # Function provided by http://www.indented.co.uk/2010/01/23/powershell-subnet-math/
  [CmdLetBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [Net.IPAddress]$IPAddress
  )
 
  process {
    $i = 3; $DecimalIP = 0;
    $IPAddress.GetAddressBytes() | ForEach-Object { $DecimalIP += $_ * [Math]::Pow(256, $i); $i-- }
 
    return [UInt32]$DecimalIP
  }
}
Function Get-SubnetCIDR{
#This will take a given Default Gateway and subnet mask and pull out the CIDR Notation
# such as 192.168.1.0/24
Param(
	[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
	[Net.IPAddress]$IPAddress,
	[Parameter(Mandatory = $true, Position = 1)]
	[Net.IPAddress]$SubnetMask
)
	Begin{
		#Create a CIDR mapping hash table from subnetmasks
		#This maps from Class A to Class C addresses or from /8 to /30 subnets
		$cidr_dict = @{
			"255.0.0.0" = "/8";
			"255.128.0.0" = "/9";
			"255.192.0.0" = "/10";
			"255.224.0.0" = "/11";
			"255.240.0.0" = "/12";
			"255.248.0.0" = "/13";
			"255.252.0.0" = "/14";
			"255.254.0.0" = "/15";
			"255.255.0.0" = "/16";
			"255.255.128.0" = "/17";
			"255.255.192.0" = "/18";
			"255.255.224.0" = "/19";
			"255.255.240.0" = "/20";
			"255.255.248.0" = "/21";
			"255.255.252.0" = "/22";
			"255.255.254.0" = "/23";
			"255.255.255.0" = "/24";
			"255.255.255.128" = "/25";
			"255.255.255.192" = "/26";
			"255.255.255.224" = "/27";
			"255.255.255.240" = "/28";
			"255.255.255.248" = "/29";
			"255.255.255.252" = "/30";
		}
		
	}
	Process{
		try{
			$network = Get-NetworkAddress -IPAddress $IPAddress -SubnetMask $SubnetMask
			return "$($network)$($cidr_dict[$($SubnetMask.IPAddressToString)])"
		}
		catch{
			throw $_
		}
	}
}
Function New-HtmlStyleObject{
<#
    .Synopsis
      Returns a HTML Object for a standard UCG Report style.
    .Description
      We have standardized on a report style for emailed reports. This is the default styling but can
	  be changed to fit the users need
    .Notes
	  Author     		: Sammy Shuck
	.EXAMPLE  
	  $html_style = New-HtmlStyleObject
#>
	New-Object PSObject `
		-Property @{
			StyleFont = New-Object PSObject `
				-Property @{
					FontFamily = "Verdana"
					FontSize = "10px"
				}
			Body = New-Object PSObject `
				-Property @{
					Background = "#FFFFFF"
					FontFamily = "Verdana"
					FontSize = "10px"
				}
			Wrapper = New-Object PSObject `
				-Property @{
					Background = "#FFFFFF"
					Margin = "5px auto"
					Width = "100%"
					Padding = "7px"
				}
			Message = New-Object PSObject `
				-Property @{
					Background = "#FFFFFF"
					Margin = "5px auto"
					Width = "100%"
					Padding = "7px"
					FontSize = "12px"
					BorderLeft = "#AAAAAA 1pt solid"
					BorderRight = "#AAAAAA 1pt solid"
					BorderTop = "#AAAAAA 1pt solid"
					BorderBottom = "#AAAAAA 1pt solid"
					PaddingLeft = "4pt"
					PaddingRight = "4pt"
					PaddingTop = "4pt"
					PaddingBottom = "4pt"
					MSOElement = "para-border-div"
					MSOBorderAlt = "solid #AAAAAA .5pt"
				}
			Footer = New-Object PSObject `
				-Property @{
					Width = "100%"
					MarginTop = "10px"
					Height = "22px"
					Background = "#FFFFFF"
					Padding = "10pt"
					Color = "#597799"
					LinkVisited = New-Object PSObject `
						-Property @{
							Color = "#597799"
						}
				}
			UnorderedList = New-Object PSObject `
				-Property @{
					Border = "none"
					Margin = "0"
					Padding = "0"
					Listed = New-Object PSObject `
						-Property @{
							MarginLeft = "30pt"
						}
				}
			Header1 = New-Object PSObject `
				-Property @{
					Border = "none"
					Margin = "0"
					FontSize = "20px"
					Padding = "3px 0px"
					Color = "#A55311"
				}
			Header2 = New-Object PSObject `
				-Property @{
					Border = "none"
					Margin = "0"
					Padding = "0"
				}
			Header3 = New-Object PSObject `
				-Property @{
					Border = "none"
					Margin = "0"
					FontSize = "15px"
					Padding = "3px 0px"
					Color = "#000000"
				}
			Header4 = New-Object PSObject `
				-Property @{
					Border = "none"
					Margin = "3px 0 5px"
					Padding = "0"
					LineHeight = "110%"
					FontSize = "12px"
					Color = "#597799"
				}
			Header5 = New-Object PSObject `
				-Property @{
					FontSize = "11px"
					Margin = "3pt 0pt 3pt 35pt"
				}
			HeaderImage = New-Object PSObject `
				-Property @{
					Border = "none"
					Margin = "0"
					Padding = "0"
				}
			EmphasizeText = New-Object PSObject `
				-Property @{
					FontSize = "16px"
				}
			Table = New-Object PSObject `
				-Property @{
					TableData = New-Object PSObject `
						-Property @{
							Border = "1px solid #AAAAAA"
							FontFamily = "Verdana"
							FontSize = "10"
							tr = New-Object PSObject `
								-Property @{
									aggregate = New-Object PSObject `
										-Property @{
											FontWeight = "bold"
											BorderTop = "1px solid #000000"
											MSOBorderTopAlt = "solid #000000 .75pt"
											BorderBottom = "1px solid #CCCCCC"
											Background = "#D5D5D5"
										}
									Odd = New-Object PSObject `
										-Property @{
											Background = "#FFFFFF"
										}
									Even = New-Object PSObject `
										-Property @{
											Background = "#EEEEEE"
										}
								}
							th = New-Object PSObject `
								-Property @{
									Background = "#000000"
									Color = "#FFFFFF"
									TextAlign = "left"
									Padding = "2px 5px"
								}
							td = New-Object PSObject `
								-Property @{
									Padding = "2px"
									BorderBottom = "1px dotted #AAAAAA"
									BorderRight = "1px solid #AAAAAA"
								}
						}
					TableInfo = New-Object PSObject `
						-Property @{
							Width = "400px"
							Border = "#AAAAAA"
							MarginBottom = "0px"
							td = New-Object PSObject `
								-Property @{
									PaddingLeft = "5px"
									FontWeight = "bold"
									FontSize = "9px"
								}
						}
					ReportTable = New-Object PSObject `
						-Property @{
							Border = "1px solid #AAAAAA"
							FontFamily = "Verdana"
							FontSize = "10"
							tr = New-Object PSObject `
								-Property @{
									groupHeader = New-Object PSObject `
										-Property @{
											Background = "#597799"
											Color = "#FFFFFF"
											Padding = "3px 2px 3px 4px"
											TextAlign = "left"
											FontSize = "12px"
											FontWeight = "bold"
										}
									optimalGroupHeader = New-Object PSObject `
										-Property @{
											Background = "#8BBA00"
											Color = "#000000"
											Padding = "3px 2px 3px 4px"
											TextAlign = "left"
											FontSize = "12px"
											FontWeight = "bold"
										}
									marginalGroupHeader = New-Object PSObject `
										-Property @{
											Background = "#F6BD0F"
											Color = "#000000"
											Padding = "3px 2px 3px 4px"
											TextAlign = "left"
											FontSize = "12px"
											FontWeight = "bold"
										}
									poorGroupHeader = New-Object PSObject `
										-Property @{
											Background = "#FF654F"
											Color = "#000000"
											Padding = "3px 2px 3px 4px"
											TextAlign = "left"
											FontSize = "12px"
											FontWeight = "bold"
										}
									Odd = New-Object PSObject `
										-Property @{
											Background = "#FFFFFF"
										}
									Even = New-Object PSObject `
										-Property @{
											Background = "#EEEEEE"
										}
								}
							th = New-Object PSObject `
								-Property @{
									Background = "#000000"
									Color = "#FFFFFF"
									TextAlign = "left"
									Padding = "2px 5px"
								}
							td = New-Object PSObject `
								-Property @{
									Padding = "2px"
									BorderBottom = "1px dotted #AAAAAA"
									BorderRight = "1px solid #AAAAAA"
									blackLine = New-Object PSObject `
										-Property @{
											Background = "#4f4f4f"
											Padding = "1px"
											BorderBottom = "0px black solid"
										}
								}
						}
				}
		}
}
Function New-HtmlReportStyle{
<#
    .Synopsis
      Returns a HTML CSS Report <style></style> tag.
    .Description
      We have standardized on a report style for emailed reports. This is the default styling but can
	  be changed to fit the users need. 
    .Notes
	  Author     		: Sammy Shuck
	.EXAMPLE  
	  $html_style = New-HtmlReportStyle
	.EXAMPLE  
	  If the user decided to change the colors and layout then the would get a HtmlStyleObject first
	  and then modify the StyleObject and pass that style object to the HtmlReportStyle
	  $html_style_object = New-HtmlStyleObject
	  $html_style_object.Body.Background = "#AAAAAA"
	  $html_style = New-HtmlReportStyle $html_style_object
#>
  Param(
  	$StyleObject = (New-HtmlStyleObject)
  )
  
  "
  <style>
		* {
			font-family:$($StyleObject.StyleFont.FontFamily);
			font-size:$($StyleObject.StyleFont.FontSize);
		}
		
		body{
			background:$($StyleObject.Body.Background);
			font-family:$($StyleObject.Body.FontFamily);
			font-size:$($StyleObject.Body.FontSize);
		}
		
		.wrapper{
			width:$($StyleObject.Wrapper.Width);
			background:$($StyleObject.Wrapper.Background);
			margin:$($StyleObject.Wrapper.Margin);
			padding:$($StyleObject.Wrapper.Padding);
		}
		
		.message{
			width:$($StyleObject.Message.Width);
			margin:$($StyleObject.Message.Margin);
			padding:$($StyleObject.Message.Padding);
			font-size:$($StyleObject.Message.FontSize);
			border-right: $($StyleObject.Message.BorderRight);
			padding-right: $($StyleObject.Message.PaddingRight);
			border-top: $($StyleObject.Message.BorderTop);
			padding-left: $($StyleObject.Message.PaddingLeft);
			background: $($StyleObject.Message.Background);
			padding-bottom: $($StyleObject.Message.PaddingBottom);
			border-left: $($StyleObject.Message.BorderLeft);
			padding-top: $($StyleObject.Message.PaddingTop);
			border-bottom: $($StyleObject.Message.BorderBottom);
			mso-element: $($StyleObject.Message.MSOElement);
			mso-border-alt: $($StyleObject.Message.MSOBorderAlt);
		}

		.footer{
			width:$($StyleObject.Footer.Width);
			margin-top:$($StyleObject.Footer.MarginTop);
			height:$($StyleObject.Footer.Height);
			background: $($StyleObject.Footer.Background);
			padding:$($StyleObject.Footer.Padding);
			color:$($StyleObject.Footer.Color);
		}
		
		.footer a:link,
		.footer a:visited{
			color:$($StyleObject.Footer.LinkVisited.Color);
		}
		
		ul{
			border:$($StyleObject.UnorderedList.Border);
			margin:$($StyleObject.UnorderedList.Margin);
			padding:$($StyleObject.UnorderedList.Padding);
		}
		
		ul.listed{
			margin-left:$($StyleObject.UnorderedList.Listed.MarginLeft);
		}
		
		img{
			border:$($StyleObject.HeaderImage.Border);
			margin:$($StyleObject.HeaderImage.Margin);
			padding:$($StyleObject.HeaderImage.Padding);
		}		

		h1{
			border:$($StyleObject.Header1.Border);
			margin:$($StyleObject.Header1.Margin);
			font-size:$($StyleObject.Header1.FontSize);
			padding:$($StyleObject.Header1.Padding);
			color:$($StyleObject.Header1.Color);
		}
		em{
			font-size:$($StyleObject.EmphasizeText.FontSize);
		}
		
		h2{
			border:$($StyleObject.Header2.Border);
			margin:$($StyleObject.Header2.Margin);
			padding:$($StyleObject.Header2.Padding);
		}

		h3{
			border:$($StyleObject.Header3.Border);
			margin:$($StyleObject.Header3.Margin);
			padding:$($StyleObject.Header3.Padding);
			font-size:$($StyleObject.Header3.FontSize);
			color:$($StyleObject.Header3.Color);
		}
		
		h4{
			border:$($StyleObject.Header4.Border);
			margin:$($StyleObject.Header4.Margin);
			padding:$($StyleObject.Header4.Padding);
			font-size:$($StyleObject.Header4.FontSize);
			color:$($StyleObject.Header4.Color);
			line-height:$($StyleObject.Header4.LineHeight);
		}
		
		h5{
			font-size:$($StyleObject.Header5.FontSize);
			margin: $($StyleObject.Header5.Margin);
		}
		
		table.report_table{
			border:$($StyleObject.Table.ReportTable.Border);
			font-family:$($StyleObject.Table.ReportTable.FontFamily);
			font-size:$($StyleObject.Table.ReportTable.FontSize);
		}
		
		table.table_data{
			border:$($StyleObject.Table.TableData.Border);
			font-family:$($StyleObject.Table.TableData.FontFamily);
			font-size:$($StyleObject.Table.TableData.FontSize);
		}

		table.table_info{
			width: $($StyleObject.Table.TableInfo.Width);
			border:$($StyleObject.Table.TableInfo.Border);
			margin-bottom: $($StyleObject.Table.TableInfo.MarginBottom);
		}

		.report_table tr.groupHeader td {
			background: $($StyleObject.Table.ReportTable.tr.groupHeader.Background);
			color: $($StyleObject.Table.ReportTable.tr.groupHeader.Color);
			padding: $($StyleObject.Table.ReportTable.tr.groupHeader.Padding);
			text-align: $($StyleObject.Table.ReportTable.tr.groupHeader.TextAlign);
			font-size: $($StyleObject.Table.ReportTable.tr.groupHeader.FontSize);
			font-weight: $($StyleObject.Table.ReportTable.tr.groupHeader.FontWeight);
			/*white-space:nowrap;*/
		}

		.report_table tr.optimalGroupHeader td {
			background: $($StyleObject.Table.ReportTable.tr.optimalGroupHeader.Background);
			color: $($StyleObject.Table.ReportTable.tr.optimalGroupHeader.Color);
			padding: $($StyleObject.Table.ReportTable.tr.optimalGroupHeader.Padding);
			text-align: $($StyleObject.Table.ReportTable.tr.optimalGroupHeader.TextAlign);
			font-size: $($StyleObject.Table.ReportTable.tr.optimalGroupHeader.FontSize);
			font-weight: $($StyleObject.Table.ReportTable.tr.optimalGroupHeader.FontWeight);
			/*white-space:nowrap;*/
		}

		.report_table tr.marginalGroupHeader td {
			background: $($StyleObject.Table.ReportTable.tr.marginalGroupHeader.Background);
			color: $($StyleObject.Table.ReportTable.tr.marginalGroupHeader.Color);
			padding: $($StyleObject.Table.ReportTable.tr.marginalGroupHeader.Padding);
			text-align: $($StyleObject.Table.ReportTable.tr.marginalGroupHeader.TextAlign);
			font-size: $($StyleObject.Table.ReportTable.tr.marginalGroupHeader.FontSize);
			font-weight: $($StyleObject.Table.ReportTable.tr.marginalGroupHeader.FontWeight);
			/*white-space:nowrap;*/
		}

		.report_table tr.poorGroupHeader td {
			background: $($StyleObject.Table.ReportTable.tr.poorGroupHeader.Background);
			color: $($StyleObject.Table.ReportTable.tr.poorGroupHeader.Color);
			padding: $($StyleObject.Table.ReportTable.tr.poorGroupHeader.Padding);
			text-align: $($StyleObject.Table.ReportTable.tr.poorGroupHeader.TextAlign);
			font-size: $($StyleObject.Table.ReportTable.tr.poorGroupHeader.FontSize);
			font-weight: $($StyleObject.Table.ReportTable.tr.poorGroupHeader.FontWeight);
			/*white-space:nowrap;*/
		}

		table.report_table th{
			background: $($StyleObject.Table.ReportTable.th.Background);
			color:$($StyleObject.Table.ReportTable.th.Color);
			text-align:$($StyleObject.Table.ReportTable.th.TextAlign);
			padding:$($StyleObject.Table.ReportTable.th.Padding);
		}
		
		table.table_data th{
			background: $($StyleObject.Table.TableData.th.Background);
			color:$($StyleObject.Table.TableData.th.Color);
			text-align:$($StyleObject.Table.TableData.th.TextAlign);
			padding:$($StyleObject.Table.TableData.th.Padding);
		}
		
		table.report_table td{
			padding:$($StyleObject.Table.ReportTable.td.Padding);
			border-bottom: $($StyleObject.Table.ReportTable.td.BorderBottom);
			border-right: $($StyleObject.Table.ReportTable.td.BorderRight);
		}
		
		table.table_data td{
			padding:$($StyleObject.Table.TableData.td.Padding);
			border-bottom: $($StyleObject.Table.TableData.td.BorderBottom);
			border-right: $($StyleObject.Table.TableData.td.BorderRight);
		}

		table.table_info td{
			padding-left:$($StyleObject.Table.TableInfo.td.PaddingLeft);
			font-weight: $($StyleObject.Table.TableInfo.td.FontWeight);
			font-size: $($StyleObject.Table.TableInfo.td.FontSize);
		}

		table.report_table tr.odd{
			background: $($StyleObject.Table.ReportTable.tr.Odd.Background);
		}
		
		table.table_data tr.odd{
			background: $($StyleObject.Table.TableData.tr.Odd.Background);
		}
		
		table.report_table tr.even{
			background: $($StyleObject.Table.ReportTable.tr.Even.Background);
		}
		
		table.table_data tr.even{
			background: $($StyleObject.Table.TableData.tr.Even.Background);
		}

		span.vm_location{
			color:#597799;
		}

		.report_table td.blackLine {
			background: $($StyleObject.Table.ReportTable.td.blackLine.Background);
			padding: $($StyleObject.Table.ReportTable.td.blackLine.Padding);
			border-bottom: $($StyleObject.Table.ReportTable.td.blackLine.BorderBottom);
		}

		tr.aggregate {
			font-weight:$($StyleObject.Table.TableData.tr.aggregate.FontWeight);
			border-top:$($StyleObject.Table.TableData.tr.aggregate.BorderTop);
			mso-border-top-alt: $($StyleObject.Table.TableData.tr.aggregate.MSOBorderTopAlt);
			border-bottom: $($StyleObject.Table.TableData.tr.aggregate.BorderBottom);
			background: $($StyleObject.Table.TableData.tr.aggregate.Background);
		}
	</style>"
}
Function Set-HtmlTableFormat {
<#
    .Synopsis
      Takes an html table and converts that html table to use the standard HtmlStyle from HtmlStyleReport 
    .Description
      Takes an html table and converts that html table to use the standard HtmlStyle from HtmlStyleReport 
    .Notes
	  Author     		: Sammy Shuck
	.EXAMPLE  
	  $report | Select Type,"Esxi Version",Name,"Stateless Runtime" | ConvertTo-Html -Fragment | Set-HtmlTableFormat
#> 	
	Param(
       	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$Line
   	)
	Begin {
       	[string]$CSSEvenClass = "even"
   	    [string]$CSSOddClass = "odd"
		$ClassName = $CSSEvenClass
	}
	Process {
		If ($Line.Contains("<tr><td>")){
			$Line = $Line.Replace("<tr>","<tr class=""$ClassName"">")
			If ($ClassName -eq $CSSEvenClass){
				$ClassName = $CSSOddClass
			}
			Else{
				$ClassName = $CSSEvenClass
			}
		}
		If($Line.Contains("<table>")){
			$Line = $Line.Replace("<table>","<div class=""tableData""><table width=""100%"" cellspacing=""0"" cellpadding=""0"" class=""table_data"">")
		}
		return $Line
	}
}
Function Get-HtmlHeader{
	Param(
		[Parameter(Mandatory=$true)]
		$Message,
		[Parameter(Mandatory=$true)]
		$Title,
		[Parameter(Mandatory=$true)]
		$ResultCount,
    $Image,
		$ReportStyle = (New-HtmlReportStyle)
	)
  "<html xmlns:rep='http://www.embotics.com/vcommander/report'><head>
  <meta http-equiv='Content-Type' content='text/html; charset=us-ascii'>
  <title>UCG Report</title>
  $($ReportStyle)
  <body>
  <div class='message'>
    <span style='font-size:12px;'>$($Message)</span>
  </div>
  <div class='wrapper'>
    <table cellspacing='0' cellpadding='0' width='100%'>
      <tr>
        <td>
          <div class='report_banner_title'>
            <h1>$($Title)</h1>
          </div>
          <div class='report_banner_subtitle'>
            <table class='clear_border_report_table'>
              <tr>
                <td><h4>Creation Date:</h4></td>
                <td colspan='2'>$(Get-Date)</td>
              </tr>
            </table>
          </div>
        </td> 
        <td valign=top style='padding:0in 0in 0in 0in'>
          <p align=right style='text-align:right'>
              <img width=250 height=38 src='$image' style='float:right' border=0 >
          </p>
        </td>
      </tr>
    </table>
    <div name='result_count'>
      <ul class='report_para'>
        <table class='clear_border_report_table'>
          <tr>
            <td><h4>Result Count:</h4></td>
            <td>$($ResultCount)</td>
          </tr>
        </table>
      </ul>
    </div>
  <div style='margin-top:10px'>"
}
Function Get-HtmlFooter{
	Param(
		[Parameter(Mandatory=$false)]
		[string]$Message
	)
	"
	</div>
	</div>
	<p class=""footer"">$($Message)</p>
	</div>
	</body>
	</html>"
}
Function Rotate-Logs(){
<# 
.SYNOPSIS  
	Used with the Write-Log function and will rotate a log based on the Size of the log
.DESCRIPTION  
	A user can choose the number of files to keep and the size of the file before being rotated
.NOTES  
	Author     		: Sammy Shuck
	Requires   		: Minimum of PowerShell V3
	
	When running multiple background jobs and all are trying to write to the same log file then
	there can be a situation in which multiple jobs all rotate a file at the same time and then
	you loose the logs. So there s a rnadom millisecond pause generated befor executing on a log rotate
	
.EXAMPLE  
	Rotate-Log -LogFilePath <path_to_file> -NumKeep 8 -SizeToRotate 1024kb
#> 
Param(
	[string]$LogFilePath = "",
	[int]$NumKeep = 24,
	$SizeToRotate=1000Kb
)
	#randomly pause between 10 and 100 ms
	$rndm = Get-Random -Minimum 10 -Maximum 100
	Sleep -Milliseconds $rndm
	#if a rotate-log is already in progress then rotateLog will be at the bottom of the file. check for this so multiple rotates are not happening
  While(-not (Get-Content -Path $LogFilePath).Contains("rotateLog")-and (Get-ChildItem $LogFilePath).Length -ge $SizeToRotate){
    try{
      Out-File -FilePath $LogFilePath -InputObject "rotateLog" -Append -Confirm:$false
      #$content = Get-Content -Path $LogFilePath
      [array]$allLogs = @()
		  #get the file and BaseName
		  $logFile = Get-ChildItem $LogFilePath
      $baseName = $logFile.BaseName
			#get all of the files similar to BaseName
			[array]$allLogs = Get-ChildItem "$($logFile.Directory)\$($baseName)*" | Sort LastWriteTime
      
      $fileCount = $allLogs.Count
			$allLogs | %{
				#Rename log files starting at 1
          If($_.BaseName -eq $logFile.BaseName){
            #Let's copy the contents to the next file then start new.
            Copy-Item -Path $LogFilePath -Destination "$($_.Directory)\$($baseName)$($fileCount)$($_.Extension)" -Confirm:$false -Force:$true
            Out-File -FilePath $LogFilePath -InputObject "[$(Get-Date)]`tNew File from Log Rotation" -Confirm:$false -ErrorAction SilentlyContinue
          }Else{
					  Rename-Item -Path $_.FullName -NewName "$($baseName)$($fileCount)$($_.Extension)" -Confirm:$false
          }
          $fileCount--
			}
      
      #get the files again since thay have been renamed
    	[array]$allLogs = Get-ChildItem "$($logFile.Directory)\$($baseName)*" | Sort -Descending LastWriteTime
    	#check if we have more than $Numkeep files and if so lets delete the older files
    	If($allLogs.Count -gt $NumKeep){
    		For( $x=$NumKeep; $x -le ($allLogs.Count - 1); $x++ ){
    			#need to loop through the logs files starting at the last log file to keep and remove the older files
    			Remove-Item -Path $allLogs[$x].FullName -Confirm:$false -Force:$true | Out-Null
    		}
    		[array]$allLogs = Get-ChildItem "$($logFile.Directory)\$($baseName)*" | Sort -Descending LastWriteTime
    	}
    }catch{ <#doNothing #> }
  }
  $currDate = Get-Date
  <#Just going to loop until the new file is created or time has exceeded 10 seconds. This will prevent other processes from creating multiple new files#> 
  While((Get-ChildItem $LogFilePath).Length -ge $SizeToRotate -and (Get-Date) -le $currDate.AddSeconds(10)){ 
	#randomly pause between 10 and 100 ms
	$rndm = Get-Random -Minimum 10 -Maximum 100
	Sleep -Milliseconds $rndm 
  }
  
  #if the time has exceeded ~10 seconds and the file still has rotateLog in the file, then we will run into an infinite loop and well, this is just going to cause problems.
  #So in this scenario we will want to rewrite the file and call the Rotate-Logs function again.
  If((Get-Date) -ge $currDate.AddSeconds(10) -and (Get-Content -Path $LogFilePath).Contains("rotateLog")){
	Get-Content -Path $LogFilePath | ?{$_ -ne "rotateLog"} | Out-File -FilePath $LogFilePath -ErrorAction SilentlyContinue
	Rotate-Logs -LogFilePath $LogFilePath -NumKeep = $NumKeep -SizeToRotate $SizeToRotate
  }
}
Function Write-Log(){
<# 
.SYNOPSIS  
	Custom Write-Log function that logs specific messages
.DESCRIPTION  
	A user passes a message in the format and style they wan to this function and this will
	write that message to a file of the users choosing
.NOTES  
	Author     		: Sammy Shuck
	Requires   		: Minimum of PowerShell V3
	
	When running multiple background jobs and all are trying to write to the same log file then
	there can be a situation in which multiple jobs compete for writing. So this function will try
	10 million times before it gives up and throws a message to the user.
	
.EXAMPLE  
	Write-Log -Path C:\temp\my_log.log -Message "Hello World!" -SizeToRotate 1024kb
#> 
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true,Position=1)]
		$Path,
		[Parameter(Mandatory=$true,Position=2,ValueFromPipeline=$true)]
		$Message,
		[Parameter(Mandatory=$false,Position=3)]
		$SizeToRotate=1000Kb
	)
	Process{
		If(Test-Path $path){
			try{
				#check the size of the log and rotate the log at a specific size
				If((Get-ChildItem $Path).Length -ge $SizeToRotate){
					#rotate the logs
					#Out-File -FilePath $Path -InputObject "[$(Get-Date)]`tInitialize Log Rotation" -Confirm:$false -ErrorAction SilentlyContinue
					Rotate-Logs -LogFilePath $Path -SizeToRotate $SizeToRotate
					#create a new log file with Name = Path
					#Out-File -FilePath $Path -InputObject "[$(Get-Date)]`tNew File from Log Rotation" -Confirm:$false -ErrorAction SilentlyContinue
					#Out-File -FilePath $Path -InputObject $Message -Confirm:$false -ErrorAction SilentlyContinue
				}#Else{ #Else the file size is not at the maximum yet so just write to the file
					
			  Out-File -FilePath $Path -InputObject $Message -Append -Confirm:$false -ErrorAction SilentlyContinue
			#}
			}catch{
				For($x=1; $x -le 10000000; $x++ ){
					#We are going to loop 10000000 times and if we get ERRORS 10000000 times (~10 seconds) then exit with a termination
					#Sleep -Milliseconds 200
					try{
						Out-File -FilePath $Path -InputObject $Message -Append -Confirm:$false -ErrorAction Stop
						#If successful the this next line will be processed essentially ending the loop
						$x = 10000001
					}catch{
						If($x -eq 10000000){ throw $_.Exception.Message }
					}
				}		
			}
		}Else{ #The file doesn't exist so lets attempt to write to the file.
			try{$log
				#this will create a new file, however, the path to file must be valid before a new file can be created
				#If the path is c:\temp\logs\logfile.log and the directory \logs\ doesn't exist then this will error
				Out-File -FilePath $Path -InputObject $Message -Confirm:$false -ErrorAction Stop
			}catch{
				throw "File Path $($Path) does not exist.`n$($_.Exception.Message)"
			}
		}
	}	
}
Function Format-Message(){
<# 
.SYNOPSIS  
	Custom Format-Message function that will format a message with a Date/Time stamp and add a Status tag of the users choosing
	and the message will be displayed on the screen
.DESCRIPTION  
	A user passes a message to this function and tags it with a status. The message will be output on the screen
	using Write-Host but will also return a System.String object that can be passed to Write-Log
	write that message to a file of the users choosing
.NOTES  
	Author     		: Sammy Shuck
	Requires   		: Minimum of PowerShell V3
	
	If wanting to output an object the best way is to use the Out-String -Stream option to stream the object's contents.
	Ex. Write-Output ($somePSObject | Select Prop1,Prop2,Prop4 | ft -AutoSize) | Out-String -Sream | Format-String
	This is incredibly helpful when using Format-Message to pipe to Write-Log since Write-Log wil lonly Out-File the
	contents of -Message.
	
.EXAMPLE  
	Format-String "Hellow World"

.EXAMPLE  
	Format-String "Hellow World" | Write-Log -Path C:\temp\hello_world.log

.EXAMPLE  
	This example is using a string instead of an object as stated in the NOTES section but the process is the same either way
	Write-Output "Hello World | Out-String -Stream | Format-Message | Write-Log -Path C:\temp\hellow_world.log
#> 
    [CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$true)]
		$Message,
        [Parameter(Mandatory=$false,Position=2)]
		$Status = "Info"
	)
    Begin{
        $datetime = Get-Date -Format "yyyy-MM-ddTHH:mm:ss:ffff"
        $return_message = ""
    }

    Process{
        $return_message += "$($Message)`n"
    }
    End{
        $return_message = $return_message.TrimEnd("`n")
        Write-Host "$($datetime)`t$($Status)`t$return_message"
        return "$($datetime)`t$($Status)`t$return_message"
    }
}
Function SetVmwareCmdletAlias(){
<#
.SYNOPSIS
	Create an alias for the Cluster cmdlets for VMware.
	
.DESCRIPTION
	Creates an Alias to VMware <verb>-Cluster cmdlet. If Microsoft FailoverClusters Module is loaded then these cmdlets will not work because both Vmware and Microsoft use the same Verb-Noun combination and Microsoft usually takes priority.

.EXAMPLE
	PS C:\> SetVmwareCmdletAlias
#>
	New-Alias -Description "This is an Alias to VMware New-Cluster cmdlet. If Microsoft FailoverClusters Module is loaded then this cmdlet will not work because both Vmware and Microsoft use the same Verb-Noun combination and Microsoft usually takes priority." -Name New-VmCluster -Value VMware.VimAutomation.Core\New-Cluster -Force:$true -Confirm:$false -PassThru:$true -Scope Global | Out-Null
	New-Alias -Description "This is an Alias to VMware Get-Cluster cmdlet. If Microsoft FailoverClusters Module is loaded then this cmdlet will not work because both Vmware and Microsoft use the same Verb-Noun combination and Microsoft usually takes priority." -Name Get-VmCluster -Value VMware.VimAutomation.Core\Get-Cluster -Force:$true -Confirm:$false -PassThru:$true -Scope Global | Out-Null
	New-Alias -Description "This is an Alias to VMware Set-Cluster cmdlet. If Microsoft FailoverClusters Module is loaded then this cmdlet will not work because both Vmware and Microsoft use the same Verb-Noun combination and Microsoft usually takes priority." -Name Set-VmCluster -Value VMware.VimAutomation.Core\Set-Cluster -Force:$true -Confirm:$false -PassThru:$true -Scope Global | Out-Null
	New-Alias -Description "This is an Alias to VMware Remove-Cluster cmdlet. If Microsoft FailoverClusters Module is loaded then this cmdlet will not work because both Vmware and Microsoft use the same Verb-Noun combination and Microsoft usually takes priority." -Name Remove-VmCluster -Value VMware.VimAutomation.Core\Remove-Cluster -Force:$true -Confirm:$false -PassThru:$true -Scope Global | Out-Null
}
Function Get-ViSession {
<#
.SYNOPSIS
	Lists vCenter Sessions.
	
.DESCRIPTION
	Lists all connected vCenter Sessions.

.EXAMPLE
	PS C:\> Get-VISession

.EXAMPLE
	PS C:\> Get-VISession | Where { $_.IdleMinutes -gt 5 }
#>
    $SessionMgr = Get-View $DefaultViserver.ExtensionData.Client.ServiceContent.SessionManager
    $AllSessions = @()
    $SessionMgr.SessionList | %{   
        $Session = New-Object -TypeName PSObject -Property @{
            Key = $_.Key
            UserName = $_.UserName
            FullName = $_.FullName
            LoginTime = ($_.LoginTime).ToLocalTime()
            LastActiveTime = ($_.LastActiveTime).ToLocalTime()
        }
        If ($_.Key -eq $SessionMgr.CurrentSession.Key) {
        	$Session | Add-Member -MemberType NoteProperty -Name Status -Value "Current Session"
        }Else{
			$Session | Add-Member -MemberType NoteProperty -Name Status -Value "Idle"
		}
		$Session | Add-Member -MemberType NoteProperty -Name IdleMinutes -Value ([Math]::Round(((Get-Date) - ($_.LastActiveTime).ToLocalTime()).TotalMinutes))
		
		$AllSessions += $Session
	}
	$AllSessions
}
Function Encrypt-String{
<# 
.SYNOPSIS  
	Encrypts a string supplied by the user, using the user's own unique encryption passkey
.DESCRIPTION  
	Encrypts a string supplied by the user, using the user's own unique encryption passkey
.NOTES  
	Function Name  	: Encrypt-String 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Encrypt the string HelloWorld using a Passkey of WorldHello
	Encrypt-String "HelloWorld" "WorldHello"
.PARAMETER String
	Required: True
	The string that is to be encrypted.
.PARAMETER Passkey
	Required: True
	The PassKey that is used to decrypt the string.
.PARAMETER arrayOutput
	Required: False
	Do Not Use!
#> 
	[CmdletBinding(ConfirmImpact="Low")]
   Param (
   		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,HelpMessage="The string that is to be encrypted.")]
		[String] $String,		
		[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$false,HelpMessage="The PassKey that is used to decrypt the string.")]
		[String] $Passkey,
		[Parameter(Mandatory=$false,Position=2,ValueFromPipeline=$false,HelpMessage="Do Not Use!")]
		[Switch] $arrayOutput
	)
	PROCESS {
		[String] $salt = "NordSaltCrypto";
		[String] $init = "NordIV_Password";
		
		$r = new-Object System.Security.Cryptography.RijndaelManaged
		$p = [Text.Encoding]::UTF8.GetBytes($Passkey)
		$s = [Text.Encoding]::UTF8.GetBytes($salt)
		$r.Key = (new-Object Security.Cryptography.PasswordDeriveBytes $p, $s, "SHA1", 5).GetBytes(32) #256/8
		$r.IV = (new-Object Security.Cryptography.SHA1Managed).ComputeHash( [Text.Encoding]::UTF8.GetBytes($init) )[0..15] 
		$c = $r.CreateEncryptor()
		$ms = new-Object IO.MemoryStream
		$cs = new-Object Security.Cryptography.CryptoStream $ms,$c,"Write"
		$sw = new-Object IO.StreamWriter $cs
		$sw.Write($String)
		$sw.Close()
		$cs.Close()
		$ms.Close()
		$r.Clear()
		[byte[]]$result = $ms.ToArray()
		return [Convert]::ToBase64String($result)
	}
}
Function Decrypt-String{
<# 
.SYNOPSIS  
	Decrypts an encrypted string supplied by the user, 
	using the user's own unique encryption passkey
.DESCRIPTION  
	Decrypts an encrypted string supplied by the user, 
	using the user's own unique encryption passkey
.NOTES  
	Function Name  	: Decrypt-String 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Decrypt the encrypted string /aqvdv6pJGEPNFlGynXwpw== using a Passkey 
	of MyPassPhrase
	Decrypt-String "/aqvdv6pJGEPNFlGynXwpw==" "MyPassPhrase"
.PARAMETER Encrypted
	Required: True
	The encrypted string that is to be decrypted.
.PARAMETER Passkey
	Required: True
	The PassKey that is used to decrypt the string.
#>
Param(
[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,HelpMessage="The encrypted string that is to be decrypted.")]
$Encrypted,
[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$false,HelpMessage="The PassKey that is used to decrypt the string.")]
[String] $Passkey
)
	$salt="NordSaltCrypto"
	$init="NordIV_Password"

	if($Encrypted -is [string]){
		$Encrypted = [Convert]::FromBase64String($Encrypted)
   	}
	$r = new-Object System.Security.Cryptography.RijndaelManaged
	$pass = [Text.Encoding]::UTF8.GetBytes($Passkey)
	$salt = [Text.Encoding]::UTF8.GetBytes($salt)
	$r.Key = (new-Object Security.Cryptography.PasswordDeriveBytes $pass, $salt, "SHA1", 5).GetBytes(32) #256/8
	$r.IV = (new-Object Security.Cryptography.SHA1Managed).ComputeHash( [Text.Encoding]::UTF8.GetBytes($init) )[0..15]
	$d = $r.CreateDecryptor()
	$ms = new-Object IO.MemoryStream @(,$Encrypted)
	$cs = new-Object Security.Cryptography.CryptoStream $ms,$d,"Read"
	$sr = new-Object IO.StreamReader $cs
	Write-Output $sr.ReadToEnd()
	$sr.Close()
	$cs.Close()
	$ms.Close()
	$r.Clear()
}
Function Decipher-Credentials{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials
.DESCRIPTION  
	Returns Encrypted Secure Credentials 
.NOTES  
	Function Name  	: Decipher-Credentials 
	Author     		: Sammy Shuck
	Requires   		: PowerShell v5
.EXAMPLE  
	Decipher-Credentials -ClientId <ClientId> -Username <username>
#> 
  Param(
  [Parameter(Mandatory=$true, position=1)]
  [string]$ClientId = $null,
  [Parameter(Mandatory=$true, position=2)]
  [string]$Username = $null,
  [Parameter(Mandatory=$true, position=3)]
  [string]$RSAPrivateFile = $null,
  [Parameter(Mandatory=$true, position=4)]
  [string]$RSASecret = $null
  )
  	BEGIN {
	Import-Module D:\Temp\Ucgmodule -WarningAction SilentlyContinue -Scope global
	  try{
		add-type @"
		    using System.Net;
		    using System.Security.Cryptography.X509Certificates;
		    public class TrustAllCertsPolicy : ICertificatePolicy {
		        public bool CheckValidationResult(
		            ServicePoint srvPoint, X509Certificate certificate,
		            WebRequest request, int certificateProblem) {
		            return true;
		        }
		    }
"@
	  }catch{
			Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
			Write-Error $_
	  }
	  
	  Format-Message -Message "Ignore Self Signed Certs setting" | Write-Log -Path $module_log
	  try{
	  	[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
	  }catch{
			Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
			Write-Error $_
	  }
	}
	
	PROCESS {
		try{
			trap{ 
				Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
				throw $_ 
			}
			$aes_cipher = New-Object AesCipher -ErrorAction Stop
			$rsa_cipher = [RsaCipher]::new()
			Format-Message -Message "Running API Query GET:https://credstore/credentialstore/GetCredential?ClientId=$($ClientId)&username=$($Username)" | Write-Log -Path $module_log
			$json_response = Invoke-RestMethod "https://credstore/credentialstore/GetCredential?ClientId=$($ClientId)&username=$($Username)" -Method:Get
			Write-Output ($json_response[0].secret[0] | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $module_log
			$rsa_cipher.decrypt($json_response[0].secret[0].shared_key, $params.RSAPrivateFile, $params.RSASecret)
			$aes_key = $rsa_cipher.get_decrypted_message()
			$aes_cipher.decrypt($json_response[0].secret[0].password, $aes_key)
			return New-Object PSObject -Property @{Username=$Username;SecurePassword=(($aes_cipher.get_DecryptedData()) | ConvertTo-SecureString -AsPlainText -Force)}
		}catch{
			Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
			Write-Error $_
			throw $_
	  }
	}
}
Function Validate-RequiredLoginParameter{
	Param(
		[Parameter(Mandatory=$false)]
	  	[string]$ClientId = $null,
	  	[Parameter(Mandatory=$false)]
	  	[string]$RSAPrivateFile = $null,
	  	[Parameter(Mandatory=$false)]
	  	[string]$RSASecret = $null
	)
	if ($PSVersionTable.PSVersion.Major -lt 5){
		$msg = "InvalidPSVersion: Powershell Version $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor).$($PSVersionTable.PSVersion.build).$($PSVersionTable.PSVersion.Revision) is not version 5.0.0.0 or greater. This feature is only enabled for PS Versions 5+."
		Format-Message -Message $msg -Status Exception | Write-Log -Path $module_log
		Write-Error $msg -Category:NotImplemented -ErrorAction Stop
	}
	
	if (-not $ClientId){
		# ClientId was not provided by the user, let's look for an environment variable
		if ($env:ClientId){
			$ClientId = $env:ClientId
			Format-Message -Message "Validate-RequiredLoginParameter`tClientId: $($ClientId)" | Write-Log -Path $module_log
		}else{
			$msg = "InvalidArgument: 'ClientId' cannot be Null or Empty. Try Get-Help Validate-RequiredLoginParameters for more information."
			Format-Message -Message $msg -Status Exception | Write-Log -Path $module_log
			Write-Error $msg -Category:InvalidArgument -ErrorAction Stop
		}
	}
	
	if (-not $RSAPrivateFile){
		# RSAPrivateFile was not provided by the user, let's look for an environment variable
		if ($env:RSAPrivateFile){
			$RSAPrivateFile = $env:RSAPrivateFile
			Format-Message -Message "Validate-RequiredLoginParameter`tRSAPrivateFile: $($RSAPrivateFile)" | Write-Log -Path $module_log
		}else{
			$msg = "InvalidArgument: 'RSAPrivateFile' cannot be Null or Empty. Try Get-Help Validate-RequiredLoginParameters for more information."
			Format-Message -Message $msg -Status Exception | Write-Log -Path $module_log
			Write-Error $msg -Category:InvalidArgument -ErrorAction Stop
		}
	}
	if (-not (Test-Path $RSAPrivateFile)){
		$msg = "InvalidArgument: 'RSAPrivateFile' must be a file path to a private key file. Try Get-Help Validate-RequiredLoginParameters for more information."
		Format-Message -Message $msg -Status Exception | Write-Log -Path $module_log
		Write-Error $msg -Category:InvalidArgument -ErrorAction Stop
	}
		
	if (-not $RSASecret){
		# RSASecret was not provided by the user, let's look for an environment variable
		if ($env:RSASecret){
			$RSASecret = $env:RSASecret
			Format-Message -Message "Validate-RequiredLoginParameter`tRSASecret: $($RSASecret[0..3])...[redacted]" | Write-Log -Path $module_log
		}else{
			$msg = "InvalidArgument: 'RSASecret' cannot be Null or Empty. Try Get-Help Validate-RequiredLoginParameters for more information."
			Format-Message -Message $msg -Status Exception | Write-Log -Path $module_log
			Write-Error $msg -Category:InvalidArgument -ErrorAction Stop
		}
	}
	if (Test-Path $RSASecret){
		# RSASecret is contained in a file, so read in the RSASecret text from the file
		$RSASecret = Get-Content $RSASecret
	}else{
		# RSASecret is assumed to be in clear text
	}
	
	return New-Object PsObject -Property @{ClientId=$ClientId;RSAPrivateFile=$RSAPrivateFile;RSASecret=$RSASecret}
}
Function Login-Ucs_old{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for Ucs login nord\oppucs01
.DESCRIPTION  
	Returns Encrypted Secure Credentials for vCenter login nord\oppucs01
.NOTES  
	Function Name  	: Login-Ucs 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Connect-Ucs -Name <ucsm> -Credential (Login-Ucs)
#> 
  Param(
  [Parameter(Mandatory=$false)]
  [string]$ClientId = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSAPrivateFile = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSASecret = $null
  )
  	#BEGIN {
	#	$params = Validate-RequiredLoginParameter -ClientId $ClientId -RSAPrivateFile $RSAPrivateFile -RSASecret $RSASecret
	#}
	PROCESS {
		try{
			trap{ throw $_ }
			[string]$private:ucg_crypto = "G:\ucg_secure\ucg_crypto"
	
			[xml]$xml = Get-Content G:\ucg_secure\ucg_secure.xml
			$pkey = [Text.Encoding]::UTF8.GetBytes((Get-ChildItem $ucg_crypto | Get-MD5Checksum))
			$p = $xml.Credentials.ucs.current.cred.password | ConvertTo-SecureString -Key $pkey[0..31]
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $xml.Credentials.ucs.current.cred.username,$p
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function Login-Ucs{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for Ucs login nord\oppucs01
.DESCRIPTION  
	Returns Encrypted Secure Credentials for vCenter login nord\oppucs01
.NOTES  
	Function Name  	: Login-Ucs 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V5
.EXAMPLE  
	Connect-Ucs -Name <ucsm> -Credential (Login-Ucs)
#> 
  Param(
  [Parameter(Mandatory=$false)]
  [string]$ClientId = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSAPrivateFile = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSASecret = $null
  )
  	BEGIN {
		try{
			trap{ 
				Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
				throw $_ 
			}
			$params = Validate-RequiredLoginParameter -ClientId $ClientId -RSAPrivateFile $RSAPrivateFile -RSASecret $RSASecret
		}catch{
			Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
			Write-Error $_
			throw $_
		}
	}
	PROCESS {
		try{
			trap{ 
				Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
				throw $_ 
			}
			$u = 'oppucs01'
			Format-Message "Initializing Server Named Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe = new-object System.IO.Pipes.NamedPipeServerStream('Cred',[System.IO.Pipes.PipeDirection]::InOut);
			Format-Message "Initializing _get_credential.ps1 for '$($u)'" | Write-Log -Path $module_log
			$job = Start-Job $_get_credential -ArgumentList @($_get_credential_file,$u)
			Format-Message "Initializing StreamReader" | Write-Log -Path $module_log
			$sr = new-object System.IO.StreamReader($pipe);
			$json = ''
			Format-Message "Waiting for Client Pipe Connection" | Write-Log -Path $module_log
			$pipe.WaitForConnection()
			Format-Message "Reading data from Pipe 'Cred'" | Write-Log -Path $module_log
			while (($cmd = $sr.ReadLine()) -ne 'exit'){
 				$json =  $json + $cmd
			}
			Format-Message "Disposing StreamReader" | Write-Log -Path $module_log
			$sr.Dispose()
			Format-Message "Disposing Client Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe.Dispose()
			
			$cred_obj = ConvertFrom-Json $json
			$cred_obj.SecurePassword = ConvertTo-SecureString $cred_obj.SecurePassword
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @([string]::Concat('', $cred_obj.Username),$cred_obj.SecurePassword)
		}catch{
			Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
			Write-Error $_
			throw $_
		}
	}
}
Function Login-MSA_old{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for HP MSA login admin
.DESCRIPTION  
	Returns Encrypted Secure Credentials for HP MSA login admin
.NOTES  
	Function Name  	: Login-MSA 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
#> 
   
	PROCESS {
		try{
			trap{ throw $_ }
			[string]$private:ucg_crypto = "G:\ucg_secure\ucg_crypto"
	
			[xml]$xml = Get-Content G:\ucg_secure\ucg_secure.xml
			$pkey = [Text.Encoding]::UTF8.GetBytes((Get-ChildItem $ucg_crypto | Get-MD5Checksum))
			$p = $xml.Credentials.msa.current.cred.password | ConvertTo-SecureString -Key $pkey[0..31]
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $xml.Credentials.msa.current.cred.username,$p
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function Login-MSA{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for HP MSA login admin
.DESCRIPTION  
	Returns Encrypted Secure Credentials for HP MSA login admin
.NOTES  
	Function Name  	: Login-MSA 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V5
#> 
   
  Param(
  [Parameter(Mandatory=$false)]
  [string]$ClientId = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSAPrivateFile = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSASecret = $null
  )
  	BEGIN {
		try{
			trap{ 
				Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
				throw $_ 
			}
			$params = Validate-RequiredLoginParameter -ClientId $ClientId -RSAPrivateFile $RSAPrivateFile -RSASecret $RSASecret
		}catch{
			Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
			Write-Error $_
			throw $_
		}
	}
	PROCESS {
		try{
			trap{ 
				Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
				throw $_ 
			}
			$u = 'p2000_admin'
			Format-Message "Initializing Server Named Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe = new-object System.IO.Pipes.NamedPipeServerStream('Cred',[System.IO.Pipes.PipeDirection]::InOut);
			Format-Message "Initializing _get_credential.ps1 for '$($u)'" | Write-Log -Path $module_log
			$job = Start-Job $_get_credential -ArgumentList @($_get_credential_file,$u)
			Format-Message "Initializing StreamReader" | Write-Log -Path $module_log
			$sr = new-object System.IO.StreamReader($pipe);
			$json = ''
			Format-Message "Waiting for Client Pipe Connection" | Write-Log -Path $module_log
			$pipe.WaitForConnection()
			Format-Message "Reading data from Pipe 'Cred'" | Write-Log -Path $module_log
			while (($cmd = $sr.ReadLine()) -ne 'exit'){
 				$json =  $json + $cmd
			}
			Format-Message "Disposing StreamReader" | Write-Log -Path $module_log
			$sr.Dispose()
			Format-Message "Disposing Client Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe.Dispose()
			
			$cred_obj = ConvertFrom-Json $json
			$cred_obj.SecurePassword = ConvertTo-SecureString $cred_obj.SecurePassword
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @([string]::Concat('admin', ''),$cred_obj.SecurePassword)
		}catch{
			Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
			Write-Error $_
			throw $_
		}
	}
}
Function Login-vCenter_old{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for vCenter login nord\oppvmwre
.DESCRIPTION  
	Returns Encrypted Secure Credentials for vCenter login nord\oppvmwre
.NOTES  
	Function Name  	: Login-vCenter 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Connect-VIServer -Server <vcenter> -Credential (Login-vCenter)
#> 
   
	PROCESS {
		try{
			trap{ throw $_ }
			[string]$private:ucg_crypto = "G:\ucg_secure\ucg_crypto"
	
			[xml]$xml = Get-Content G:\ucg_secure\ucg_secure.xml
			$pkey = [Text.Encoding]::UTF8.GetBytes((Get-ChildItem $ucg_crypto | Get-MD5Checksum))
			$p = $xml.Credentials.vcenter.current.cred.password | ConvertTo-SecureString -Key $pkey[0..31]
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $xml.Credentials.vcenter.current.cred.username,$p
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function Login-vCenter{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for vCenter login nord\oppvmwre
.DESCRIPTION  
	Returns Encrypted Secure Credentials for vCenter login nord\oppvmwre
.NOTES  
	Function Name  	: Login-vCenter 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V5
.EXAMPLE  
	Connect-VIServer -Server <vcenter> -Credential (Login-vCenter)
#> 
   
  Param(
  [Parameter(Mandatory=$false)]
  [string]$ClientId = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSAPrivateFile = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSASecret = $null
  )
  	BEGIN {
		try{
			trap{ 
				Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
				throw $_ 
			}
			$params = Validate-RequiredLoginParameter -ClientId $ClientId -RSAPrivateFile $RSAPrivateFile -RSASecret $RSASecret
		}catch{
			Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
			Write-Error $_
			throw $_
		}
	}
	PROCESS {
		try{
			trap{ 
				Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
				throw $_ 
			}
			$u = 'oppvmwre'
			Format-Message "Initializing Server Named Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe = new-object System.IO.Pipes.NamedPipeServerStream('Cred',[System.IO.Pipes.PipeDirection]::InOut);
			Format-Message "Initializing _get_credential.ps1 for '$($u)'" | Write-Log -Path $module_log
			$job = Start-Job $_get_credential -ArgumentList @($_get_credential_file,$u)
			Format-Message "Initializing StreamReader" | Write-Log -Path $module_log
			$sr = new-object System.IO.StreamReader($pipe);
			$json = ''
			Format-Message "Waiting for Client Pipe Connection" | Write-Log -Path $module_log
			$pipe.WaitForConnection()
			Format-Message "Reading data from Pipe 'Cred'" | Write-Log -Path $module_log
			while (($cmd = $sr.ReadLine()) -ne 'exit'){
 				if ($cmd -eq 'exception'){
					Write-Error "Exception: Error in Processing Credentials, please check logs at $($module_log) for more information" -ErrorAction Stop
				}
				$json =  $json + $cmd
			}
			Format-Message "Disposing StreamReader" | Write-Log -Path $module_log
			$sr.Dispose()
			Format-Message "Disposing Client Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe.Dispose()
			
			$cred_obj = ConvertFrom-Json $json
			$cred_obj.SecurePassword = ConvertTo-SecureString $cred_obj.SecurePassword
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @([string]::Concat('nord\', $cred_obj.Username),$cred_obj.SecurePassword)
		}catch{
			Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message -Status Exception | Write-Log -Path $module_log
			Write-Error $_
			Format-Message "Disposing StreamReader during exception" | Write-Log -Path $module_log
			$sr.Dispose()
			Format-Message "Disposing Client Pipe 'Cred' during exception" | Write-Log -Path $module_log
			$pipe.Dispose()
			throw $_
		}
	}
}
Function Login-vCenterReadOnly_old{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for vCenter login nord\oppvfog01 which is a read only account
.DESCRIPTION  
	Returns Encrypted Secure Credentials for vCenter nord\oppvfog01 which is a read only account
.NOTES  
	Function Name  	: Login-vCenterReadOnly 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Connect-VIServer -Server <vcenter> -Credential (Login-vCenterReadOnly)
#> 
   
	PROCESS {
		try{
			trap{ throw $_ }
			[string]$private:ucg_crypto = "G:\ucg_secure\ucg_crypto"
	
			[xml]$xml = Get-Content G:\ucg_secure\ucg_secure.xml
			$pkey = [Text.Encoding]::UTF8.GetBytes((Get-ChildItem $ucg_crypto | Get-MD5Checksum))
			$p = $xml.Credentials.vcenterreadonly.current.cred.password | ConvertTo-SecureString -Key $pkey[0..31]
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $xml.Credentials.vcenterreadonly.current.cred.username,$p
		}catch{
			Write-Error $_
			throw $_
		}
#		$tmp = Get-Content G:\vSphere-Key-Files\vCenterReadOnly.xml | ConvertTo-SecureString -Key (1..16)
#		$tmp_p = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'nord\oppvfog01',$tmp
#		$tmp = $null
#		return $tmp_p
	}
}
Function Login-vCenterReadOnly{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for vCenter login nord\oppvfog01 which is a read only account
.DESCRIPTION  
	Returns Encrypted Secure Credentials for vCenter nord\oppvfog01 which is a read only account
.NOTES  
	Function Name  	: Login-vCenterReadOnly 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V5
.EXAMPLE  
	Connect-VIServer -Server <vcenter> -Credential (Login-vCenterReadOnly)
#> 
   
  Param(
  [Parameter(Mandatory=$false)]
  [string]$ClientId = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSAPrivateFile = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSASecret = $null
  )
  	BEGIN {
		try{
			trap{ throw $_ }
			$params = Validate-RequiredLoginParameter -ClientId $ClientId -RSAPrivateFile $RSAPrivateFile -RSASecret $RSASecret
		}catch{
			Write-Error $_
			throw $_
		}
	}
	PROCESS {
		try{
			trap{ throw $_ }
			$u = 'oppvfog01'
			Format-Message "Initializing Server Named Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe = new-object System.IO.Pipes.NamedPipeServerStream('Cred',[System.IO.Pipes.PipeDirection]::InOut);
			Format-Message "Initializing _get_credential.ps1 for '$($u)'" | Write-Log -Path $module_log
			$job = Start-Job $_get_credential -ArgumentList @($_get_credential_file,$u)
			Format-Message "Initializing StreamReader" | Write-Log -Path $module_log
			$sr = new-object System.IO.StreamReader($pipe);
			$json = ''
			Format-Message "Waiting for Client Pipe Connection" | Write-Log -Path $module_log
			$pipe.WaitForConnection()
			Format-Message "Reading data from Pipe 'Cred'" | Write-Log -Path $module_log
			while (($cmd = $sr.ReadLine()) -ne 'exit'){
 				$json =  $json + $cmd
			}
			Format-Message "Disposing StreamReader" | Write-Log -Path $module_log
			$sr.Dispose()
			Format-Message "Disposing Client Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe.Dispose()
			
			$cred_obj = ConvertFrom-Json $json
			$cred_obj.SecurePassword = ConvertTo-SecureString $cred_obj.SecurePassword
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @([string]::Concat('nord\', $cred_obj.Username),$cred_obj.SecurePassword)
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function Login-vSphere_old{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for vSphere ESXi login root
.DESCRIPTION  
	Returns Encrypted Secure Credentials for vSphere ESXi login root
.NOTES  
	Function Name  	: Login-vSphere
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Connect-VIServer -Server <VMHost> -Credential (Login-vSphere)
#> 
   
	PROCESS {
		try{
			trap{ throw $_ }
			[string]$private:ucg_crypto = "G:\ucg_secure\ucg_crypto"
	
			[xml]$xml = Get-Content G:\ucg_secure\ucg_secure.xml
			$pkey = [Text.Encoding]::UTF8.GetBytes((Get-ChildItem $ucg_crypto | Get-MD5Checksum))
			$p = $xml.Credentials.vsphere.current.cred.password | ConvertTo-SecureString -Key $pkey[0..31]
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $xml.Credentials.vsphere.current.cred.username,$p
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function Login-vSphere{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for vSphere ESXi login root
.DESCRIPTION  
	Returns Encrypted Secure Credentials for vSphere ESXi login root
.NOTES  
	Function Name  	: Login-vSphere
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Connect-VIServer -Server <VMHost> -Credential (Login-vSphere)
#> 
   
  Param(
  [Parameter(Mandatory=$false)]
  [string]$ClientId = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSAPrivateFile = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSASecret = $null
  )
  	BEGIN {
		try{
			trap{ throw $_ }
			$params = Validate-RequiredLoginParameter -ClientId $ClientId -RSAPrivateFile $RSAPrivateFile -RSASecret $RSASecret
		}catch{
			Write-Error $_
			throw $_
		}
	}
	PROCESS {
		try{
			trap{ throw $_ }
			$u = 'esxi_root'
			Format-Message "Initializing Server Named Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe = new-object System.IO.Pipes.NamedPipeServerStream('Cred',[System.IO.Pipes.PipeDirection]::InOut);
			Format-Message "Initializing _get_credential.ps1 for '$($u)'" | Write-Log -Path $module_log
			$job = Start-Job $_get_credential -ArgumentList @($_get_credential_file,$u)
			Format-Message "Initializing StreamReader" | Write-Log -Path $module_log
			$sr = new-object System.IO.StreamReader($pipe);
			$json = ''
			Format-Message "Waiting for Client Pipe Connection" | Write-Log -Path $module_log
			$pipe.WaitForConnection()
			Format-Message "Reading data from Pipe 'Cred'" | Write-Log -Path $module_log
			while (($cmd = $sr.ReadLine()) -ne 'exit'){
 				$json =  $json + $cmd
			}
			Format-Message "Disposing StreamReader" | Write-Log -Path $module_log
			$sr.Dispose()
			Format-Message "Disposing Client Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe.Dispose()
			
			$cred_obj = ConvertFrom-Json $json
			$cred_obj.SecurePassword = ConvertTo-SecureString $cred_obj.SecurePassword
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @([string]::Concat('root', ''),$cred_obj.SecurePassword)
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function Login-vSphereSIAB_old{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for vSphere ESXi login root
.DESCRIPTION  
	Returns Encrypted Secure Credentials for vSphere ESXi login root
.NOTES  
	Function Name  	: Login-vSphere
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Connect-VIServer -Server <VMHost> -Credential (Login-vSphere)
#> 
   
	PROCESS {
		try{
			trap{ throw $_ }
			[string]$private:ucg_crypto = "G:\ucg_secure\ucg_crypto"
	
			[xml]$xml = Get-Content G:\ucg_secure\ucg_secure.xml
			$pkey = [Text.Encoding]::UTF8.GetBytes((Get-ChildItem $ucg_crypto | Get-MD5Checksum))
			$p = $xml.Credentials.vspheresiab.current.cred.password | ConvertTo-SecureString -Key $pkey[0..31]
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $xml.Credentials.vspheresiab.current.cred.username,$p
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function Login-vSphereSIAB{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for vSphere ESXi login root
.DESCRIPTION  
	Returns Encrypted Secure Credentials for vSphere ESXi login root
.NOTES  
	Function Name  	: Login-vSphere
	Author     		: Sammy Shuck
	Requires   		: PowerShell V5
.EXAMPLE  
	Connect-VIServer -Server <VMHost> -Credential (Login-vSphere)
#> 
   
  Param(
  [Parameter(Mandatory=$false)]
  [string]$ClientId = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSAPrivateFile = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSASecret = $null
  )
  	BEGIN {
		try{
			trap{ throw $_ }
			$params = Validate-RequiredLoginParameter -ClientId $ClientId -RSAPrivateFile $RSAPrivateFile -RSASecret $RSASecret
		}catch{
			Write-Error $_
			throw $_
		}
	}
	PROCESS {
		try{
			trap{ throw $_ }
			$u = 'esxisiab_root'
			Format-Message "Initializing Server Named Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe = new-object System.IO.Pipes.NamedPipeServerStream('Cred',[System.IO.Pipes.PipeDirection]::InOut);
			Format-Message "Initializing _get_credential.ps1 for '$($u)'" | Write-Log -Path $module_log
			$job = Start-Job $_get_credential -ArgumentList @($_get_credential_file,$u)
			Format-Message "Initializing StreamReader" | Write-Log -Path $module_log
			$sr = new-object System.IO.StreamReader($pipe);
			$json = ''
			Format-Message "Waiting for Client Pipe Connection" | Write-Log -Path $module_log
			$pipe.WaitForConnection()
			Format-Message "Reading data from Pipe 'Cred'" | Write-Log -Path $module_log
			while (($cmd = $sr.ReadLine()) -ne 'exit'){
 				$json =  $json + $cmd
			}
			Format-Message "Disposing StreamReader" | Write-Log -Path $module_log
			$sr.Dispose()
			Format-Message "Disposing Client Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe.Dispose()
			
			$cred_obj = ConvertFrom-Json $json
			$cred_obj.SecurePassword = ConvertTo-SecureString $cred_obj.SecurePassword
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @([string]::Concat('root', ''),$cred_obj.SecurePassword)
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function Login-vSphereSIABBuild_old{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for vSphere ESXi login root
.DESCRIPTION  
	Returns Encrypted Secure Credentials for vSphere ESXi login root
.NOTES  
	Function Name  	: Login-vSphereSIABBuild
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Connect-VIServer -Server <VMHost> -Credential (Login-vSphereSIABBuild)
#> 
   
	PROCESS {
		try{
			trap{ throw $_ }
			[string]$private:ucg_crypto = "G:\ucg_secure\ucg_crypto"
	
			[xml]$xml = Get-Content G:\ucg_secure\ucg_secure.xml
			$pkey = [Text.Encoding]::UTF8.GetBytes((Get-ChildItem $ucg_crypto | Get-MD5Checksum))
			$p = $xml.Credentials.vspheresiabbuild.current.cred.password | ConvertTo-SecureString -Key $pkey[0..31]
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $xml.Credentials.vspheresiabbuild.current.cred.username,$p
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function Login-vSphereSIABBuild{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for vSphere ESXi login root
.DESCRIPTION  
	Returns Encrypted Secure Credentials for vSphere ESXi login root
.NOTES  
	Function Name  	: Login-vSphereSIABBuild
	Author     		: Sammy Shuck
	Requires   		: PowerShell V5
.EXAMPLE  
	Connect-VIServer -Server <VMHost> -Credential (Login-vSphereSIABBuild)
#> 
   
  Param(
  [Parameter(Mandatory=$false)]
  [string]$ClientId = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSAPrivateFile = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSASecret = $null
  )
  	BEGIN {
		try{
			trap{ throw $_ }
			$params = Validate-RequiredLoginParameter -ClientId $ClientId -RSAPrivateFile $RSAPrivateFile -RSASecret $RSASecret
		}catch{
			Write-Error $_
			throw $_
		}
	}
	PROCESS {
		try{
			trap{ throw $_ }
			$u = 'esxisiabbuild_root'
			Format-Message "Initializing Server Named Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe = new-object System.IO.Pipes.NamedPipeServerStream('Cred',[System.IO.Pipes.PipeDirection]::InOut);
			Format-Message "Initializing _get_credential.ps1 for '$($u)'" | Write-Log -Path $module_log
			$job = Start-Job $_get_credential -ArgumentList @($_get_credential_file,$u)
			Format-Message "Initializing StreamReader" | Write-Log -Path $module_log
			$sr = new-object System.IO.StreamReader($pipe);
			$json = ''
			Format-Message "Waiting for Client Pipe Connection" | Write-Log -Path $module_log
			$pipe.WaitForConnection()
			Format-Message "Reading data from Pipe 'Cred'" | Write-Log -Path $module_log
			while (($cmd = $sr.ReadLine()) -ne 'exit'){
 				$json =  $json + $cmd
			}
			Format-Message "Disposing StreamReader" | Write-Log -Path $module_log
			$sr.Dispose()
			Format-Message "Disposing Client Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe.Dispose()
			
			$cred_obj = ConvertFrom-Json $json
			$cred_obj.SecurePassword = ConvertTo-SecureString $cred_obj.SecurePassword
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @([string]::Concat('root', ''),$cred_obj.SecurePassword)
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function Login-InfluxDB_old{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for InfluxDB login anonymous
.DESCRIPTION  
	Returns Encrypted Secure Credentials for InfluxDB login anonymous
.NOTES  
	Function Name  	: Login-InfluxDB 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Connect-VIServer -Server <vcenter> -Credential (Login-InfluxDB)
#> 
   
	PROCESS {
		try{
			trap{ throw $_ }
			[string]$private:ucg_crypto = "G:\ucg_secure\ucg_crypto"
	
			[xml]$xml = Get-Content G:\ucg_secure\ucg_secure.xml
			$pkey = [Text.Encoding]::UTF8.GetBytes((Get-ChildItem $ucg_crypto | Get-MD5Checksum))
			$p = $xml.Credentials.influxdb.current.cred.password | ConvertTo-SecureString -Key $pkey[0..31]
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $xml.Credentials.influxdb.current.cred.username,$p
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function Login-InfluxDB{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for InfluxDB login anonymous
.DESCRIPTION  
	Returns Encrypted Secure Credentials for InfluxDB login anonymous
.NOTES  
	Function Name  	: Login-InfluxDB 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V5
.EXAMPLE  
	Connect-VIServer -Server <vcenter> -Credential (Login-InfluxDB)
#> 
   
  Param(
  [Parameter(Mandatory=$false)]
  [string]$ClientId = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSAPrivateFile = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSASecret = $null
  )
  	BEGIN {
		try{
			trap{ throw $_ }
			$params = Validate-RequiredLoginParameter -ClientId $ClientId -RSAPrivateFile $RSAPrivateFile -RSASecret $RSASecret
		}catch{
			Write-Error $_
			throw $_
		}
	}
	PROCESS {
		try{
			trap{ throw $_ }
			$u = 'influxdb_anonymous'
			Format-Message "Initializing Server Named Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe = new-object System.IO.Pipes.NamedPipeServerStream('Cred',[System.IO.Pipes.PipeDirection]::InOut);
			Format-Message "Initializing _get_credential.ps1 for '$($u)'" | Write-Log -Path $module_log
			$job = Start-Job $_get_credential -ArgumentList @($_get_credential_file,$u)
			Format-Message "Initializing StreamReader" | Write-Log -Path $module_log
			$sr = new-object System.IO.StreamReader($pipe);
			$json = ''
			Format-Message "Waiting for Client Pipe Connection" | Write-Log -Path $module_log
			$pipe.WaitForConnection()
			Format-Message "Reading data from Pipe 'Cred'" | Write-Log -Path $module_log
			while (($cmd = $sr.ReadLine()) -ne 'exit'){
 				$json =  $json + $cmd
			}
			Format-Message "Disposing StreamReader" | Write-Log -Path $module_log
			$sr.Dispose()
			Format-Message "Disposing Client Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe.Dispose()
			
			$cred_obj = ConvertFrom-Json $json
			$cred_obj.SecurePassword = ConvertTo-SecureString $cred_obj.SecurePassword
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @([string]::Concat('anonymous', ''),$cred_obj.SecurePassword)
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function Login-HyperV{
<# 
.SYNOPSIS  
	Returns Encrypted Secure Credentials for HyperV login nord\vcphypv
.DESCRIPTION  
	Returns Encrypted Secure Credentials for HyperV login nord\vcphypv
.NOTES  
	Function Name  	: Login-HyperV
	Author     		: Sammy Shuck
	Requires   		: PowerShell V5
.EXAMPLE  
	Get-SCVMMServer -ComputerName <vmmserver> -Credential (Login-HyperV)
#> 
   
  Param(
  [Parameter(Mandatory=$false)]
  [string]$ClientId = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSAPrivateFile = $null,
  [Parameter(Mandatory=$false)]
  [string]$RSASecret = $null
  )
  	BEGIN {
		try{
			trap{ throw $_ }
			$params = Validate-RequiredLoginParameter -ClientId $ClientId -RSAPrivateFile $RSAPrivateFile -RSASecret $RSASecret
		}catch{
			Write-Error $_
			throw $_
		}
	}
	PROCESS {
		try{
			trap{ throw $_ }
			$u = 'vcphypv'
			Format-Message "Initializing Server Named Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe = new-object System.IO.Pipes.NamedPipeServerStream('Cred',[System.IO.Pipes.PipeDirection]::InOut);
			Format-Message "Initializing _get_credential.ps1 for '$($u)'" | Write-Log -Path $module_log
			$job = Start-Job $_get_credential -ArgumentList @($_get_credential_file,$u)
			Format-Message "Initializing StreamReader" | Write-Log -Path $module_log
			$sr = new-object System.IO.StreamReader($pipe);
			$json = ''
			Format-Message "Waiting for Client Pipe Connection" | Write-Log -Path $module_log
			$pipe.WaitForConnection()
			Format-Message "Reading data from Pipe 'Cred'" | Write-Log -Path $module_log
			while (($cmd = $sr.ReadLine()) -ne 'exit'){
 				$json =  $json + $cmd
			}
			Format-Message "Disposing StreamReader" | Write-Log -Path $module_log
			$sr.Dispose()
			Format-Message "Disposing Client Pipe 'Cred'" | Write-Log -Path $module_log
			$pipe.Dispose()
			
			$cred_obj = ConvertFrom-Json $json
			$cred_obj.SecurePassword = ConvertTo-SecureString $cred_obj.SecurePassword
			return New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @([string]::Concat('nord\', $cred_obj.Username),$cred_obj.SecurePassword)
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function Create-vCenterLogin{
<# 
.SYNOPSIS  
	Creates Secure Password File for vCenter Login nord\oppvmwre
.DESCRIPTION  
	Creates Secure Password File for vCenter Login nord\oppvmwre
	This function can only be ran from the Scripty server
.NOTES  
	Function Name  	: Create-vCenterLogin 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Create-vCenterLogin
#> 
   
	PROCESS {
		Write-Warning "Create-vCenterLogin has been labeled obsolete. Please use ' New-LoginCredentials -CredentialType vCenter ' going further"
		Write-Error "Create-vCenterLogin has been labeled obsolete. Please use ' New-LoginCredentials -CredentialType vCenter ' going further"
		return $null
#		If(Test-Path "D:\git-ucg\vSphere-Key-Files\vCenter.xml"){
#		Read-Host -Prompt "Please type the password for the vCenter user 'nord\oppvmwre'" -AsSecureString | ConvertFrom-SecureString -Key (1..16) | Out-File D:\git-ucg\vSphere-Key-Files\vCenter.xml -Force -Confirm:$false
#		Write-Host "vCenter Login Credentials for 'nord\oppvmwre' Have Been Created"
#		cd "D:\git-ucg\vSphere-Key-Files"
#		git add -A
#		git commit -m "Changing the password for vCenterLogin nord\oppvmwre"
#		git push origin master
#		}
	}
}
Function Create-vCenterReadOnlyLogin{
<# 
.SYNOPSIS  
	Creates Secure Password File for vCenter Login nord\oppvfog01
.DESCRIPTION  
	Creates Secure Password File for vCenter Login nord\oppvfog01
.NOTES  
	Function Name  	: Create-vCenterReadOnlyLogin 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Create-vCenterReadOnlyLogin
#> 
   
	PROCESS {
		Write-Warning "Create-vCenterReadOnlyLogin has been labeled obsolete. Please use ' New-LoginCredentials -CredentialType vCenterReadOnly ' going further"
		Write-Error "Create-vCenterReadOnlyLogin has been labeled obsolete. Please use ' New-LoginCredentials -CredentialType vCenterReadOnly ' going further"
		return $null
#		If(Test-Path "D:\git-ucg\vSphere-Key-Files\vCenterReadOnly.xml"){
#		Read-Host -Prompt "Please type the password for the vCenter user 'nord\oppvfog01'" -AsSecureString | ConvertFrom-SecureString -Key (1..16) | Out-File D:\Local-Script-Repository\vSphere-Key-Files\vCenterReadOnly.xml -Force -Confirm:$false
#		Write-Host "vCenter Login Credentials for 'nord\opvfog01' Have Been Created"
#		cd "D:\git-ucg\vSphere-Key-Files"
#		git add -A
#		git commit -m "Changing the password for vCenterLogin nord\oppvfog01"
#		git push origin master
#		}
	}
}
Function Create-vSphereLogin{
<# 
.SYNOPSIS  
	Creates Secure Password File for vSphere ESXi Login root
.DESCRIPTION  
	Creates Secure Password File for vSphere ESXi Login root
.NOTES  
	Function Name  	: Create-vSphereLogin 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Create-vSphereLogin
#> 
   
	PROCESS {
		Write-Warning "Create-vCenterReadOnlyLogin has been labeled obsolete. Please use ' New-LoginCredentials -CredentialType vSphere ' going further"
		Write-Error "Create-vCenterReadOnlyLogin has been labeled obsolete. Please use ' New-LoginCredentials -CredentialType vSphere ' going further"
		return $null
#		If(Test-Path "D:\git-ucg\vSphere-Key-Files\vmhost.xml"){
#		Read-Host -Prompt "Please type the password for the vSphere ESXi user 'root'" -AsSecureString | ConvertFrom-SecureString -Key (1..16) | Out-File D:\Local-Script-Repository\vSphere-Key-Files\vmhost.xml -Force -Confirm:$false
#		Write-Host "vSphere ESXi Login Credentials for 'root' Have Been Created"
#		cd "D:\git-ucg\vSphere-Key-Files"
#		git add -A
#		git commit -m "Changing the password for ESXi root"
#		git push origin master
#		}
	}
}
Function Create-UcsLogin{
<# 
.SYNOPSIS  
	Creates Secure Password File for Ucs Login nord\oppucs01
.DESCRIPTION  
	Creates Secure Password File for Ucs Login nord\oppucs01
.NOTES  
	Function Name  	: Create-UcsLogin 
	Author     		: Sammy Shuck
	Requires   		: PowerShell V2
.EXAMPLE  
	Create-UcsLogin
#> 
   
	PROCESS {
		Write-Warning "Create-UcsLogin has been labeled obsolete. Please use ' New-LoginCredentials -CredentialType UCS ' going further"
		Write-Error "Create-UcsLogin has been labeled obsolete. Please use ' New-LoginCredentials -CredentialType UCS ' going further"
		return $null
#		If(Test-Path "D:\git-ucg\UCS-Key-Files\Ucs.xml"){
#		Read-Host -Prompt "Please type the password for the Ucs user 'nord\oppucs01'" -AsSecureString | ConvertFrom-SecureString -Key (1..16) | Out-File D:\Local-Script-Repository\UCS-Key-Files\Ucs.xml -Force -Confirm:$false
#		Write-Host "Ucs Login Credentials for 'nord\oppucs01' Have Been Created"
#		cd "D:\git-ucg\UCS-Key-Files"
#		git add -A
#		git commit -m "Changing the password for UCS Login oppucs01"
#		git push origin master
#		}
	}
}
Function Get-MD5Checksum{
	Param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		$Object
	)
	Process{
		try{
			$MD5csp = New-Object System.Security.Cryptography.MD5CryptoServiceProvider
			$MD5Checksum = [System.BitConverter]::ToString($MD5csp.ComputeHash([System.IO.File]::ReadAllBytes($Object)))
			return $MD5Checksum
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
Function New-LoginCredentials{
	Param(
		[string]$Username,
		[PSCredential]$Credential,
		[ValidateSet("vCenter","vCenterReadOnly","vSphere","vSphereSIAB","vSphereSIABBuild","UCS","MSA","InfluxDB")]
		[Parameter(Mandatory=$true)]
		[string]$CredentialType
	)
	Begin{
		if(-not $Username -and (-not $Credential)){
			#Username or Credential has to be provided
			Write-Error "Cannot process command because of one or more missing mandatory parameters: Username or Credential." -Category InvalidArgument -CategoryReason "ParameterBindingException"
			throw $Error[0]
		}
		elseif($Username -and (-not $Credential)){
			#prompt for password if Username was provided
			try{ 
				$Credential = Get-Credential -Message "Please enter the credentials for username '$($Username)'." -UserName $Username -ErrorAction Stop
				if($Credential.Password.Length -eq 0){ throw "Empty or NULL value provided for one or more mandatory parameters: Username and Password" }
			}catch{
				Write-Error $_ -Category SecurityError -CategoryReason "NullOrEmptyPassword"
				throw $Error[0]
			}
		}
		elseif($Credential.Password.Length -eq 0){
			Write-Error "Empty or NULL value provided for one or more mandatory parameters: Username and Password" -Category SecurityError -CategoryReason "NullOrEmptyPassword"
			throw $Error[0]
		}
		
		[string]$private:xmlPath = "D:\git-ucg\ucg_secure\ucg_secure.xml"
		[string]$private:ucg_crypto = "D:\git-ucg\ucg_secure\ucg_crypto"
		if(-not (Test-Path $xmlPath)){ 
			Write-Error "Unable to access D:\git-ucg\ directory. This must be ran on the scripting server A0319P184 in order to update the credential store." `
			 -Category ResourceUnavailable -CategoryReason "FileResourceUnavailable"
			 throw $Error[0]
		}
	}
	Process{
		try{
			trap{ throw $_ }
			$pkey = [Text.Encoding]::UTF8.GetBytes((Get-ChildItem $ucg_crypto | Get-MD5Checksum))
			
			#convert from secure string using a 256bit key. Because $pkey returns a 47 Byte array then we can only use 32 indexes to get to 256bits; 
			#  256bit/8bitperbyte = 32bytes
			#  so we use the array indexes 0 to 31
			#From Microsoft technet:
			#When you use the Key or SecureKey parameters to specify a key, the key length must be correct. For example, a key of 128 bits can be specified as a byte 
			#  array of 16 digits. Similarly, 192-bit and 256-bit keys correspond to byte arrays of 24 and 32 digits, respectively.
			$secure_password = $Credential.Password | ConvertFrom-SecureString -Key $pkey[0..31]
			
			[xml]$xml = Get-Content -Path $xmlPath
			#select the past element
			$past_element = $xml.SelectNodes("Credentials/$($CredentialType.toLower())/past")
			
			#Create a new XML Element named cred to be added to the Credential/<type>/past element
			$new_past_element = $xml.CreateElement("cred")
			$new_past_element.SetAttribute("username",$xml.Credentials."$($CredentialType.toLower())".current.cred.username)
			$new_past_element.SetAttribute("password",$xml.Credentials."$($CredentialType.toLower())".current.cred.password)
			
			#Add the new past/cred node to the XML doc
			$new_xml_node = $past_element.AppendChild($new_past_element)
			
			#Update the XML Attributes for the new current credential
			$xml.Credentials."$($CredentialType.toLower())".current.cred.username = $Credential.Username
			$xml.Credentials."$($CredentialType.toLower())".current.cred.password = "$($secure_password)"
			
			#Save the XML Doc
			$xml.Save($xmlPath)
			
			# Update git repo
			cd "D:\git-ucg\ucg_secure"
			git add -A
			git commit -m "Changing the password for $($CredentialType) user $($Credential.UserName)"
			git push origin master
			
		}catch{
			Write-Error $_
			throw $_
		}
	}
}
function Rename-ClusterNetworks{
[cmdletbinding()]
Param(
	[parameter(Mandatory=$true)]
	$ClusterName,
	$Name="*"
)
	Write-Verbose "Parameter Set:`n`tClusterName : $($ClusterName)`n`tName : $($Name)"
	Get-Cluster -Name $ClusterName | Get-ClusterNetwork -Name $Name | %{ $cl_net = $_
		Write-Verbose "Cluster Network Information:"
		Write-Output ($cl_net | Select @{Name='Cluster';Expression={$_.Cluster.Name}},Name,Address,Id,Metric) | ft -AutoSize| Out-String -Stream | Write-Verbose

		if($cl_net.Address -eq "192.168.10.0"){
			# S2D network
			try{
				Write-Verbose "Renaming $($cl_net.Name) to vEthernet (S2D)"
				$cl_net.Name = "vEthernet (S2D)"
			}catch{
				Write-Verbose "Unable to Rename the Network"
				Write-Warning "Cluster Network $($cl_net.Name) already exists as $($cl_net.Name). No changes made."
			}
		}elseif($cl_net.Address -eq "192.168.20.0"){
			#LiveMigration Network
			try{
				Write-Verbose "Renaming $($cl_net.Name) to vEthernet (LiveMigration)"
				$cl_net.Name = "vEthernet (LiveMigration)"
			}catch{
				Write-Warning "Cluster Network $($cl_net.Name) already exists as $($cl_net.Name). No changes made."
			}
		}else{
			#OSMgmt Network
			try{
				Write-Verbose "Renaming $($cl_net.Name) to vEthernet (OSMgmt)"
				$cl_net.Name = "vEthernet (OSMgmt)"
			}catch{
				Write-Warning "Cluster Network $($cl_net.Name) already exists as $($cl_net.Name). No changes made."
			}
		}
	}
}
function Rename-ClusterSharedVolume{
[cmdletbinding()]
	Param(
		$CSVName = "*",
		$Cluster = $null
	)

	# Get the Cluster Shared Volumes
	Write-Verbose "Collecting the Cluster Shared Volumes matching Name $($CSVName)"
	$csv = Get-ClusterSharedVolume -Name $CSVName
	Write-Output ($csv | ft -AutoSize| Out-String -Stream | Write-Verbose)
	
	# Get the Volume Information
	Write-Verbose "Collecting the Cluster Shared Volumes Filesystem Paths $($CSVName)"
	$vh = @{}
	Get-Volume | ?{$_.FileSystem -eq "CSVFS"} | %{ $vh[$_.Path] = $_ }
	Write-Output ($vh | ft -AutoSize| Out-String -Stream | Write-Verbose)

	# Map the Virtual Disk Friendly Name to the Cluster Shared Volume
	Write-Verbose "Mapping the Virtual Disk Friendly Name to the Cluster Shared Volume"
	$csv | %{
	    $v = $vh[$_.SharedVolumeInfo.Partition.Name] 
	    if ($v -ne $null){
	        $_ | Add-Member -NotePropertyName VDName -NotePropertyValue $v.FileSystemLabel
			Write-Output (New-Object PSOBject -Property @{Name=$_.Name;VirtualDisk=$_.VDName;CSV=$_.SharedVolumeInfo.FriendlyVolumeName} | ft -AutoSize| Out-String -Stream | Write-Verbose)
	    }
	}

	# Rename the Cluster Shared Volumes
	$csv | %{
		Write-Verbose "Renaming Cluster Shared Volume $($_.SharedVolumeInfo.FriendlyVolumeName) to $($_.VDName)"
		Rename-Item $_.SharedVolumeInfo.FriendlyVolumeName $_.VDName
		
		Write-Verbose "Renaming Cluster Disk Resource $($_.Name) to $($_.VDName)"
		$_.Name = $_.VDName
	}
	
	return $csv
}
function Get-SCDeployVolume{
[cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        $VMMServer,
        [Parameter(Mandatory=$true)]
        $ClusterName
    )

    function Set-VolumeDeployTarget{
    [cmdletbinding()]
		Param(
            [Parameter(Mandatory=$true,ValueFromPipeline)]
            $Volume,
            $Value = $true
        )

        Process{
			Write-Verbose "Flagging volume $($_.VolumePath) to DeployTarget=$($Value)"
            $_.DeployTarget = $Value
        }
    }
       
	if ($VMMServer -isnot [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]){
		Write-Verbose "$($VMMServer) is not of type [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]. Getting SCVMM Server"
    	$vmm = Get-SCVMMServer -ComputerName $VMMServer
	}
    if ($ClusterName -isnot [Microsoft.FailoverClusters.PowerShell.ClusterObject] -and $ClusterName -isnot [Microsoft.SystemCenter.VirtualMachineManager.ClientObject]){
		Write-Verbose "$($ClusterName) is not of type [Microsoft.FailoverClusters.PowerShell.ClusterObject] or [Microsoft.SystemCenter.VirtualMachineManager.ClientObject]. Getting Cluster."
		$cl = Get-SCVMHostCluster -Name $ClusterName -VMMServer $vmm
	}
    Write-Verbose "Collecting the Cluster Shared Volumes for cluster $($cl.Name)"
    $cl_vols = Get-ClusterSharedVolume -Cluster $cl
	Write-Output ($cl_vols | ft -AutoSize) | Out-String -Stream | Write-Verbose
    
    Write-Verbose "Collecting Free Space information"
	$vol_info = @{}
    $cl_vols | %{ $vol = $_
        $vol_info[$vol.Name] = New-Object PSObject -Property @{Name=$vol.Name;
        	Id=$vol.Id;
        	VolumePath=$vol.SharedVolumeInfo.FriendlyVolumeName;
        	FreeSpace=$vol.SharedVolumeInfo.Partition.FreeSpace;
        	PercentFree=$vol.SharedVolumeInfo.Partition.PercentFree;
        	DeployTarget=$false}
		Write-Output ($vol_info[$vol.Name] | ft -AutoSize) | Out-String -Stream | Write-Verbose
    }
	Write-Verbose "Evaluating Volume Sizes and Collecting valid Deploy Volumes"
    $vol_info.Values | ?{$_.FreeSpace -eq ($vol_info.Values.FreeSpace | Measure-Object -Maximum).Maximum} | ?{$_.FreeSpace -gt 10} | Set-VolumeDeployTarget
	Write-Output ($vol_info.Values | ?{$_.DeployTarget}) | Out-String -Stream | Write-Verbose
	
	return ($vol_info.Values | ?{$_.DeployTarget})
}

#endregion

Evaluate-Parameters $PSBoundParameters
SetVmwareCmdletAlias

$script:_get_credential = {
	param(
		$script_file,
		$username
	)
	C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe -windowstyle hidden -file $script_file "$($username)"
}

$ErrorActionPreference = $EAP
$WarningPreference = $WP
Format-Message -Message "UcgModule Loaded" | Write-Log -Path $module_log

