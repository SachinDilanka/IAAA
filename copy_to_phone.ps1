$shell = New-Object -ComObject Shell.Application
$thisPC = $shell.Namespace(17)

$phone = $null
foreach ($item in $thisPC.Items()) {
    if ($item.Name -match "HONOR" -or $item.Name -match "X5c" -or $item.Name -match "Phone") {
        $phone = $item
        break
    }
}

if ($phone) {
    Write-Host "Found phone: " $phone.Name
    $phoneFolder = $phone.GetFolder
    $storage = $null
    foreach ($item in $phoneFolder.Items()) {
        if ($item.Name -match "Internal" -or $item.Name -match "storage") {
            $storage = $item
            break
        }
    }

    if ($storage) {
        Write-Host "Found storage: " $storage.Name
        $storageFolder = $storage.GetFolder
        $downloadFolder = $null
        foreach ($item in $storageFolder.Items()) {
            if ($item.Name -eq "Download") {
                $downloadFolder = $item.GetFolder
                break
            }
        }

        if ($downloadFolder) {
            Write-Host "Copying LATEST APK to Phone Download folder..."
            $downloadFolder.CopyHere("C:\Users\Lenovo\Downloads\AcousticAware_Deaf_App_LATEST.apk", 16)
            Write-Host "SUCCESS: AcousticAware_Deaf_App_LATEST.apk copied to phone!"
        }
    }
}
