##Auto-Generated using "PSProject Builder" Created by Matt Hamende 2018
#######################################################################
#Description: generates wireframe powershell projects
#Features:
## Define ScriptRoot
## Standard Function Libraries
## PSModule Prerequities Loader
## JSON Config File
########################################################################

#Set Default Error Handling - Set to Continue for Production
$ErrorActionPreference = "Stop"

#Define Logger Function
Function Log($message) {
    "$(Get-Date -Format u) | $message"
}

#Define Script Root for relative paths
$RunDir = split-path -parent $MyInvocation.MyCommand.Definition
Log "Setting Location to: $RunDir"
Set-Location $RunDir # Sets directory

#Imports Function Library
Log "Importing Modules"
Try {
    Remove-Module Functions -ErrorAction SilentlyContinue
}
Catch {}
Try {
    Import-Module "$RunDir\Modules\Functions.psm1" -DisableNameChecking -ErrorAction SilentlyContinue
}
Catch { $_ }

#Load Config
Log "Loading Config"
$Config = (Get-Content "$RunDir\config.json") -join "`n" | ConvertFrom-Json

#Load Prerequisites
Prereqs -config $Config

## Script Below this line #######################################################