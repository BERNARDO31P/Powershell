# WPF-Assemblys laden
# Get-ChildItem wird verwendet, um alle Dateien mit dem Namen Common*.PS1 im Verzeichnis $PSScriptRoot zu finden.
# ForEach-Object wird dann verwendet, um jede gefundene Datei auszuführen.
Get-ChildItem -Path $PSScriptRoot -Filter Common*.PS1 | ForEach-Object {. ($_.FullName)}

# Erstellt ein neues Fenster mit der XAML-Datei "PowerShell-AD.xaml" im Verzeichnis $PSScriptRoot.
$Window = New-Window -XamlFile "$PSScriptRoot\PowerShell-AD.xaml"

# Setzt die aktuelle Kultur auf die Kultur des aktuellen Threads.
Set-CurrentCulture

# Initialisiert die globale Variable $EditingID mit dem Wert null.
$global:EditingID = $null;

# Definiert eine Klasse namens UserListItem mit den Eigenschaften Surname, Name, SamAccountName, EmailAddress und ObjectGUID.
class UserListItem {
    [string]$Surname
    [string]$Name
    [string]$SamAccountName
    [string]$EmailAddress
    [Guid]$ObjectGUID
}

# Fügt dem TabControl ein Event hinzu, das bei Änderung der Auswahl ausgelöst wird.
# Wenn der ausgewählte Index 1 ist, wird die Funktion Update-UserList aufgerufen.
# Wenn das zweite Element im TabControl ausgewählt ist, wird die Sichtbarkeit von $UserEdit auf 'Hidden' gesetzt.
$TabControl.Add_SelectionChanged({
    if ($TabControl.SelectedIndex -eq 1) {
        Update-UserList
    }

    if ($TabControl.SelectedItem -ne $null) {
        $UserEdit.Visibility = 'Hidden'
    }
})

# API-Anmeldeinformationen und Details zum Domaincontroller
# Definiert die Variablen $Username, $Password und $DomainController.
$Username = "Administrator"
$Password = ConvertTo-SecureString "Berni123!!" -AsPlainText -Force
$DomainController = "192.168.32.15"

# Erstellt ein PSCredential-Objekt mit $Username und $Password, um sich beim Domaincontroller zu authentifizieren.
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $Password

# Funktion, die ausgelöst wird, wenn die Auswahl in der Benutzerliste geändert wird.
function UserList_SelectionChanged
{
    # Der ausgewählte Benutzer wird in der Variable $SelectedUser gespeichert.
    $SelectedUser = $UserList.SelectedItem
    # Wenn $SelectedUser nicht null ist, wird der Wert von $SelectedUser in das Tag-Feld von $UserList gespeichert.
    if ($null -ne $SelectedUser)
    {
        $UserList.Tag = $SelectedUser
    }
}

# Funktion zum Bearbeiten eines Benutzers in Active Directory
function Edit-ADUser {
    # Importiert das Active Directory Modul
    Import-Module ActiveDirectory

    # Definiert die Domain
    $Domain = "kaesereiag-bno.local"

    # Benutzerdetails
    $NewUserFirstName = $FirstNameEdit.text
    $NewUserLastName = $LastNameEdit.Text
    $NewUserUsername = $UsernameEdit.Text
    $NewUserEmail = $EmailEdit.Text
    $NewUserPrincipalName = "$NewUserUsername@$Domain"
    $NewUserName = "$NewUserFirstName $NewUserLastName"

    # Bearbeitet den neuen Benutzer
    try {
        # Setzt die Eigenschaften des Benutzers in Active Directory
        Set-ADUser -Identity $global:EditingID -Replace @{userprincipalname="$NewUserPrincipalName";givenname="$NewUserFirstName";sn="$NewUserLastName";samaccountname="$NewUserUsername";mail="$NewUserEmail"} -Server $DomainController -Credential $Credential
        # Benennt das AD-Objekt um
        Rename-ADObject -Identity $global:EditingID -NewName $NewUserName -Server $DomainController -Credential $Credential

        # Setzt den Text und die Farbe des Ergebnisfeldes
        $ResultEdit.Foreground = 'Green'
        $ResultEdit.Text = "User $NewUserUsername has been edited successfully."

        # Leert die Eingabefelder
        $FirstNameEdit.Text = "";
        $LastNameEdit.Text = "";
        $UsernameEdit.Text = "";
        $EmailEdit.Text = "";
    } catch {
        # Setzt den Text und die Farbe des Ergebnisfeldes im Fehlerfall
        $ResultEdit.Foreground = 'Red'
        $ResultEdit.Text = "Error: Failed to edit user $NewUserUsername. Error details: $_"
    }
}

