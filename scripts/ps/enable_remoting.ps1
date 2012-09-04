# Author: Carlos Perez carlos_perez@darkoperator.com
function Confirm-IsAdmin
{
    (whoami /all | Select-String S-1-16-12288) -ne $null
}
if (Confirm-IsAdmin) {
	Write-Host "Modifying Public profile interfaces to none public profile"
	$nlm = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]"{DCB00C01-570F-4A9B-8D69-199FDBA5723B}"))
	$connections = $nlm.getnetworkconnections()
	$connections |foreach {
    	if ($_.getnetwork().getcategory() -eq 0)
    	{
        	$_.getnetwork().setcategory(1)
    	}
	}
	Write-Host "Enable PS Remoting"
	Enable-PSRemoting -Force
}
else {
	Write-Host "Not Running with Administrator Privileges, could not enable PSRemoting"
}