# Load WPF assemblies
Get-ChildItem -Path $PSScriptRoot -Filter Common*.PS1 | ForEach-Object {. ($_.FullName)}
$Window = New-Window -XamlFile "$PSScriptRoot\PowerShell-AD.xaml"

Set-CurrentCulture

$global:EditingID = $null;

class UserListItem {
    [string]$Surname
    [string]$Name
    [string]$SamAccountName
    [string]$EmailAddress
    [Guid]$ObjectGUID
}

$TabControl.Add_SelectionChanged({
    if ($TabControl.SelectedIndex -eq 1) {
        Update-UserList
    }
})

# API credentials and domain controller details
$Username = "Administrator"
$Password = ConvertTo-SecureString "Berni123!!" -AsPlainText -Force
$DomainController = "192.168.32.15"
# Create a PSCredential object to authenticate with the domain controller
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $Password

function UserList_SelectionChanged
{
    $SelectedUser = $UserList.SelectedItem
    if ($null -ne $SelectedUser)
    {
        $UserList.Tag = $SelectedUser
    }
}

function Edit-ADUser {
    # Import Active Directory module
    Import-Module ActiveDirectory

    $Domain = "kaesereiag-bno.local"
    $OrganizationalUnit = "CN=Users,DC=kaesereiag-bno,DC=local"

    # User details
    $NewUserFirstName = $FirstNameEdit.text
    $NewUserLastName = $LastNameEdit.Text
    $NewUserUsername = $UsernameEdit.Text
    $NewUserEmail = $EmailEdit.Text
    $NewUserPrincipalName = "$NewUserUsername@$Domain"
    $NewUserName = "$NewUserFirstName $NewUserLastName"

    # Create the new user
    try {
        # TODO: FIX NAME ATTRIBUTE!!!
        Set-ADUser -Identity $global:EditingID -Replace @{name="$NewUserName";userprincipalname="$NewUserPrincipalName";givenname="$NewUserFirstName";sn="$NewUserLastName";samaccountname="$NewUserUsername";mail="$NewUserEmail"} -Server $DomainController -Credential $Credential

        $ResultEdit.Foreground = 'Green'
        $ResultEdit.Text = "User $NewUserUsername has been edited successfully."

        $FirstNameEdit.Text = "";
        $LastNameEdit.Text = "";
        $UsernameEdit.Text = "";
        $EmailEdit.Text = "";
    } catch {
        $ResultEdit.Foreground = 'Red'
        $ResultEdit.Text = "Error: Failed to edit user $NewUserUsername. Error details: $_"
    }
}

# Function to create a new user in Active Directory
function Add-NewADUser {
    # Import Active Directory module
    Import-Module ActiveDirectory

    $Domain = "kaesereiag-bno.local"
    $OrganizationalUnit = "CN=Users,DC=kaesereiag-bno,DC=local"

    # User details
    $NewUserFirstName = $FirstNameAdd.text
    $NewUserLastName = $LastNameAdd.Text
    $NewUserUsername = $UsernameAdd.Text
    $NewUserEmail = $EmailAdd.Text
    $NewUserPassword = ConvertTo-SecureString $PasswordAdd.Password -AsPlainText -Force

    # Create the new user
    try {
        New-ADUser -Name "$NewUserFirstName $NewUserLastName" `
            -GivenName $NewUserFirstName `
            -Surname $NewUserLastName `
            -SamAccountName $NewUserUsername `
            -UserPrincipalName "$NewUserUsername@$Domain" `
            -EmailAddress $NewUserEmail `
            -AccountPassword $NewUserPassword `
            -Enabled $true `
            -Path $OrganizationalUnit `
            -Server $DomainController `
            -Credential $Credential
        $ResultAdd.Foreground = 'Green'
        $ResultAdd.Text = "User $NewUserUsername has been created successfully."

        $FirstNameAdd.Text = "";
        $LastNameAdd.Text = "";
        $UsernameAdd.Text = "";
        $EmailAdd.Text = "";
        $PasswordAdd.Password = "";
    } catch {
        $ResultAdd.Foreground = 'Red'
        $ResultAdd.Text = "Error: Failed to create user $NewUserUsername. Error details: $_"
    }
}

function Update-UserList {
    # Get all users from Active Directory
    $Users = Get-ADUser -Filter * -Properties Name, SamAccountName, EmailAddress, ObjectGUID -Server $DomainController -Credential $Credential

    # Create a list of UserListItem objects
    $UserListItems = New-Object System.Collections.ObjectModel.ObservableCollection[UserListItem]

    # Populate the list with the user data
    foreach ($User in $Users) {
        $UserListItem = New-Object UserListItem
        $UserListItem.Name = $User.Name
        $UserListItem.SamAccountName = $User.SamAccountName
        $UserListItem.EmailAddress = $User.EmailAddress
        $UserListItem.ObjectGUID = $User.ObjectGUID
        $UserListItems.Add($UserListItem)
    }

    # Update the DataGrid's ItemsSource
    $UserList.ItemsSource = $UserListItems
}

function EditMenuItem_Click {
    # Get the selected user from the DataGrid
    $SelectedUser = $UserList.Tag
    $User = Get-ADUser -Filter "SamAccountName -like '$($SelectedUser.SamAccountName)'" -Properties GivenName, Surname, SamAccountName, EmailAddress, ObjectGUID -Server $DomainController -Credential $Credential

    # Check if a user is selected
    if ($null -ne $User) {
        $global:EditingID = $User.ObjectGUID

        $UserEdit.Visibility = 'Visible'
        $TabControl.Items[1].IsSelected = $false

        $FirstNameEdit.Text = $User.GivenName;
        $LastNameEdit.Text = $User.Surname;
        $UsernameEdit.Text = $User.SamAccountName;
        $EmailEdit.Text = $User.EmailAddress;
    } else {
        [System.Windows.MessageBox]::Show("Please select a user to edit.", "No User Selected", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }

}

function DeleteMenuItem_Click {
    # Get the selected user from the DataGrid
    $SelectedUser = $UserList.Tag

    # Check if a user is selected
    if ($null -ne $SelectedUser) {
        # Confirm the delete action with the user
        $Result = [System.Windows.MessageBox]::Show("Are you sure you want to delete $($SelectedUser.Name)?", "Confirm Delete", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)

        if ($Result -eq "Yes") {
            # Remove the selected user from Active Directory
            try {
                Remove-ADUser -Identity $SelectedUser.ObjectGUID -Server $DomainController -Credential $Credential -Confirm:$false
                Update-UserList # Update the user list
                [System.Windows.MessageBox]::Show("User $($SelectedUser.Name) has been deleted.", "User Deleted", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            } catch {
                [System.Windows.MessageBox]::Show("Error deleting user $($SelectedUser.Name): $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        }
    } else {
        [System.Windows.MessageBox]::Show("Please select a user to delete.", "No User Selected", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }
}



# Add event handler for the Submit button
$ButtonAdd.Add_Click({ Add-NewADUser })
$ButtonEdit.Add_Click({ Edit-ADUser })

# Add event handlers
$DeleteMenuItem.Add_Click({DeleteMenuItem_Click})
$EditMenuItem.Add_Click({EditMenuItem_Click})
$UserList.Add_SelectionChanged({UserList_SelectionChanged})

# Show the window
$Window.ShowDialog() | Out-Null
