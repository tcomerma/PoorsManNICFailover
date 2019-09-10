#requires -version 2
<#
.SYNOPSIS
  Permet el failover entre 2 NICS

.DESCRIPTION
    En Windows 10 no hi ha teaming. Intel té un driver que teòricament ho resol, però després
    de moltes proves, no hem aconseguit fer-ho funcionar de forma estable. Com que hem de posar
    les màquines en producció, aquest script de merda permet fer una xapussa per sortir del pas.

    Bàsicament la idea és tenir una tasca programada que executa aquest script que verifica si la 
    tarja activa té link, i en cas de que no en tingui, l'script
    - Desactiva el NIC
    - El desconfigura
    - Activa la segona tarja
    - La configura

.PARAMETER ConfigScript
    Fitxer amb la configuració de xarxa

.INPUTS
    none

.OUTPUTS
    None

.NOTES
  Version:        1.0
  Author:         Toni Comerma
  Creation Date:  6 de setembre de 2019
  Purpose/Change: Versió inicial
  
  TODO

    - Verificar el funcionament amb Windows en altres idiomes
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
#$ErrorActionPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

$sRootPath = "C:\Users\adm_tcp\Scripts\PoorsManNICFailover"

#Dot Source required Function Libraries
. "$sRootPath\Logging_Functions.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "1.0"

#Log File Info
$sLogPath = $sRootPath
$sLogName = "PoorsManNICFailover.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

# Config File
$ConfigFile = Join-Path -Path $sLogPath -ChildPath "PoorsManNICFailover.json"

#-----------------------------------------------------------[Functions]------------------------------------------------------------



Function ReadConfig{
  Param([string]$File)
  
  $cfg = Get-Content -Path $File | Out-String | ConvertFrom-Json
  $cfg
}

Function GetNIC{
   Param([string]$Name)
   Get-NetAdapter -Name $Name
}

Function DisableNIC{
   Param($NIC, $Config)
   try {
      Remove-NetIPAddress -IPAddress $Config.IP -Confirm:$false
      Remove-NetRoute -InterfaceAlias $NIC.ifAlias -NextHop $Config.Gateway -Confirm:$false
   }
   catch {
      Log-Write -LogPath $sLogFile -LineValue "Problema eliminant config de $($NIC.Name). Continuem..."
   }

   Disable-NetAdapter -Name $NIC.Name -Confirm:$false
}

Function EnableNIC{
   Param($NIC, $Config)

   Enable-NetAdapter -Name $NIC.Name 
   # Esperar a que adaptador Actiu. Si no falla
   For ($i=0; $i -le 10; $i++) {
     $status = Get-NetAdapter -Name $NIC.Name | Select-Object -Property "Status"
     if ($status -ne "Disabled") {
        break
     } else {
        Start-Sleep -Seconds 1
     }

   }
   New-NetIPAddress –InterfaceAlias $NIC.ifAlias –IPAddress $Config.IP –PrefixLength $Config.Prefix -DefaultGateway $Config.Gateway | Out-Null

}

#-----------------------------------------------------------[Execution]------------------------------------------------------------


Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
#Script Execution goes here

$Config = ReadConfig -File $ConfigFile

$NICMaster = GetNIC -Name $Config.NICMaster
$NICBackup = GetNIC -Name $Config.NICBackup

# Si NIC Master OK -> sortir
if ($NICMaster.Status -eq "Up") {
    Log-Write -LogPath $sLogFile -LineValue "$($Config.NICMaster) OK. No s'han fet canvis"
    Log-Finish -LogPath $sLogFile
} 

# Si NIC Backup OK -> Sortir
if ($NICBackup.Status -eq "Up") {
    Log-Write -LogPath $sLogFile -LineValue "$($Config.NICBackup) OK, $($Config.NICMaster) KO. No s'han fet canvis"
    Log-Finish -LogPath $sLogFile
} 

# Si NIC Backup Deshabilitada
  # Aturar Master
  # Engegar Backup
  # Sortir
if ($NICMaster.Status -eq "Disabled") {
   DisableNIC -NIC $NICBackup -Config $Config.NICConfig
   EnableNIC -NIC $NICMaster -Config $Config.NICConfig
   Log-Write -LogPath $sLogFile -LineValue "Canviant Configuració: Activada $($Config.NICMaster) amb èxit"
   Log-Finish -LogPath $sLogFile
} 

# Si NIC Master Deshabilitada
  # Aturar Backup
  # Engegar Master
  # Sortir
if ($NICBackup.Status -eq "Disabled") {
   DisableNIC -NIC $NICMaster -Config $Config.NICConfig
   EnableNIC -NIC $NICBackup -Config $Config.NICConfig
   Log-Write -LogPath $sLogFile -LineValue "Canviant Configuració: Activada $($Config.NICBackup) amb èxit"
   Log-Finish -LogPath $sLogFile
} 


Log-Write -LogPath $sLogFile -LineValue "ERROR: No hariem d'haver arribat aquí."
Log-Finish -LogPath $sLogFile
