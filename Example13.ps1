###########
#  Learn how to build Material Design based PowerShell apps
#  --------------------
#  Example13: Introducing Theme
#  --------------------
#  Avi Coren (c)
#  Blog     - https://avicoren.wixsite.com/powershell
#  Github   - https://github.com/DrHalfBaked/PowerShell.MaterialDesign
#  LinkedIn - https://www.linkedin.com/in/avi-coren-6647b2105/
#
Get-ChildItem -Path $PSScriptRoot -Filter Common*.PS1 | ForEach-Object {. ($_.FullName)}

$Window = New-Window -XamlFile "$PSScriptRoot\Example13.xaml"
$ConfigFilePath = "$PSScriptRoot\Example.config"
$ConfigXML = Open-File -Path $ConfigFilePath -FileType xml

Set-Theme -Window $Window -PrimaryColor $ConfigXML.Parameters.Settings.Theme.PrimaryColor -SecondaryColor $ConfigXML.Parameters.Settings.Theme.SecondaryColor -ThemeMode $ConfigXML.Parameters.Settings.Theme.Mode
$LeftDrawer_PrimaryColor_LstBox.Itemssource = $ThemePrimaryColors
$LeftDrawer_SecondaryColor_LstBox.Itemssource = $ThemeSecondaryColors
$LeftDrawer_ThemeMode_TglBtn.IsChecked = if((Get-ThemeMode -Window $Window) -eq "Dark") {$true} else {$false}

$Bitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
$Bitmap.BeginInit()
$Bitmap.UriSource = "$PSScriptRoot/Resources/Images/mr_bean_tiny.jpg"
$Bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$Bitmap.EndInit()
$LeftDrawer_Chip_Img.Source = $Bitmap
$LeftDrawer_Chip_Img.RenderTransformOrigin=".5,.5"
$LeftDrawer_Chip_Img.RenderTransform.ScaleX = 1.1
$LeftDrawer_Chip_Img.RenderTransform.ScaleY = 1.1

[scriptblock]$OnClosingLeftDrawer = {
    $DrawerHost.IsLeftDrawerOpen = $false
    $LeftDrawer_Open_TglBtn.IsChecked = $false
    $LeftDrawer_Open_TglBtn.Visibility="Visible"
}

$DrawerHost.add_DrawerClosing($OnClosingLeftDrawer)

$LeftDrawer_Close_TglBtn.add_Click($OnClosingLeftDrawer)

$LeftDrawer_Open_TglBtn.add_Click({ 
    $DrawerHost.IsLeftDrawerOpen = $true
    $LeftDrawer_Close_TglBtn.IsChecked = $true
    $LeftDrawer_Open_TglBtn.Visibility="Hidden"
})

$LeftDrawer_Menu_LstBox.add_SelectionChanged({ 
    switch ($LeftDrawer_Menu_LstBox.SelectedItem.Content) {
        "Settings"  {
                        Set-NavigationRailTab -NavigationRail $NavRail -TabName "Settings"
                    }

        "Open File" {
                        $OpeneFilePath = Get-OpenFilePath -InitialDirectory $InitialDirectory  -Filter $FileFilter 
                        if ($OpeneFilePath) {
                            New-Snackbar -Snackbar $MainSnackbar -Text "You selected $OpeneFilePath"
                        }
                    }

        "Exit"      {
                        $Window.Close()
                    }
    }
    $DrawerHost.IsLeftDrawerOpen = $false
    $LeftDrawer_Menu_LstBox.SelectedIndex = -1 
})

$NavRail.add_SelectionChanged({ 
    New-Snackbar -Snackbar $MainSnackbar -Text "You selected the $(Get-NavigationRailSelectedTabName -NavigationRail $NavRail) page" 
})

$LeftDrawer_ThemeMode_TglBtn.Add_Click({ 
        $ThemeMode = if ($LeftDrawer_ThemeMode_TglBtn.IsChecked -eq $true) {"Dark"} else {"Light"}
        Set-Theme -Window $Window -ThemeMode $ThemeMode
}) 

$LeftDrawer_PrimaryColor_LstBox.Add_SelectionChanged( {
    $this | Out-Host
    $_  | Out-Host
    if ($this.IsMouseCaptured ) {   # this condition prvents the event to be triggered when listbox selection is changed programatically
        Set-Theme -Window $Window -PrimaryColor $LeftDrawer_PrimaryColor_LstBox.SelectedValue
    }
})
   
$LeftDrawer_SecondaryColor_LstBox.Add_SelectionChanged( {
    if ($this.IsMouseCaptured ) {   # this condition prvents the event to be triggered when listbox selection is changed programatically
        Set-Theme -Window $Window -SecondaryColor $LeftDrawer_SecondaryColor_LstBox.SelectedValue
    }
})   

$LeftDrawer_Theme_Undo_Btn.Add_Click( {
    Set-Theme -Window $Window -PrimaryColor $ConfigXML.Parameters.Settings.Theme.PrimaryColor -SecondaryColor $ConfigXML.Parameters.Settings.Theme.SecondaryColor -ThemeMode $ConfigXML.Parameters.Settings.Theme.Mode
    $LeftDrawer_ThemeMode_TglBtn.IsChecked = if((Get-ThemeMode -Window $Window) -eq "Dark") {$true} else {$false}
    $LeftDrawer_PrimaryColor_LstBox.SelectedIndex = $ThemePrimaryColors.indexof($ConfigXML.Parameters.Settings.Theme.PrimaryColor)
    $LeftDrawer_SecondaryColor_LstBox.SelectedIndex = $ThemeSecondaryColors.indexof($ConfigXML.Parameters.Settings.Theme.SecondaryColor)
})

$LeftDrawer_Theme_Apply_Btn.Add_Click( {

    $IsChanged = $false
    if (($LeftDrawer_PrimaryColor_LstBox.SelectedValue) -and $ConfigXML.Parameters.Settings.Theme.PrimaryColor -ne $LeftDrawer_PrimaryColor_LstBox.SelectedValue) {
        $IsChanged = $true
        $ConfigXML.Parameters.Settings.Theme.PrimaryColor = $LeftDrawer_PrimaryColor_LstBox.SelectedValue
    }
    if (($LeftDrawer_SecondaryColor_LstBox.SelectedValue) -and $ConfigXML.Parameters.Settings.Theme.SecondaryColor -ne $LeftDrawer_SecondaryColor_LstBox.SelectedValue) {
        $IsChanged = $true
        $ConfigXML.Parameters.Settings.Theme.SecondaryColor = $LeftDrawer_SecondaryColor_LstBox.SelectedValue
    }
    if (($ConfigXML.Parameters.Settings.Theme.Mode -eq "Light") -and ($LeftDrawer_ThemeMode_TglBtn.IsChecked)) {
        $IsChanged = $true
        $ConfigXML.Parameters.Settings.Theme.Mode = "Dark"
    }
    if (($ConfigXML.Parameters.Settings.Theme.Mode -eq "Dark") -and (!$LeftDrawer_ThemeMode_TglBtn.IsChecked)) {
        $IsChanged = $true
        $ConfigXML.Parameters.Settings.Theme.Mode = "Light"
    }
    if ($IsChanged) {
        try {
            $ConfigXML.Save($ConfigFilePath)
            New-Snackbar -Snackbar $MainSnackbar -Text "Theme was successfully saved"
        }
        catch {
            New-Snackbar -Snackbar $MainSnackbar -Text  $_[0] -ButtonCaption "OK"
            return
        }
    }  
})


$Window.ShowDialog() | out-null