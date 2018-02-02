Param(
  $vcenter,
  $VM)

Connect-VIServer -Server $vCenter
$VM = Get-VM -Name $VM

(Get-AdvancedSetting -Entity $VM | ?{ $_.Value -like "*multi-writer*"}).Name

Disconnect-VIServer * -ErrorAction SilentlyContinue