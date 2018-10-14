# NewProject.ps1 -- Run to Build New Projects From Template
#Define Run Directory
$RunDir = split-path -parent $MyInvocation.MyCommand.Definition

#Common Logger Function
Function Log($message) {
    "$(Get-Date -Format u) | $message"
}


#Uncomment to Serialize new file
Function FileSerializer ($file){
    $RawFile = Get-Content $file

    $NewString = ''
    ForEach($line in $RawFile){
        $NewString += "`n$line"
    }
    $NewString
}

Log "Serializing Template Files"
$Template = FileSerializer -file "$RunDir\Templates\Template.ps1"
$Function = FileSerializer -file "$RunDir\Templates\Full_Library.psm1"


$JSON = [PSCustomObject]@{
    ScriptTemplate = $Template
    FunctionsTemplate = $Function
    ConfigTemplate = '{"PSModule": {
        "Repository": "http://www.powershellgallery.com",
        "Modules": [
            "PowerShellGet",
            "Invoke-SqlCmd2",
            "PSObjectifier"
        ]
    }}'
}

Log "Exporting JSON"
$JSON | ConvertTo-Json | Set-Content $RunDir\templates\template.json -Force
#
#Load Template
Log "Loading Config..."
$Config = (Get-Content "$RunDir\Templates\template.json") -join "`n" | ConvertFrom-Json

$ProjectName = Read-Host -Prompt "Enter Project Name"

#Create Project Root
Log "Creating Project Root..."
if(-not (Test-Path $RunDir\$ProjectName)){
    $ProjectDir = New-Item -ItemType Directory -Path $RunDir\..\$ProjectName
}

#Create Temp Dir
Log "Creating Temp Directory"
if(-not (Test-Path $ProjectDir\Temp)){
    $Temp = New-Item -ItemType Directory -Path $ProjectDir\Temp
}

#Create Module Dir
Log "Creating Modules Directory"
if(-not (Test-Path $ProjectDir\Modules)){
    $Modules = New-Item -ItemType Directory -Path $ProjectDir\Modules
}
Log "Creating New Functions Library"
$Config.FunctionsTemplate | Out-File $Modules\Functions.psm1 -Force

#Create Main Script
Log "Creating $($ProjectName).ps1"
$Config.ScriptTemplate | Out-File $ProjectDir\$ProjectName.ps1 -Force

#Create Config File
Log "Creating Config File..."
$Config.ConfigTemplate | Out-File $ProjectDir\config.json -Force