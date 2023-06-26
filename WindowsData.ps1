

# Check location
if ( $($args.Count) -ne 1 )
{
 write-host " "
 $thisscript = $MyInvocation.MyCommand.Name
 write-host "usage: $thisscript [location]"
 write-host " "
 write-host "Source or Target to be provided as location as per the environment where the script is executed."
 write-host
 exit 10
}

$location = $args[0]
$ofname="`uname -n`_$location.json"



# Create objects
$objCOMPUTERSYSTEM = Get-WmiObject -Class Win32_ComputerSystem
$objOPERATINGSYSTEM = Get-WMIObject -Class win32_operatingsystem

# Hostname and OS details
$optxt = "{"
$hname = $objCOMPUTERSYSTEM.Name
$ofname=$hname + "_" + $location + ".json"
$optxt += """hostname""" + ":" + """$hname""" + ","
$hos = $objOPERATINGSYSTEM.caption
$optxt += """Operating System""" + ":" + """$hos""" + ","
$osver = $objOPERATINGSYSTEM.version
$optxt += """Version Number""" + ":" + """$osver""" + ","
$sermajor = $objOPERATINGSYSTEM.Servicepackmajorversion
$serminor = $objOPERATINGSYSTEM.Servicepackminorversion
$serpack = "$sermajor.$serminor"
$optxt += """Service Pack""" + ":" + """$serpack""" + ","

<#
# Patching details
$optxt += """Patch Details""" + ":["
$hfcnt=0
foreach ( $aa in (get-wmiobject -class win32_quickfixengineering | select hotfixid, description, installedOn) )
{ $hfcnt++ }
$hotcnt = 1
foreach ( $aa in (get-wmiobject -class win32_quickfixengineering | select hotfixid, description, installedOn) )
{ 
  $hfid = $aa.hotfixid
  $optxt += "{" + """HotfixID""" + ":" + """$hfid""" + ","
  $hfdes = $aa.description
  $optxt += """Description""" + ":" + """$hfdes""" + ","
  $hfinsdt = $aa.installedOn
  $optxt += """Installed On""" + ":" + """$hfinsdt""" + "}"
  if ($hotcnt -ne $hfcnt ) { $optxt += ","; $hotcnt++ }
  }
$optxt += "],"
#>

# Domain, OU and applied group policy details
$domain = $objCOMPUTERSYSTEM.domain
$optxt += """Domain""" + ":" + """$domain""" + ","
$domainpart = $objCOMPUTERSYSTEM.partofdomain
$optxt += """Part of Domain""" + ":" + """$domainpart""" + ","

$optxt += """Domain OU""" + ":["
$dmcnt=0

<#
try 
{
Add-WindowsFeature RSAT-AD-PowerShell | out-null
$adou = Get-ADOrganizationalUnit -Filter 'Name -like "*"' | Select Name, DistinguishedName
foreach ( $aa in $adou )
{ $dmcnt++ }
$domcnt = 1
foreach ( $aa in $adou )
{ 
  $domname = $aa.Name
  $optxt += "{" + """Name""" + ":" + """$domname""" + ","
  $disname = $aa.DistinguishedName
  $optxt += """Distinguished Name""" + ":" + """$disname""" + "}"
  if ($domcnt -ne $dmcnt ) { $optxt += ","; $domcnt++ }
  }
}
catch
{
 $errmsg = $_ ; $optxt += """$errmsg"""
}
$optxt += "],"

$grpoli = gpresult /scope computer -v | select-string -Pattern "Group Policy was applied from" 
$grpol = $grpoli -split ":"
$grpolicy = $grpol[1]
$optxt += """Applied group policy""" + ":" + """$grpolicy""" + ","
#>

# Ipconfig and persistent route details
$ipconf = ipconfig /all
$ipcnt = $ipconf.count 
$optxt += """ipconfig""" + ":["
$icnt = 1
foreach ( $ii in $ipconf )
{ 
  if ( [string]::IsNullOrEmpty($ii) )
  { }
  else 
  { $optxt += """$ii"""
    if ($icnt -ne $ipcnt ) 
    { $optxt += "," } 
  }
  $icnt++ 
}
$optxt += "],"  

$nxhop = (Get-WmiObject -Class Win32_IP4RouteTable)[0].NextHop
$optxt += """Persistent Route""" + ":" + """$nxhop""" + ","

# $rtcnt=0
# foreach ( $aa in (Get-NetRoute -PolicyStore persistentstore) )
# { $rtcnt++ }

# $rotcnt = 1
# foreach ( $aa in (Get-NetRoute -PolicyStore persistentstore) )
# { 
  # $ifalias = $aa.InterfaceAlias
  # $optxt += "{" + """InterfaceAlias""" + ":" + """$ifalias""" + ","
  # $nxhop = $aa.NextHop	
  # $optxt += """Next hop""" + ":" + """$nxhop""" + "}"
  # if ($rtcnt -ne $rotcnt ) { $optxt += ","; $rotcnt++ }
  # }
