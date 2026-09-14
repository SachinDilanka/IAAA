$userPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)
if ($userPath -notlike "*C:\src\flutter\bin*") {
    $newPath = $userPath + ";C:\src\flutter\bin"
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, [System.EnvironmentVariableTarget]::User)
    Write-Host "Successfully added C:\src\flutter\bin to User PATH!"
} else {
    Write-Host "C:\src\flutter\bin is already in User PATH."
}
