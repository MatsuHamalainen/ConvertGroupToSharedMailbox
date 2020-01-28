# ConvertGroupToSharedMailbox
Contains the tools to convert an Office 365 mail enabled security- or distribution group into a shared mailbox

DEPENDENCIES:

Powershell has to be at least version 5.0
If Module AzureAD is not installed the script will attempt to use "Install-Module" utility in order to install it

HOWTO IMPORT:

Copy both psm1 scripts in to the same folder and run command:
    import-module "C:\example\git\GrouptToSharedMB\ConvertGroupToSharedMailbox.psm1"
    
PARAMETERS:

	.PARAMETER Groups
	The names of the groups to be converted in quotes separated by commas
	.PARAMETER Delegate
	Should the users be delegated the right to send on behalf of the created shared mailbox
	.PARAMETER AutoMap
	Should the automapping function be enabled for the users in the shared mailbox
	.PARAMETER Confirm
	Should the script do a prompt before removing any groups
    
USAGE:

Use the module by calling it in the same powershell window that was used to import the module:
ConvertGroupToSharedMailbox -Groups "Example1","Example2" -Delegate:$true -AutoMap:$false -Confirm:$false

The script will prompt for credential, first for Connect-AzureAD and then for the PSSession. Please provice credentials with correct privileges to the could environment.
