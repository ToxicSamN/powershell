
Param([String[]]$naaLookup=$null,[String[]]$devLookup=$null,[switch]$R1,[switch]$R2,[switch]$GC)
$path = "\\cns0319p02\uis_san1\DR2\log\rdm_map\"
#$path = "D:\temp\rdm_map\"
$child = dir $path | ?{$_.Name.EndsWith(".out")} | Sort CreationTime
$chk = $null
$child | %{ If($_.CreationTime -gt $chk.CreationTime){ $chk = $_ }}; $child = $chk
If($child.Count -gt 1){ $child = $child[$child.Count-1] }

$contents = Get-Content $child.PSPath
[array]$srdfRdmReplication = @()
$line = 0
$contents | %{ $line = $line+1
	$tmp = $_
	$tmp1 = $tmp.Split("	") | ?{$_ -ne "" -and $_ -ne $null}
	If($line -gt 1){
		$_pso = New-Object PSObject -Property @{R1dev=$tmp1[0];R1naa=$tmp1[1];R2dev=$tmp1[2];R2naa=$tmp1[3];GCdev=$tmp1[4];GCnaa=$tmp1[5]}
		[array]$srdfRdmReplication += $_pso | Select R1dev,R1naa,R2dev,R2naa,GCdev,GCnaa
	}
}

If($naaLookup -and $devLookup){
	If($R1){ return $srdfRdmReplication | ?{$_.R1naa -eq $naaLookup -and $_.R1dev -eq $devLookup } }
	ElseIf($R2){ return $srdfRdmReplication | ?{$_.R2naa -eq $naaLookup -and $_.R2dev -eq $devLookup } }
	ElseIf($GC){ return $srdfRdmReplication | ?{$_.GCnaa -eq $naaLookup -and $_.GCdev -eq $devLookup } }
	Else{ return $srdfRdmReplication | ?{ ($_.R1naa -eq $naaLookup -or $_.R2naa -eq $naaLookup -or $_.GCnaa -eq $naaLookup) -and ($_.R1dev -eq $devLookup -or $_.R2dev -eq $devLookup -or $_.GCdev -eq $devLookup) } }
}
ElseIf($naaLookup){
	If($R1){ return $srdfRdmReplication | ?{$_.R1naa -eq $naaLookup } }
	ElseIf($R2){ return $srdfRdmReplication | ?{$_.R2naa -eq $naaLookup } }
	ElseIf($GC){ return $srdfRdmReplication | ?{$_.GCnaa -eq $naaLookup } }
	Else{ return $srdfRdmReplication | ?{ $_.R1naa -eq $naaLookup -or $_.R2naa -eq $naaLookup -or $_.GCnaa -eq $naaLookup } }
}
ElseIf($devLookup){
	If($R1){ return $srdfRdmReplication | ?{$_.R1dev -eq $devLookup } } 
	ElseIf($R2){ return $srdfRdmReplication | ?{$_.R2dev -eq $devLookup } } 
	ElseIf($GC){ return $srdfRdmReplication | ?{$_.GCdev -eq $devLookup } } 
	Else{ return $srdfRdmReplication | ?{ $_.R1dev -eq $devLookup -or $_.R2dev -eq $devLookup -or $_.GCdev -eq $devLookup } }
}
Else{ return $srdfRdmReplication }
