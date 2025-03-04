# Helpers
function Get-OutFileForParam
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$OutputDirectory,
        [Parameter(Mandatory=$false)]
        [string]$FileName,
        [Parameter(Mandatory=$false)]
        [switch]$StdOut
    )

    $ErrorActionPreference = "Stop"
    if (-not $PSBoundParameters.ContainsKey("Verbose")) { $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference") }

    if (-not $StdOut)
    {
        (Join-Path $OutputDirectory $FileName)
    }
    else
    {
        $null
    }
}
function Out-FileAndExcel
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$OutFile,
        [Parameter(Mandatory=$false)]
        [switch]$Excel
    )

    $ErrorActionPreference = "Stop"
    if (-not $PSBoundParameters.ContainsKey("Verbose")) { $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference") }

    if ($OutFile)
    {
        Write-Host "Data written to $($OutFile)"
        if ($Excel)
        {
            Open-CsvInExcel $OutFile
        }
    }
}
function Invoke-AuditLogMethod
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Appliance,
        [Parameter(Mandatory=$false)]
        [object]$AccessToken,
        [Parameter(Mandatory=$false)]
        [switch]$Insecure,
        [Parameter(Mandatory=$true, Position=0)]
        [string]$RelativeUrl,
        [Parameter(Mandatory=$true, Position=1)]
        [DateTime]$DayOnly,
        [Parameter(Mandatory=$true, Position=2)]
        [string]$Filter,
        [Parameter(Mandatory=$true, Position=3)]
        [string]$Fields,
        [Parameter(Mandatory=$false)]
        [string]$OutFile,
        [Parameter(Mandatory=$false)]
        [switch]$Excel
    )

    $ErrorActionPreference = "Stop"
    if (-not $PSBoundParameters.ContainsKey("Verbose")) { $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference") }

    $local:EndDate = ($DayOnly.AddDays(1))

    # Calling AuditLog with just an endDate returns a result using a startDate 24 hours before the specified endDate
    Import-Module -Name "$PSScriptRoot\sg-utilities.psm1" -Scope Local
    Invoke-SafeguardMethod -AccessToken $AccessToken -Appliance $Appliance -Insecure:$Insecure Core GET $RelativeUrl `
        -Accept "text/csv" -OutFile $local:OutFile `
        -Parameters @{
            endDate = (Format-DateTimeAsString $local:EndDate);
            filter = $Filter; fields = $Fields }

    Out-FileAndExcel -OutFile $local:OutFile -Excel:$Excel
}

<#
.SYNOPSIS
Get CSV report of accounts without passwords.

.DESCRIPTION
This cmdlet will generate CSV containing every account that has been added to Safeguard
that does not have a password stored in Safeguard.

This cmdlet will generate and save a CSV file by default.  This file can be opened
in Excel automatically using the -Excel parameter or the Open-CsvInExcel cmdlet.
You may alternatively send the CSV output to standard out.

.PARAMETER Appliance
IP address or hostname of a Safeguard appliance.

.PARAMETER AccessToken
A string containing the bearer token to be used with Safeguard Web API.

.PARAMETER Insecure
Ignore verification of Safeguard appliance SSL certificate.

.PARAMETER OutputDirectory
String containing the directory where to create the CSV file.

.PARAMETER Excel
Automatically open the CSV file into excel after it is generation.

.PARAMETER StdOut
Send CSV to standard out instead of generating a file.

.INPUTS
None.

.OUTPUTS
A CSV file or CSV text.

.EXAMPLE
Get-SafeguardReportAccountWithoutPassword -StdOut

