$VerbosePreference = "Continue"

#Clear and prepare SelectedUsers array
$SelectedUsers = @()

Write-Host `r`n
Write-Host -ForegroundColor Cyan "The selection grid may take a while to display, depending on the number of users returned"

#LoopStart: until you've finished adding more users
do {
    #Prompt user for string to search users display name
    $UserSearch = Read-Host -Prompt "Enter Display Name search string"
    #Clear and prepare Users array
    $Users = @()

    #Return all users matching the search string
    $Users = Get-AzureRmADUser -SearchString $UserSearch
    
    #If we can't find any users, prompt user for an email address
    if ($Users.Count -eq 0) {
        Write-Host `r`n
        Write-Host -ForegroundColor Cyan "No users found, try entering an email address"
        $UserSearch = Read-Host -Prompt "Enter email address"
        
        #Return all users matching the email address
        $Users = Get-AzureRmADUser -Mail $UserSearch

        #If the email returns nothing, try searching on UserPrincipalName
        if ($Users.Count -eq 0) {
            $Users = @()
            $Users = Get-AzureRmADUser -UserPrincipalName $UserSearch
        }
    }

    #If we found some users then;
    if ($Users.Count -ne 0) {
        #If only one user was found, add it 
        if ($Users.Count -eq 1) {
            $SelectedUsers += $Users
        } else {
            #If more than one user was found, use a GridView to select the required users.
            $SelectedUsers += $Users | select DisplayName, UserPrincipalName, ID | Sort-Object Name | Out-GridView -Title "Select Users" -PassThru
        }
        #Write the selected users to output
        Write-Output  $SelectedUsers | select DisplayName, UserPrincipalName, ID | Sort-Object Name | Format-Table -AutoSize
    }
    #Prompt user to keep adding more users
    $KeepAdding = Read-Host -Prompt "Add more users? (Y/N)"

    #LoopEnd: until you've finished adding more users
} until ($KeepAdding -notin ('Y','y'))

#If there are no selected users then exit out, otherwise continue
if ($SelectedUsers.Count -eq 0) {
    Write-Host `r`n
    Write-Host -ForegroundColor Cyan "No Users selected, we're done here"
} else {
    
    #Write out selected users and get confirmation to continue
    Write-Output  $SelectedUsers | select DisplayName, UserPrincipalName, ID | Sort-Object Name | Format-Table -AutoSize
    $Cont = Read-Host "Continue (Y/N)"

    if ($Cont -in ('Y','y')) {
        
        $SelectedSubscriptions = @()
        $SelectedSubscriptions = Get-AzureRmSubscription | Select Name, ID | Out-GridView -Title "Select Subscriptions (Ctrl/Shift click for multiples)" -PassThru 

        $Roles = @()
        $Roles = Get-AzureRmRoleDefinition | select Name, Description, IsCustom, Id | Sort-Object -Property @{Expression = {$_.IsCustom}; Ascending = $false}, Name | Out-GridView -title "Select Roles  (Ctrl/Shift click for multiples)" -PassThru
        Select-AzureRmSubscription -SubscriptionId $SelectedSubscriptions[0].ID

        foreach ($Sub in $SelectedSubscriptions) {
            foreach ($User in $SelectedUsers) {
                foreach ($Role in $Roles) {
                    New-AzureRmRoleAssignment -ObjectId $User.Id -Scope "/subscriptions/$($Sub.Id)" -RoleDefinitionName $Role.Name -ErrorAction Continue
                }
            }
        }
    } else {
        Write-Host `r`n
        Write-Host -ForegroundColor Cyan "You've selected not to continue, we're done here"
    }
}
