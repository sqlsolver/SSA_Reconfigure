	if (-not(Test-Path $xmlfile)){ 
		Write-Warning "The file containing script parameters cannot be located."
		Write-Host "The file to create the script parameters must be located in the same directory as the calling script." -ForegroundColor:Green
		return $false
		}
	#Load and validate the configuration file
	[xml]$scriptParams = Get-Content $xmlfile
	$SSAparams = $scriptParams.params.SSA
		if($SSAparams -eq $null){
			Write-Warning "Component parameters are not present in the parameters file."
			Write-Host "Ensure that the parameters file contains one or more nodes." -ForegroundColor:DarkMagenta
			return $false
		}		
	return $SSAparams


	#Namespace manager for xPath - See http://www.w3schools.com/xml/xml_namespaces.asp
function nameSpaceManager () {
	[xml]$xPathParams = Get-Content $xmlfile
	$nsmgr = New-Object System.Xml.XmlNamespaceManager $xPathParams.NameTable
	$nsmgr.AddNamespace("ns0", "urn:params-schema")
	return $nsmgr
}
