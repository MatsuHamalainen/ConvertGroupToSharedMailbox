#requires -version 5.0
#requires -module AzureAD

<#
	.SYNOPSIS
	Converts a mail enabled security group or a distribution group to a shared mailbox in Office 365
	.DESCRIPTION
	Use this command to convert a security group or a distribution group into a shared mailbox.
	The shared mailbox will have the same users and security groups as members and will be added to all of the groups that the original group was a member of.
	The Command also adds the original groups alias information into the new shared mailbox.
	Non domain users and contacts will not be added to the shared mailbox as members nor will distribution groups.
	.PARAMETER Groups
	The names of the groups to be converted in quotes separated by commas
	.PARAMETER Delegate
	Should the users be delegated the right to send on behalf of the created shared mailbox
	.PARAMETER AutoMap
	Should the automapping function be enabled for the shared mailbox
	.PARAMETER Confirm
	Should the script do a prompt before removing any groups
	.EXAMPLE
	ConvertGroupToSharedMailbox "Example1","Example2" -Delegate:$true -AutoMap:$false -Confirm:$false
#>

function ConvertGroupToSharedMailbox ($Groups, [bool]$Delegate=$true, [bool]$AutoMap=$true, [bool]$Confirm=$true){
	if (Get-Module -ListAvailable -Name 'AzureAD') {
		Connect-AzureAD
		$OfficeSession = StartSession
		foreach ($Group in $Groups){
			Write-Host "Starting conversion for group $Group" 
			Try 
			{
				$Mail = Get-DistributionGroup -Identity $Group -ErrorAction Stop | Select -Property "PrimarySmtpAddress" 
			}
			Catch
			{
				Write-Host "Group $Group not found"
				break
			}
			$Group = Get-DistributionGroup -Identity $Group | Select -Property "DisplayName" | %{$_.DisplayName}
			$AddressList = get-recipient -Identity $Mail.PrimarySmtpAddress -Resultsize unlimited | select emailaddresses | %{$_.EmailAddresses | ?{($_.split(":")[0] -eq "smtp")}|%{$_.split(":")[1]}}
			$Members = Get-DistributionGroupMember -Identity $Group | Where-object {$_.RecipientType -eq "UserMailbox"} | %{Get-AzureADUser -SearchString $_.Name} | Where-object {$_.UserType -eq "Member"}
			$DelegateUsers = $Members | Select-Object -Property "UserPrincipalName"
			$DelegateGroups = Get-DistributionGroupMember -Identity $Group |where-object {$_.RecipientType -eq "MailUniversalSecurityGroup"} | %{Get-DistributionGroup -Identity $_.Name} | Select-Object -Property "PrimarySmtpAddress"
			$DelegateMembers = New-Object System.Collections.Generic.List[System.Object]
			$DelegateUsers | %{$DelegateMembers.Add($_.UserPrincipalName)}
			$DelegateGroups | %{$DelegateMembers.Add($_.PrimarySmtpAddress)}
			$ExternalMembers = Get-DistributionGroupMember -Identity $Group | Where-object {$_.RecipientType -eq "MailUser" -or $_.RecipientType -eq "MailContact"}
			$DistributionGroups = Get-DistributionGroupMember -Identity $Group |where-object {$_.RecipientType -eq "MailUniversalDistributionGroup"} | Select-Object -Property "Name"
			$Members = $Members | Select-object -Property UserPrincipalName
			$Membership = GetGroupMembership $Group
			DeleteDistributionGroup $Group
			CreateSharedMailbox $Group $Mail
			if($delegate){GrantSendOnBehalf $Group $DelegateMembers}
			if($DelegateMembers){AddSharedMailboxMembers $Group $Members}
			if($DelegateGroups){AddSharedMailboxGroups $Group $DelegateGroups}
			if($Membership){AddToGroups $Mail $Membership}
			if($ExternalMembers){PrintExternalMembers $ExternalMembers}
			if($DistributionGroups){PrintDistributionGroups $DistributionGroups}
			if($AddressList.length -ge 1){AddSharedMailboxAlias $Mail}
		}
		EndSession $OfficeSession
		Write-Host "Group to shared mailbox conversion complete."
	}
	else {
		$Prompt = Read-Host -Prompt "Do you want to install Connect-AzureAD module? Y(Yes) Default Y: "
		if([string]::IsNullOrWhiteSpace($Prompt)){
			$Prompt = y
		}
		if($Prompt -eq 'y'){
			Install-Module AzureAD -Force
			ConvertGroupToSharedMailbox $Groups $Delegate $AutoMap $Confirm
		}
		else{
			break
		}
	}
}

