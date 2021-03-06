Param(
  [Parameter(Mandatory=$true, Position=1)]
  [ValidateNotNullOrEmpty()]
  [string]$NewServerName,
  [Parameter(Mandatory=$true, Position=2)]
  [ValidateNotNullOrEmpty()]
  [string]$DomainName,
  [Parameter(Mandatory=$true, Position=3)]
  [ValidateNotNullOrEmpty()]
  [string]$vmm_server_name="vmm0990p01",
  [Parameter(Mandatory=$true, Position=4)]
  [ValidateNotNullOrEmpty()]
  [string]$vmm_hostgroup_name="0990",
  [Parameter(Mandatory=$false, Position=5)]
  [string]$OSMgmtAdapter1="Embedded LOM 1 Port 1",
  [Parameter(Mandatory=$false, Position=6)]
  [string]$OSMgmtAdapter2="Embedded LOM 1 Port 2",
  [Parameter(Mandatory=$false, Position=7)]
  [string]$S2DAdapter1="PCIe Slot 2 Port 2",
  [Parameter(Mandatory=$false, Position=8)]
  [string]$S2DAdapter2="PCIe Slot 5 Port 2",
  [Parameter(Mandatory=$false, Position=9)]
  [string]$GuestAdapter1="PCIe Slot 2 Port 1",
  [Parameter(Mandatory=$false, Position=10)]
  [string]$GuestAdapter2="PCIe Slot 5 Port 1",
  [string[]]$SkipSteps
)

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
Function Get-Credentials(){
  Format-Message "Obtaining the credentials for adding the computer to the domain" | Write-Log -Path $log_file
  Write-Host "`n`nPlease provide the credentials that are allowed to add servers to the domain."
  $u = Read-Host "Username"
  $p = Read-Host "Password" -AsSecureString
  $cred = New-Object System.Management.Automation.PSCredential ($u,$p)
  Format-Message "Credentials for $($u) collected" | Write-Log -Path $log_file
  return $cred
}
Function Get-LocalAdminCredentials(){
  Format-Message "Obtaining the Current credentials for the Local Administrator Account" | Write-Log -Path $log_file
  Write-Host "`n`nPlease provide the credentials for the Current Local Administrator user."
  $u = "Administrator"
  $p = Read-Host "Password" -AsSecureString
  $cred = New-Object System.Management.Automation.PSCredential ($u,$p)
  Format-Message "Credentials for $($u) collected" | Write-Log -Path $log_file
  return $cred
}
Function Out-Credential(){
  Param(
    [Parameter(Mandatory=$true)]
    $credential
  )
  $cred = New-Object PSObject -Property @{"username" = $credential.UserName; "password" = ($credential.Password | ConvertFrom-SecureString -Key (1..16))}
  $cred | Export-Csv C:\temp\setup_cred.dat -NoTypeInformation
}
Function Out-AdminCredential(){
  Param(
    [Parameter(Mandatory=$true)]
    $credential
  )
  $cred = New-Object PSObject -Property @{"username" = $credential.UserName; "password" = ($credential.Password | ConvertFrom-SecureString -Key (1..16))}
  $cred | Export-Csv C:\temp\setup_admin_cred.dat -NoTypeInformation
}
Function Read-Credential(){
  $cred = $null
  if (Test-Path "C:\TEMP\setup_cred.dat"){
  	$data = Import-Csv C:\TEMP\setup_cred.dat
 	 $cred = New-object System.Management.Automation.PSCredential ($data.username,($data.password | ConvertTo-SecureString -Key (1..16)))
  }
  return $cred
}
Function Read-AdminCredential(){
  $cred = $null
  if (Test-Path "C:\TEMP\setup_admin_cred.dat"){
  	$data = Import-Csv C:\TEMP\setup_admin_cred.dat
 	$cred = New-object System.Management.Automation.PSCredential ($data.username,($data.password | ConvertTo-SecureString -Key (1..16)))
  }
  return $cred
}
Function Remove-Credential(){
  Remove-Item -Path C:\temp\setup_cred.dat -Confirm:$false -Force:$true
  Remove-Item -Path C:\TEMP\setup_admin_cred.dat -Confirm:$false -Force:$true
}
Function Install-Chef(){
  New-Item -Path C:\chef\log -ItemType directory -Confirm:$false -Force:$true
  $web_client = New-Object System.Net.WebClient
  $web_client.Downloadfile('https://mvnrepo.nordstrom.net/nexus/content/repositories/thirdparty/com/nordstrom/wse/chef_client/12.8.1/chef_client-12.8.1-x64.msi','C:\Temp\chef_client.msi')
  $web_client.Downloadfile('https://mvnrepo.nordstrom.net/nexus/content/repositories/thirdparty/com/nordstrom/wse/client-rb/1.1/client-rb-1.1.rb','C:\Chef\client.rb')
  $web_client.Downloadfile('https://mvnrepo.nordstrom.net/nexus/content/repositories/thirdparty/com/nordstrom/wse/nordwse-validator/1.0/nordwse-validator-1.0.pem','C:\Chef\nordwse-validator.pem')
  
  Start-Process -FilePath msiexec -ArgumentList /qn, /i, 'C:\temp\chef_client.msi /log c:\temp\chef_client_install_log.txt', ADDLOCAL="ChefClientFeature" -Wait
}
Function Set-WseChefRecipe{
  Start-Process -FilePath C:\opscode\chef\bin\chef-client.bat -ArgumentList @('-c', 'C:\chef\client.rb', '-L', 'C:\chef\log\chef.log', '-r', 'recipe[wse_base]', '-E', 'PROD') -Wait
}
Function Update-Step(){
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $next_step
  )

  $next_step | Out-File -FilePath $step_file -Confirm:$false -Force:$true
  $step = $next_step
}
Function Read-Step(){

  if(Test-Path $step_file){ 
    $step = Get-Content -Path $step_file 
  }
}
Function Set-EveryonePermissions(){
  Param(
    [Parameter(Mandatory=$true)]
    $FileOrFolderPath
  )
  
  $acl = Get-Acl $FileOrFolderPath
  $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule('Everyone','FullControl', 'ContainerInherit,ObjectInherit', 'InheritOnly', 'Allow')))
  Set-Acl $FileOrFolderPath -AclObject $acl
}
Function Set-StaticIP(){
Param(
	[Parameter(Mandatory=$true)]
	$NetworkAdapterName
)
	$netadapt = Get-NetAdapter -Name $NetworkAdapterName
	$ipaddr = $netadapt | Get-NetIPAddress -AddressFamily IPV4 | ?{$_.prefixOrigin -eq "Dhcp"}
	$defGateway = Get-NetRoute -AddressFamily IPV4 -DestinationPrefix "0.0.0.0/0"
	$dnsServer = $netadapt | Get-DnsClientServerAddress -AddressFamily IPV4
	if (-not [string]::IsNullOrEmpty($ipaddr)){
		$netadapt | Remove-NetIPAddress -Confirm:$false
		Remove-NetRoute -AddressFamily IPV4 -DestinationPrefix "0.0.0.0/0" -Confirm:$false
		$staticIP = $netadapt | New-NetIPAddress -AddressFamily IPv4 -IPAddress $ipaddr.IPv4Address -DefaultGateway $defGateway.NextHop -PrefixLength $ipaddr.PrefixLength -Confirm:$false
		$netadapt | Set-DnsClientServerAddress -ServerAddresses ($dnsServer.ServerAddresses | ?{$_ -ne "10.228.32.22"}) -Confirm:$false
	}
	$netadapt | Get-NetIPConfiguration
}
Function Install-GitHubDesktop(){

	cd c:\temp
$inf = "[Setup]
Lang=default
Dir=C:\Program Files\Git
Group=Git
NoIcons=0
SetupType=default
Components=gitlfs,assoc,assoc_sh
Tasks=
EditorOption=VIM
PathOption=Cmd
SSHOption=OpenSSH
CURLOption=OpenSSL
CRLFOption=CRLFAlways
BashTerminalOption=MinTTY
PerformanceTweaksFSCache=Enabled
UseCredentialManager=Enabled
EnableSymlinks=Disabled
"
	$inf | Out-File -FilePath "C:\temp\gitinstall.inf" -Encoding UTF8 -Force:$true
	C:\Temp\Git-2.16.2-64-bit.exe /LOADINF="C:\temp\gitinstall.inf" /SILENT /SUPPRESSMSGBOXES /LOG="C:\temp\gitinstall.log"
	Sleep -Seconds 90
	
	# Install posh-git for powershell
	#Add-Type -Assembly "System.IO.Compression.Filesystem" -ErrorAction SilentlyContinue
	#[IO.Compression.ZipFile]::ExtractToDirectory("C:\temp\posh-git-master.zip","C:\Temp")
	#cd C:\Temp\posh-git-master
	#.\install.ps1
	
	return pwd
}
Function Set-Pause(){
	Param(
		[int]$Timeout=5
	)
	
	Write-Host "Paused for review of output"
	($Timeout..0) | %{
		Write-Host "Auto Continuing in $_"
		Sleep -Seconds 1
	}
}
Function Verify-InstallFinished(){
	Param(
		$LogFilePath,
		$SearchMessage,
		[int]$Timeout=9999
	)
	
	foreach ($n in ($Timeout..0)) {
		$chk = $null
		$data = Get-Content -Path $LogFilePath
		$chk = $data | ?{$_ -like "*$($SearchMessage)*"}
		if ($chk){ break; }
		Sleep -Seconds 1
	}
}

