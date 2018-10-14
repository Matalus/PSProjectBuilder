Function FileSerializer ($file){
    $RawFile = Get-Content $file

    $NewString = ''
    ForEach($line in $RawFile){
        $NewString += "`n$line"
    }
    $NewString
}

$RunDir = split-path -parent $MyInvocation.MyCommand.Definition

$path = "$RunDir\Templates\Template.ps1"

$String = FileSerializer -file $path

$JSON = [PSCustomObject]@{
    String = $String
}

$JSON | ConvertTo-Json | Set-Content $RunDir\test.json -Force

$Obj = (Get-Content $RunDir\test.json) -join "`n" | ConvertFrom-Json
$Obj.String | Out-File .\testFile.ps1 -Force
