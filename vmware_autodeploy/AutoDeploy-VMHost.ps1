#<#region ######################################### Parameters #########################################
Param(
		[Parameter(Mandatory=$true,Position=0)]
		[string]$vCenter=$null,
		[string]$Cluster="",
		[string]$VMHost="",
		[string]$MAC="",
		[string]$ImageProfile="",
		[string]$HostProfile="",
		[switch]$Add = $false,
		[switch]$Remove = $false,
		[switch]$Move = $false,
		[switch]$Noprompt = $false,
		[ValidateScript({
			if(-not (Test-Path $_)){ "" | Out-File -FilePath $_ -ErrorAction Stop; Test-Path $_ }
			else{$true}
		})]
		[alias("l")]
		[string]$Log = "\\a0319p184\UCG-Logs\Autodeploy-VMHost.log"
)
#endregion

#<#region ######################################### Variables and Constants ##############################
	#$ErrorActionPreference
	#$WarningPreference = "SilentlyContinue"
#>#endregion

#<#region ######################################### Functions ############################################
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
	Function Present-Menu(){
		Param(
			[Parameter(Mandatory=$true)]
			[array]$menuItems = @(),
			[string]$Message = ""
		)
		Process{
			try{
				Write-Host $Message
				Write-Log -Path $Log -Message "[$(Get-Date)]`t$($Message)"
				$menuItems | %{
					$menuNum = ($menuItems.IndexOf($_) + 1) #need to add one as the Index starts at 0 and we want to present this as menu item 1, 2, 3 ect
					Write-Host "`t$($menuNum). $($_)"
					Write-Log -Path $Log -Message "[$(Get-Date)]`t$($menuNum). $($_)"
				}
				$usrInput = $null
				Write-Log -Path $Log -Message "[$(Get-Date)]`tPlease Select an option "
				$usrInput = Read-Host "Please Select an option: "
				Write-Log -Path $Log -Message "[$(Get-Date)]`tUser provided data: $($usrInput)"
				$usrInput = [System.Convert]::ToInt32($usrInput)

				If([string]::IsNullOrEmpty($usrInput) -or $usrInput -eq 0){
					#Invalid selection
					Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`tInvalid Selection : NULL VALUE"
					throw "Error:`tInvalid Selection : NULL VALUE"
				}
				#Check to make sure the slection is a valid selection
				$chk = $null
				$chk = $menuItems[$usrInput-1]
				If([string]::IsNullOrEmpty($chk)){
					#Invalid selection
					Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`tInvalid Selection. Item $($usrInput) doesn't exist."
					throw "Error:`tInvalid Selection. Item $($usrInput) doesn't exist."
				}
			}Catch{
				Write-Error $_.Exception.Message
				$chk = $null
			}
		}
		End{
			return $chk
		}
	}
	Function Prompt-Entry(){
		Param(
			[Parameter(Mandatory=$false)]
			[array]$menuItems = @(),
			[Parameter(Mandatory=$true)]
			[string]$Message = ""
		)
		Process{
			try{
				Write-Host "`nPlease provide the required input for $($Message)."
				Write-Log -Path $Log -Message "[$(Get-Date)]`tPlease provide the required input for $($Message)."
				If(-not [string]::IsNullOrEmpty($menuItems)){
					$menuItems | %{
						$menuNum = ($menuItems.IndexOf($_) + 1) #need to add one as the Index starts at 0 and we want to present this as menu item 1, 2, 3 ect
						Write-Host "`t$($menuNum). $($_)"
						Write-Log -Path $Log -Message "[$(Get-Date)]`t$($menuNum). $($_)"
					}
				}
				$usrInput = $null
				$usrInput = Read-Host "$($Message) "
				Write-Log -Path $Log -Message "[$(Get-Date)]`tUser provided data: $($usrInput)"

				If(-not [string]::IsNullOrEmpty($menuItems)){
					$usrInput = [System.Convert]::ToInt32($usrInput)
					If([string]::IsNullOrEmpty($usrInput) -or $usrInput -eq 0){
						#Invalid selection
						Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`tInvalid Selection : NULL VALUE"
						throw "Error:`tInvalid Selection : NULL VALUE"
					}
					#Check to make sure the slection is a valid selection
					$chk = $null
					$chk = $menuItems[$usrInput-1]
					If([string]::IsNullOrEmpty($chk)){
						#Invalid selection
						Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`tInvalid Selection. Item $($usrInput) doesn't exist."
						throw "Error:`tInvalid Selection. Item $($usrInput) doesn't exist."
					}
				}Else{
					If([string]::IsNullOrEmpty($usrInput)){
						#Invalid selection
						Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`tInvalid Entry : NULL VALUE"
						throw "Error:`tInvalid Entry : NULL VALUE"
					}
					$chk = $null
					$chk = $usrInput
				}
			}Catch{
				Write-Error $_.Exception.Message
				$chk = $null
			}
		}
		End{
			If(-not [string]::IsNullOrEmpty($chk)){
				$chk = "$($Message) > $($chk)"
				Write-Log -Path $Log -Message "[$(Get-Date)]`t$($chk)"
			}
			return $chk
		}
	}
	Function Verify-Configuration(){
		Param(
			[Parameter()]
				[array]$itemList = @(),
				[string]$Message = ""
		)
		Process{
			try{
				Write-Log -Path $Log -Message "[$(Get-Date)]`tVerify-Configuration"
				Write-Host "`n$($Message)"
				Write-Log -Path $Log -Message "[$(Get-Date)]`t$($Message)"
				$itemList | %{
					Write-Host "`t$($_)"
					Write-Log -Path $Log -Message "[$(Get-Date)]`t$($_)"
				}
				Write-Log -Path $Log -Message "[$(Get-Date)]`tVerify the configuration (y/n)"
				$usrInput = Read-Host "`nVerify the configuration (y/n)"
				Write-Log -Path $Log -Message "[$(Get-Date)]`tUser provided data: $($usrInput)"

				If($usrInput -ne "y" -and $usrInput -ne "n"){
					Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`tInvalid Selection. Please choose 'Y' or 'N'"
					throw "Error: Invalid Selection. Please choose 'Y' or 'N'"
				}
				$rtrn = $usrInput
			}
			catch{
				Write-Error $_.Exception.Message
				$rtrn = $null
			}
		}
		End{
			return $rtrn
		}
	}
	Function Create-DeployRule(){
	#this function is specific to this script only. Peices can be moved to other script
	#but as a whole there are dependencies in this function to global variables of the script
		Param(
			[Parameter(Mandatory=$true)]
				$Cluster = $null,
			[Parameter(Mandatory=$true)]
				[string]$MACAddress = $null,
			[Parameter(Mandatory=$true)]
				[string]$ImageProfile = $null,
			[Parameter(Mandatory=$true)]
				$HostProfile = $null
		)
		Begin{
			Write-Host "Creating Deploy Rule" -ForegroundColor Cyan
			Write-Log -Path $Log -Message "[$(Get-Date)]`tCreating Deploy Rule"
		}
		Process{
			$deployRule = $null
			try{
				#Add Image Profile software depot
				$impFile = ($imageprofiles.Values | ?{$_.Name -eq "$($ImageProfile).zip"}) | ?{$_.Name -eq "$($ImageProfile).zip"}
				Write-Log -Path $Log -Message "[$(Get-Date)]`tAdding ImageProfile $($ImageProfile).zip"
				Add-EsxSoftwareDepot -DepotUrl $impFile.FullName | Out-Null
				$imp = Get-EsxImageProfile | ?{$_.Name  -eq "$($ImageProfile)"}

				#Ensure the MAC address is correct
				[regex]$macRegEx = "^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$"
				$MACAddress = $MACAddress.Replace("-",":")
				If(-not ($MACAddress -match $macRegEx)){
					Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`tThe MAC Address is not in the form of 00:00:00:00:00:00`n$($MACAddress)"
					throw "The MAC Address is not in the form of 00:00:00:00:00:00`n$($MACAddress)"
				}
				$patternList = @("mac=$($MACAddress)")

				#generate Item List
				$itemList = @($imp,$Cluster,$HostProfile)

				Write-Log -Path $Log -Message "[$(Get-Date)]`tNew-DeployRule -Name $($Cluster.Name.replace('_deploy','')) -Item {$($imp.Name),$($Cluster.Name),$($HostProfile.Name)} -Pattern {mac=$($MACAddress)}"
				$deployRule = New-DeployRule -Name ($Cluster.Name.replace('_deploy','')) -Item $itemList -Pattern $patternList
				$gc = Add-DeployRule -DeployRule $deployRule
				$deployRule = Get-DeployRule -Name $deployRule.Name

			}catch{
				Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`t$($_.Exception.Message)"
				Write-Error $_.Exception.Message
				throw $_.Exception.Message
			}
		}
		End{
			Write-Log -Path $Log -Message "[$(Get-Date)]`tDeploy Rule Created"
			Write-Log -Path $Log -Message $deployRule
			return $deployRule
		}
	}
	Function Add-ToDeployRule(){
	#this function is specific to this script only. Peices can be moved to other script
	#but as a whole there are dependencies in this function to global variables of the script
		Param(
			[Parameter(Mandatory=$true)]
				$deployRule = $null,
			[Parameter(Mandatory=$true)]
				[string]$MACAddress = $null
		)
		Begin{
			Write-Host "Adding to Deploy Rule" -ForegroundColor Cyan
			Write-Log -Path $Log -Message "[$(Get-Date)]`tAdding $($MACAddress) to Deploy Rule"
		}
		Process{
			try{

				#Ensure the MAC address is correct
				[regex]$macRegEx = "^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$"
				$MACAddress = $MACAddress.Replace("-",":")
				If(-not ($MACAddress -match $macRegEx)){
					Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`tThe MAC Address is not in the form of 00:00:00:00:00:00`n$($MACAddress)"
					throw "The MAC Address is not in the form of 00:00:00:00:00:00`n$($MACAddress)"
				}
				#add to the MAC to the pattern list
				$patternList = $deployRule.PatternList
				$patternList += "mac=$($MACAddress)"

				$deployRule = Copy-DeployRule -DeployRule $deployRule -ReplacePattern $patternList
				$deployRule = Get-DeployRule -Name $deployRule.Name

			}catch{
				Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`t$($_.Exception.Message)"
				Write-Error $_.Exception.Message
				throw $_.Exception.Message
			}
		}
		End{
			Write-Log -Path $Log -Message "[$(Get-Date)]`tAdded $($MACAddress) to Deploy Rule"
			Write-log -Path $log -Message $deployRule
			return $deployRule
		}
	}
	Function Remove-FromDeployRule(){
	#this function is specific to this script only. Peices can be moved to other script
	#but as a whole there are dependencies in this function to global variables of the script
		Param(
			[Parameter(Mandatory=$true)]
				$deployRule = $null,
			[Parameter(Mandatory=$true)]
				[string]$MACAddress = $null
		)
		Begin{
			Write-Host "Removing from Deploy Rule $($deployrule.name)" -ForegroundColor Cyan
			Write-Log -Path $Log -Message "[$(Get-Date)]`tRemoving $($MACAddress) from Deploy Rule $($deployrule.name)"
			$successMessage = ""
			$dprl = $deployRule
		}
		Process{
			try{
				#Ensure the MAC address is correct
				[regex]$macRegEx = "^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$"
				$MACAddress = $MACAddress.Replace("-",":").tolower()
				If(-not ($MACAddress -match $macRegEx)){
					Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`tThe MAC Address is not in the form of 00:00:00:00:00:00`n$($MACAddress)"
					throw "The MAC Address is not in the form of 00:00:00:00:00:00`n$($MACAddress)"
				}
				#add to the MAC to the pattern list
				[collections.arraylist]$patternList = $deployRule.PatternList
				If ($patternList.count -gt 1) {
          $patternList.remove("mac=$($MACAddress)")
					$deployRule | %{
						$dprl = Copy-DeployRule -DeployRule $_ -ReplacePattern $patternList
					}
					$successMessage = "Removed $($MACAddress) from Deploy Rule $($deployrule.name)"
				} else {
					$gc = Remove-DeployRule -DeployRule $srcDeployRule -Delete
					$successMessage = "Removing DeployRule $($deployrule.name) as this is the last host in the rule."
				}
			}catch{
				Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`t$($_.Exception.Message)"
				Write-Error $_.Exception.Message
				throw $_.Exception.Message
			}
		}
		End{
      Write-Log -Path $Log -Message "[$(Get-Date)]`t$successMessage"
      return $successMessage
		}
	}
	Function New-AutoDeployCluster(){
		Param(
		[Parameter(Mandatory=$true,Position=0)][string]$Name=$null
		)

		Begin{
			Write-Host "Creating VM Cluster $($Name)"
			Write-Log -Path $Log -Message "[$(Get-Date)]`tCreating vSphere Cluster $($Name)"
			$clObj = $null
		}
		Process{
			try{
				$dc = Get-Datacenter -Name "0319"
				$clObj = New-VmCluster -Location $dc -Name $Name -HAAdmissionControlEnabled:$true -DrsEnabled:$true -HAEnabled:$true -DrsAutomationLevel FullyAutomated -HAIsolationResponse DoNothing -HARestartPriority Medium -VMSwapfilePolicy InHostDatastore -ErrorAction SilentlyContinue
			}catch{
				Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`t$($_.Exception.Message)"
				Write-Error $_.Exception.Message
				throw $_.Exception.Message
			}
		}
		End{
			Write-Log -Path $Log -Message "[$(Get-Date)]`tCreated vSphere Cluster $($Name)"
			return $clObj
		}
	}
	Function Validate-Parameters{
		[CmdletBinding()]
		Param(
			[Parameter(Mandatory=$true)]
			[string]$vCenter=$null,
			[Parameter(Mandatory=$true)]
			[string]$Cluster="",
			[Parameter(Mandatory=$true)]
			[string]$VMHost="",
			[Parameter(Mandatory=$true)]
			[string]$MAC="",
			[Parameter(Mandatory=$true)]
			[string]$ImageProfile="",
			[Parameter(Mandatory=$true)]
			[string]$HostProfile="",
			[switch]$Add = $false,
			[switch]$Remove = $false,
			[switch]$Move = $false
		)
		Begin{
			[bool]$validate = $false
		}
		Process{
			try{
				If(-not $Add -and -not $Move -and -not $Remove){
					throw "Cannot bind argument to parameter 'Add', 'Move', 'Remove' because it is missing. Must specify one parameter 'Add', 'Move', 'Remove'"
					Validate-Parameters : Cannot bind argument to parameter 'HostProfile' because it is an empty string.
				}Else{ $validate = $true }
			}catch{
				Write-Error $_ -Category:InvalidData -CategoryActivity "[Validate-Parameters]" -CategoryReason "ParameterBindingValidationException" -ErrorId "ParameterArgumentValidationErrorMissingMandatoryParameter"
			}
		}
		End{
			return $validate
		}
	}
#>#endregion

#<#region ######################################### Includes ###########################################
	Write-Host "Initializing ..."
	LoadSnapins
	LoadModules
	Import-Module UcgModule -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore -Confirm:$false -Scope:AllUsers
	cls
  cd g:\autodeploy
#>#endregion

#<#region ######################################### Logging ##############################################
	$ScriptName = ($MyInvocation.MyCommand).Name
	$ScriptName = $ScriptName.SubString(0,$scriptname.indexof("."))
	$ScriptPath = Split-Path $script:MyInvocation.MyCommand.Path
	$Date = Get-Date -format 'yyyyMMddHHmmss'
  $rundate = get-date -format M_d_yyyy
	$userID = get-content env:username
#endregion #>#

#<#region ######################################### Main #################################################
	Write-Host "Initializing ..."
	#region  ##### Get Esxi Images
		$adDirectory = "E:\released\"
		$esxiVersions = Get-ChildItem -Path $adDirectory -Directory -Exclude @("vendorVIBs") | Select Name,FullName
		[hashtable]$imageprofiles = @{}
		$esxiVersions | %{ $ver = $_
			$imageprofiles.Add($_.Name,(Get-ChildItem -Path "$($_.FullName)\offline"))
		}
		Write-Log -Path $Log -Message "$('#'*60)`n[$(Get-Date)]`tUser $($Env:USERNAME) Starting Autodeploy-VMHost.ps1"
	#endregion

	#region  ##### Define DHCP server to vCenter relationship
		$DHCPServerInfo = @(
			(New-Object PSObject -Property @{
				DHCPServer="a0319p10157"
				vCenter="a0319p1199"
				ScopeName="v692"
				Domain="nordstrom.net"
			}),
			(New-Object PSObject -Property @{
				DHCPServer="a0319p10158"
				vCenter="a0319p10133"
				ScopeName="v693"
				Domain="nordstrom.net"
			}),
			(New-Object PSObject -Property @{
				DHCPServer="a0319t10111"
				vCenter="y0319t1919"
				ScopeName="v698"
				Domain="nordstrom.net"
			})
		)
	#endregion

	#region  ##### Connect to viserver, get all clusters, deployrules, hostprofiles and licenses
		$vi = Connect-VIServer -Server $vCenter -Credential (Login-vCenter) -ErrorAction Stop
		Write-Log -Path $Log -Message "[$(Get-Date)]`tConnected to vCenter $($vCenter)"
		[array]$allClusters = Get-View -ViewType ClusterComputeResource
		[array]$alldeployRules = Get-DeployRule
		[array]$allHostProfiles = Get-VMHostProfile | ?{$_.Name -like "*Autodeploy*"}
		[array]$esxiLicenses = @()
		$licenseManager = Get-View (Get-View ServiceInstance).Content.LicenseManager
		[array]$esxiLicenses = $licenseManager.Licenses | %{
			$chk=$null
			$chk = $_.Properties | ?{($_.Key -eq "ProductName" -and $_.Value -like "*ESX*")};
			If(-not [string]::IsNullOrEmpty($chk)){
				$chk=$null
				$chk = $_.Properties | ?{($_.Key -eq "ProductVersion" -and $_.Value -like "$($esxiVersion.Split('.')[0])*")}
				If(-not [string]::IsNullOrEmpty($chk)){ "$($_.Name) | $($_.LicenseKey)" }
			}
		}
		cls
	#endregion

	#region  ##### User Menus or Not (If $NoPrompt -eq $true then validate command line variables)
		If(-not $NoPrompt){
			#region  #### Create Menus
				#region  #### Create Cluster List - Remove this REGION to setup the script for automation and eliminate the Menu prompts
					$ExistingAutoDeployClustersPlusNew = @("New Autodeploy Cluster")
					$ExistingAutoDeployClusters += get-deployrule | sort Name | select -expand Name
					$ExistingAutoDeployClustersPlusNew += get-deployrule | sort Name | select -expand Name
				#endregion

				#region  #### Create the menu option Variable
					$Menu = New-Object PSObject -Property @{
						Message= "What would you like to do?"
						ItemList= @("Deploy a New VMHost","Move an Existing VMHost to a Different Cluster","Remove an Existing VMHost")
						Menu1= New-Object PSObject -Property @{
							Message= "Which cluster are you adding the VMHost to?"
							ItemList= $($ExistingAutoDeployClustersPlusNew -as [array])
							Item1Prompt= @(
								(New-Object PSObject -Property @{
									PromptMsg= "Cluster Name"
									ItemList= $null
								}),
								(New-Object PSObject -Property @{
									PromptMsg= "VMHost Name"
									ItemList= $null
								}),
								(New-Object PSObject -Property @{
									PromptMsg= "UCS MAC Address of eth0"
									ItemList= $null
								}),
								(New-Object PSObject -Property @{
									PromptMsg= "ESXi Image Profile"
									ItemList= ($imageprofiles.Values.Name -as [array])
								}),
								(New-Object PSObject -Property @{
									PromptMsg= "vCenter Host Profile"
									ItemList= ($allHostProfiles.Name -as [array])
								})
							)
							Item2Prompt= @(
								(New-Object PSObject -Property @{
									PromptMsg= "VMHost Name"
									ItemList= $null
								}),
								(New-Object PSObject -Property @{
									PromptMsg= "UCS MAC Address of eth0"
									ItemList= $null
								})
							)
						}
						Menu2= New-Object PSObject -Property @{
							Message= "Where are you Moving the VMHost to?"
							ItemList= $($ExistingAutoDeployClusters -as [array])
							Item1Prompt= @(
								(New-Object PSObject -Property @{
									PromptMsg= "VMHost Name"
									ItemList= $null
								}),
								(New-Object PSObject -Property @{
									PromptMsg= "UCS MAC Address of eth0"
									ItemList= $null
								})
							)
						}
						Menu3= New-Object PSObject -Property @{
							Message= "Where are you Removing the VMHost from?"
							ItemList= $($ExistingAutoDeployClusters -as [array])
							Item1Prompt= @(
								(New-Object PSObject -Property @{
									PromptMsg= "VMHost Name"
									ItemList= $null
								}),
								(New-Object PSObject -Property @{
									PromptMsg= "UCS MAC Address of eth0"
									ItemList= $null
								}),
								(New-Object PSObject -Property @{
									PromptMsg= "Remove DHCP and DNS Records (y/n)"
									ItemList= $null
								})
							)
						}
					}
				#endregion
			#endregion

			#region  #### Present the Menus
				#region ############################################################ Present the Menu Options
					Write-Log -Path $Log -Message "[$(Get-Date)]`tPrompting the User for input..."
					Do{
						Do{
							$choice = Present-Menu -menuItems @("Deploy a New VMHost","Move an Existing VMHost to a Different Cluster","Remove an Existing VMHost") -Message "What would you like to do?"
						}While([string]::IsNullOrEmpty($choice))
						Write-Host "`n"
						[array]$answers = @()
						Switch(($Menu.ItemList.IndexOf($choice))){
							0	{ 	$subMenu = "Menu1"
									Do{
										$choiceSm = Present-Menu -menuItems $($ExistingAutoDeployClustersPlusNew -as [array]) -Message $Menu.$subMenu.Message
									}While([string]::IsNullOrEmpty($choiceSm))									
									Switch(($Menu.$subMenu.ItemList.IndexOf($choiceSm))){
										0	{
												[array]$answers += $Menu.$subMenu.Item1Prompt | %{
													Do{ $tmp = Prompt-Entry -Message $_.PromptMsg -menuItems $_.ItemList }While([string]::IsNullOrEmpty($tmp))
													$tmp
												}
											}
										default	{
												[array]$answers += "Cluster Name > $($choiceSm)"
												$choiceSm = "Existing Autodeploy Cluster"
												[array]$answers += $Menu.$subMenu.Item2Prompt | %{
													Do{ $tmp = Prompt-Entry -Message $_.PromptMsg -menuItems $_.ItemList }While([string]::IsNullOrEmpty($tmp))
													$tmp
												}
											}
									}
								}
							1	{ 	$subMenu = "Menu2"
									Do{
										$choiceSm = Present-Menu -menuItems $Menu.$subMenu.ItemList -Message $Menu.$subMenu.Message
									}While([string]::IsNullOrEmpty($choiceSm))
									[array]$answers += "Cluster Name > $($choiceSm)"
									$choiceSm = "Existing Autodeploy Cluster"
									[array]$answers += $Menu.$subMenu.Item1Prompt | %{
										Do{ $tmp = Prompt-Entry -Message $_.PromptMsg -menuItems $_.ItemList }While([string]::IsNullOrEmpty($tmp))
										$tmp
									}
								}
							2	{ 	$subMenu = "Menu3"
									Do{
										$choiceSm = Present-Menu -menuItems $Menu.$subMenu.ItemList -Message $Menu.$subMenu.Message
									}While([string]::IsNullOrEmpty($choiceSm))
									[array]$answers += "Cluster Name > $($choiceSm)"
									$choiceSm = "Existing Autodeploy Cluster"
									[array]$answers += $Menu.$subMenu.Item1Prompt | %{
										Do{ $tmp = Prompt-Entry -Message $_.PromptMsg -menuItems $_.ItemList }While([string]::IsNullOrEmpty($tmp))
										$tmp
									}
								}
						}
						
						If ($choice -ne "Remove an Existing VMHost") {
							#licenseKey Assignment
							[array]$esxiLicenses += "No License Change Required"
							Do{ $licenseOption = Present-Menu -menuItems $esxiLicenses -Message "`nLicense Keys are assigned at the cluster and apply to all host within the cluster.`nPlease choose the appropriate License Key option."
							}While([string]::IsNullOrEmpty($licenseOption))
						} else {
							$licenseOption = "No License Change Required"
						}

						$newAry = @()
						$newAry += "$($choice) > $($choiceSm)"
						$newAry += $answers
						$newAry += $licenseOption
						$verify = Verify-Configuration -Message "Please Verify the following configuration" -itemList $newAry
					}While($verify -ne "Y")
				#endregion ######################################################### Present the Menu Options

			#endregion

			#region  #### Parse the menu choices
				#region ############################################################ Create variables based on menu answers
					$tmpEAP = $ErrorActionPreference
					$ErrorActionPreference = "SilentlyContinue"
					$Cluster = ($answers | ?{$_ -like "Cluster Name > *"}).Split(">")[1].TrimStart(" ")
					$clusterDeployRuleName = $cluster.split("_")[0]
					If ($choice -eq "Deploy a New VMHost"){
						$Add = $true
						$VMHost = ($answers | ?{$_ -like "VMHost Name > *"}).Split(">")[1].TrimStart(" ")
						$MAC = ($answers | ?{$_ -like "UCS MAC Address of eth0 > *"}).Split(">")[1].TrimStart(" ")
						$ImageProfile = ($answers | ?{$_ -like "ESXi Image Profile > *"}).Split(">")[1].Replace(".zip","").TrimStart(" ")
						$HostProfile = ($answers | ?{$_ -like "vCenter Host Profile > *"}).Split(">")[1].TrimStart(" ")
						If($choiceSm -ne "New Autodeploy Cluster"){
							$ImageProfile = $alldeployRules | ?{$_.Name -like "$clusterDeployRuleName*"} | %{$dp = $_
								($dp.ItemList | ?{($_.getType()).BaseType.FullName -eq "VMware.ImageBuilder.Types.ImageProfile"}).Name
							}
							$HostProfile = $alldeployRules | ?{$_.Name -like "$clusterDeployRuleName*"} | %{$dp = $_
								($dp.ItemList | ?{($_.getType()).FullName -eq "VMware.VimAutomation.ViCore.Impl.V1.Host.Profile.VMHostProfileImpl"}).Name
							}
						}
					} elseIf ($choice -eq "Move an Existing VMHost to a Different Cluster"){
						$Move = $true
						$VMHost = ($answers | ?{$_ -like "VMHost Name > *"}).Split(">")[1].TrimStart(" ")
						$MAC = ($answers | ?{$_ -like "UCS MAC Address of eth0 > *"}).Split(">")[1].TrimStart(" ")
						$ImageProfile = ($answers | ?{$_ -like "ESXi Image Profile > *"}).Split(">")[1].Replace(".zip","").TrimStart(" ")
						$HostProfile = ($answers | ?{$_ -like "vCenter Host Profile > *"}).Split(">")[1].TrimStart(" ")
						If($choiceSm -eq "Existing Autodeploy Cluster"){
							$ImageProfile = $alldeployRules | ?{$_.Name -like "$clusterDeployRuleName*"} | %{$dp = $_
								($dp.ItemList | ?{($_.getType()).BaseType.FullName -eq "VMware.ImageBuilder.Types.ImageProfile"}).Name
							}
							$HostProfile = $alldeployRules | ?{$_.Name -like "$clusterDeployRuleName*"} | %{$dp = $_
								($dp.ItemList | ?{($_.getType()).FullName -eq "VMware.VimAutomation.ViCore.Impl.V1.Host.Profile.VMHostProfileImpl"}).Name
							}
						}
					} elseIf ($choice -eq "Remove an Existing VMHost"){
						$Remove = $true
						$VMHost = ($answers | ?{$_ -like "VMHost Name > *"}).Split(">")[1].TrimStart(" ")
						$MAC = ($answers | ?{$_ -like "UCS MAC Address of eth0 > *"}).Split(">")[1].TrimStart(" ")
            $RemoveDHCPandDNS = ($answers | ?{$_ -like "Remove DHCP and DNS Records (y/n) > *"}).Split(">")[1].TrimStart(" ")
					}
					If($licenseOption -eq "No License Change Required"){
						$licenseKey = $null
					} else {
						$tmp=$licenseOption.Split("|")[1]; $licenseKey = $tmp.Replace(" ","")
					}
					$ErrorActionPreference = $tmpEAP
				#endregion
			#endregion
		} elseIf (-not (Validate-Parameters -vCenter $vCenter -Cluster $Cluster -VMHost $VMHost -MAC $MAC -ImageProfile $ImageProfile -HostProfile $HostProfile -Add:$Add.IsPresent -Move:$Move.IsPresent -Remove:$Remove.IsPresent -ErrorAction Stop )){
			#not needed because of -ErrorAction Stop in the ELSEIF statement, but this is an extra failsafe
			"EXIT_ON_ERROR"
			exit 1
		}
	#endregion

	#region  ##### DeployRule and Licensing work
		try{
			#region  #### Lets Update our vCenter Data first
				$allClusters.UpdateViewData()
				[array]$alldeployRules = Get-DeployRule
				[array]$allHostProfiles = Get-VMHostProfile | ?{$_.Name -like "*Autodeploy*"}
			#endregion

			#region  #### Get 'er done
				$rtrn = @()
				If ($Add){
					#region  #### Adding
						$chk = $null; $chk = $alldeployRules | ?{$_.Name -like "$clusterDeployRuleName*"}
						If (-not [string]::IsNullOrEmpty($chk)){
							### if the new cluster already has a deploy rule
								$rtrn += Add-ToDeployRule -deployRule $chk -MACAddress $MAC
								$clObj = $rtrn[$rtrn.Count-1].ItemList | ?{$_.GetType().Name -eq "ClusterImpl"}
						} else {
							### otherwise Create a Deploy Rule
								$cl = $allClusters | ?{$_.Name -like "$clusterDeployRuleName*"}
								$hp = $allHostProfiles | ?{$_.Name -eq $HostProfile}
								If ([string]::IsNullOrEmpty($cl)){
									### throw "ERROR: Unable to find the cluster $($Cluster) in vCenter $($vCenter)`nThe cluster must exist in vCenter before a Deploy Rule is created"
									Write-Warning "Unable to locate the cluster $($Cluster) in vCenter $($vCenter).`nCreating the cluster $($Cluster) now..."
									Write-Log -Path $Log -Message "[$(Get-Date)]`tWarning:`tUnable to locate the cluster $($Cluster) in vCenter $($vCenter).`nCreating the cluster $($Cluster) now..."
									$clObj = New-AutoDeployCluster -Name $Cluster
									$cl = $clObj.ExtensionData
								}
								$rtrn += Create-DeployRule -Cluster (Get-VmCluster -Id $cl.MoRef) -MACAddress $MAC -ImageProfile $ImageProfile -HostProfile (Get-VMHostProfile -Id $hp.Id)
								$clObj = $rtrn[$rtrn.Count-1].ItemList | ?{$_.GetType().Name -eq "ClusterImpl"}
						}
						### run a test/repair against the host and deploy rule
						try{
							$gc = Get-VMHost | ?{$_.Name -like "$($VMHost)*"} | Test-DeployRuleSetCompliance -ErrorAction SilentlyContinue | Repair-DeployRuleSetCompliance -ErrorAction SilentlyContinue
						}Catch{
							Write-Log -Path $Log -Message "[$(Get-Date)]`tVerbose:`tNo ESXi Host exists in vCenter, so the Test-DeployRuleSetCompliace and Repair-DeployRuleSetCompliance Failed. This is not a big problem"
							Write-Verbose "No ESXi Host exists in vCenter, so the Test-DeployRuleSetCompliace and Repair-DeployRuleSetCompliance Failed. This is not a big problem"
						}
					#endregion
				}
				ElseIf($Move){
					#region  #### Moving
						#Ensure the MAC address is correct
						[regex]$macRegEx = "^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$"
						$MAC = $MAC.Replace("-",":")
						If(-not ($MAC -match $macRegEx)){
							Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`tThe MAC Address is not in the form of 00:00:00:00:00:00`n$($MACAddress)"
							throw "The MAC Address is not in the form of 00:00:00:00:00:00`n$($MAC)"
						}
						$srcDeployRule = $null; $srcDeployRule = $alldeployRules | ?{$_.PatternList -contains "mac=$($MAC)"}
						If([string]::IsNullOrEmpty($srcDeployRule)){
							#source deploy rule doesn't exist
							Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`tNo existing deploy rule has been found with MAC Address $($MAC)`nThe option selected was to MOVE the host from an existing deploy rule."
							throw "No existing deploy rule has been found with MAC Address $($MAC)`nThe option selected was to MOVE the host from an existing deploy rule."
						}

						$chk = $null; $chk = $alldeployRules | ?{$_.Name -like "$clusterDeployRuleName*"}
						If(-not [string]::IsNullOrEmpty($chk)){
							#the new cluster already has a deploy rule
							$rtrn += Add-ToDeployRule -deployRule $chk -MACAddress $MAC
							$clObj = $rtrn[$rtrn.Count-1].ItemList | ?{$_.GetType().Name -eq "ClusterImpl"}
						}Else{
							#Else Create a Deploy Rule
							$cl = $allClusters | ?{$_.Name -like "$clusterDeployRuleName*"}
							If([string]::IsNullOrEmpty($cl)){
								#throw "ERROR: Unable to find the cluster $($Cluster) in vCenter $($vCenter)`nThe cluster must exist in vCenter before a Deploy Rule is created"
								Write-Log -Path $Log -Message "[$(Get-Date)]`tWarning:`tUnable to locate the cluster $($Cluster) in vCenter $($vCenter).`nCreating the cluster $($Cluster) now..."
								Write-Warning "Unable to locate the cluster $($Cluster) in vCenter $($vCenter).`nCreating the cluster $($Cluster) now..."
								$clObj = New-AutoDeployCluster -Name $Cluster
								$cl = $clObj.ExtensionData
							}
							$rtrn += Create-DeployRule -Cluster (Get-VIObjectByVIView -MORef $cl.MoRef) -MACAddress $MAC -ImageProfile $ImageProfile -HostProfile ($allHostProfiles | ?{$_.Name -eq $HostProfile})
							$clObj = $rtrn[$rtrn.Count-1].ItemList | ?{$_.GetType().Name -eq "ClusterImpl"}
						}
						$rtrn += Remove-FromDeployRule -deployRule $srcDeployRule -MACAddress $MAC
						#run a test/repair against the host and deploy rule
						try{
							$gc = Get-VMHost | ?{$_.Name -like "$($VMHost)*"} | Test-DeployRuleSetCompliance -ErrorAction SilentlyContinue | Repair-DeployRuleSetCompliance -ErrorAction SilentlyContinue
						}Catch{
							Write-Log -Path $Log -Message "[$(Get-Date)]`tVerbose:`tNo ESXi Host exists in vCenter, so the Test-DeployRuleSetCompliace and Repair-DeployRuleSetCompliance Failed. This is not a big problem"
							Write-Verbose "No ESXi Host exists in vCenter, so the Test-DeployRuleSetCompliace and Repair-DeployRuleSetCompliance Failed. This is not a big problem"
						}
					#endregion
				}
				ElseIf($Remove){
					#region  #### Removing
						#Ensure the MAC address is correct
						[regex]$macRegEx = "^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$"
						$MAC = $MAC.Replace("-",":")
						If(-not ($MAC -match $macRegEx)){
							Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`tThe MAC Address is not in the form of 00:00:00:00:00:00`n$($MACAddress)"
							throw "The MAC Address is not in the form of 00:00:00:00:00:00`n$($MAC)"
						}
						$srcDeployRule = $null; $srcDeployRule = $alldeployRules | ?{$_.PatternList -contains "mac=$($MAC)"}
						If([string]::IsNullOrEmpty($srcDeployRule)){
							#source deploy rule doesn't exist
							Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`tNo existing deploy rule has been found with MAC Address $($MAC)`nThe option selected was to REMOVE the host from an existing deploy rule."
							throw "No existing deploy rule has been found with MAC Address $($MAC)`nThe option selected was to REMOVE the host from an existing deploy rule."
						}
						If ($srcDeployRule.patternlist.count -gt 1) {
							$rtrn += Remove-FromDeployRule -deployRule $srcDeployRule -MACAddress $MAC
						}
						If ($srcDeployRule.patternlist.count -eq 1) {
							$rtrn += "Unable to remove host from deploy rule as this is the last host in the rule. Deleting rule instead."
							$gc = Remove-DeployRule -DeployRule $srcDeployRule -Delete
						}
						try{
							$gc = Get-VMHost | ?{$_.Name -like "$($VMHost)*"} | Test-DeployRuleSetCompliance -ErrorAction SilentlyContinue | Repair-DeployRuleSetCompliance -ErrorAction SilentlyContinue
						}Catch{
							Write-Log -Path $Log -Message "[$(Get-Date)]`tVerbose:`tNo ESXi Host exists in vCenter, so the Test-DeployRuleSetCompliace and Repair-DeployRuleSetCompliance Failed. This is not a big problem"
							Write-Verbose "No ESXi Host exists in vCenter, so the Test-DeployRuleSetCompliace and Repair-DeployRuleSetCompliance Failed. This is not a big problem"
						}
					#endregion
				}
				#region  #### Handling the LicenseKey
					If(-not [string]::IsNullOrEmpty($licenseKey) -and (-not [string]::IsNullOrEmpty($clObj))){
						$ldm = Get-LicenseDataManager
						$ld = New-Object VMware.VimAutomation.License.Types.LicenseData
						$lke = New-Object Vmware.VimAutomation.License.Types.LicenseKeyEntry
						$lke.TypeId = "vmware-vsphere"
						$lke.LicenseKey = $licenseKey

						$ld.LicenseKeys += $lke
						$ldm.UpdateAssociatedLicenseData($clObj.Uid,$ld) | Out-Null
						$rtrn += $ldm.QueryAssociatedLicenseData($clObj.Uid)
					}
				#endregion
      #endregion
			}
		catch{
			#region  #### In case of emergency
				Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`t$($_.Exception.Message)"
				Write-Error $_.Exception.Message
				Disconnect-VIServer * -Confirm:$false
				throw $_.Exception.Message
				$DHCPServerInfo = $null; $VMHost = $null; $MAC = $null
			#endregion
		}
	#endregion

	Disconnect-VIServer * -Confirm:$false
	#region  ##### DHCP reservations and DNS records work
		try{
			$remoteOptions = $DHCPServerInfo | ?{$_.vCenter -eq $vCenter}
			$winOS = (Get-WmiObject -class Win32_OperatingSystem).Caption
      
			If($Add){
				If($VMHost -like "*.nordstrom.net*"){ $VMHost = $VMHost.Replace('.nordstrom.net','') } #This is the Leno line, since he likes to use FQDNs ... way to go
				Write-Log -Path $Log -Message "[$(Get-Date)]`tRunning New-DHCPReservation.ps1"
				$DHCP = .\New-DHCPReservation.ps1 -Name $VMHost -MacAddress $MAC -DHCPServer $remoteOptions.DHCPServer -ScopeName $remoteOptions.ScopeName -Log $Log
				Write-Log -Path $Log -Message $DHCP
				Write-Log -Path $Log -Message "[$(Get-Date)]`tRunning New-DNSRecord.ps1"
				$DNS = .\New-DNSRecord.ps1 -Name $VMHost -IPAddress $DHCP.IPAddress -DNSServer "10.16.172.129" -Domain $remoteOptions.Domain -Log $Log
				Write-Log -Path $Log -Message $DNS
				$rtrn += $DHCP; $rtrn += $DNS
			}ElseIf($Remove){
				If ($RemoveDHCPandDNS -like "y*"){
					#this section is commented out for now. Not sure if this is how removals should be handled.
          $DHCP = .\Remove-DHCPReservation.ps1 -Name $VMHost -MacAddress $MAC -DHCPServer $remoteOptions.DHCPServer -ScopeName $remoteOptions.ScopeName
					$rtrn += "Removed DHCP record $($DHCP.IPAddress)"
					If ([string]::IsNullOrEmpty(($DHCP.IPAddress))){
            $DNS = "No IP address was returned from the DHCP removal procedure so no DNS entry will be removed."
          } else {
            $DNS = .\Remove-DNSRecord.ps1 -Name $VMHost -IPAddress $($DHCP.IPAddress) -DNSServer "10.16.172.129" -Domain $($remoteOptions.Domain)					
            $DNS = "Removed DNS records for $VMHost"
          }
          $rtrn += $DNS
				}
			}
		}
		catch{
			Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`t$($_.Exception.Message)"
			Write-Error $_.Exception.Message
			throw $_.Exception.Message
		}
	#endregion
#endregion

#<#region ######################################### Cleanup #################################################
	Write-Log -Path $Log -Message $rtrn
	#return $rtrn #this may be causing an issue with multiple runs in the same powershell session
	$rtrn
	exit 0
#endregion #>