# Script Level Variable Declarations
New-Variable -Name log_file -Value "C:\temp\server_setup.log" -Option AllScope -Scope Script -ErrorAction SilentlyContinue
New-Variable -Name step_file -Value "C:\temp\server_setup.dat" -Option AllScope -Scope Script -ErrorAction SilentlyContinue
New-Variable -Name step -Value "Start" -Option AllScope -Scope Script -ErrorAction SilentlyContinue

sleep -Seconds 10 # Lets wait 10 seconds for boot and then continue

if(-not (Test-Path "C:\temp")){
  New-Item -Path C:\temp -ItemType directory -Confirm:$false -Force:$true
  Set-EveryonePermissions "C:\temp"
}

Read-Step

$cred = Read-Credential
if (-not $cred){
	Format-Message "Prompting for Domain Credentials" | Write-Log -Path $log_file
	$cred = Get-Credentials
	Format-Message "Saving Domain Credentials" | Write-Log -Path $log_file
	Out-Credential $cred
}
$admin_cred = Read-AdminCredential
if (-not $admin_cred){
	Format-Message "Prompting for Local Administrator Credentials" | Write-Log -Path $log_file
	$admin_cred = Get-LocalAdminCredentials
	Format-Message "Saving Local Administrator Credentials" | Write-Log -Path $log_file
	Out-AdminCredential $admin_cred
}
if (-not (Test-Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Continue-Setup.bat')){
	Format-Message "Creating Startup Script" | Write-Log -Path $log_file
	$bat_str = "
	@echo off
	set CMD=C:\Windows\system32\cmd.exe /c
	set POWERSHELL=C:\WINDOWS\system32\windowspowershell\v1.0\powershell.exe
	set PSSCRIPT=C:\temp\Hyperv_Windows_Setup.ps1
	set NewServerName='$($NewServerName)'
	set DomainName='$($DomainName)'
	set vmm_server_name='$($vmm_server_name)'
	set vmm_hostgroup_name='$($vmm_hostgroup_name)'
	set net_adapter1G_1_name='$($OSMgmtAdapter1)'
	set net_adapter1G_2_name='$($OSMgmtAdapter2)'
	set net_adapters2d_1_name='$($S2DAdapter1)'
	set net_adapters2d_2_name='$($S2DAdapter2)'
	set net_adapterguest_1_name='$($GuestAdapter1)'
	set net_adapterguest_2_name='$($GuestAdapter2)'
	time /T >> C:\temp\Execpowershell.log
	echo %CMD% %POWERSHELL% -command ""&'%PSSCRIPT%' %NewServerName% %DomainName% %vmm_server_name% %vmm_hostgroup_name% %net_adapter1G_1_name% %net_adapter1G_2_name% %net_adapters2d_1_name% %net_adapters2d_2_name% %net_adapterguest_1_name% %net_adapterguest_2_name%"" >> C:\temp\Execpowershell.log
	%CMD% %POWERSHELL% -command ""&'%PSSCRIPT%' %NewServerName% %DomainName% %vmm_server_name% %vmm_hostgroup_name% %net_adapter1G_1_name% %net_adapter1G_2_name% %net_adapters2d_1_name% %net_adapters2d_2_name% %net_adapterguest_1_name% %net_adapterguest_2_name%""
	"
	Write-Output ($bat_str) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
	$bat_str | Out-File 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Continue-Setup.bat' -Encoding utf8
}

$session = New-PSSession -ComputerName $vmm_server_name -Credential $cred -ErrorAction SilentlyContinue
Import-PSSession -Session $session -Module VirtualMachineManager -ErrorAction SilentlyContinue

Do{
  Switch($step)
  {
    "Start"       { $next_step = "AutoLogin"
					if ($SkipSteps -notcontains $step){
	                    try{
						  if (-not $cred){
							Format-Message "Prompting for Domain Credentials" | Write-Log -Path $log_file
							$cred = Get-Credentials
							Format-Message "Saving Domain Credentials" | Write-Log -Path $log_file
							Out-Credential $cred
						}
						
						if (-not $admin_cred){
							Format-Message "Prompting for Local Administrator Credentials" | Write-Log -Path $log_file
							$admin_cred = Get-LocalAdminCredentials
							Format-Message "Saving Local Administrator Credentials" | Write-Log -Path $log_file
							Out-AdminCredential $admin_cred
						}
	                      Format-Message "Starting Server Setup" | Write-Log -Path $log_file
						  Copy-Item -Path $MyInvocation.MyCommand.Path -Destination C:\temp\ -Force:$true -Confirm:$false
						  
						  Format-Message "Disbaling User Account Control" | Write-Log -Path $log_file
						  Write-Output (New-ItemProperty -Path "HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system" -Name EnableLUA -PropertyType DWord -Value 0 -Force -ErrorAction SilentlyContinue) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  
						  netsh Advfirewall set allprofiles state off
						  
	                      Update-Step $next_step
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
	"AutoLogin"  { $next_step = "ChangeName"
					if ($SkipSteps -notcontains $step){
						Format-Message "Setting up Auto Login for Local Administrator" | Write-Log -Path $log_file
	                    try{
	                      $reg_path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\WinLogon"
						  Format-Message "Configuring DefalutUserName" | Write-Log -Path $log_file
						  if (Get-ItemProperty -Path $reg_path -Name "DefaultUserName"){
						  	Set-ItemProperty -Path $reg_path -Name "DefaultUserName" -Value "Administrator" -Force:$true
						  }else{
						  	New-ItemProperty -Path $reg_path -Name "DefaultUserName" -Value "Administrator" -PropertyType String -Force:$true
						  }
						  
						  Format-Message "Configuring DefalutPassword" | Write-Log -Path $log_file
						  $clear_passwd = $admin_cred.GetNetworkCredential().Password
						  if (Get-ItemProperty -Path $reg_path -Name "DefaultPassword"){
						  	Set-ItemProperty -Path $reg_path -Name "DefaultPassword" -Value $clear_passwd -Force:$true
						  }else{
						  	New-ItemProperty -Path $reg_path -Name "DefaultPassword" -Value $clear_passwd -PropertyType String -Force:$true
						  }
						  $clear_passwd = $null
						  
						  Format-Message "Configuring AutoAdminLogon" | Write-Log -Path $log_file
						  if (Get-ItemProperty -Path $reg_path -Name "AutoAdminLogon"){
						  	Set-ItemProperty -Path $reg_path -Name "AutoAdminLogon" -Value "1" -Force:$true
						  }else{
						  	New-ItemProperty -Path $reg_path -Name "AutoAdminLogon" -Value "1" -PropertyType String -Force:$true
						  }
						  
	                      Update-Step $next_step
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
	"AutoLoginDom"{ $next_step = "GITSetup"
					if ($SkipSteps -notcontains $step){
						Format-Message "Setting up Auto Login for Domain Administrator" | Write-Log -Path $log_file
	                    try{
	                      $reg_path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\WinLogon"
						  Format-Message "Configuring DefalutUserName" | Write-Log -Path $log_file
						  if (Get-ItemProperty -Path $reg_path -Name "DefaultUserName"){
						  	Set-ItemProperty -Path $reg_path -Name "DefaultUserName" -Value "$($DomainName)\$($cred.UserName)" -Force:$true
						  }else{
						  	New-ItemProperty -Path $reg_path -Name "DefaultUserName" -Value "$($DomainName)\$($cred.UserName)" -PropertyType String -Force:$true
						  }
						  
						  Format-Message "Configuring DefalutPassword" | Write-Log -Path $log_file
						  $clear_passwd = $cred.GetNetworkCredential().Password
						  if (Get-ItemProperty -Path $reg_path -Name "DefaultPassword"){
						  	Set-ItemProperty -Path $reg_path -Name "DefaultPassword" -Value $clear_passwd -Force:$true
						  }else{
						  	New-ItemProperty -Path $reg_path -Name "DefaultPassword" -Value $clear_passwd -PropertyType String -Force:$true
						  }
						  $clear_passwd = $null
						  
						  Format-Message "Configuring AutoAdminLogon" | Write-Log -Path $log_file
						  if (Get-ItemProperty -Path $reg_path -Name "AutoAdminLogon"){
						  	Set-ItemProperty -Path $reg_path -Name "AutoAdminLogon" -Value "1" -Force:$true
						  }else{
						  	New-ItemProperty -Path $reg_path -Name "AutoAdminLogon" -Value "1" -PropertyType String -Force:$true
						  }
						  
						  Update-Step $next_step
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
	"InstallVMMCon"{ $next_step = 'AddSCVMM'
						if ($SkipSteps -notcontains $step){
							try{
								Format-Message "Installing VMM Console" | Write-Log -Path $log_file
								Format-Message "Creating VMClient.ini file" | Write-Log -Path $log_file
								"[OPTIONS]" | Out-File -FilePath c:\Temp\vmm_console\VMClient.ini -Confirm:$false
								"ProgramFiles=C:\Program Files\Microsoft System Center\Virtual Machine Manager" | Out-File -FilePath c:\Temp\vmm_console\VMClient.ini -Append -Confirm:$false
								"IndigoTcpPort=8100" | Out-File -FilePath c:\Temp\vmm_console\VMClient.ini -Append -Confirm:$false
								"MUOptIn = 0" | Out-File -FilePath c:\Temp\vmm_console\VMClient.ini -Append -Confirm:$false
								"VmmServerForOpsMgrConfig = $($vmm_server_name)" | Out-File -FilePath c:\Temp\vmm_console\VMClient.ini -Append -Confirm:$false
								if (Test-Path -Path 'C:\Temp\vmm_console\setup.exe'){
									C:\Temp\vmm_console\setup.exe /client /i /IACCEPTSCEULA /f C:\Temp\vmm_console\vmclient.ini
									if (-not Test-Path "C:\Program Files\Microsoft System Center\Virtual Machine Manager\bin\VmmAdminUI.exe"){
										Write-Error -Message "VMM Console Setup failed or not complete. No logging available for unattended install. Please validate or manually install VMM Console from C:\temp\vmm_console\setup.exe" -ErrorAction Stop
									}
									Update-Step $next_step
								}else{
									Write-Error -Message 'VMM_Console Setup Not Located at C:\Temp\vmm_console\setup.exe' -ErrorAction Stop
								}
							}catch{ 
								Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
								Set-Pause 15
								exit -1
							}
						}else{ Update-Step $next_step }
				   }
    "AddSCVMM"	  { $next_step = 'SetVMMNetwork'
					if ($SkipSteps -notcontains $step){
	                    try{
						  $script_block = {
						  Param(
						  	[string]$vmm_server_name,
							[string]$vmm_hostgroup_name,
							[string]$vmhostName,
							$cred,
							$log_file
						  )
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

						  	Format-Message "Adding to SCVMM" | Write-Log -Path $log_file
							Format-Message "VMM: $($vmm_server_name); HostGroup: $($vmm_hostgroup_name); VMHOST: $($vmhostName)" | Write-Log -Path $log_file
	                        $vmm = Get-SCVMMServer -ComputerName $vmm_server_name -Credential $cred
						    Write-Output ($vmm | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						    $vmm_hostgroup = Get-SCVMHostGroup -Name $vmm_hostgroup_name -VMMServer $vmm
						    Write-Output ($vmm_hostgroup | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
							Write-Output ((Add-SCVMHost -ComputerName $vmhostName -Credential $cred -VMMServer $vmm -VMHostGroup $vmm_hostgroup -Reassociate:$true -ErrorAction Stop) | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  }
						  
						  Write-Output ((Invoke-Command $vmm_server_name -ScriptBlock $script_block -Credential $cred -ArgumentList @($vmm_server_name, "$($vmm_hostgroup_name)", $env:ComputerName, $cred, $log_file) -ErrorAction Stop)) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  Set-Pause
	                      Update-Step $next_step
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
	"SetVMMNetwork"{ $next_step = "SetStaticIP"
					if ($SkipSteps -notcontains $step){
	                    $script_block = {
						Param(
						  $vmmServer,
						  $vmhostName,
						  $vmm_hostgroup_name,
						  $cred,
						  $log_file,
						  $OSMgmtAdapter1,
						  $OSMgmtAdapter2,
						  $S2DAdapter1,
						  $S2DAdapter2,
						  $GuestAdapter1,
						  $GuestAdapter2
						)
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
						function Set-UplinkProfile(){
							Param(
								$VMHost,
								$VMMServer,
								$UplinkProfile,
								$NetAdapter
							)
							if ($NetAdapter.UplinkPortProfileSet.Name -ne $UplinkProfile.Name){
								return (Set-SCVMHostNetworkAdapter -VMHostNetworkAdapter $NetAdapter -UplinkPortProfileSet $UplinkProfile)
							}else { return $null }
						}
						function Get-AvailableNetAdapters(){
						  	Param(
								$NetAdapters,
								$LogicalSwitch
							)
							$adapter_array = @()
							$NetAdapters | %{ $na = $_
								if ($na.VirtualNetwork.LogicalSwitch.Name -ne $LogicalSwitch.Name){
									$adapter_array += $na
								}
							}
							return $adapter_array
						}

						try{
	                      Format-Message "Configuring the VMM Logical Networking" | Write-Log -Path $log_file
						  $vmm = Get-SCVMMServer -ComputerName $vmmServer -Credential $cred
						  $vmhost = Get-SCVMHost -ComputerName $vmhostName
	                      $vmhost_netadapts = Get-SCVMHostNetworkAdapter -VMHost $vmhost
						  # Format-Message "OSMgmt Network Adapters" | Write-Log -Path $log_file
						  # $osmgmt = $vmhost_netadapts | ?{$_.ConnectionName -eq $OSMgmtAdapter1 -or $_.ConnectionName -eq $OSMgmtAdapter2}
						  # Write-Output ($osmgmt | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  Format-Message "S2D/LiveMigration Network Adapters" | Write-Log -Path $log_file
						  $s2dlm = $vmhost_netadapts | ?{$_.ConnectionName -eq $S2DAdapter1 -or $_.ConnectionName -eq $S2DAdapter2}
						  Write-Output ($s2dlm | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  Format-Message "Guest Network Adapters" | Write-Log -Path $log_file
						  $guest = $vmhost_netadapts | ?{$_.ConnectionName -eq $GuestAdapter1 -or $_.ConnectionName -eq $GuestAdapter2}
						  Write-Output ($guest | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  
						  # $vs_mgmt = Get-SCUplinkPortProfileSet -Name "vs$($vmm_hostgroup_name)mgmt"
						  # Write-Output ($vs_mgmt | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  $vs_s2dlm = Get-SCUplinkPortProfileSet -Name "vs$($vmm_hostgroup_name)s2dlm"
						  Write-Output ($vs_s2dlm | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  $vs_guest = Get-SCUplinkPortProfileSet -Name "vs$($vmm_hostgroup_name)guest"
						  Write-Output ($vs_guest | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  
						  # $ls_mgmt = Get-SCLogicalSwitch -Name "ls$($vmm_hostgroup_name)mgmt"
						  # Write-Output ($ls_mgmt | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  $ls_s2dlm = Get-SCLogicalSwitch -Name "ls$($vmm_hostgroup_name)s2dlm" 
						  Write-Output ($ls_s2dlm | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  $ls_guest = Get-SCLogicalSwitch -Name "ls$($vmm_hostgroup_name)guest"
						  Write-Output ($ls_guest | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  
						  
						  #$osmgmt | %{ 
						  #	Format-Message "Seting the VMHostNetworkAdapter $($_.Name) to the uplink Port Profile $($vs_mgmt.Name)" | Write-Log -Path $log_file
						  #	Write-Output (Set-UplinkProfile -VMHost $vmhost -NetAdapter $_ -UplinkProfile $vs_mgmt -VMMServer $vmm | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file }
						  
						  $s2dlm | %{ 
						  	Format-Message "Seting the VMHostNetworkAdapter $($_.Name) to the uplink Port Profile $($vs_s2dlm.Name)" | Write-Log -Path $log_file
						  	Write-Output (Set-UplinkProfile -VMHost $vmhost -NetAdapter $_ -UplinkProfile $vs_s2dlm -VMMServer $vmm | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file }
						  
						  $guest | %{ 
						  	Format-Message "Seting the VMHostNetworkAdapter $($_.Name) to the uplink Port Profile $($vs_guest.Name)" | Write-Log -Path $log_file
							Write-Output (Set-UplinkProfile -VMHost $vmhost -NetAdapter $_ -UplinkProfile $vs_guest -VMMServer $vmm | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file }
						  
						 
						  Format-Message "Applying the Logical Switch $($ls_s2dlm.Name)" | Write-Log -Path $log_file
						  $s2d_net_adapts = Get-AvailableNetAdapters -NetAdapters $s2dlm -LogicalSwitch $ls_s2dlm
						  Write-Output ($s2d_net_adapts | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  if ($s2d_net_adapts){
						  	Write-Output (New-SCVirtualNetwork -VMHost $vmhost -VMHostNetworkAdapters $s2d_net_adapts -LogicalSwitch $ls_s2dlm -DeployVirtualNetworkAdapters| ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  }else{ 
						  	Format-Message "Logical Switch $($ls_s2dlm.Name) has already been applied." | Write-Log -Path $log_file
							Write-Output ($s2dlm | Select Name,ConnectionName,VirtualNetwork,UplinkPortProfileSet | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  }
						  
						  Format-Message "Applying the Logical Switch $($ls_guest.Name)" | Write-Log -Path $log_file
						  $guest_net_adapts = Get-AvailableNetAdapters -NetAdapters $guest -LogicalSwitch $ls_guest
						  Write-Output ($guest_net_adapts | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  if ($guest_net_adapts){
						  	Write-Output (New-SCVirtualNetwork -VMHost $vmhost -VMHostNetworkAdapters $guest_net_adapts -LogicalSwitch $ls_guest -DeployVirtualNetworkAdapters | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  }else{ 
						  	Format-Message "Logical Switch $($ls_guest.Name) has already been applied." | Write-Log -Path $log_file
							Write-Output ($guest | Select Name,ConnectionName,VirtualNetwork,UplinkPortProfileSet | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  }
						  
						  # Format-Message "Applying the Logical Switch $($ls_mgmt.Name)" | Write-Log -Path $log_file
						  # $os_net_adapts = Get-AvailableNetAdapters -NetAdapters $osmgmt -LogicalSwitch $ls_mgmt
						  # Write-Output ($os_net_adapts | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  # if ($os_net_adapts){
						  # 	Write-Output (New-SCVirtualNetwork -VMHost $vmhost -VMHostNetworkAdapters $os_net_adapts -LogicalSwitch $ls_mgmt -DeployVirtualNetworkAdapters| ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  # }else{ 
						  # 	Format-Message "Logical Switch $($ls_mgmt.Name) has already been applied." | Write-Log -Path $log_file
						  # 	Write-Output ($osmgmt | Select Name,ConnectionName,VirtualNetwork,UplinkPortProfileSet | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  # }
						  Write-Host "Waiting for Network Configuration Completion"
						  (0..120) | %{ 
						  	try{ipconfig /flusdns > C:\Temp\null.dat }catch{ <#Do Nothing#> }
							Sleep -Seconds 1
						  }
						  
						  Set-SCVMHost -VMHost $vmhost -EnableLiveMigration $true
						  
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
	                      exit -1
	                    }
						}
						
						try{
							Write-Output (Invoke-Command $vmm_server_name -ScriptBlock $script_block -ArgumentList @($vmm_server_name,$env:computerName,$vmm_hostgroup_name,$cred,$log_file,$OSMgmtAdapter1,$OSMgmtAdapter2,$S2DAdapter1,$S2DAdapter2,$GuestAdapter1,$GuestAdapter2) -Credential $cred -ErrorAction Stop | ft -AutoSize) |  Out-String -Stream | Format-Message | Write-Log -Path $log_file
							Get-NetAdapter -Name $S2DAdapter1 | ? {Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName 'S2D_1' -ManagementOS -PhysicalNetAdapterName $_.Name}
						    Get-NetAdapter -Name $S2DAdapter2 | ? {Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName 'S2D_2' -ManagementOS -PhysicalNetAdapterName $_.Name}
							Set-Pause
							Update-Step $next_step
						}catch{
							Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
							Set-Pause 15
	                      	exit -1
						}
					}else{ Update-Step $next_step }
                  }
    "SetStaticIP" { $next_step = "InstallChef"
					if ($SkipSteps -notcontains $step){
	                    try{
						  Format-Message "Configuring Static IP Address" | Write-Log -Path $log_file
	                      Write-Output (Set-StaticIP -NetworkAdapterName "vEthernet (ls$($vmm_hostgroup_name)mgmt)" | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  Sleep -Seconds 15
	                      Update-Step $next_step
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
    "ChangeName"  { $next_step = "AddDomain"
					if ($SkipSteps -notcontains $step){
	                    try{
	                      if($env:COMPUTERNAME -ne $NewServerName){
	                        Format-Message "Changing the Server name from $($env:COMPUTERNAME) to $($NewServerName)" | Write-Log -Path $log_file
	                        #Rename-Computer -NewName $NewServerName -Force:$true -LocalCredential $admin_cred -ErrorAction Stop
	                        $PC = Get-WmiObject -Class Win32_ComputerSystem
							$PC.Rename($NewServerName)
							Format-Message "Server Rename complete .. Restarting computer $($NewServerName)" | Write-Log -Path $log_file
							Set-Pause
	                        Update-Step $next_step
	                        Restart-Computer -Confirm:$false -Force:$true -ErrorAction Stop
							break
	                      }
	                      Update-Step $next_step
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
    "AddDomain"   { $next_step = "AddAdmins"
					if ($SkipSteps -notcontains $step){
	                    try{
	                      Format-Message "Adding computer $($env:COMPUTERNAME) to domain $($DomainName)" | Write-Log -Path $log_file
	                      try{
	                        # test if the computer is already added to the domain. If Get-ADComputer returns an error then the answer is no
	                        #  Otherwise if the cmdlet returns a value and no error then skip on over
	                        Get-ADComputer $env:COMPUTERNAME -Properties * -ErrorAction Stop | Out-Null
	                        Format-Message "Computer $($env:COMPUTERNAME) already a member of domain $($DomainName)" | Write-Log -Path $log_file
							Set-Pause
	                        Update-Step $next_step
	                      }catch{
	                        Add-Computer -DomainName nordstrom.net -Credential $cred -Confirm:$false -Force:$true -ErrorAction Stop
	                        Format-Message "Domain add complete .. Restarting computer $($env:COMPUTERNAME)" | Write-Log -Path $log_file
							Set-Pause
	                        Update-Step $next_step
	                        Restart-Computer -Confirm:$false -Force:$true -ErrorAction Stop
							break
	                      }
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
    "AddAdmins"   { $next_step = "AutoLoginDom"
                    if ($SkipSteps -notcontains $step){
						try{
	                      Format-Message "Adding groups to Local Administrators group" | Write-Log -Path $log_file
	                      
	                      Format-Message "Adding 'nord\itucg' Administrators group" | Write-Log -Path $log_file
	                      try{
	                        Get-LocalGroupMember "Administrators" -Member "nord\itucg" -ErrorAction Stop
	                        Format-Message "Member 'nord\itucg' already added to Administrators group" | Write-Log -Path $log_file
	                      }catch{
	                        Add-LocalGroupMember -Group Administrators -Member "nord\itucg" -Confirm:$false -ErrorAction Stop
	                      }
	                      
	                      Format-Message "Adding 'nord\UcgSecondaryAccounts' Administrators group" | Write-Log -Path $log_file
	                      try{
	                        Get-LocalGroupMember "Administrators" -Member "nord\UcgSecondaryAccounts" -ErrorAction Stop
	                        Format-Message "Member 'nord\UcgSecondaryAccounts' already added to Administrators group" | Write-Log -Path $log_file
	                      }catch{
	                        Add-LocalGroupMember -Group Administrators -Member "nord\UcgSecondaryAccounts" -Confirm:$false -ErrorAction Stop
	                      }
						  Format-Message "Adding 'nord\OMAdmins' Administrators group" | Write-Log -Path $log_file
	                      try{
	                        Get-LocalGroupMember "Administrators" -Member "nord\OMAdmins" -ErrorAction Stop
	                        Format-Message "Member 'nord\OMAdmins' already added to Administrators group" | Write-Log -Path $log_file
	                      }catch{
	                        Add-LocalGroupMember -Group Administrators -Member "nord\OMAdmins" -Confirm:$false -ErrorAction Stop
	                      }
						  Format-Message "Adding 'nord\vcphypv' Administrators group" | Write-Log -Path $log_file
	                      try{
	                        Get-LocalGroupMember "Administrators" -Member "nord\UcgSecondaryAccounts" -ErrorAction Stop
	                        Format-Message "Member 'nord\UcgSecondaryAccounts' already added to Administrators group" | Write-Log -Path $log_file
	                      }catch{
	                        Add-LocalGroupMember -Group Administrators -Member "nord\UcgSecondaryAccounts" -Confirm:$false -ErrorAction Stop
	                      }
	                      
	                      Format-Message "Local Administrators Configuration complete" | Write-Log -Path $log_file
						  Set-Pause
	                      Update-Step $next_step
	                      Restart-Computer -Confirm:$false -Force:$true -ErrorAction Stop
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
    "InstallChef" { $next_step = "WSEChefRec"
                    if ($SkipSteps -notcontains $step){
						try{
	                      Format-Message "Installing Chef for Windows" | Write-Log -Path $log_file
	                      Install-Chef
	                      Update-Step $next_step
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
    "WSEChefRec"  { $next_step = "End"
                    if ($SkipSteps -notcontains $step){
						try{
	                      Format-Message "Applying Chef Recipe WSE_BASE" | Write-Log -Path $log_file
	                      Set-WseChefRecipe
	                      Update-Step $next_step
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
    "InstallFC"   { $next_step = "InstallDCB"
                    if ($SkipSteps -notcontains $step){
						try{
	                      Format-Message "Installing Windows Feature Failover Cluster and Management Tools" | Write-Log -Path $log_file
	                      if(-not (Get-WindowsFeature -ComputerName $env:COMPUTERNAME | ?{$_.Installed -and $_.Name -eq "Failover-Clustering"})){
	                        Install-WindowsFeature -Name "Failover-Clustering" -IncludeAllSubFeature –IncludeManagementTools
	                        Update-Step $next_step
	                      }else{
	                        Update-Step $next_step
	                        Format-Message "Windows Feature Failover Cluster and Management Tools already installed" | Write-Log -Path $log_file
	                      }
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
    "InstallDCB"  { $next_step = "SetupRDMA"
                    if ($SkipSteps -notcontains $step){
						try{
	                      Format-Message "Installing Windows Feature Data-Center-Bridging" | Write-Log -Path $log_file
	                      if(-not (Get-WindowsFeature -ComputerName $env:COMPUTERNAME | ?{$_.Installed -and $_.Name -eq "Data-Center-Bridging"})){
	                        Install-WindowsFeature -Name "Data-Center-Bridging"
	                        Update-Step $next_step
	                      }else{
	                        Update-Step $next_step
	                        Format-Message "Windows Feature Data Center Bridging is already installed" | Write-Log -Path $log_file
	                      }
						  Set-Pause
	                      Restart-Computer -Confirm:$false -Force:$true -ErrorAction Stop
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
    "GITSetup"    { $next_step = "GITClone"
                    if ($SkipSteps -notcontains $step){
						try{
	                      Format-Message "Installing Git for Windows" | Write-Log -Path $log_file
						  (New-Object System.Net.WebClient).DownloadFile("ftp://y0319p609/Git-2.16.2-64-bit.exe", "C:\temp\Git-2.16.2-64-bit.exe")
						  (New-Object System.Net.WebClient).DownloadFile("ftp://y0319p609/posh-git-master.zip", "C:\temp\posh-git-master.zip")
						  $git_exe = Install-GitHubDesktop
						  Set-Pause
						  Update-Step $next_step
						  Restart-Computer -Confirm:$false -Force:$true -ErrorAction Stop
	                      break
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
	"GITClone"    { $next_step = "InstallMellanoxDrivers"
                    if ($SkipSteps -notcontains $step){
						try{
	                      Format-Message "Cloning HYPERV repo" | Write-Log -Path $log_file
						  git clone --branch master "https://ciggit:6qLoc3wcNYz4uAxDKsaz@gitlab.nordstrom.com/cig/hyperv.git" C:\Temp\hyperv
						  Sleep -Seconds 5
						  git clone --branch master "https://ciggit:6qLoc3wcNYz4uAxDKsaz@gitlab.nordstrom.com/cig/psmodules.git" C:\Temp\psmodules
						  Sleep -Seconds 5
						  
						  
						  Copy-Item C:\Temp\hyperv\utils C:\ -Force:$true -Confirm:$false -Recurse:$true
						  Copy-Item C:\Temp\hyperv\firmware C:\ -Force:$true -Confirm:$false -Recurse:$true
						  Copy-Item C:\Temp\hyperv\scripts C:\ -Force:$true -Confirm:$false -Recurse:$true
						  Copy-Item C:\Temp\hyperv\software\vmm_console C:\temp\ -Force:$true -Confirm:$false -Recurse:$true
						  Copy-Item C:\Temp\psmodules\UcgModule "$($Env:ProgramFiles)\WindowsPowerShell\Modules\" -Force:$true -Confirm:$false -Recurse:$true
						  Remove-Item C:\Temp\hyperv -Force:$true -Confirm:$false -Recurse:$true
						  Remove-Item C:\Temp\psmodules -Force:$true -Confirm:$false -Recurse:$true
						  Set-Pause
	                      Update-Step $next_step
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
                  }
	"InstallHyperV"	{ $next_step = "InstallFC"
						if ($SkipSteps -notcontains $step){
							try{
								Format-Message "Installing Windows Feature Hyper-V" | Write-Log -Path $log_file
		                      if(-not (Get-WindowsFeature -ComputerName $env:COMPUTERNAME | ?{$_.Installed -and $_.Name -eq "Hyper-V"})){
		                        Install-WindowsFeature -Name "Hyper-V" -IncludeManagementTools
		                        Update-Step $next_step
		                      }else{
		                        Update-Step $next_step
		                        Format-Message "Windows Feature Hyper-V is already installed" | Write-Log -Path $log_file
		                      }
		                    }catch{
		                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
							  Set-Pause 15
		                      exit -1
		                    }
						}else{ Update-Step $next_step }
					
					}
	"InstallMellanoxDrivers"{ $next_step = "InstallHyperV"
                    if ($SkipSteps -notcontains $step){
						try{
	                      Format-Message "Installing Mellanox Firmware Tool in Silent Mode" | Write-Log -Path $log_file
						  C:\firmware\WinMFT_x64_4_9_0_38.exe /S /v/passive /v/l* /v"C:\temp\MellanoxFirmwareTool_install.log"
						  Sleep -Seconds 2
						  Verify-InstallFinished -LogFilePath "C:\temp\MellanoxFirmwareTool_install.log" -SearchMessage "=== Logging stopped:"
						  Format-Message "Installing Mellanox Drivers in Silent Mode" | Write-Log -Path $log_file
						  C:\firmware\MLNX_WinOF2-1_80_51000_All_x64.exe /S /v/passive /v/l* /v"C:\temp\MellanoxDriver_install.log" /vMT_SKIPFWUPGRD=1
						  Sleep -Seconds 2
						  Verify-InstallFinished -LogFilePath "C:\temp\MellanoxDriver_install.log" -SearchMessage "Installation success or error status" -Timeout 60
						  Set-Pause
	                      Update-Step $next_step
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
					}else{ Update-Step $next_step }
				  }
	"SetupRDMA"	  { $next_step = "InstallVMMCon"
					  if ($SkipSteps -notcontains $step){
						  try{
							  Get-NetAdapter  | ?{$_.Name -eq $S2DAdapter1} | Sort-Object number |% {$_ | Set-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket" -RegistryValue 9000}
							  Get-NetAdapter  | ?{$_.Name -eq $S2DAdapter2} | Sort-Object number |% {$_ | Set-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket" -RegistryValue 9000}
							  Set-NetAdapterAdvancedProperty -Name $S2DAdapter1 -RegistryKeyword "*FlowControl" -RegistryValue 0 | ft -AutoSize
							  Set-NetAdapterAdvancedProperty -Name $S2DAdapter2 -RegistryKeyword "*FlowControl" -RegistryValue 0 | ft -AutoSize
							  New-NetQosPolicy SMB -NetDirectPortMatchCondition 445 -PriorityValue8021Action 3 -Verbose | ft -AutoSize
							  Enable-NetQosFlowControl -Priority 3 -Verbose | ft -AutoSize
							  Disable-NetQosFlowControl -Priority 0,1,2,4,5,6,7 -Verbose | ft -AutoSize
							  Get-NetAdapter | ?{$_.Name -eq $S2DAdapter1} | Enable-NetAdapterQos -Verbose | ft -AutoSize
							  Get-NetAdapter | ?{$_.Name -eq $S2DAdapter2} | Enable-NetAdapterQos -Verbose | ft -AutoSize
							  New-NetQosTrafficClass "SMB" -Priority 3 -BandwidthPercentage 50 -Algorithm ETS -Verbose | ft -AutoSize
							  Enable-NetAdapterQos -Name @($S2DAdapter1,$S2DAdapter2) -Verbose | ft -AutoSize
						  }catch{
							  Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
							  Set-Pause 15
							  exit -1
	                    }
						  
						  Write-Output (Get-NetAdapter | ?{$_.Name -eq $S2DAdapter1} | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  Write-Output (Get-NetAdapter | ?{$_.Name -eq $S2DAdapter1} | Get-NetAdapterAdvancedProperty | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  Write-Output (Get-NetAdapter | ?{$_.Name -eq $S2DAdapter2} | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  Write-Output (Get-NetAdapter | ?{$_.Name -eq $S2DAdapter2} | Get-NetAdapterAdvancedProperty | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  Write-Output (Get-NetQosPolicy | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  Write-Output (Get-NetQosTrafficClass | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  Write-Output (Get-NetAdapterQos | ?{$_.Name -eq $S2DAdapter1} | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  Write-Output (Get-NetAdapterQos | ?{$_.Name -eq $S2DAdapter2} | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
						  
						  Update-Step $next_step
						  
					  }else{ Update-Step $next_step }
                  }
    "End"         { $next_step = "Complete"
                    if ($SkipSteps -notcontains $step){
						try{
	                      Format-Message "All Tasks complete, Cleaning Up" | Write-Log -Path $log_file
	                      Format-Message "Remove Credential File" | Write-Log -Path $log_file
	                      Remove-Credential
	                      Format-Message "Remove Startup Script" | Write-Log -Path $log_file
	                      Remove-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Continue-Setup.bat' -Confirm:$false -Force:$true
						  Format-Message "Remove AutoLogin" | Write-Log -Path $log_file
						  $reg_path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\WinLogon"
						  Remove-ItemProperty -Path $reg_path -Name "DefaultUserName" -Force:$true -Confirm:$false -ErrorAction SilentlyContinue
						  Remove-ItemProperty -Path $reg_path -Name "DefaultPassword" -Force:$true -Confirm:$false -ErrorAction SilentlyContinue
						  Remove-ItemProperty -Path $reg_path -Name "AutoAdminLogon" -Force:$true -Confirm:$false -ErrorAction SilentlyContinue
	                      Update-Step $next_step
	                    }catch{
	                      Format-Message -Message $_.Exception,$_.ScriptStackTrace -Status Error | Write-Log -Path $log_file
						  Set-Pause 15
	                      exit -1
	                    }
	                    Format-Message "Cleanup Complete. Exit code 0" | Write-Log -Path $log_file
						Write-Host "`n`nServer will reboot in 60 seconds.."
						Set-Pause 60
						Restart-Computer -Confirm:$false -Force:$true -ErrorAction Stop
	                    exit 0
					}else{ 
						Update-Step $next_step
						Format-Message "Cleanup Complete. Exit code 0" | Write-Log -Path $log_file
						Write-Host "`n`nServer will reboot in 60 seconds.."
						Set-Pause 60
						Restart-Computer -Confirm:$false -Force:$true -ErrorAction Stop
	                    exit 0
					}
                  }
    default       { Set-Pause 15; exit 99 }
  }
}while($step -ne "Complete")
