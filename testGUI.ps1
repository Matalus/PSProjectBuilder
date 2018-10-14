<# This form was created using POSHGUI.com  a free online gui designer for PowerShell
.NAME
    PSProject.Builder
.SYNOPSIS
    Builds PSProjects for quick deployments
#>

Import-Module .\Modules\Library.psm1 -ErrorAction Continue
$commands = Get-Command -Module Library

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$Script:DirectoryChecked = @()
$Script:ModulesChecked = @()
$Script:FunctionsChecked = @()

#region begin GUI{ 

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '340,222'
    $Form.text                       = "PSProjectBuilder"
    $Form.BackColor                  = "#4a4a4a"
    $Form.TopMost                    = $true
    $Form.AutoScale                  = $true
    $Form.AutoSize                   = $true
    $Form.AutoSizeMode               = "GrowAndShrink"
    
    $Label2                          = New-Object system.Windows.Forms.Label
    $Label2.text                     = "Select Project Options"
    $Label2.AutoSize                 = $true
    $Label2.width                    = 25
    $Label2.height                   = 10
    $Label2.location                 = New-Object System.Drawing.Point(22,52)
    $Label2.Font                     = 'Microsoft Sans Serif,10,style=Bold'
    $Label2.ForeColor                = "#b8e986"
    
    $Label3                          = New-Object system.Windows.Forms.Label
    $Label3.text                     = "Directory Options:"
    $Label3.AutoSize                 = $true
    $Label3.width                    = 25
    $Label3.height                   = 10
    $Label3.location                 = New-Object System.Drawing.Point(22,153)
    $Label3.Font                     = 'Microsoft Sans Serif,10,style=Bold'
    $Label3.ForeColor                = "#ffffff"
    
    $Label4                          = New-Object system.Windows.Forms.Label
    $Label4.text                     = "Functions:"
    $Label4.AutoSize                 = $true
    $Label4.width                    = 25
    $Label4.height                   = 10
    $Label4.location                 = New-Object System.Drawing.Point(212,152)
    $Label4.Font                     = 'Microsoft Sans Serif,10,style=Bold'
    $Label4.ForeColor                = "#ffffff"
    
    $Label5                          = New-Object system.Windows.Forms.Label
    $Label5.text                     = "Prerequisites:"
    $Label5.AutoSize                 = $true
    $Label5.width                    = 25
    $Label5.height                   = 10
    $Label5.location                 = New-Object System.Drawing.Point(23,226)
    $Label5.Font                     = 'Microsoft Sans Serif,10,style=Bold'
    $Label5.ForeColor                = "#ffffff"
    
    $CheckBox1                       = New-Object system.Windows.Forms.CheckBox
    $CheckBox1.text                  = "Temp"
    $CheckBox1.AutoSize              = $false
    $CheckBox1.width                 = 95
    $CheckBox1.height                = 20
    $CheckBox1.location              = New-Object System.Drawing.Point(23,175)
    $CheckBox1.Font                  = 'Microsoft Sans Serif,10'
    $CheckBox1.ForeColor             = "#f5a623"
    $Checkbox1.Add_CheckStateChanged({
        Write-Host "$($Checkbox1.Text): $($Checkbox1.CheckState)"
        if ($Checkbox1.CheckState -eq "Checked"){
            $obj =  [PSCustomObject]@{
                Name = $Checkbox1.Text
            }
            $Script:DirectoryChecked += $obj
        } elseif ($Checkbox1.CheckState -eq "Unchecked"){
            $Script:DirectoryChecked = $Script:DirectoryChecked | Where-Object {
                $_.Name -ne $Checkbox1.text
            }
        } else{
            #do nothing
        }   
    })

    
    $CheckBox2                       = New-Object system.Windows.Forms.CheckBox
    $CheckBox2.text                  = "Modules"
    $CheckBox2.AutoSize              = $false
    $CheckBox2.width                 = 95
    $CheckBox2.height                = 20
    $CheckBox2.location              = New-Object System.Drawing.Point(23,199)
    $CheckBox2.Font                  = 'Microsoft Sans Serif,10'
    $CheckBox2.ForeColor             = "#f5a623"
    $CheckBox2.Add_CheckStateChanged({
        Write-Host "$($CheckBox2.Text): $($CheckBox2.CheckState)"
        if ($checkbox2.CheckState -eq "Checked"){
            $obj = [PSCustomObject]@{
                Name = $checkbox2.Text
            }
            $Script:DirectoryChecked += $obj
        } elseif ($checkbox2.CheckState -eq "Unchecked"){
            $Script:DirectoryChecked = $Script:DirectoryChecked | Where-Object {
                $_.Name -ne $checkbox2.text
            }
        } else{
            #do nothing
        }   
    })

    
    $CheckBox3                       = New-Object system.Windows.Forms.CheckBox
    $CheckBox3.text                  = "Invoke-SqlCmd2"
    $CheckBox3.AutoSize              = $false
    $CheckBox3.width                 = 174
    $CheckBox3.height                = 20
    $CheckBox3.location              = New-Object System.Drawing.Point(23,247)
    $CheckBox3.Font                  = 'Microsoft Sans Serif,10'
    $CheckBox3.ForeColor             = "#f5a623"
    
    $PSProjectBuilder                = New-Object system.Windows.Forms.Label
    $PSProjectBuilder.text           = "PSProjectBuilder"
    $PSProjectBuilder.AutoSize       = $true
    $PSProjectBuilder.width          = 25
    $PSProjectBuilder.height         = 10
    $PSProjectBuilder.location       = New-Object System.Drawing.Point(22,18)
    $PSProjectBuilder.Font           = 'Microsoft Sans Serif,20'
    $PSProjectBuilder.ForeColor      = "#b8e986"
    
    $Button1                         = New-Object system.Windows.Forms.Button
    $Button1.text                    = "Build Project"
    $Button1.width                   = 319
    $Button1.height                  = 30
    $Button1.location                = New-Object System.Drawing.Point(23,73)
    $Button1.Font                    = 'Segoe UI,11,style=Bold'
    $Button1.ForeColor               = "#b8e986"
    
    $ListView1                       = New-Object system.Windows.Forms.ListView
    $ListView1.text                  = "listView"
    $ListView1.width                 = 321
    $ListView1.height                = 30
    $ListView1.location              = New-Object System.Drawing.Point(23,112)

    $TextBox1                        = New-Object system.Windows.Forms.TextBox
    $TextBox1.multiline              = $false
    $TextBox1.text                   = "Enter Project Name"
    $TextBox1.BackColor              = "#000000"
    $TextBox1.width                  = 320
    $TextBox1.height                 = 20
    $TextBox1.location               = New-Object System.Drawing.Point(23,118)
    $TextBox1.Font                   = 'Microsoft Sans Serif,10'
    $TextBox1.ForeColor              = "#ffffff"

            

    $controls = @($Label2,$Label3,$Label4,$Label5,$CheckBox1,$CheckBox2,$CheckBox3,$PSProjectBuilder,$Button1,$ListView1,$TextBox1)

