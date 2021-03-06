Import-LocalizedData -BindingVariable localizedData -FileName Resources.psd1;

function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $LicenseServer,
        [Parameter()] [ValidateSet('Present','Absent')] [System.String] $Ensure = 'Present',
        [Parameter()] [ValidateNotNull()] [System.Int16] $LicenseServerPort = 27000,
        [Parameter()] [ValidateSet('PLT','ENT','APP')] [System.String] $LicenseEdition = 'PLT',
        [Parameter()] [ValidateSet('UserDevice','Concurrent')] [System.String] $LicenseModel = 'UserDevice',
        [Parameter()] [System.Boolean] $TrustLicenseServerCertificate = $true,
        [Parameter()] [AllowNull()] [System.Management.Automation.PSCredential] $Credential
    )
    begin {
        if (-not (TestXDModule -Name 'Citrix.Configuration.Admin.V2' -IsSnapin)) {
            ThrowInvalidProgramException -ErrorId 'Citrix.Configuration.Admin.V2' -ErrorMessage $localizedData.XenDesktopSDKNotFoundError;
        }
    }
    process {
        $scriptBlock = {
            Add-PSSnapin -Name 'Citrix.Configuration.Admin.V2' -ErrorAction Stop;
            try {
                $xdSiteConfig = Get-ConfigSite;
            }
            catch { }
            $targetResource = @{
                LicenseServer = $xdSiteConfig.LicenseServerName;
                LicenseServerPort = $xdSiteConfig.LicenseServerPort;
                LicenseEdition = $xdSiteConfig.ProductEdition;
                LicenseModel = $xdSiteConfig.LicensingModel;
                TrustLicenseServerCertificate = !([System.String]::IsNullOrEmpty($xdSiteConfig.MetaDataMap.CertificateHash));
                Ensure = $using:Ensure;
            };
            return $targetResource;
        } #end scriptblock

        $invokeCommandParams = @{
            ScriptBlock = $scriptBlock;
            ErrorAction = 'Stop';
        }
        if ($Credential) { AddInvokeScriptBlockCredentials -Hashtable $invokeCommandParams -Credential $Credential; }
        else { $invokeCommandParams['ScriptBlock'] = [System.Management.Automation.ScriptBlock]::Create($scriptBlock.ToString().Replace('$using:','$')); }
        Write-Verbose ($localizedData.InvokingScriptBlockWithParams -f [System.String]::Join("','", @($LicenseServer, $LicenseServerPort, $LicenseEdition, $LicenseModel)));
        return Invoke-Command @invokeCommandParams;
    } #end process
} #end function Get-TargetResource

function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $LicenseServer,
        [Parameter()] [ValidateSet('Present','Absent')] [System.String] $Ensure = 'Present',
        [Parameter()] [ValidateNotNull()] [System.Int16] $LicenseServerPort = 27000,
        [Parameter()] [ValidateSet('PLT','ENT','APP')] [System.String] $LicenseEdition = 'PLT',
        [Parameter()] [ValidateSet('UserDevice','Concurrent')] [System.String] $LicenseModel = 'UserDevice',
        [Parameter()] [System.Boolean] $TrustLicenseServerCertificate = $true,
        [Parameter()] [AllowNull()] [System.Management.Automation.PSCredential] $Credential
    )
    process {
        $isInDesiredState = $true;
        if ($Ensure -eq 'Absent') {
            ## Not supported and we will always return $true
            Write-Warning $localizedData.RemovingLicenseServerPropertiesWarning;
        }
        else {
            $targetResource = Get-TargetResource @PSBoundParameters;
            if ($LicenseServer -ne $targetResource['LicenseServer']) { $isInDesiredState = $false }
            elseif ($LicenseServerPort -ne $targetResource['LicenseServerPort']) { $isInDesiredState = $false }
            elseif ($LicenseEdition -ne $targetResource['LicenseEdition']) { $isInDesiredState = $false }
            elseif ($LicenseModel -ne $targetResource['LicenseModel']) { $isInDesiredState = $false }
            elseif ($TrustLicenseServerCertificate -ne $targetResource['TrustLicenseServerCertificate']) { $isInDesiredState = $false }
            if ($isInDesiredState) {
                Write-Verbose $localizedData.ResourceInDesiredState;
            }
            else {
                Write-Verbose $localizedData.ResourceNotInDesiredState;
            }
        }
        return $isInDesiredState;
    } #end process
} #end function Test-TargetResource

function Set-TargetResource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $LicenseServer,
        [Parameter()] [ValidateSet('Present','Absent')] [System.String] $Ensure = 'Present',
        [Parameter()] [ValidateNotNull()] [System.Int16] $LicenseServerPort = 27000,
        [Parameter()] [ValidateSet('PLT','ENT','APP')] [System.String] $LicenseEdition = 'PLT',
        [Parameter()] [ValidateSet('UserDevice','Concurrent')] [System.String] $LicenseModel = 'UserDevice',
        [Parameter()] [System.Boolean] $TrustLicenseServerCertificate = $true,
        [Parameter()] [AllowNull()] [System.Management.Automation.PSCredential] $Credential
    )
    begin {
        if (-not (TestXDModule -Name 'Citrix.Configuration.Admin.V2' -IsSnapin)) {
            ThrowInvalidProgramException -ErrorId 'Citrix.Configuration.Admin.V2' -ErrorMessage $localizedData.XenDesktopSDKNotFoundError;
        }
        elseif ($TrustLicenseServerCertificate -and (-not (TestXDModule -Name 'Citrix.Licensing.Admin.V1' -IsSnapin))) {
            ThrowInvalidProgramException -ErrorId 'Citrix.Licensing.Admin.V1' -ErrorMessage $localizedData.XenDesktopSDKNotFoundError;
        }
    }
    process {
        $scriptBlock = {
            Add-PSSnapin -Name 'Citrix.Configuration.Admin.V2' -ErrorAction Stop;
            $setConfigSiteParams = @{
                LicenseServerName = $using:LicenseServer;
                LicenseServerPort = $using:LicenseServerPort;
                ProductEdition = $using:LicenseEdition;
                LicensingModel = $using:LicenseModel;
            }
            Write-Verbose ($using:localizedData.SettingLicenseServerProperties -f $using:LicenseServer, $using:LicenseServerPort, $using:LicenseEdition);
            Set-ConfigSite @setConfigSiteParams;
            if ($using:TrustLicenseServerCertificate) {
                Add-PSSnapin -Name 'Citrix.Licensing.Admin.V1' -ErrorAction Stop;
                $licenseServerCertificateHash = (Get-LicCertificate -AdminAddress $using:LicenseServer).CertHash;
                Set-ConfigSiteMetadata -Name 'CertificateHash' -Value $licenseServerCertificateHash;
            }
        } #end scriptBlock
        
        $invokeCommandParams = @{
            ScriptBlock = $scriptBlock;
            ErrorAction = 'Stop';
        }
        if ($Credential) { AddInvokeScriptBlockCredentials -Hashtable $invokeCommandParams -Credential $Credential; }
        else { $invokeCommandParams['ScriptBlock'] = [System.Management.Automation.ScriptBlock]::Create($scriptBlock.ToString().Replace('$using:','$')); }
        Write-Verbose ($localizedData.InvokingScriptBlockWithParams -f [System.String]::Join("','", @($LicenseServer, $LicenseServerPort, $LicenseEdition, $LicenseModel)));
        return Invoke-Command @invokeCommandParams;
    } #end process
} #end function Set-TargetResource