function StartSession {
	Write-Host "Getting credentials for the session."
	$Credential = get-credential
	Write-Host "Starting session..."
	$OfficeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/powershell-liveid" -Credential $Credential -Authentication "Basic" -AllowRedirection
	Write-Host "Importing session..."
	Import-PSSession $OfficeSession -AllowClobber
	return $OfficeSession
}

function EndSession ($OfficeSession){
	Write-Host "Ending session"
	Remove-PSSession $OfficeSession.Id
	Disconnect-AzureAD
}

function GetGroupMembership ($Name){
	Write-Host "Retrieving the groups membership information"
	$GroupList = Get-AzureAdGroup
	$ID = Get-AzureADGroup -SearchString $Name | where-object{$_.DisplayName -eq $Name} | Select-object -Property 'ObjectId'
	$Identity=foreach($Group in $GroupList){$validator = Get-AzureADGroupMember -ObjectId $Group.ObjectId | Where {$_.ObjectId -eq $ID.ObjectId} | Select-Object -Property 'DisplayName'; if($validator){Get-DistributionGroup -Identity $group.DisplayName}}
	$Result = $Identity | %{Get-DistributionGroup -Identity $_.DisplayName} | Select-Object -Property 'PrimarySmtpAddress'
	return $Result
}

function AddToGroups ($MailAddress, $Membership){
	Write-host "Adding the shared mailbox to groups according to the original memberships"
	$Membership | %{Add-DistributionGroupMember -Identity $_.PrimarySmtpAddress -Member $MailAddress.PrimarySmtpAddress}
}

function CreateSharedMailbox ($Name, $Mail){
	$Address = $Mail.PrimarySmtpAddress
	Write-host "Creating a shared mailbox $Address"
	New-Mailbox -Shared -Name $Name -DisplayName $Name -PrimarySmtpAddress $Address | Out-null
}

function AddSharedMailboxAlias ($Mail){
	Write-Host "Adding alias addresses to the shared mailbox:"
	$Timer = Get-Date
	$result=$false
	$Address = $Mail.PrimarySmtpAddress
	Write-Host "    Waiting for the mailbox to synchronize over to Azure AD. This might take up to a minute."
	do{
		$MailUser = get-azureaduser -SearchString $Address | Where-Object {$_.UserPrincipalName -eq $Address}
		if($MailUser){
			Write-Host "    The user has been synchronized, attempting to add alias addresses."
			$Done = $false
			While(-not $Done){
				Try{
					Start-Sleep -s 1
					$AddressList | %{if($_ -ne $Address){Set-Mailbox $Address -EmailAddresses @{Add=$_} -ErrorAction Stop}}
					Write-Host "Alternative email addresses added succesfully"
					$Done = $true
				}Catch{
					# Ignore error
				}
			}
			$result=$true
		break
		}
	}while ($Timer.AddSeconds(60) -gt (get-date))
	if(-not $result){
		Write-Host "Timeout. Unable to add alias addresses from list: $AddressList"
	}
}

function AddSharedMailboxMembers ($Group, $Members){
	Write-Host "Adding original member users to the shared mailbox"
	$Members | %{Add-MailboxPermission -Identity $Group -User $_.UserPrincipalName -AccessRights FullAccess -AutoMapping:$AutoMap | Out-null}
	$Members | %{Add-RecipientPermission -Identity $Group -Trustee $_.UserPrincipalName -Accessrights SendAs -Confirm:$false | Out-null}
}

function AddSharedMailboxGroups ($Group, $MailGroups){
	Write-Host "Adding the original member groups to the shared mailbox"
	$MailGroups | %{Add-MailboxPermission -Identity $Group -User $_.PrimarySmtpAddress -AccessRights FullAccess -AutoMapping:$AutoMap | Out-null}
	$MailGroups | %{Add-RecipientPermission -Identity $Group -Trustee $_.PrimarySmtpAddress -Accessrights SendAs -Confirm:$false | Out-null}
}

function GrantSendOnBehalf ($Mailbox, $DelegateMembers){
	Write-Host "Granting send on behalf privileges to the members"
	Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo $DelegateMembers
}

function DeleteDistributionGroup ($Name){
	Write-Host "Removing $Name"
	Remove-DistributionGroup -Identity $Name -Confirm:$Confirm
}

function PrintExternalMembers ($External){
	Write-Host "The following users were not added to the shared mailbox: $External"
}

function PrintDistributionGroups ($DistributionGroups){
	Write-Host "The following distribution groups were not added to the shared mailbox: $DistributionGroups"
}

Export-ModuleMember -Function ConvertGroupToSharedMailbox