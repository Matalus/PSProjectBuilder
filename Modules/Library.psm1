#Library of Functions related to Cross Reference Rebuild

#Parses tabs from Excel file and converts to CSV for import into PowerShell
Function ExportWSToCSV ($excelFile, $csvLoc) {
    $excelFile
    $E = New-Object -ComObject Excel.Application
    $E.Visible = $false
    $E.DisplayAlerts = $false
    $wb = $E.Workbooks.Open($excelFile.FullName)
    foreach ($ws in $wb.Worksheets) {
        $n = $ws.Name
        "Saving to: $csvLoc\$($excelFile.BaseName)_$n.csv"
        $ws.SaveAs("$csvLoc\$($excelFile.BaseName)_$n.csv", 6)
    }

    $E.Quit()
}

Export-ModuleMember ExportWSToCSV

Function CreateInsertRow ($Row, $Index, $SiteName) {
    $Ext = $Index[$Row.Full_Path]
    $Insert = @"
        `r
        --Internal:$($row.Device_Sensor_ID)
        --External: $($Ext.Device_Sensor_ID)
        --Path: $($row.Full_Path)
        INSERT INTO [dbo].[External_Device_Sensor_Xref]
           ([Device_Sensor_ID]
           ,[External_Device_Sensor_ID]
           ,[Last_Updated_By]
           ,[Last_Update_Date]
           ,[Site_Name]
           ,[Last_Updated_Document_ID])
        VALUES
           ('$($row.Device_Sensor_ID)'
           ,'$($Ext.Device_Sensor_ID)'
           ,616
           ,SYSUTCDATETIME()
           ,'$($SiteName)'
           ,NULL)
    GO
"@
    $Insert
}

Export-ModuleMember CreateInsertRow

Function SQLQuery($query, $dbconfig) {    
    #Determines if Credentials are implicit or explict and creates cred object
    if ($dbconfig.user.length -ge 1) {
        $pass = ConvertTo-SecureString $dbconfig.pass -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential(
            $dbconfig.user, 
            $pass
        )
    }

    $Database = $dbconfig.Database
    $ServerInstance = $dbconfig.ServerInstance

    if ($cred) {
        $Params = @{
            Database       = $Database
            ServerInstance = $ServerInstance
            QueryTimeout   = 60        
            #OutputSqlErrors = $true
            Query          = $query
            Username       = $dbconfig.user
            Password       = $dbconfig.pass

        }
    }
    else {
        $Params = @{
            Database       = $Database
            ServerInstance = $ServerInstance
            QueryTimeout   = 60        
            #OutputSqlErrors = $true
            Query          = $query
        }
    }
    Try {
        Invoke-Sqlcmd2 @Params
    }
    Catch {
        Write-Host "Error Executing SQL Query : `n `n Database: $($Database) `n ServerInstance: $($ServerInstance) `n `n $($query) `n" 
        Write-Error $_ -ErrorAction Stop 
    }
}

Export-ModuleMember SQLQuery

Function CPPQuery () {
    $Query = @"
SELECT
CPP.*
FROM dbo.Cache_Partition_Paths CPP
    INNER JOIN dbo.Device_Sensors DS
    ON DS.Device_Sensor_ID = CPP.Device_Sensor_ID
        AND CPP.Path_Type = 0
WHERE DS.Is_Deleted = 0
"@
    $Query
}

Export-ModuleMember CPPQuery

Function XREFQuery () {
    $Query = @"
    SELECT *
    FROM dbo.External_Device_Sensor_Xref    
"@
    $Query
}

Export-ModuleMember XREFQuery

Function LocationsQuery () {
    $Query = @"
    SELECT *
    FROM dbo.Locations
"@
    $Query
}

Export-ModuleMember LocationsQuery

Function DSQuery ($partitions) {
    $Query = @"
    SELECT DS.*
    FROM dbo.Device_Sensors DS
    INNER JOIN dbo.Devices D
        ON DS.Device_ID = D.Device_ID
    INNER JOIN dbo.Partitions P 
        ON D.Partition_ID = P.Partition_ID
    INNER JOIN dbo.Partition_Transitive_Closure PTC 
        ON P.Parent_Partition_ID = PTC.Child_Partition_ID
    WHERE DS.Is_Deleted = 0
    AND PTC.Parent_Partition_ID IN ($partitions)    
"@
    $Query
}

Export-ModuleMember DSQuery

Function Prereqs ($config) {
    $Repository = $config.PSModule.Repository
    Try {
        $Ping = $null
        $Ping = (Invoke-WebRequest -Uri $Repository).StatusCode
    }
    Catch { $Ping = $_ }
    $Modules = $config.PSModule.Modules
    
    if ($Ping.GetType().name -eq "ErrorRecord" -or $PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host -ForegroundColor Cyan "Error Encountered Connecting to Repository : $Repository"
        Write-Host -ForegroundColor Red $Ping.Exception
        ""
        
        if (Test-Path -Path ".\modules") {
            $modulepath = ";$scriptDir\modules"
            if(-not ($env:PSModulePath -like $modulepath)){
                Write-Host "adding  to PSModulePath"
                $env:PSModulePath += $modulepath
            }

            Write-Host "Attempting to Load Modules from .\modules ..."

            ForEach ($Module in $Modules) {
                $installed = Get-Module -ListAvailable -Name $Module
                $loaded = Get-Module -Name $Module
                if ($installed -and $loaded) {
                    Write-Host -ForegroundColor Cyan "Module: $Module - Already Loaded"
                }
                else {
                    Write-Host -ForegroundColor Green "Module: $Module - Loading..."
                    Try {
                        Remove-Module $Module -Force -ErrorAction SilentlyContinue
                        Import-Module  ".\modules\$Module\$module.ps1"                                              
                    }
                    Catch {
                        Try {
                            Remove-Module $Module -Force -ErrorAction SilentlyContinue
                            Import-Module  ".\modules\$Module" 
                        }
                        Catch {$_}      
                    }
                    Get-Module $Module
                }
            }
        }

    }
    elseif ($Modules -eq $null -or $Modules.Count -le 0) {
        Write-Host -ForegroundColor Cyan "Error No Modules Listed in Config"
    }
    else {
        ForEach ($Module in $Modules) {
            $installed = Get-Module -ListAvailable -Name $Module
            $loaded = Get-Module -Name $Module
            if ($installed -and $loaded) {
                Write-Host -ForegroundColor Cyan "Module: $Module - Already Loaded"
            }
            elseif ($installed -and $loaded -ne $true) {
                Write-Host -ForegroundColor Green "Module: $Module - Loading..."
                Import-Module $Module
                Get-Module $Module
            }
            else {
                Write-Host -ForegroundColor Yellow "Module: $Module - Installing..."
                Install-Module $Module -Force -Repository PSGallery -Confirm:$false
                Import-Module $Module
                Get-Module $Module
            }
        }        
    }
    ""
}

Export-ModuleMember Prereqs

Function Merge-CSVFiles($CSVPath, $XLOutput) {
    $csvFiles = Get-ChildItem ("$CSVPath\*") -Include *.csv | Sort-Object -Descending
    $Excel = New-Object -ComObject excel.application 
    $Excel.visible = $false
    $Excel.sheetsInNewWorkbook = $csvFiles.Count
    $workbooks = $excel.Workbooks.Add()
    $CSVSheet = 1

    Foreach ($CSV in $Csvfiles) {
        $worksheets = $workbooks.worksheets
        $CSVFullPath = $CSV.FullName
        $SheetName = ($CSV.name -split "\.")[0]
        $worksheet = $worksheets.Item($CSVSheet)
        $worksheet.Name = $SheetName
        $TxtConnector = ("TEXT;" + $CSVFullPath)
        Log "Merging Worksheet $SheetName"
        $CellRef = $worksheet.Range("A1")
        $Connector = $worksheet.QueryTables.add($TxtConnector, $CellRef)
        $worksheet.QueryTables.item($Connector.name).TextFileCommaDelimiter = $True
        $worksheet.QueryTables.item($Connector.name).TextFileParseType = 1
        $worksheet.QueryTables.item($Connector.name).Refresh() | Out-Null
        $worksheet.QueryTables.item($Connector.name).delete()
        $worksheet.UsedRange.EntireColumn.AutoFit() | Out-Null
        $CSVSheet++
    }

    $workbooks.SaveAs($XLOutput, 51)
    $workbooks.Saved = $true
    $workbooks.Close()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbooks) | Out-Null
    $excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

Export-ModuleMember Merge-CSVFiles

Function ExportWSToCSV ($excelFile, $csvLoc) {
    $E = New-Object -ComObject Excel.Application
    $E.Visible = $false
    $E.DisplayAlerts = $false
    $wb = $E.Workbooks.Open($excelFile.FullName)
    foreach ($ws in $wb.Worksheets) {
        $n = $ws.Name
        "Saving to: .\$((get-item $csvLoc).name)\$($excelfile.Basename)_$n.csv"
        $ws.SaveAs("$csvLoc\$($excelfile.Basename)_$n.csv", 6)
    }
    ""
    $E.Quit()
}

Export-ModuleMember ExportWSToCSV

Function LoginUser ($config) {
    $user = $config.username
    $password = $config.password
    $URI = "$($config.WebHost)/$($config.LoginMethod)"
    $provider = Get-NetIPInterface | Where-Object { 
        $_.ConnectionState -eq "Connected" 
    } | Sort-Object InterfaceMetric | Select-Object -First 1
    $adapter = Get-NetAdapter | Where-Object { 
        $_.IfIndex -eq $Provider.IfIndex 
    }
    $JSON = $Config.JSONLoginUser
    $JSON.LoginName = $user
    $JSON.Password = $password
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    $JSON.MacAddresses = $adapter.MacAddress
    $JSON.ComputerName = $env:COMPUTERNAME
    $JSON.UserAgent = [System.Environment]::OSVersion.VersionString

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember LoginUser

Function GetSelectMethod ($config, $user, $service, $method) {
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONSelectMethod
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember GetSelectMethod

Function GetSensor ($config, $user, $sensor) {
    $service = $config.DeviceMethod
    $method = "SELECT_713"
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONSelectMethod
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    $JSON | Add-Member sensorID($sensor)

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember GetSensor


Function GetPartition ($config, $user, $partition) {
    $service = $config.PartitionMethod
    $method = "SELECT_103"
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONSelectMethod
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    $JSON | Add-Member partitionID($partition) -Force

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember GetPartition

Function GetDevices ($config, $user, $partition) {
    $Service = $config.DeviceMethod
    $Method = "SELECT_15003"
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONSelectMethod
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    $JSON | Add-Member -NotePropertyName "partitionID" -NotePropertyValue $partition -Force

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember GetDevices

Function GetDeviceProperties ($config, $user, $deviceID) {
    $Service = $config.DeviceMethod
    $Method = "SELECT_181"
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONSelectMethod
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    $JSON | Add-Member -NotePropertyName "deviceID" -NotePropertyValue $deviceID -Force

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember GetDeviceProperties

Function SetSensorType ($data, $config, $user) {
    #To do add logic to determine if sensor type cd is present in template
    $service = $config.DeviceMethod
    if ($data.Sensor_Type_CD -eq $Null -or $data.Sensor_Type_CD -eq "NULL") {
        $IsNew = $true
        $method = "AddDeviceSensorType"
        $data.Sensor_Type_CD = 0
    }
    else {
        $IsNew = $false
        $method = "ModifyDeviceSensorType"
    }
    #Set Rest connection params
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONSetSensorType
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    #Set Poco properties from template
    $JSON.poco.Sensor_Type_CD = if ($data.Sensor_Type_CD -eq $Null -or
        $data.Sensor_Type_CD -eq "NULL") {
        0
    }
    else {$data.Sensor_Type_CD}
    $JSON.poco.Device_Type_CD = [int]$data.Device_Type_CD
    $JSON.poco.Sensor_Name = $data.Sensor_Name
    $JSON.poco.Sensor_Short_Name = $data.Sensor_Short_Name
    if ($JSON.poco.Sensor_Short_Name.length -gt 15){
        Write-Host -ForegroundColor Yellow "Sensor_Short_Name: [$($data.Sensor_Short_Name)]LEN($($data.Sensor_Short_Name.length)) exceeds 15 char"
        Write-Error "Sensor_Short_Name: [$($data.Sensor_Short_Name)]LEN($($data.Sensor_Short_Name.length)) exceeds 15 char"
    }
    $JSON.poco.Measurement_Type_CD = if ($data.Measurement_Type_CD) {
        [int]$data.Measurement_Type_CD
    }
    else {
        ($Measurement_Types | Where-Object {
                $_.Measurement_Name -eq $data.Measurement_Type
            }).Measurement_Type_CD
        
    }
    if ($JSON.poco.Measurement_Type_CD -eq $Null){
        Write-Host -ForegroundColor Yellow "Error: unable to match measurement type: $($data.Measurement_Type)"
        Write-Error "Error: unable to match measurement type: $($data.Measurement_Type)"
    }
    $JSON.poco.Last_Update_date = "$([System.DateTime]::UtcNow.GetDateTimeFormats("O"))"
    $JSON.poco.Is_Deleted = [System.Convert]::ToBoolean($data.Is_Deleted)
    $JSON.poco.Is_Critical = [System.Convert]::ToBoolean($data.Is_Critical)
    $JSON.poco.Rounding_Precision = $data.Rounding_Precision
    $JSON.poco.Deadband_Percentage = if ($data.Deadband_Percentage -eq "NULL") {$null}else {$data.Deadband_Percentage}
    $JSON.poco.External_Tag_Format = if ($data.External_Tag_Format -eq "NULL") {$null}else {$data.External_Tag_Format}
    $JSON.poco.Disable_History = [System.Convert]::ToBoolean($data.Disable_History)
    $JSON.poco.Setpoint_Timeout_Seconds = if ($data.Setpoint_Timeout_Seconds -eq "NULL") {$null}else {$data.Setpoint_Timeout_Seconds}
    $JSON.poco.Sensor_Category_Type_CD = if ($data.Sensor_Category_Type_CD -eq "NULL") {$null}else {$data.Sensor_Category_Type_CD}
    $JSON.poco.Description = if ($data.Description -eq "NULL") {$null}else {$data.Description}
    $JSON.poco.IsNew = $IsNew

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember SetSensorType

Function AddDeviceType ($data, $config, $user) {
    #To do add logic to determine if sensor type cd is present in template
    $service = $config.DeviceMethod
    $method = "AddDeviceType"
    #Set Rest connection params
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONAddDeviceType
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    #Set Poco properties from template
    $JSON.poco.Device_Type_Name = $data.Device_Type
    $JSON.poco.Device_Type_Short_Name = $data.Device_Type_Short
    $JSON.poco.Last_Updated_By = $user.Login_ID
    $JSON.poco.Last_Update_date = "$([System.DateTime]::UtcNow.GetDateTimeFormats("O"))"
    $JSON.poco.Is_Deleted = [System.Convert]::ToBoolean($data.Is_Deleted)
    $JSON.poco.Description = if ($data.Description -eq "NULL") {$null}else {$data.Description}

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember AddDeviceType

Function GetDeviceSensors ($config, $user, $deviceID) {
    $Service = $config.DeviceMethod
    $Method = "SELECT_858"
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONSelectMethod
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    $JSON | Add-Member -NotePropertyName "deviceID" -NotePropertyValue $deviceID -Force

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember GetDeviceSensors

Function InsertSensor ($data, $config, $user, $device, $sensortype) {
    $service = $config.DeviceMethod
    $method = "Device_Sensor_Insert"
    #Set Rest connection params
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONInsertSensor
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    #Set Poco properties from template
    $JSON.Device_ID = $device.Device_ID
    $JSON.Monitor_Type_CD = ($Monitor_Types.Result | Where-Object { 
            $_.Description -eq $data.Monitor_Type 
        }).Monitor_Type_CD
    $JSON.Sensor_Type_CD = $sensortype.Sensor_Type_CD
    $JSON.Reading_Type_CD = ($Reading_Types.Result | Where-Object { 
            $_.Description -eq $data.Reading_Type
        }).Reading_Type_CD
    $JSON.Last_Updated_By = $user.Login_ID
    $JSON.URI = "$($data.Monitor_URL)$($data.Monitor_Server_ID)$($data.Monitor_Item_ID)"
    $JSON.Is_Deleted = [System.Convert]::ToBoolean($data.Is_Deleted)
    $JSON.Polling_Interval_Seconds = if ($data.Polling -eq "NULL") {$null}else {$data.Polling}

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember InsertSensor

Function InsertDevice ($data, $partition, $config, $user) {
    $service = $config.DeviceMethod
    $method = "Device_Insert"
    #Set Rest connection params
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONInsertDevice
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    $JSON.Last_Updated_By = $user.Login_ID
    $JSON.Is_Deleted = [System.Convert]::ToBoolean($data.Is_Deleted)
    $JSON.Partition_ID = $data.Partition_ID
    $JSON.Device_Type_CD = $data.Device_Type_CD
    $JSON.Device_Up_Date = "$([System.DateTime]::UtcNow.GetDateTimeFormats("O"))"
    $JSON.Device_Name = $data.Device_Name
    $JSON.Host_Name = (
        $data.Device_Name + 
        "." +
        $partition.partition_short_name +    
        ".anywhere.corp").Replace(" ", "").ToLower()
    

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember InsertDevice

Function DestroyDevice ($config, $user, $device, $taskid) {
    $service = $Config.MiscMethod
    $method = "Task_Set"
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONDestroyDevice
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    $JSON.Task_ID = $taskid.guid
    $JSON.Start_Date = "$([System.DateTime]::UtcNow.GetDateTimeFormats("O"))"
    $JSON.Parameter_XML = (
        '<?xml version="1.0" encoding="utf-8"?>' + 
        '<EntityDestructionParameters xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">' +
        '<EntityTypeToDestroy>Device</EntityTypeToDestroy>' +
        "<EntityID>$($Device.Device_ID)</EntityID>" +
        "<RequestedBy>$($user.Login_ID)</RequestedBy>" +
        '</EntityDestructionParameters>')

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember DestroyDevice

Function DestroySensor ($config, $user, $sensor, $taskid) {
    $service = $Config.MiscMethod
    $method = "Task_Set"
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONDestroyDevice
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    $JSON.Task_ID = $taskid.guid
    $JSON.Start_Date = "$([System.DateTime]::UtcNow.GetDateTimeFormats("O"))"
    $JSON.Parameter_XML = (
        '<?xml version="1.0" encoding="utf-8"?>' + 
        '<EntityDestructionParameters xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">' +
        '<EntityTypeToDestroy>Sensor</EntityTypeToDestroy>' +
        "<EntityID>$($sensor)</EntityID>" +
        "<RequestedBy>$($user.Login_ID)</RequestedBy>" +
        '</EntityDestructionParameters>')

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember DestroySensor


Function TaskProgress ($config, $user, $taskid) {
    $service = $Config.MiscMethod
    $method = "Task_Progress_Set"
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONTaskProgressSet
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    $JSON.Task_ID = $taskid.guid
    $JSON.Progress_Date = "$([System.DateTime]::UtcNow.GetDateTimeFormats("O"))"

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember TaskProgress

Function GetTask ($config, $user, $taskid) {
    $service = $config.MiscMethod
    $method = "Task_Get"
    $URI = "$($config.WebHost)/$($service)$($method)"
    $JSON = $config.JSONSelectMethod
    $JSON.Ticket = $user.Ticket
    $JSON.LoginID = $user.Login_ID
    $JSON.Environment = $config.Environment
    $JSON.AppID = $config.AppID
    $JSON | Add-Member Task_ID($taskid.guid) -Force

    $params = @{
        Uri         = $URI
        Method      = "Post"
        Body        = ($JSON | ConvertTo-Json)
        ContentType = "application/json; charset=utf-8"
        ErrorAction = "Inquire"
    }

    Invoke-RestMethod @params
}

Export-ModuleMember GetTask






