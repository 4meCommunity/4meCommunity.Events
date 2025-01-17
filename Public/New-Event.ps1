Function New-Event
{
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param
    (
        [Parameter(Mandatory = $True, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $True, ParameterSetName = 'PAT')]
        [Parameter(Mandatory = $True, ParameterSetName = 'Plain')]
        [ValidateSet('Production', 'Quality', 'Demo')]
        [String] $EnvironmentType,

        [Parameter(Mandatory = $True, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $True, ParameterSetName = 'PAT')]
        [Parameter(Mandatory = $True, ParameterSetName = 'Plain')]
        [ValidateSet('EU', 'AU', 'UK', 'US', 'CH')]
        [String] $EnvironmentRegion,

        [Parameter(Mandatory = $True, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $True, ParameterSetName = 'PAT')]
        [Parameter(Mandatory = $True, ParameterSetName = 'Plain')]
        [String] $AccountName,

        [Parameter(Mandatory = $True, ParameterSetName = 'Default')]
        [PSCredential] $Credentials,

        [Parameter(Mandatory = $True, ParameterSetName = 'PAT')]
        [String] $PAT,

        [Parameter(Mandatory = $True, ParameterSetName = 'Plain')]
        [String] $ClientId,
        [Parameter(Mandatory = $True, ParameterSetName = 'Plain')]
        [String] $ClientSecret,
        
        [Parameter(Mandatory = $True, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $True, ParameterSetName = 'PAT')]
        [Parameter(Mandatory = $True, ParameterSetName = 'Plain')]
        [HashTable] $Parameters,

        [Parameter(Mandatory = $False, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $False, ParameterSetName = 'PAT')]
        [Parameter(Mandatory = $False, ParameterSetName = 'Plain')]
        [Alias('NoBody')]
        [Switch] $AsUrl
    )

    Begin
    {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Start"

        $Domain = '4me.com'
        If ($EnvironmentType -eq 'Quality')
        {
            $Domain = '4me.qa'
        }
        ElseIf ($EnvironmentType -eq 'Demo')
        {
            $Domain = '4me-demo.com'
        }

        $ApiHost = "https://api.$($EnvironmentRegion.ToLower()).$($Domain)"
        If ($EnvironmentRegion -eq 'EU')
        {
            $ApiHost = "https://api.$($Domain)"
        }
    }

    Process
    {
        $Headers = @{
            'X-4me-Account' = $AccountName
        }

        If ($PSCmdlet.ParameterSetName -eq 'PAT')
        {
            $Headers.Add('Authorization', "Bearer $PAT") | Out-Null
        }
        ElseIf ($PSCmdlet.ParameterSetName -eq 'Plain')
        {
            $token = Get-4meAccessToken -EnvironmentType $EnvironmentType -EnvironmentRegion $EnvironmentRegion -ClientId $ClientId -ClientSecret $ClientSecret
            $Headers.Add('Authorization', "Bearer $token") | Out-Null
        }
        ElseIf ($PSCmdlet.ParameterSetName -eq 'Default')
        {
            $token = Get-4meAccessToken -EnvironmentType $EnvironmentType -EnvironmentRegion $EnvironmentRegion -Credential $Credentials
            $Headers.Add('Authorization', "Bearer $token") | Out-Null
        }

        $Url = "$($ApiHost)/v1/events"
        $AdditionalParameters = @{}
        If ($AsUrl.IsPresent)
        {
            $UrlEncoded = ''
            ForEach ($key in $Parameters.Keys)
            {
                $UrlEncoded += "&$($key)=$([uri]::EscapeDataString($Parameters[$key]))"
            }
            # Remove leading &
            $UrlEncoded = $UrlEncoded.SubString(1, $UrlEncoded.Length - 1)
            $Url += "?$UrlEncoded"
        }
        Else
        {
            $AdditionalParameters.Add('Body', ( $Parameters | ConvertTo-Json ) )
        }

        $Response = Invoke-WebRequest -Uri $Url -Method POST -Headers $Headers -UseBasicParsing @AdditionalParameters

        If ($Response.StatusCode -eq 201)
        {
            Return [PSCustomObject]@{
                'Success' = $True
                'IsNew'   = $True
                'Request' = ( $Response.Content | ConvertFrom-Json )
            }
        }
        ElseIf ($Response.StatusCode -eq 200)
        {
            Return [PSCustomObject]@{
                'Success' = $True
                'IsNew'   = $False
                'Request' = ( $Response.Content | ConvertFrom-Json )
            }
        }
        Else
        {
            Write-Warning "[$($MyInvocation.MyCommand.Name)] Recieved unknown status code from Events API: $($Response.StatusCode). Assuming failure"
            Return [PSCustomObject]@{
                'Success' = $False
                'Content' = $Response.Content
            }
        }
    }

    End
    {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] End"
    }
}