#$optxt += "],"

<#
# Active port details  
$optxt += """Active Ports""" + ":["

$locports = @()
$locports += netstat -ano | select-string -pattern 'established'
$locports += netstat -ano | select-string -pattern 'Listening'

$ptcnt = $locports.count
$potcnt = 1

foreach ($port in $locports)
{ 
  $abc = $port -split " "
  $wcnt = 0
  foreach ( $a in $abc )
  { 
    if ( [string]::IsNullOrEmpty($a) ) {}
	else
	{
	  $wcnt++
	  if ( $wcnt -eq 2 ) { $locport = $a }
	  if ( $wcnt -eq 4 ) { $portstate = $a }
	
	}
  }
#$optxt += """$locport""" + ":" + """$portstate"""
$optxt += "{" + """Port""" + ":" + """$locport""" + ","
$optxt += """State""" + ":" + """$portstate""" + "}"
if ($ptcnt -ne $potcnt ) { $optxt += "," }
$potcnt++
}
  
$optxt += "],"
#>

# OS activation detail
$actcode = (Get-WmiObject -Class SoftwareLicensingProduct | where {$_.PartialProductKey}).LicenseStatus
switch($actcode)
{
  0 {  $actstat = "Unlicensed" }
  1 {  $actstat = "Licensed" }
  2 {  $actstat = "OOBGrace" }
  3 {  $actstat = "OOTFrace" }
  4 {  $actstat = "NonGenuineGrace" }
  5 {  $actstat = "Notification" }
  6 {  $actstat = "ExtendedGrace" }
}
$optxt += """Windows Activation status""" + ":" + """$actstat""" + ","

# Automatically started services
$optxt += """Autostart services""" + ":["
$srcnt=0
foreach ( $aa in ((Get-WmiObject -Query "Select Name From Win32_Service Where Startmode='Auto'").Name) )
{ $srcnt++ }

$srtcnt = 1
foreach ( $aa in ((Get-WmiObject -Query "Select Name From Win32_Service Where Startmode='Auto'").Name) )
{ 
  $optxt += """$aa"""
  if ($srcnt -ne $srtcnt ) { $optxt += ","; $srtcnt++ }
  }
$optxt += "],"

# Cluster service check
$clustervar = Get-Service -DisplayName 'Microsoft Cluster Service' -erroraction silentlycontinue
if ( "$?" -eq 'False' )
{ $optxt += """Cluster Services""" + ":" + """Service not found""" + "," }
else 
{ 
  $clustervar = (Get-Service -DisplayName 'Microsoft Cluster Service').status
  $optxt += """Cluster Services""" + ":" + """$clustervar""" + "," }

# Service account enabled service details  
$winserlist = Get-WmiObject Win32_Service -filter 'STARTNAME LIKE "%Local%"' | select -property Name, StartName, StartMode, State
$winserlist += Get-WmiObject Win32_Service -filter 'STARTNAME LIKE "%Network%"' | select -property Name, StartName, StartMode, State

$optxt += """Services started by service accounts""" + ":[" 

$sercnt=0
foreach ( $aa in $winserlist )
{ $sercnt++ }

$srvcnt = 1
foreach ( $aa in $winserlist )
{ 
  $sername = $aa.Name ; $startedby = $aa.startname ; $startmode = $aa.Startmode ; $stat = $aa.State
  $optxt += "{" + """Service""" + ":" + """$sername""" + ","
  $optxt += """Startedby""" + ":" + """$startedby""" + ","
  $optxt += """StartMode""" + ":" + """$startmode""" + ","
  $optxt += """State""" + ":" + """$stat""" + "}"
  if ($sercnt -ne $srvcnt ) { $optxt += ","; $srvcnt++ }
  }
$optxt += "],"

# Local disk details
$optxt += """Local disk details""" + ":[" 
$diskinfo = (Get-WmiObject -Class Win32_logicaldisk | select drivetype, deviceid, size, freespace )

$localdisk = @()
foreach ( $xx in $diskinfo )
{ if ( $xx.drivetype -eq 3 ) { $localdisk += $xx } }

$dkcnt = $localdisk.count
$dskcnt = 1
foreach ( $aa in $localdisk )
{ 
     $drid = $aa.deviceid ; $drs = $aa.size ; $drf = $aa.freespace
	 $drsize = [math]::round($drs/1gb,1) 
     $drfree = [math]::round($drf/1gb,1)
	 $drused = $drsize - $drfree
	 $optxt += "{" + """Drive""" + ":" + """$drid""" + ","
	 $optxt += """Used""" + ":" + """$drused GB""" + ","
	 $optxt += """Free""" + ":" + """$drfree GB""" + ","
	 $optxt += """Size""" + ":" + """$drsize GB""" + "}"
	 if ($dskcnt -ne $dkcnt ) { $optxt += "," }
  
  $dskcnt++  
}

$optxt += "]"

$optxt += "}"
$opttxt = $optxt.replace('\','\\')
$opttxt | set-content $ofname

