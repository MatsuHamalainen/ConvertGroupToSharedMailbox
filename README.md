# ConvertGroupToSharedMailbox
Contains the tools to convert an Office 365 mail enabled security- or distribution group into a shared mailbox

DEPENDENCIES:

Powershell has to be at least version 5.0

If Module AzureAD is not installed the script will attempt to use "Install-Module" utility in order to install it

IMPORTING:

Copy both psm1 scripts in to the same folder and run command:

import-module "C:\example\git\GrouptToSharedMB\ConvertGroupToSharedMailbox.psm1"
    
PARAMETERS:

	.PARAMETER Groups
	The names of the groups to be converted in quotes separated by commas. You should use the groups Display Name with this argument
	.PARAMETER Delegate
	Should the users be delegated the right to send on behalf of the created shared mailbox
	.PARAMETER AutoMap
	Should the automapping function be enabled for the users in the shared mailbox
	.PARAMETER Confirm
	Should the script do a prompt before removing any groups
    
USAGE:

Use the module by calling it in the same powershell window that was used to import the module:

ConvertGroupToSharedMailbox -Groups "Example1","Example2" -Delegate:$true -AutoMap:$false -Confirm:$false


The script will prompt for credential, first for Connect-AzureAD and then for the PSSession. Please provide credentials with correct privileges to the could environment.

FUNCTIONALITY:

The script goes through each group specified in the arguments one at a time. It first gets the additional email addresses the group has. Then it gets the groups members and separates them based on what type they are. For users, only MailboxUsers who are members of the domain are added. For groups, only MailUniversalSecurityGroups are added to the shared mailbox. After this the script goes through all of the security groups in the domain and checks each one of them if the group in question is a member.

After the script has the required information it starts the conversion process. First it deletes the existing group. Then it creates a shared mailbox with the same DisplayName and EmailAddress, and removes diacritics for the Name attribute to comply with Azures standard. If the delegate parameter is true it grants send on behalf privilege to all of the members that are going to be added. It then proceeds to add the MailUniversalSecurityGroups and MailboxUsers. Next it adds the shared mailbox in to the same groups that the original group was a member of and after that it prints the users/contacts and distribution lists that were not added into the new shared mailbox. Finally it adds the additional email addresses that the original group had to the shared mailbox. This final part requires the shared mailbox user to synchronize into Azure and thus might take a while (up to a minute) to complete.

ATTENTION:

Make sure that every group and user that are part of the conversion process (Either the ones that the converted group is a member of or the ones that are members of the converted group) have unique Display Names. 