# Funktion zum Erstellen eines neuen Benutzers in Active Directory
function Add-NewADUser {
    # Importiert das Active Directory Modul
    Import-Module ActiveDirectory

    # Definiert die Domain und die Organisationseinheit
    $Domain = "kaesereiag-bno.local"
    $OrganizationalUnit = "CN=Users,DC=kaesereiag-bno,DC=local"

    # Benutzerdetails
    $NewUserFirstName = $FirstNameAdd.text
    $NewUserLastName = $LastNameAdd.Text
    $NewUserUsername = $UsernameAdd.Text
    $NewUserEmail = $EmailAdd.Text
    $NewUserPassword = ConvertTo-SecureString $PasswordAdd.Password -AsPlainText -Force

    # Erstellt den neuen Benutzer
    try {
        # Erstellt einen neuen Benutzer in Active Directory
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

        # Setzt den Text und die Farbe des Ergebnisfeldes
        $ResultAdd.Foreground = 'Green'
        $ResultAdd.Text = "User $NewUserUsername has been created successfully."

        # Leert die Eingabefelder
        $FirstNameAdd.Text = "";
        $LastNameAdd.Text = "";
        $UsernameAdd.Text = "";
        $EmailAdd.Text = "";
        $PasswordAdd.Password = "";
    } catch {
        # Setzt den Text und die Farbe des Ergebnisfeldes im Fehlerfall
        $ResultAdd.Foreground = 'Red'
        $ResultAdd.Text = "Error: Failed to create user $NewUserUsername. Error details: $_"
    }
}

# Funktion zum Aktualisieren der Benutzerliste
function Update-UserList {
    # Holt alle Benutzer aus Active Directory
    $Users = Get-ADUser -Filter * -Properties Name, SamAccountName, EmailAddress, ObjectGUID -Server $DomainController -Credential $Credential

    # Erstellt eine Liste von UserListItem-Objekten
    $UserListItems = New-Object System.Collections.ObjectModel.ObservableCollection[UserListItem]

    # Füllt die Liste mit den Benutzerdaten
    foreach ($User in $Users) {
        $UserListItem = New-Object UserListItem
        $UserListItem.Name = $User.Name
        $UserListItem.SamAccountName = $User.SamAccountName
        $UserListItem.EmailAddress = $User.EmailAddress
        $UserListItem.ObjectGUID = $User.ObjectGUID
        $UserListItems.Add($UserListItem)
    }

    # Aktualisiert die ItemsSource des DataGrids
    $UserList.ItemsSource = $UserListItems
}

# Funktion, die aufgerufen wird, wenn das Kontextmenü "Bearbeiten" angeklickt wird
function EditMenuItem_Click {
    # Holt den ausgewählten Benutzer aus dem DataGrid
    $SelectedUser = $UserList.Tag
    $User = Get-ADUser -Filter "SamAccountName -like '$($SelectedUser.SamAccountName)'" -Properties GivenName, Surname, SamAccountName, EmailAddress, ObjectGUID -Server $DomainController -Credential $Credential

    # Überprüft, ob ein Benutzer ausgewählt ist
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

# Funktion, die aufgerufen wird, wenn das Kontextmenü "Löschen" angeklickt wird
function DeleteMenuItem_Click {
    # Holt den ausgewählten Benutzer aus dem DataGrid
    $SelectedUser = $UserList.Tag

    # Überprüft, ob ein Benutzer ausgewählt ist
    if ($null -ne $SelectedUser) {
        # Bestätigt die Löschaktion mit dem Benutzer
        $Result = [System.Windows.MessageBox]::Show("Are you sure you want to delete $($SelectedUser.Name)?", "Confirm Delete", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)

        if ($Result -eq "Yes") {
            # Entfernt den ausgewählten Benutzer aus Active Directory
            try {
                Remove-ADUser -Identity $SelectedUser.ObjectGUID -Server $DomainController -Credential $Credential -Confirm:$false
                Update-UserList # Aktualisiert die Benutzerliste
                [System.Windows.MessageBox]::Show("User $($SelectedUser.Name) has been deleted.", "User Deleted", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            } catch {
                [System.Windows.MessageBox]::Show("Error deleting user $($SelectedUser.Name): $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        }
    } else {
        [System.Windows.MessageBox]::Show("Please select a user to delete.", "No User Selected", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }
}

# Fügt einen Ereignishandler für den Submit-Button hinzu
$ButtonAdd.Add_Click({ Add-NewADUser })
$ButtonEdit.Add_Click({ Edit-ADUser })

# Fügt Ereignishandler hinzu
$DeleteMenuItem.Add_Click({DeleteMenuItem_Click})
$EditMenuItem.Add_Click({EditMenuItem_Click})
$UserList.Add_SelectionChanged({UserList_SelectionChanged})

# Zeigt das Fenster an
$Window.ShowDialog() | Out-Null
