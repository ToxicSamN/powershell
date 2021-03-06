
cls

Function SyntaxUsage([string]$Message = $null)
{
	$syntaxEcho = "
	Proper Usage:
	
	Parameters:
	-f      <Path and Filename to datastore,cluster>[Required]
	-h      <Help>	
	"
	Write-Host $syntaxEcho
	$Message
	Exit 1
}
$Filename = $null
$targs = $args
$carg = 0
$args | %{ 
			$carg++
			[string]$tempstr = $_
			If ($tempstr.StartsWith("-"))
			{[string]$tempvar = $_
				Switch -wildcard ($tempvar.ToLower()){
				"-f*" {[string]$Filename = $targs[$carg]}
				#"-email*" {[string]$SendToEmail = $targs[$carg]}
				}
			}
			Else{
				Switch ($tempstr.ToLower()){
					"?" { SyntaxUsage }
					"help" { SyntaxUsage }
					"-h" { SyntaxUsage }
				}
			}
			
		 }

If($Filename -eq '' -or $Filename -eq $null){ SyntaxUsage }
Write-Host "Loading Modules..."
Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue
Import-Module UcgModule -WarningAction SilentlyContinue
CLS
$ds = Import-Csv $Filename
$vi = Connect-VIServer -Server A0319P8K -Credential (Login-vCenter) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
[array]$sucRename, [array]$failRename, [array]$noloDs = @(),@(),@()

$ds = $ds | Sort Cluster
$ds | %{
	$tds = $_
	If($sucRename -notcontains $tds.Datastore -and $failRename -notcontains $tds.Datastore -and $noloDs -notcontains $tds.Datastore){
		$nds = Get-Datastore -Name $tds.Datastore -Server $vi.Name -ErrorAction SilentlyContinue
		If($nds -eq $null -or $nds -eq ''){ 
			If($sucRename -notcontains $tds.Datastore){
				If($failRename -notcontains $tds.Datastore) { [array]$noloDs += $tds.Datastore; Write-Host " $($tds.Datastore) could not be found." }
			}
		}
		Else{
			$nds = $nds | Set-Datastore -Name ($tds.Datastore + "_rpl") -Server $vi.Name -ErrorAction SilentlyContinue
			If($nds.Name -eq ($tds.Datastore + "_rpl")){
				[array]$sucRename += $tds.Datastore
				Write-Host " $($tds.Datastore) was renamed to $($nds.Name)."
			}Else{
				[array]$failRename += $tds.Datastore
				Write-Host " $($tds.Datastore) was NOT renamed to $($tds.Datastore)_rpl."
			}
		}
	}
}
Write-Host "`n`n"
Write-Host "Successfull Renamed Datastores:" -BackgroundColor Green -ForegroundColor Black
$sucRename | %{ Write-Host "$($_)" -BackgroundColor Green -ForegroundColor Black }
Write-Host "`n`n"
Write-Host "Failed to Rename Datastores:" -BackgroundColor Red -ForegroundColor Black
$failRename | %{ Write-Host "$($_)" -BackgroundColor Red -ForegroundColor Black }
Write-Host "`n`n"
Write-Host "Failed to Locate Datastores:" -BackgroundColor Yellow -ForegroundColor Black
$noloDs | %{ Write-Host "$($_)" -BackgroundColor Yellow -ForegroundColor Black }

Disconnect-VIServer -Server $vi.Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
