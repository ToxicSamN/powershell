# created by sammy shuck
# in vcenter one can configure an alarm to execute a script
# when the alarm fires. This is used by such script to then
# email the alarm with a custom message.
Param(
  [Parameter(Mandatory=$true)]
  [string[]]$To = @(),
  [Parameter(Mandatory=$true)]
  [string]$From = @(),
  [string]$CustomMessage = ""
)
[string]$html = @"
<body>
  <p>$($CustomMessage.Replace("`n","<br>"))</p>
  
  Target: $($Env:VMWARE_ALARM_TARGET_NAME)
  <br>Previous Status: $($Env:VMWARE_ALARM_OLDSTATUS)
  <br>New Status: $($Env:VMWARE_ALARM_NEWSTATUS)
  <br>
  <br>Alarm Definition:
  <br>$($Env:VMWARE_ALARM_DECLARINGSUMMARY)
  <br>
  <br>Event Details:
  <br> $($Env:VMWARE_ALARM_EVENTDESCRIPTION)
 </body>
"@

Send-MailMessage -To $To -From $From -BodyAsHtml $html -SmtpServer "exchange.nordstrom.net" -Subject "[VMware vCenter - Alarm $($Env:VMWARE_ALARM_NAME)] $($Env:VMWARE_ALARM_EVENTDESCRIPTION)" -ErrorAction Stop
exit 0