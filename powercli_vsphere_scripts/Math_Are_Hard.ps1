
cls
#prep
Connect-VIServer -Server a0319p10133
$cl = Get-View -ViewType ClusterComputeResource -Filter @{"name"="cl0319ora12t001"}


#Future Resource Capacity
$numNewNodes = 2
$future_physicalCores_perNode = 0
$future_physicalMemGB_perNode = 0

$future_physicalCores = $future_physicalCores_perNode * $numNewNodes
$future_physicalMem = ($future_physicalMemGB_perNode * 1073741824) * $numNewNodes


#HA Percent/Factors
$totalHostCount = $cl.Host.Count + $numNewNodes
  #N+1
  $n1_percent = [Math]::Ceiling((1/$totalHostCount)*100)
  $n1_factor = $n1_percent/100
  #N+2
  $n2_percent = [Math]::Ceiling((2/$totalHostCount)*100)
  $n2_factor = $n2_percent/100


#Usable Resources

$cluster_numCores = ($cl.Summary.NumCpuCores + $future_physicalCores)
$cluster_numMem = ($cl.Summary.TotalMemory + $future_physicalMem)

$cpuOverCommit_factor = 4
$n1_real_Cpu = [Math]::Floor($cluster_numCores - ($cluster_numCores*$n1_factor))
$n2_real_Cpu = [Math]::Floor($cluster_numCores - ($cluster_numCores*$n2_factor))
$n1_usableCPU = ([Math]::Floor($cluster_numCores - ($cluster_numCores*$n1_factor))*$cpuOverCommit_factor)
$n2_usableCPU = ([Math]::Floor($cluster_numCores - ($cluster_numCoress*$n2_factor))*$cpuOverCommit_factor)

$n1_usableMemGB = [Math]::Floor(($cluster_numMem - ($cluster_numMem*$n1_factor))/1073741824)
$n2_usableMemGB = [Math]::Floor(($cluster_numMem - ($cluster_numMem*$n2_factor))/1073741824)



#VM Usage
$vms = Get-VIObjectByVIView -MORef $cl.MoRef | Get-VM | Get-View
$vmUsedCPU = [Math]::Ceiling(($vms.Config.Hardware.numCpu | Measure-Object -Sum).Sum)
$vmUsedMemGB = [Math]::Ceiling(($vms.Config.Hardware.MemoryMB | Measure-Object -Sum).Sum/1024)

#Future Resources Usage Increases
$vmUsedCPU += 0
$vmUsedMemGB += 48

#If($totalHostCount -le 4){
  #Use N+1
  $n1_cpuUsed_percent = [Math]::Ceiling(($vmUsedCPU/$n1_usableCPU)*100)
  $n1_memUsed_percent = [Math]::Ceiling(($vmUsedMemGB/$n1_usableMemGB)*100)
  
#}Else{
  #Use N+2
  $n2_cpuUsed_percent = [Math]::Ceiling(($vmUsedCPU/$n2_usableCPU)*100)
  $n2_memUsed_percent = [Math]::Ceiling(($vmUsedMemGB/$n2_usableMemGB)*100)
#}


#Calculate Actual Overcommitment
$n1_actual_CPU_oc = $vmUsedCPU/$n1_real_Cpu
$n2_actual_CPU_oc = $vmUsedCPU/$n2_real_Cpu

$n1_actual_Mem_oc = $vmUsedMemGB/$n1_usableMemGB
$n2_actual_Mem_oc = $vmUsedMemGB/$n2_usableMemGB