$xloc = 205
$yloc = 175
ForEach($Command in $commands){
    New-Variable -Name "$($command.name)" -Value $(New-Object System.Windows.Forms.CheckBox) -Force
    $(Get-Variable -Name "$($command.name)").Value.text = "$($command.name)"
    $(Get-Variable -Name "$($command.name)").Value.AutoSize =  $false
    $(Get-Variable -Name "$($command.name)").Value.width = 200  
    $(Get-Variable -Name "$($command.name)").Value.Height = 20 
    $(Get-Variable -Name "$($command.name)").Value.location = New-Object System.Drawing.Point($xloc,$yloc)
    $(Get-Variable -Name "$($command.name)").Value.Font = 'Microsoft Sans Serif,10'
    $(Get-Variable -Name "$($command.name)").Value.ForeColor = "#f5a623"
    $(Get-Variable -Name "$($command.name)").Value.Add_CheckStateChanged({
        Write-Host "$($this.Text): $($this.CheckState)"
        if ($this.CheckState -eq "Checked"){
            
            $obj =  [PSCustomObject]@{
                Name = $this.text
            }
            $Script:FunctionsChecked += $obj
        } elseif ($this.CheckState -eq "Unchecked"){
            $Script:FunctionsChecked = $Script:FunctionsChecked | Where-Object {
                $_.Name -ne $this.text
            }
        } else{
            #do nothing
        }   
    })
    $controls += $(Get-Variable -Name "$($command.name)").Value
    $yloc += 20         
}

$Form.controls.AddRange($controls)

#region gui events {
#endregion events }

#endregion GUI }




[void]$Form.ShowDialog()