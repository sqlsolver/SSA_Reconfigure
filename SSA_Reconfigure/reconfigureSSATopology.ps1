<# 
.SYNOPSIS
Modify a SharePoint 2013 or 2015 enterprise search service topology.
.DESCRIPTION
This script adds or replaces search components and cleans up any topologies that are no longer active.
.PARAMETER xmlfile
Refers the path to an .XML file which contains parameters for the components being created or removed. Assure your parameters file
is located in the same directory as the .ps1 file.
menu options, please keep in mind removal will not succeed unless the items you are removing are no longer in the activie topology.
.EXAMPLE
From the PowerShell prompt run .\reconfigureSSATopology.ps1 -xmlfile .\[enter the name of your parameters file].xml
.NOTES
16-03-15 Assembled by Ramona Maxwell - Microsoft Public License (Ms-PL)
.LINK
http://www.microsoft.com/en-us/openness/licenses.aspx
#>

Param([string]$xmlfile) 
$ErrorActionPreference = "Continue"
$dateStamp = Get-Date -Format "yyyy-MM-dd-hhmm"
$transcript = ".\" + $dateStamp + "_" + $MyInvocation.MyCommand.Name.Replace(".ps1", "") + ".log"
$outputFile = ".\" + $dateStamp + "_" + $MyInvocation.MyCommand.Name.Replace(".ps1", "") + "_SSAconfiguration.doc"
Start-Transcript -Path $transcript

function Get-Parameters(){
	<#
	.SYNOPSIS
	Loads and validates the XML file containing the script parameters.
	.DESCRIPTION
	This function verifies the configuration file exists and is loaded. It then returns the parameters from the file at the node specified.	
	#>	
	if (-not(Test-Path $xmlfile)){ 
		Write-Warning "The file containing script parameters cannot be located."
		Write-Host "The file to create the script parameters must be located in the same directory as the calling script." -ForegroundColor:Green
		return $false
		}
	#Load and validate the configuration file
	[xml]$scriptParams = Get-Content $xmlfile
	$SSAparams = $scriptParams.params.SSA.SSI
		if($SSAparams -eq $null){
			Write-Warning "Component parameters are not present in the parameters file."
			Write-Host "Ensure that the parameters file contains one or more nodes." -ForegroundColor:DarkMagenta
			return $false
		}		
	return $SSAparams	
}