.EXAMPLE
Get-SafeguardReportAccountWithoutPassword -OutputDirectory "C:\reports\" -Excel
#>
function Get-SafeguardReportAccountWithoutPassword
{
    [CmdletBinding(DefaultParameterSetName="File")]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Appliance,
        [Parameter(Mandatory=$false)]
        [object]$AccessToken,
        [Parameter(Mandatory=$false)]
        [switch]$Insecure,
        [Parameter(Mandatory=$false, ParameterSetName="File", Position=0)]
        [string]$OutputDirectory = (Get-Location),
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [switch]$Excel = $false,
        [Parameter(Mandatory=$false, ParameterSetName="StdOut")]
        [switch]$StdOut
    )

    $ErrorActionPreference = "Stop"
    if (-not $PSBoundParameters.ContainsKey("Verbose")) { $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference") }

    $local:OutFile = (Get-OutFileForParam -OutputDirectory $OutputDirectory -FileName "sg-accounts-wo-password-$((Get-Date).ToString("yyyyMMddTHHmmssZz")).csv" -StdOut:$StdOut)

    Invoke-SafeguardMethod -AccessToken $AccessToken -Appliance $Appliance -Insecure:$Insecure Core GET "PolicyAccounts" -Accept "text/csv" -OutFile $local:OutFile -Parameters @{
        filter = "HasPassword eq false";
        fields = ("SystemId,Id,SystemName,Name,DomainName,SystemNetworkAddress,HasPassword,Disabled,AllowPasswordRequest,AllowSessionRequest," + `
            "PlatformDisplayName") }

    Out-FileAndExcel -OutFile $local:OutFile -Excel:$Excel
}

<#
.SYNOPSIS
Get CSV report of access requests for a given date (24 hour period).

.DESCRIPTION
This cmdlet will generate CSV containing every instance of access requests that either
released a password or initialized a session during a 24 hour period.  Dates in Safeguard
are UTC, but this cmdlet will use the local time for the 24 hour period.

This cmdlet will generate and save a CSV file by default.  This file can be opened
in Excel automatically using the -Excel parameter or the Open-CsvInExcel cmdlet.
You may alternatively send the CSV output to standard out.

.PARAMETER Appliance
IP address or hostname of a Safeguard appliance.

.PARAMETER AccessToken
A string containing the bearer token to be used with Safeguard Web API.

.PARAMETER Insecure
Ignore verification of Safeguard appliance SSL certificate.

.PARAMETER OutputDirectory
String containing the directory where to create the CSV file.

.PARAMETER Excel
Automatically open the CSV file into excel after it is generation.

.PARAMETER StdOut
Send CSV to standard out instead of generating a file.

.PARAMETER LocalDate
The date for which to run the report (Default is today).  Ex. "2019-02-14".

.INPUTS
None.

.OUTPUTS
A CSV file or CSV text.

.EXAMPLE
Get-SafeguardReportDailyAccessRequest -StdOut

.EXAMPLE
Get-SafeguardReportDailyAccessRequest -OutputDirectory "C:\reports\" -Excel

.EXAMPLE
Get-SafeguardReportDailyAccessRequest -LocalDate "2019-02-22" -Excel
#>
function Get-SafeguardReportDailyAccessRequest
{
    [CmdletBinding(DefaultParameterSetName="File")]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Appliance,
        [Parameter(Mandatory=$false)]
        [object]$AccessToken,
        [Parameter(Mandatory=$false)]
        [switch]$Insecure,
        [Parameter(Mandatory=$false, ParameterSetName="File", Position=0)]
        [string]$OutputDirectory = (Get-Location),
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [switch]$Excel = $false,
        [Parameter(Mandatory=$false, ParameterSetName="StdOut")]
        [switch]$StdOut,
        [Parameter(Mandatory=$false)]
        [DateTime]$LocalDate = (Get-Date)
    )

    $ErrorActionPreference = "Stop"
    if (-not $PSBoundParameters.ContainsKey("Verbose")) { $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference") }

    $local:DayOnly = (New-Object "System.DateTime" -ArgumentList $LocalDate.Year, $LocalDate.Month, $LocalDate.Day)
    $local:OutFile = (Get-OutFileForParam -OutputDirectory $OutputDirectory -FileName "sg-daily-access-request-$(($local:DayOnly).ToString("yyyy-MM-dd")).csv" -StdOut:$StdOut)

    Invoke-AuditLogMethod -AccessToken $AccessToken -Appliance $Appliance -Insecure:$Insecure "AuditLog/AccessRequests/Activities" $local:DayOnly `
        "Action eq 'CheckOutPassword' or Action eq 'InitializeSession'" `
        ("LogTime,RequestId,RequesterId,RequesterName,SystemId,AccountId,SystemName,AccountName,AccountDomainName,AccessRequestType,Action," + `
        "SessionId,ApplianceId,ApplianceName") `
        -OutFile $local:OutFile -Excel:$Excel
}

<#
.SYNOPSIS
Get CSV report of password check failures for a given date (24 hour period).

.DESCRIPTION
This cmdlet will generate CSV containing every instance of password check
failures for a 24 hour period.  Dates in Safeguard are UTC, but this cmdlet
will use the local time for the 24 hour period.

This cmdlet will generate and save a CSV file by default.  This file can be opened
in Excel automatically using the -Excel parameter or the Open-CsvInExcel cmdlet.
You may alternatively send the CSV output to standard out.

.PARAMETER Appliance
IP address or hostname of a Safeguard appliance.

.PARAMETER AccessToken
A string containing the bearer token to be used with Safeguard Web API.

.PARAMETER Insecure
Ignore verification of Safeguard appliance SSL certificate.

.PARAMETER OutputDirectory
String containing the directory where to create the CSV file.

.PARAMETER Excel
Automatically open the CSV file into excel after it is generation.

.PARAMETER StdOut
Send CSV to standard out instead of generating a file.

.PARAMETER LocalDate
The date for which to run the report (Default is today).  Ex. "2019-02-14".

.INPUTS
None.

.OUTPUTS
A CSV file or CSV text.

.EXAMPLE
Get-SafeguardReportDailyPasswordCheckFail -StdOut

.EXAMPLE
Get-SafeguardReportDailyPasswordCheckFail -OutputDirectory "C:\reports\" -Excel

.EXAMPLE
Get-SafeguardReportDailyPasswordCheckFail -LocalDate "2019-02-22" -Excel
#>
function Get-SafeguardReportDailyPasswordCheckFail
{
    [CmdletBinding(DefaultParameterSetName="File")]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Appliance,
        [Parameter(Mandatory=$false)]
        [object]$AccessToken,
        [Parameter(Mandatory=$false)]
        [switch]$Insecure,
        [Parameter(Mandatory=$false, ParameterSetName="File", Position=0)]
        [string]$OutputDirectory = (Get-Location),
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [switch]$Excel = $false,
        [Parameter(Mandatory=$false, ParameterSetName="StdOut")]
        [switch]$StdOut,
        [Parameter(Mandatory=$false)]
        [DateTime]$LocalDate = (Get-Date)
    )

    $ErrorActionPreference = "Stop"
    if (-not $PSBoundParameters.ContainsKey("Verbose")) { $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference") }

    $local:DayOnly = (New-Object "System.DateTime" -ArgumentList $LocalDate.Year, $LocalDate.Month, $LocalDate.Day)
    $local:OutFile = (Get-OutFileForParam -OutputDirectory $OutputDirectory -FileName "sg-daily-pwcheck-fail-$(($local:DayOnly).ToString("yyyy-MM-dd")).csv" -StdOut:$StdOut)

    Invoke-AuditLogMethod -AccessToken $AccessToken -Appliance $Appliance -Insecure:$Insecure "AuditLog/Passwords/CheckPassword" $local:DayOnly `
        "EventName eq 'PasswordCheckFailed'" `
        ("LogTime,SystemId,AccountId,SystemName,AccountName,AccountDomainName,NetworkAddress,PlatformDisplayName,EventName," + `
        "RequestStatus.Message,AssetPartitionId,AssetPartitionName,ProfileId,ProfileName,SyncGroupId,SyncGroupName,ApplianceId,ApplianceName") `
        -OutFile $local:OutFile -Excel:$Excel
}

<#
.SYNOPSIS
Get CSV report of successful password checks for a given date (24 hour period).

.DESCRIPTION
This cmdlet will generate CSV containing every instance of password checks that
succeeded for a 24 hour period.  Dates in Safeguard are UTC, but this cmdlet
will use the local time for the 24 hour period.

This cmdlet will generate and save a CSV file by default.  This file can be opened
in Excel automatically using the -Excel parameter or the Open-CsvInExcel cmdlet.
You may alternatively send the CSV output to standard out.

.PARAMETER Appliance
IP address or hostname of a Safeguard appliance.

.PARAMETER AccessToken
A string containing the bearer token to be used with Safeguard Web API.

.PARAMETER Insecure
Ignore verification of Safeguard appliance SSL certificate.

.PARAMETER OutputDirectory
String containing the directory where to create the CSV file.

.PARAMETER Excel
Automatically open the CSV file into excel after it is generation.

.PARAMETER StdOut
Send CSV to standard out instead of generating a file.

.PARAMETER LocalDate
The date for which to run the report (Default is today).  Ex. "2019-02-14".

.INPUTS
None.

.OUTPUTS
A CSV file or CSV text.

.EXAMPLE
Get-SafeguardReportDailyPasswordCheckSuccess -StdOut

.EXAMPLE
Get-SafeguardReportDailyPasswordCheckSuccess -OutputDirectory "C:\reports\" -Excel

.EXAMPLE
Get-SafeguardReportDailyPasswordCheckSuccess -LocalDate "2019-02-22" -Excel
#>
function Get-SafeguardReportDailyPasswordCheckSuccess
{
    [CmdletBinding(DefaultParameterSetName="File")]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Appliance,
        [Parameter(Mandatory=$false)]
        [object]$AccessToken,
        [Parameter(Mandatory=$false)]
        [switch]$Insecure,
        [Parameter(Mandatory=$false, ParameterSetName="File", Position=0)]
        [string]$OutputDirectory = (Get-Location),
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [switch]$Excel = $false,
        [Parameter(Mandatory=$false, ParameterSetName="StdOut")]
        [switch]$StdOut,
        [Parameter(Mandatory=$false)]
        [DateTime]$LocalDate = (Get-Date)
    )

    $ErrorActionPreference = "Stop"
    if (-not $PSBoundParameters.ContainsKey("Verbose")) { $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference") }

    $local:DayOnly = (New-Object "System.DateTime" -ArgumentList $LocalDate.Year, $LocalDate.Month, $LocalDate.Day)
    $local:OutFile = (Get-OutFileForParam -OutputDirectory $OutputDirectory -FileName "sg-daily-pwcheck-success-$(($local:DayOnly).ToString("yyyy-MM-dd")).csv" -StdOut:$StdOut)

    Invoke-AuditLogMethod -AccessToken $AccessToken -Appliance $Appliance -Insecure:$Insecure "AuditLog/Passwords/CheckPassword" $local:DayOnly `
        "EventName eq 'PasswordCheckSucceeded'" `
        ("LogTime,SystemId,AccountId,SystemName,AccountName,AccountDomainName,NetworkAddress,PlatformDisplayName,EventName," + `
        "AssetPartitionId,AssetPartitionName,ProfileId,ProfileName,SyncGroupId,SyncGroupName,ApplianceId,ApplianceName") `
        -OutFile $local:OutFile -Excel:$Excel
}

<#
.SYNOPSIS
Get CSV report of password change failures for a given date (24 hour period).

.DESCRIPTION
This cmdlet will generate CSV containing every instance of password changes that
failed for a 24 hour period.  Dates in Safeguard are UTC, but this cmdlet
will use the local time for the 24 hour period.

This cmdlet will generate and save a CSV file by default.  This file can be opened
in Excel automatically using the -Excel parameter or the Open-CsvInExcel cmdlet.
You may alternatively send the CSV output to standard out.

.PARAMETER Appliance
IP address or hostname of a Safeguard appliance.

.PARAMETER AccessToken
A string containing the bearer token to be used with Safeguard Web API.

.PARAMETER Insecure
Ignore verification of Safeguard appliance SSL certificate.

.PARAMETER OutputDirectory
String containing the directory where to create the CSV file.

.PARAMETER Excel
Automatically open the CSV file into excel after it is generation.

.PARAMETER StdOut
Send CSV to standard out instead of generating a file.

.PARAMETER LocalDate
The date for which to run the report (Default is today).  Ex. "2019-02-14".

.INPUTS
None.

.OUTPUTS
A CSV file or CSV text.

.EXAMPLE
Get-SafeguardReportDailyPasswordChangeFail -StdOut

.EXAMPLE
Get-SafeguardReportDailyPasswordChangeFail -OutputDirectory "C:\reports\" -Excel

.EXAMPLE
Get-SafeguardReportDailyPasswordChangeFail -LocalDate "2019-02-22" -Excel
#>
function Get-SafeguardReportDailyPasswordChangeFail
{
    [CmdletBinding(DefaultParameterSetName="File")]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Appliance,
        [Parameter(Mandatory=$false)]
        [object]$AccessToken,
        [Parameter(Mandatory=$false)]
        [switch]$Insecure,
        [Parameter(Mandatory=$false, ParameterSetName="File", Position=0)]
        [string]$OutputDirectory = (Get-Location),
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [switch]$Excel = $false,
        [Parameter(Mandatory=$false, ParameterSetName="StdOut")]
        [switch]$StdOut,
        [Parameter(Mandatory=$false)]
        [DateTime]$LocalDate = (Get-Date)
    )

    $ErrorActionPreference = "Stop"
    if (-not $PSBoundParameters.ContainsKey("Verbose")) { $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference") }

    $local:DayOnly = (New-Object "System.DateTime" -ArgumentList $LocalDate.Year, $LocalDate.Month, $LocalDate.Day)
    $local:OutFile = (Get-OutFileForParam -OutputDirectory $OutputDirectory -FileName "sg-daily-pwchange-fail-$(($local:DayOnly).ToString("yyyy-MM-dd")).csv" -StdOut:$StdOut)

    Invoke-AuditLogMethod -AccessToken $AccessToken -Appliance $Appliance -Insecure:$Insecure "AuditLog/Passwords/ChangePassword" $local:DayOnly `
        "EventName eq 'PasswordChangeFailed'" `
        ("LogTime,SystemId,AccountId,SystemName,AccountName,AccountDomainName,NetworkAddress,PlatformDisplayName,EventName," + `
        "AssetPartitionId,AssetPartitionName,ProfileId,ProfileName,SyncGroupId,SyncGroupName,ApplianceId,ApplianceName") `
        -OutFile $local:OutFile -Excel:$Excel
}

<#
.SYNOPSIS
Get CSV report of successful password changes for a given date (24 hour period).

.DESCRIPTION
This cmdlet will generate CSV containing every instance of successful password changes
for a 24 hour period.  Dates in Safeguard are UTC, but this cmdlet
will use the local time for the 24 hour period.

This cmdlet will generate and save a CSV file by default.  This file can be opened
in Excel automatically using the -Excel parameter or the Open-CsvInExcel cmdlet.
You may alternatively send the CSV output to standard out.

.PARAMETER Appliance
IP address or hostname of a Safeguard appliance.

.PARAMETER AccessToken
A string containing the bearer token to be used with Safeguard Web API.

.PARAMETER Insecure
Ignore verification of Safeguard appliance SSL certificate.

.PARAMETER OutputDirectory
String containing the directory where to create the CSV file.

.PARAMETER Excel
Automatically open the CSV file into excel after it is generation.

.PARAMETER StdOut
Send CSV to standard out instead of generating a file.

.PARAMETER LocalDate
The date for which to run the report (Default is today).  Ex. "2019-02-14".

.INPUTS
None.

.OUTPUTS
A CSV file or CSV text.

.EXAMPLE
Get-SafeguardReportDailyPasswordChangeSuccess -StdOut

.EXAMPLE
Get-SafeguardReportDailyPasswordChangeSuccess -OutputDirectory "C:\reports\" -Excel

.EXAMPLE
Get-SafeguardReportDailyPasswordChangeSuccess -LocalDate "2019-02-22" -Excel
#>
function Get-SafeguardReportDailyPasswordChangeSuccess
{
    [CmdletBinding(DefaultParameterSetName="File")]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Appliance,
        [Parameter(Mandatory=$false)]
        [object]$AccessToken,
        [Parameter(Mandatory=$false)]
        [switch]$Insecure,
        [Parameter(Mandatory=$false, ParameterSetName="File", Position=0)]
        [string]$OutputDirectory = (Get-Location),
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [switch]$Excel = $false,
        [Parameter(Mandatory=$false, ParameterSetName="StdOut")]
        [switch]$StdOut,
        [Parameter(Mandatory=$false)]
        [DateTime]$LocalDate = (Get-Date)
    )

    $ErrorActionPreference = "Stop"
    if (-not $PSBoundParameters.ContainsKey("Verbose")) { $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference") }

    $local:DayOnly = (New-Object "System.DateTime" -ArgumentList $LocalDate.Year, $LocalDate.Month, $LocalDate.Day)
    $local:OutFile = (Get-OutFileForParam -OutputDirectory $OutputDirectory -FileName "sg-daily-pwchange-success-$(($local:DayOnly).ToString("yyyy-MM-dd")).csv" -StdOut:$StdOut)

    Invoke-AuditLogMethod -AccessToken $AccessToken -Appliance $Appliance -Insecure:$Insecure "AuditLog/Passwords/ChangePassword" $local:DayOnly `
        "EventName eq 'PasswordChangeSucceeded'" `
        ("LogTime,SystemId,AccountId,SystemName,AccountName,AccountDomainName,NetworkAddress,PlatformDisplayName,EventName," + `
        "AssetPartitionId,AssetPartitionName,ProfileId,ProfileName,SyncGroupId,SyncGroupName,ApplianceId,ApplianceName") `
        -OutFile $local:OutFile -Excel:$Excel
}

<#
.SYNOPSIS
Generates user entitlement report for a set of users in Safeguard via the Web API.

.DESCRIPTION
User entitlement report is a report of what accounts can be accessed by a set of users.

.PARAMETER Appliance
IP address or hostname of a Safeguard appliance.

.PARAMETER AccessToken
A string containing the bearer token to be used with Safeguard Web API.

.PARAMETER Insecure
Ignore verification of Safeguard appliance SSL certificate.

.PARAMETER UserList
An integer containing the ID of the access policy to get or a string containing the name.

.PARAMETER OutputDirectory
String containing the directory where to create the CSV file.

.PARAMETER Excel
Automatically open the CSV file into excel after it is generation.

.PARAMETER StdOut
Send CSV to standard out instead of generating a file.

.INPUTS
None.

.OUTPUTS
A CSV file or CSV text.

.EXAMPLE
Get-SafeguardReportUserEntitlement -AccessToken $token -Appliance 10.5.32.54 -Insecure

.EXAMPLE
Get-SafeguardReportUserEntitlement testUser1,testUser2

.EXAMPLE
Get-SafeguardReportUserEntitlement 123
#>
function Get-SafeguardReportUserEntitlement
{
    [CmdletBinding(DefaultParameterSetName="File")]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Appliance,
        [Parameter(Mandatory=$false)]
        [object]$AccessToken,
        [Parameter(Mandatory=$false)]
        [switch]$Insecure,
        [Parameter(Mandatory=$false,Position=0)]
        [object[]]$UserList,
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [string]$OutputDirectory = (Get-Location),
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [switch]$Excel = $false,
        [Parameter(Mandatory=$false, ParameterSetName="StdOut")]
        [switch]$StdOut
    )

    $ErrorActionPreference = "Stop"
    if (-not $PSBoundParameters.ContainsKey("Verbose")) { $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference") }

    Import-Module -Name "$PSScriptRoot\sg-utilities.psm1" -Scope Local
    if (-not (Test-SafeguardMinVersionInternal -Appliance $Appliance -Insecure:$Insecure -MinVersion "2.7"))
    {
        throw "This cmdlet requires Safeguard version 2.7 or greater"
    }

    $local:OutFile = (Get-OutFileForParam -OutputDirectory $OutputDirectory -FileName "sg-user-entitlements-$((Get-Date).ToString("yyyy-MM-dd")).csv" -StdOut:$StdOut)

    if ($UserList)
    {
        [object[]]$local:Users = $null
        foreach ($local:User in $UserList)
        {
            $local:ResolvedUser = (Get-SafeguardUser -AccessToken $AccessToken -Appliance $Appliance -Insecure:$Insecure -UserToGet $User)
            $local:Users += $($local:ResolvedUser).Id
        }
        Invoke-SafeguardMethod -AccessToken $AccessToken -Appliance $Appliance -Insecure:$Insecure Core GET "Reports/Entitlements/UserEntitlements" `
            -Parameters @{ userIds = ($Users -join ",") } -Accept "text/csv" -OutFile $local:OutFile
    }
    else
    {
        Invoke-SafeguardMethod -AccessToken $AccessToken -Appliance $Appliance -Insecure:$Insecure Core GET "Reports/Entitlements/UserEntitlements" `
            -Accept "text/csv" -OutFile $local:OutFile
    }

    Out-FileAndExcel -OutFile $local:OutFile -Excel:$Excel
}

<#
.SYNOPSIS
Generates report of user group memberships for users in Safeguard via the Web API.

.DESCRIPTION
User membership report includes which users are in which groups along with
a few of the attributes of those users.

.PARAMETER Appliance
IP address or hostname of a Safeguard appliance.

.PARAMETER AccessToken
A string containing the bearer token to be used with Safeguard Web API.

.PARAMETER Insecure
Ignore verification of Safeguard appliance SSL certificate.

.PARAMETER OutputDirectory
String containing the directory where to create the CSV file.

.PARAMETER Excel
Automatically open the CSV file into excel after it is generation.

.PARAMETER StdOut
Send CSV to standard out instead of generating a file.

.INPUTS
None.

.OUTPUTS
A CSV file or CSV text.

.EXAMPLE
Get-SafeguardReportUserGroupMembership -Excel

.EXAMPLE
Get-SafeguardReportUserGroupMembership -StdOut
#>
function Get-SafeguardReportUserGroupMembership
{
    [CmdletBinding(DefaultParameterSetName="File")]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Appliance,
        [Parameter(Mandatory=$false)]
        [object]$AccessToken,
        [Parameter(Mandatory=$false)]
        [switch]$Insecure,
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [string]$OutputDirectory = (Get-Location),
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [switch]$Excel = $false,
        [Parameter(Mandatory=$false, ParameterSetName="StdOut")]
        [switch]$StdOut
    )

    $ErrorActionPreference = "Stop"
    if (-not $PSBoundParameters.ContainsKey("Verbose")) { $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference") }

    $local:Memberships = @()
    (Invoke-SafeguardMethod -AccessToken $AccessToken -Appliance $Appliance -Insecure:$Insecure Core GET "UserGroups") | ForEach-Object {
        $local:GroupInfo = New-Object PSObject -Property ([ordered]@{
            GroupId = $_.Id;
            GroupName = $_.Name;
            GroupDescription = $_.Description;
            GroupDistinguishedName = $_.DirectoryProperties.DistinguishedName
        })
        $_.Members | ForEach-Object {
            $local:MembershipInfo = New-Object PSObject -Property ([ordered]@{
                GroupName = $local:GroupInfo.GroupName;
                GroupDescription = $local:GroupInfo.GroupDescription;
                GroupDistinguishedName = $local:GroupInfo.GroupDistinguishedName;
                GroupId = $local:GroupInfo.GroupId;
                UserIdentityProvider = $_.PrimaryAuthenticationProviderName;
                UserName = $_.UserName;
                UserDisplayName = $_.DisplayName;
                UserDescription = $_.Description;
                UserDistinguishedName = $_.DirectoryProperties.DistinguishedName;
                UserIdentityProviderId = $_.PrimaryAuthenticationProviderId;
                UserId = $_.Id;
                UserAdminRoles = ($_.AdminRoles -join ", ");
                UserIsPartitionOwner = $_.IsPartitionOwner;
                UserEmailAddress = $_.EmailAddress;
                UserWorkPhone = $_.WorkPhone;
                UserMobilePhone = $_.MobilePhone;
                UserSecondaryMobilePhone = $_.SecondaryMobilePhone
            })
            $local:Memberships += $local:MembershipInfo
        }
    }

    if ($StdOut)
    {
        $local:Memberships | ConvertTo-Csv -NoTypeInformation
    }
    else
    {
        $local:OutFile = (Get-OutFileForParam -OutputDirectory $OutputDirectory -FileName "sg-usergroup-memberships-$((Get-Date).ToString("yyyy-MM-dd")).csv" -StdOut:$StdOut)
        $local:Memberships | ConvertTo-Csv -NoTypeInformation | Out-File $local:OutFile
        Out-FileAndExcel -OutFile $local:OutFile -Excel:$Excel
    }
}

<#
.SYNOPSIS
Generates report of account management configuration in Safeguard via the Web API.

.DESCRIPTION
Account management configuration report includes information for each asset and
account: asset partition, profile, password policy, check schedule, change
schedule, and sync group.

.PARAMETER Appliance
IP address or hostname of a Safeguard appliance.

.PARAMETER AccessToken
A string containing the bearer token to be used with Safeguard Web API.

.PARAMETER Insecure
Ignore verification of Safeguard appliance SSL certificate.

.PARAMETER OutputDirectory
String containing the directory where to create the CSV file.

.PARAMETER Excel
Automatically open the CSV file into excel after it is generation.

.PARAMETER StdOut
Send CSV to standard out instead of generating a file.

.INPUTS
None.

.OUTPUTS
A CSV file or CSV text.

.EXAMPLE
Get-SafeguardReportAssetManagementConfiguration -Excel

.EXAMPLE
Get-SafeguardReportAssetManagementConfiguration -StdOut
#>
function Get-SafeguardReportAssetManagementConfiguration
{
    [CmdletBinding(DefaultParameterSetName="File")]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Appliance,
        [Parameter(Mandatory=$false)]
        [object]$AccessToken,
        [Parameter(Mandatory=$false)]
        [switch]$Insecure,
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [string]$OutputDirectory = (Get-Location),
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [switch]$Excel = $false,
        [Parameter(Mandatory=$false, ParameterSetName="StdOut")]
        [switch]$StdOut
    )

    $ErrorActionPreference = "Stop"
    if (-not $PSBoundParameters.ContainsKey("Verbose")) { $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference") }

    $local:ProfileLookupTable = @{}
    (Invoke-SafeguardMethod -AccessToken $AccessToken -Appliance $Appliance `
            -Insecure:$Insecure Core GET "AssetPartitions/Profiles") | ForEach-Object {
        $local:ProfileLookupTable["$($_.AssetParitionId)_$($_.Id)"] = $_
    }
    $local:Configurations = @()
    (Invoke-SafeguardMethod -AccessToken $AccessToken -Appliance $Appliance `
            -Insecure:$Insecure Core GET "AssetAccounts") | ForEach-Object {
        $local:Profile = $local:ProfileLookupTable["$($_.AssetParitionId)_$($_.EffectiveProfileId)"]
        $local:Configuration = New-Object PSObject -Property ([ordered]@{
            AssetPartitionName = $_.AssetPartitionName;
            AssetName = $_.AssetName;
            AccountName = $_.Name;
            AccountDescription = $_.Description;
            AccountDistinguishedName = $_.DistinguishedName;
            PlatformDisplayName = $_.PlatformDisplayName;
            AssetPartitionId = $_.AssetParitionId;
            AssetId = $_.AssetId;
            AccountId = $_.Id;
            ProfileName = $_.EffectiveProfileName;
            SyncGroupName = $_.SyncGroupName;
            AccountPasswordRuleName = $local:Profile.AccountPasswordRuleName;
            AccountPasswordRuleDescription = $local:Profile.AccountPasswordRule.Description;
            CheckScheduleName = $local:Profile.CheckScheduleName;
            CheckScheduleDescription = $local:Profile.CheckSchedule.Description;
            ChangeScheduleName = $local:Profile.ChangeScheduleName;
            ChangeScheduleDescription = $local:Profile.ChangeSchedule.Description;
            ProfileId = $_.EffectiveProfileId;
            AccountPasswordRuleId = $local:Profile.AccountPasswordRuleId;
            CheckScheduleId = $local:Profile.CheckScheduleId;
            ChangeScheduleId = $local:Profile.ChangeScheduleId;
            SyncGroupId = $_.SyncGroupId;
            SyncGroupPriority = $_.SyncGroupPriority
        })
        $local:Configurations += $local:Configuration
    }

    if ($StdOut)
    {
        $local:Configurations | ConvertTo-Csv -NoTypeInformation
    }
    else
    {
        $local:OutFile = (Get-OutFileForParam -OutputDirectory $OutputDirectory -FileName "sg-usergroup-memberships-$((Get-Date).ToString("yyyy-MM-dd")).csv" -StdOut:$StdOut)
        $local:Configurations | ConvertTo-Csv -NoTypeInformation | Out-File $local:OutFile
        Out-FileAndExcel -OutFile $local:OutFile -Excel:$Excel
    }
}

<#
.SYNOPSIS
Generates report of a2a entitlements in Safeguard via the Web API.

.DESCRIPTION
A2A entitlement report contains information about every A2A registration,
the certificate user that can call the account retrieval, and which accounts
can be retrieved.

.PARAMETER Appliance
IP address or hostname of a Safeguard appliance.

.PARAMETER AccessToken
A string containing the bearer token to be used with Safeguard Web API.

.PARAMETER Insecure
Ignore verification of Safeguard appliance SSL certificate.

.PARAMETER OutputDirectory
String containing the directory where to create the CSV file.

.PARAMETER Excel
Automatically open the CSV file into excel after it is generation.

.PARAMETER StdOut
Send CSV to standard out instead of generating a file.

.INPUTS
None.

.OUTPUTS
A CSV file or CSV text.

.EXAMPLE
Get-SafeguardReportA2aEntitlement -Excel

.EXAMPLE
Get-SafeguardReportA2aEntitlement -StdOut
#>
function Get-SafeguardReportA2aEntitlement
{
    [CmdletBinding(DefaultParameterSetName="File")]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Appliance,
        [Parameter(Mandatory=$false)]
        [object]$AccessToken,
        [Parameter(Mandatory=$false)]
        [switch]$Insecure,
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [string]$OutputDirectory = (Get-Location),
        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [switch]$Excel = $false,
        [Parameter(Mandatory=$false, ParameterSetName="StdOut")]
        [switch]$StdOut
    )

    $ErrorActionPreference = "Stop"
    if (-not $PSBoundParameters.ContainsKey("Verbose")) { $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference") }

    $local:Entitlements = @()

    (Invoke-SafeguardMethod -AccessToken $AccessToken -Appliance $Appliance -Insecure:$Insecure `
            Core GET "A2ARegistrations") | ForEach-Object {
        $local:A2a = $_
        (Invoke-SafeguardMethod -AccessToken $AccessToken -Appliance $Appliance -Insecure:$Insecure `
                Core GET "A2ARegistrations/$($local:A2a.Id)/RetrievableAccounts") | ForEach-Object {
            $local:Entitlement = New-Object PSObject -Property ([ordered]@{
                A2ARegistrationId = $local:A2a.Id;
                AppName = $local:A2a.AppName;
                Description = $local:A2a.Description;
                Disabled = $local:A2a.Disabled;
                CertificateUserId = $local:A2a.CertificateUserId;
                CertificateUser = $local:A2a.CertificateUser;
                CertificateUserThumbprint = $local:A2a.CertificateUserThumbprint;
                AssetId = $_.SystemId;
                AccountId = $_.AccountId;
                AssetName = $_.SystemName;
                AccountName = $_.AccountName;
                DomainName = $_.DomainName;
                AccountType = $_.AccountType;
                IPRestrictions = ($_.IpRestrictions -join ", ");
                AccountDisabled = [bool]($_.AccountDisabled)
            })
            $local:Entitlements += $local:Entitlement
        }
    }

    if ($StdOut)
    {
        $local:Entitlements | ConvertTo-Csv -NoTypeInformation
    }
    else
    {
        $local:OutFile = (Get-OutFileForParam -OutputDirectory $OutputDirectory -FileName "sg-a2a-entitlements-$((Get-Date).ToString("yyyy-MM-dd")).csv" -StdOut:$StdOut)
        $local:Entitlements | ConvertTo-Csv -NoTypeInformation | Out-File $local:OutFile
        Out-FileAndExcel -OutFile $local:OutFile -Excel:$Excel
    }
}