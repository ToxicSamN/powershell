Param(
	$ComputerName = $null,
	$NewPassword = $null
)

$sb = {
Param(
	[ValidateNotNullOrEmpty()]
	$passwd = $null
)
	Write-Host $passwd
	net user administrator "$($passwd)"
}

Invoke-Command $ComputerName -ScriptBlock $sb -ArgumentList $NewPassword