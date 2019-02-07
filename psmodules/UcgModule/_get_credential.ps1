Param(
	[string]$Username = $null
)

Import-Module Ucgmodule -WarningAction SilentlyContinue -Scope global
Import-Module Encryption -WarningAction SilentlyContinue -Scope global

$module_log = "$($UcgLogPath)\UcgModule.log"

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
	Import-Module D:\Temp\Ucgmodule -WarningAction SilentlyContinue -Scope global
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

try{
	Format-Message "Initializing Client Pipe 'Cred'" | Write-Log -Path $module_log
	$pipe = new-object System.IO.Pipes.NamedPipeClientStream('.', 'Cred',[System.IO.Pipes.PipeDirection]::InOut,
	                                                                [System.IO.Pipes.PipeOptions]::None, 
	                                                                [System.Security.Principal.TokenImpersonationLevel]::Impersonation);
	Format-Message "Connecting Client Pipe 'Cred'" | Write-Log -Path $module_log
	$pipe.Connect();
	Format-Message "Initializing StreamWriter" | Write-Log -Path $module_log
	$sw = new-object System.IO.StreamWriter($pipe);
	$params = Validate-RequiredLoginParameter
	$cred_obj = Decipher-Credentials -ClientId $params.ClientId -Username $Username -RSAPrivateFile $params.RSAPrivateFile -RSASecret $params.RSASecret
	$cred_obj.SecurePassword = $cred_obj.SecurePassword | ConvertFrom-SecureString
	Format-Message "Pushing Data to Pipe" | Write-Log -Path $module_log
	$sw.WriteLine((ConvertTo-Json $cred_obj))
	$sw.WriteLine('exit')
	Format-Message "Disposing StreamWriter" | Write-Log -Path $module_log
	$sw.Dispose()
	Format-Message "Disposing Client Pipe 'Cred'" | Write-Log -Path $module_log
	$pipe.Dispose()
}catch{
	Write-Output ($_ | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $module_log
	Write-Error $_
	Format-Message "Exception occurred in _get_credential main" | Write-Log -Path $module_log
	$sw.WriteLine('exception')
	$sw.WriteLine('exit')
	Format-Message "Disposing StreamWriter during exception" | Write-Log -Path $module_log
	$sw.Dispose()
	Format-Message "Disposing Client Pipe 'Cred' during exception" | Write-Log -Path $module_log
	$pipe.Dispose()
}