function addComponents () {
	$SSA = Get-SPEnterpriseSearchServiceApplication
	Write-Host "The search service application being modified is " $SSA.Name
	$active = Get-SPEnterpriseSearchTopology -SearchApplication $SSA -Active
	#The -clone switch is important in the below command, without it you are replacing rather than updating topology
	$clone = New-SPEnterpriseSearchTopology -SearchApplication $SSA -Clone -SearchTopology $active
	Write-Host "The topology being cloned is " $clone
	Get-Parameters | ForEach-Object {
		$SSI = $_
		$targetSSI = Get-SPEnterpriseSearchServiceInstance -Identity $SSI.ServerName
		Write-Host "Host where components will be installed is: " $SSI.ServerName	
		Write-Host "Now starting the search service instance on " $targetSSI.Server	
		Start-SPEnterpriseSearchServiceInstance -Identity $targetSSI
		Start-Sleep -Seconds 10
		If ($targetSSI.Status -eq 'Online') {
			Write-Host "The status of the target search service is: " $targetSSI.Status	
				If ($SSI.addAdmin -like "*y*") {
					Write-Host "An admin component will be added to " $targetSSI.Server
					New-SPEnterpriseSearchAdminComponent -SearchTopology $clone -SearchServiceInstance $targetSSI
				}
				If ($SSI.addCrawl -like "y") {
					Write-Host "A crawl component will be added to " $targetSSI.Server	
					New-SPEnterpriseSearchCrawlComponent -SearchTopology $clone -SearchServiceInstance $targetSSI
				}
				If ($SSI.addContent -like "y") {
					Write-Host "A content processing component will be added to " $targetSSI.Server
					New-SPEnterpriseSearchContentProcessingComponent -SearchTopology $clone -SearchServiceInstance $targetSSI
				}
				If ($SSI.addAnalytics -like "y") {
					Write-Host "An analytics processing component will be added to " $targetSSI.Server
					New-SPEnterpriseSearchAnalyticsProcessingComponent -SearchTopology $clone -SearchServiceInstance $targetSSI
				}
				If ($SSI.addQuery -like "y") {
					Write-Host "A query processing component will be added to " $targetSSI.Server
					New-SPEnterpriseSearchQueryProcessingComponent -SearchTopology $clone -SearchServiceInstance $targetSSI
				}
				If (($SSI.indexComponent.RootDirectory -eq $null) -and ($SSI.addIndex -like "y")) {
					Write-Host "An index component will be added to " $targetSSI.Server 
					New-SPEnterpriseSearchIndexComponent -SearchTopology $clone -SearchServiceInstance $targetSSI -IndexPartition $SSI.indexComponent.IndexPartition
				}
				If (($SSI.indexComponent.RootDirectory -ne $null) -and ($SSI.addIndex -like "y")) {
					Write-Host "An index component will be added to " $SSI.ServerName " and the root directory will be changed to " $SSI.indexComponent.RootDirectory
					New-SPEnterpriseSearchIndexComponent -SearchTopology $clone -SearchServiceInstance $targetSSI -IndexPartition $SSI.indexComponent.IndexPartition -RootDirectory $SSI.indexComponent.RootDirectory
				}
		}
		Else {
			Write-Host "The status of the SSI is " $targetSSI.Status `n
			Write-Host "Please check that each search service instance is running and try again later."
			Menu
		}				

	}
	$clone.Activate()
	Start-Sleep -Seconds 100	
	$newSSAconfiguration = Get-SPEnterpriseSearchTopology -SearchApplication $SSA
	Write-Output "The updated topology of the search application " $SSA.Name " is:" `n
	Write-Output $newSSAconfiguration
	Menu
}

function removeInactiveTopologies () {
	$SSA = Get-SPEnterpriseSearchServiceApplication
	$SSAtopology = Get-SPEnterpriseSearchTopology -SearchApplication $SSA 
	Write-Output "The current topologies are: " $SSAtopology
	forEach ($topology in $SSAtopology){
	if ($SSAtopology.State -eq 'Inactive') {
		Write-Output "The topology with the ID: "$topology.TopologyId " is inactive and has been removed."
		Remove-SPEnterpriseSearchTopology -Identity $topology -Confirm:$false
		}
	}
	Write-Output "The remaining topologies are: " $SSAtopology 
	Menu
	}



function VerifyExit() {
		$VerifyExit = read-host "Are you sure you want to exit? (y/n)"  
        if (($VerifyExit -eq "y") -or ($VerifyExit -eq "Y")){
		Stop-Transcript
		Start-Sleep -Seconds 3
		exit
		}  
        if (($VerifyExit -eq "n") -or ($VerifyExit -eq "N")){Menu}  
        else {
			write-host -ForegroundColor:Red "Please select y to exit or n to continue."   
            VerifyExit  
        }  
}

function Menu() {
	Write-Host `n
	Write-Host "------------------Search Topology Configuration----------------------"   
	Write-Host ""   
	Write-Host "    1. Add or replace components in an existing search topology."
	Write-Host "    2. Remove all inactive topologies and their components."     
	Write-Host "    3. Exit" 
	Write-Host "                             _____________                            "   
	Write-Host "-----------------------------_____________----------------------------"  
	$answer = Read-Host "Please select an option"   
	if ($answer -eq 1) {addComponents}
	if ($answer -eq 2) {removeInactiveTopologies}
	if ($answer -eq 3) {VerifyExit}
	else {
		write-host -ForegroundColor red "Invalid Selection (please enter a letter or integer corresponding to your choice), returning to menu."  
    	sleep -Seconds 2  
    	Menu
	}
}
Menu