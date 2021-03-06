﻿<#
This module is designed for encryption of Rsa using OAEPEncoding and Aes using AES_MODE_CFB.

Requires Powershell 5.0+

Author: Sammy
Date 8/28/2018
#>

$bccrypto_dll = Join-Path -Path $PSScriptRoot -ChildPath 'BouncyCastle.Crypto.dll'
Write-Host $PSScriptRoot
#Add-Type -Path $bccrypto_dll
[Reflection.Assembly]::LoadFile($bccrypto_dll)


class PasswordFinder : Org.BouncyCastle.OpenSsl.IPasswordFinder{
	
	hidden [string] $password
	
	PasswordFinder([string] $password){
		$this.password = $password
	}
	
	[char[]] GetPassword(){
		return $this.password.ToCharArray()
	}
}

class RsaCipher{
	
	hidden [string] $encrypted_message
	hidden [byte[]] $encrypted_message_bytes
	hidden [string] $decrypted_message
	hidden [byte[]] $decrypted_message_bytes
	
	RsaCipher(){
		$this.encrypted_message = ''
		$this.decrypted_message = ''
	}
	
	[Void]decrypt([string] $encrypted_message, [string] $private_key, [string] $secret_code){
		$decrypted_msg = ''
		$str_to_bytes = [System.Convert]::FromBase64String($encrypted_message);
		
		$cipher = [Org.BouncyCastle.Crypto.Encodings.OAEPEncoding]::new([Org.BouncyCastle.Crypto.Engines.RsaEngine]::new())
		$key_pair = $this.DecodeRsaPrivateKey($private_key, $secret_code)
		$cipher.Init($false, $key_pair.Private)
		$this.decrypted_message_bytes = $cipher.ProcessBlock($str_to_bytes, 0, $str_to_bytes.Length)
		$decrypted_msg = [System.Text.Encoding]::UTF8.GetString($this.decrypted_message_bytes)
		
		$this.decrypted_message = $decrypted_msg 
	}
	
	[Org.BouncyCastle.Crypto.AsymmetricCipherKeyPair] DecodeRsaPrivateKey([string] $encrypted_pkey, [string] $secret){
		$str_reader = [System.IO.File]::OpenText($encrypted_pkey)
		$pemReader = [Org.BouncyCastle.OpenSsl.PemReader]::new($str_reader, [PasswordFinder]::new($secret))
		[Object] $privateKey_obj = $pemReader.ReadObject()
		$rsa_private_key = $privateKey_obj.Private
		$rsa_public_key = $privateKey_obj.public
		$key_pair = [Org.BouncyCastle.Crypto.AsymmetricCipherKeyPair]::new($rsa_public_key, $rsa_private_key)
		return $key_pair
	}
}

class AesManagedObject {
	
	$ManagedObject
	$BlockSize
	$KeySize
	$Key
	$IV
	
	AesManagedObject(){
		$this.ManagedObject = [System.Security.Cryptography.Aes]::Create('Aes')
		$this.ManagedObject.GenerateKey()
		$this.ManagedObject.GenerateIV()
		# Setting a default CipherMode of MODE_CFB. The user can change this on thier own
		$this.ManagedObject.Mode = [System.Security.Cryptography.CipherMode]::CFB
		$this.ManagedObject.Key = $this.get_key($this.ManagedObject.Key)
		$this.ManagedObject.IV = $this.get_iv($this.ManagedObject.IV)
		
		$this.BlockSize = $this.ManagedObject.BlockSize
		$this.KeySize = $this.ManagedObject.KeySize
		$this.Key = [System.Convert]::ToBase64String($this.ManagedObject.Key)
		$this.IV = [System.Convert]::ToBase64String($this.ManagedObject.IV)
	}
	
	AesManagedObject($key, $iv){
		$this.ManagedObject = [System.Security.Cryptography.Aes]::Create('Aes')
		# Setting a default CipherMode of MODE_CFB. The user can change this on thier own
		$this.ManagedObject.Mode = [System.Security.Cryptography.CipherMode]::CFB
		$this.ManagedObject.Key = $this.get_key($key)
		$this.ManagedObject.IV = $this.get_iv($iv)

		$this.BlockSize = $this.ManagedObject.BlockSize
		$this.KeySize = $this.ManagedObject.KeySize
		$this.Key = [System.Convert]::ToBase64String($this.ManagedObject.Key)
		$this.IV = [System.Convert]::ToBase64String($this.ManagedObject.IV)
	}
	
	[System.Byte[]] get_key($key){
		if ($key.getType().Name -eq "String") {
			return [System.Convert]::FromBase64String($key)
        }
        else {
            return $key 
        }
	}
	
	[System.Byte[]] get_iv($iv){
		if ($iv.getType().Name -eq "String") {
            return [System.Convert]::FromBase64String($iv)
        }
        else {
            return $iv
        }
	}
	
	static [System.Byte[]] RandomBytes($size){
		$buffer = [System.Byte[]]::new($size)
		$rnd = [System.Random]::new()
		$rnd.NextBytes($buffer)
		return $buffer
	}
}

class AesCipher {
	[AesManagedObject] $AES
	hidden $EncryptedData
	hidden $DecryptedData
	
	AesCipher(){
		$this.AES = New-Object AesManagedObject
		$this.EncryptedData = $null
		$this.DecryptedData = $null
	}

	[Void] encrypt($raw) {
	    $raw_bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
	    $crypt = $this.AES.ManagedObject.CreateEncryptor()
	    $encrypted_data = $crypt.TransformFinalBlock($raw_bytes, 0, $raw_bytes.Length);
	    $this.EncryptedData = [System.Convert]::ToBase64String(($this.AES.ManagedObject.IV + $encrypted_data) -as [Byte[]])
		$this.AES.ManagedObject.Dispose()
	}

	[Void] decrypt($enc, $key=$null) {
		if ($enc -is [string]){
	    	$enc = [System.Convert]::FromBase64String($enc)
		}
		if ($key -is [string]){
			$key = [System.Convert]::FromBase64String($key)
		}
	    $IV = $enc[0..15] # first 16 Bytes is where the IV is located
	    $this.AES = [AesManagedObject]::new($key, $IV)
	    $crypt = $this.AES.ManagedObject.CreateDecryptor();
	    $unencrypted_data = $crypt.TransformFinalBlock($enc, 16, $enc.Length - 16);
	    $this.AES.ManagedObject.Dispose()
	    $this.DecryptedData = [System.Text.Encoding]::UTF8.GetString($unencrypted_data).Trim([char]0)
	}
}

function New-EncryptionObject {
	Param(
		[parameter(Mandatory=$true)]
		$type = 'RSA'
	)
	
	if ($type -eq 'rsa'){
		return [RsaCipher]::new()
	}
	elseif ($type -eq 'aes'){
		return [AesCipher]::new()
	}
	else{
		Write-Error "Incorrect Cipher Type provided. Valid values are 'RSA' and AES'." -Category InvalidArgument -ErrorAction Stop
	}
}
