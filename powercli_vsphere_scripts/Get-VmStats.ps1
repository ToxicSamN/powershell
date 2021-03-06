<#
  .NOTES
  This code was heavily lifted from the vFlux-Compute.ps1 file on github at https://github.com/vmkdaily/vFlux-Stats-Kit/blob/master/vFlux-Compute.ps1
  Modified for our purposes.

#>
Param(
  [Parameter(Mandatory = $False,Position=1)]
  [String]$vCenter,
  [Parameter(Mandatory = $False,Position=2)]
  [string]$Datacenter,
  [Parameter(Mandatory = $False,Position=3)]
  $viSession
)
$start = Get-Date

$InfluxStruct = New-Object -TypeName PSObject -Property @{
  Store = $Datacenter
  CurlPath = 'C:\Servutls\curl.exe';
  InfluxDbServer = 'metrics-data.monitoring.nonprod.aws.cloud.nordstrom.net'; #IP Address
  InfluxDbPort = 8086;
  InfluxDbName = 'unified_computing_group';
  InfluxDbUser = 'anonymous'; #write a better method than this for prod
  InfluxDbPassword = 'anonymous'; #write a better method than this for prod
  InfluxDbCred = ""
  InfluxDbUri = ""
  MetricsString = '' #emtpy string that we populate later.
  
}

$InfluxStruct.InfluxDbCred = "$($InfluxStruct.InfluxDbUser):$($InfluxStruct.InfluxDbPassword)" #should place this into the InfluxStruct
$InfluxStruct.InfluxDbUri = "http://$($InfluxStruct.InfluxDbServer):$($InfluxStruct.InfluxDbPort)/write?db=$($InfluxStruct.InfluxDbName)"
$ReadyMaxAllowed = .20  #acceptable %ready time per vCPU.  Typical max is .10 to .20.
$VmStatTypes = 'cpu.usage.average','cpu.ready.summation','mem.usage.average','net.usage.average','virtualdisk.write.average','virtualdisk.read.average','virtualdisk.totalreadlatency.average','virtualdisk.totalwritelatency.average'

$outNull = Connect-VIServer -Server $vCenter -Session $viSession -WarningAction SilentlyContinue | Out-Null
$VMImpl = Get-Datacenter -Name $Datacenter | Get-VM | ?{$_.PowerState -eq "PoweredOn"}

Get-Stat -Entity $VMImpl -Stat $VMStatTypes -Realtime -MaxSamples 1 | `
  Group-Object -Property Entity,Instance | `
  %{
    $InfluxStruct.MetricsString += $_.Group | %{ 
      $instance = $(If($_.Instance){$_.Instance}Else{"0"})
      $cluster = $(If($_.Entity.VMHost.Parent){$_.Entity.VMHost.Parent}Else{"0"})
      $measurement = $(If($_.MetricId){$_.MetricId}Else{"0"})
      $value = $(If($_.Value){$_.Value}Else{"0"})
      $interval = $(If($_.IntervalSecs){$_.IntervalSecs}Else{"0"})
      $Unit = $(If($_.Unit) {$_.Unit} Else {"0"})
      $numcpu = $_.Entity.ExtensionData.Config.Hardware.NumCPU
      $memorygb = $_.Entity.ExtensionData.Config.Hardware.MemoryMB/1KB
      
      [int64]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date "1/1/1970")).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch
      
      If($_.MetricId -eq 'cpu.ready.summation') {
        $ready = [math]::Round($(($_.Value / ($_.IntervalSecs * 1000)) * 100), 2)
        $value = $(If($ready){$ready}Else{"0"})
        $EffectiveReadyMaxAllowed = $numcpu * $ReadyMaxAllowed
        $rdyhealth = $numcpu * $ReadyMaxAllowed - $ready
#        If($rdyhealth){
#          $measurement = 'cpu.ready.health.derived'
#          $value = $rdyhealth
#        } #end If-$rdyHealth
      } #end If-MetricId
      
      ("$($measurement),host=$($_.Entity.Name),store=$($Datacenter),type=VM,cluster=$($cluster.Name),instance=$($instance),unit=$($Unit),interval=$($interval),numcpu=$($numcpu),memorygb=$($memorygb) value=$($value) $($timestamp)" + "`n")
      
    } #end MetricString loop 
  } #end group-object loop

return $InfluxStruct