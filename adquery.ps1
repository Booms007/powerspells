# from BloodHoundOLD
function Convert-LDAPProperty {
<#
    .SYNOPSIS
        Helper that converts specific LDAP property result fields.
        Used by several of the Get-Net* function.
    .PARAMETER Properties
        Properties object to extract out LDAP fields for display.
#>
    param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [ValidateNotNullOrEmpty()]
        $Properties
    )

    $ObjectProperties = @{}

    $Properties.PropertyNames | ForEach-Object {
        if (($_ -eq "objectsid") -or ($_ -eq "sidhistory")) {
            # convert the SID to a string
            $ObjectProperties[$_] = (New-Object System.Security.Principal.SecurityIdentifier($Properties[$_][0],0)).Value
        }
        elseif($_ -eq "objectguid") {
            # convert the GUID to a string
            $ObjectProperties[$_] = (New-Object Guid (,$Properties[$_][0])).Guid
        }
        elseif( ($_ -eq "lastlogon") -or ($_ -eq "lastlogontimestamp") -or ($_ -eq "pwdlastset") -or ($_ -eq "lastlogoff") -or ($_ -eq "badPasswordTime") ) {
            # convert timestamps
            if ($Properties[$_][0] -is [System.MarshalByRefObject]) {
                # if we have a System.__ComObject
                $Temp = $Properties[$_][0]
                [Int32]$High = $Temp.GetType().InvokeMember("HighPart", [System.Reflection.BindingFlags]::GetProperty, $null, $Temp, $null)
                [Int32]$Low  = $Temp.GetType().InvokeMember("LowPart",  [System.Reflection.BindingFlags]::GetProperty, $null, $Temp, $null)
                $ObjectProperties[$_] = ([datetime]::FromFileTime([Int64]("0x{0:x8}{1:x8}" -f $High, $Low)))
            }
            else {
                $ObjectProperties[$_] = ([datetime]::FromFileTime(($Properties[$_][0])))
            }
        }
        elseif($Properties[$_][0] -is [System.MarshalByRefObject]) {
            # try to convert misc com objects
            $Prop = $Properties[$_]
            try {
                $Temp = $Prop[$_][0]
                Write-Verbose $_
                [Int32]$High = $Temp.GetType().InvokeMember("HighPart", [System.Reflection.BindingFlags]::GetProperty, $null, $Temp, $null)
                [Int32]$Low  = $Temp.GetType().InvokeMember("LowPart",  [System.Reflection.BindingFlags]::GetProperty, $null, $Temp, $null)
                $ObjectProperties[$_] = [Int64]("0x{0:x8}{1:x8}" -f $High, $Low)
            }
            catch {
                $ObjectProperties[$_] = $Prop[$_]
            }
        }
        elseif($Properties[$_].count -eq 1) {
            $ObjectProperties[$_] = $Properties[$_][0]
        }
        else {
            $ObjectProperties[$_] = $Properties[$_]
        }
    }

    New-Object -TypeName PSObject -Property $ObjectProperties
}



function AdQuery{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,mandatory=$true)]
        [string] $ldapflter,
        [Parameter(Position=1,mandatory=$false)]
        [string[]] $attributes=$null,
        [Parameter(Position=2,mandatory=$false)]
        [string] $searchRoot=$null,
        [Parameter(Position=3,mandatory=$false)]
        [string] $serverTimeLimit=600l

    )
    $searcher=[adsisearcher]""
    if ($searchRoot -ne $null){
        $searcher.SearchRoot=$searchRoot
    }
    $searcher.Filter=$ldapflter
    $searcher.PageSize=200
    $searcher.ServerTimeLimit=$serverTimeLimit
    $searcher

}

function FindActiveComputers($osversion="Windows 7*"){
    
    $d=(Get-Date).AddDays(-30)
    $ldapfilter="(&(objectClass=computer)(operatingSystem=$($osversion))(lastLogon>=$($d.ToFileTime())))"
    (AdQuery -ldapflter $ldapfilter).FindAll() | % {$_.Properties | Convert-LDAPProperty }
}

function FindVeryActiveComputers($osversion="Windows 7*"){
    
    $d=(Get-Date).AddHours(-8)
    $ldapfilter="(&(objectClass=computer)(operatingSystem=$($osversion))(lastLogon>=$($d.ToFileTime())))"
    (AdQuery -ldapflter $ldapfilter).FindAll() | % {$_.Properties | Convert-LDAPProperty }
}

function OneObject($ldapfilter){
    (AdQuery -ldapflter $ldapfilter).FindOne() | % {$_.Properties | Convert-LDAPProperty }|fl
}