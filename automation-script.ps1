<#
    .DESCRIPTION
        PowerShell script to automate the deployment of Azure resources from template files

    .NOTES
        AUTHOR: Matt McInnis
        LASTEDIT: Mar 28, 2018
        LICENSE: MIT. Use at own risk. 
        WARNING: Deploying Azure resources can cost money. Please be aware before running.   
#>

# Resource Group Name:   Where the resource will be created
# Storage Account Name:  Location of the template file
# Storage File Name:     File name of the template file
# KeyVaultName:          Name of the Key Vault where credentials are stored
$ResourceGroupName = "hdi_datafactory"            # ensure this resource group has already been created
$StorageAccountName = "cs297a3de4284bex4f1dx8f7"  # replace with your own!
$StorageFileName = "template.json"
$KeyVaultName = "mykeyvault112233"                # replace with your own!

# Authenticate to Azure if running from Azure Automation
$ServicePrincipalConnection = Get-AutomationConnection -Name "AzureRunAsConnection"
Add-AzureRmAccount `
    -ServicePrincipal `
    -TenantId $ServicePrincipalConnection.TenantId `
    -ApplicationId $ServicePrincipalConnection.ApplicationId `
    -CertificateThumbprint $ServicePrincipalConnection.CertificateThumbprint | Write-Verbose

# Retrieve credentials from Key Vault
try {
    # If the code below fails, you may need to add or update modules; described here: http://www.rahulpnath.com/blog/accessing-azure-key-vault-from-azure-runbook/
    Write-Output "Attempting to retrieve credentials from Key Vault."

    # clusterName:           Defined, and must be consisten with, the template file
    # clusterLoginPassword:  Required parameter of template. 
    # sshPassword:           Required parameter of template.
    # storageAccountKey:     Enables access to template file stored in storage account's File Share
    $clusterName = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name "clusterName"
    $clusterLoginPassword = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name "clusterLoginPassword"
    $sshPassword = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name "sshPassword"
    $storageAccountKey = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name "storageAccountKey"
}
catch {
    Write-Output "Failed to retrieve credentials from Key Vault."
    Write-Error -Message $_.Exception
    throw $_.Exception
}



# Parameters to be passed to template file
#   - clusterName must be consisten with clusterName from template file
#   - be sure to provide all required credentials
$Parameters = @{
    "clusterName"          = $clusterName.SecretValueText
    "clusterLoginPassword" = $clusterLoginPassword.SecretValueText
    "sshPassword"          = $sshPassword.SecretValueText
}

# Create a new Azure storage context
try {
    Write-Output "Building Azure Storage Context."
    $Context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storageAccountKey.SecretValueText
}
catch {
    Write-Output "Failed to build Azure Storage Context."
    Write-Error -Message $_.Exception
    throw $_.Exception
}

# Retrieve the template file, add to temporary storage
try {
    Write-Output "Retrieving the template file from File Share."    
    Get-AzureStorageFileContent -ShareName 'myfileshare' -Context $Context -path $StorageFileName -Destination 'C:\Temp'
    $TemplateFile = Join-Path -Path 'C:\Temp' -ChildPath $StorageFileName
}
catch {
    Write-Output "Failed to retrieve the template file from File Share."   
    Write-Error -Message $_.Exception
    throw $_.Exception 
}

# Deploy the template file
try {
    Write-Output "Deploying Azure resource."
    New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile -TemplateParameterObject $Parameters
}
catch {
    Write-Output "Azure deployment created!"    
    Write-Error -Message $_.Exception
    throw $_.Exception
}

<#
MIT License

Copyright (c) [2018] [Matt McInnis]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>