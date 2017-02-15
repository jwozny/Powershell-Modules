function Get-ConflictFiles {
    Param(
        [Parameter(Mandatory=$true)][string]$Share,
        [Parameter(Mandatory=$true)][string]$Filename,
        [Parameter(Mandatory=$true)][string]$Namespace,
        [string]$Domain = (Get-WmiObject Win32_ComputerSystem).Domain
    )
    $Manifest = "\\$Domain\$Namespace\$Share\DfsrPrivate\ConflictAndDeletedManifest.xml"
    $Files = Get-DfsrPreservedFiles -Path $Manifest | Where-Object Path -like "*$Filename*"
    Return $Files
}
 
function Restore-ConflictFiles {
    Param(
        [Parameter(Mandatory=$true)][string]$Share,
        [Parameter(Mandatory=$true)][Object[]]$Files,
        [Parameter(Mandatory=$true)][string]$Namespace,
        [string]$Domain = (Get-WmiObject Win32_ComputerSystem).Domain
    )
    $Manifest = "\\$Domain\$Namespace\$Share\DfsrPrivate\ConflictAndDeletedManifest.xml"
    foreach ($File in $Files) {
        $OriginalFile = $File.Path -replace "^.*\\$Namespace\\", "\\$Domain\$Namespace\"
        $ConflictFile = $File.PreservedName
        $error.clear()
        try {
            Copy-Item "\\$Domain\$Namespace\$Share\DfsrPrivate\ConflictAndDeleted\$ConflictFile" $OriginalFile -Force
        }
        catch {}
        if (!$error) {
            Write-Host "**RESTORED**" $OriginalFile -ForegroundColor Green
            (Get-Content $Manifest) -notmatch "^.*$ConflictFile.*$" | Out-File $Manifest -Force -Encoding ascii
        }
    }
}
 
function Restore-ConflictFile {
    Param(
        [Parameter(Mandatory=$true)][string]$Share,
        [Parameter(Mandatory=$true)][Object]$File,
        [Parameter(Mandatory=$true)][string]$Namespace,
        [string]$Domain = (Get-WmiObject Win32_ComputerSystem).Domain
    )
    $Manifest = "\\$Domain\$Namespace\$Share\DfsrPrivate\ConflictAndDeletedManifest.xml"
    $OriginalFile = $File.Path -replace "^.*\\$Namespace\\", "\\$Domain\$Namespace\"
    $ConflictFile = $File.PreservedName
    $error.clear()
    try {
        Copy-Item "\\$Domain\$Namespace\$Share\DfsrPrivate\ConflictAndDeleted\$ConflictFile" $OriginalFile -Force
    }
    catch {}
    if (!$error) {
        Write-Host "**RESTORED**" $OriginalFile -ForegroundColor Green
        (Get-Content $Manifest) -notmatch "^.*$ConflictFile.*$" | Out-File $Manifest -Force -Encoding ascii
    }
}
 
function Find-MissingFiles {
    Param(
        [Parameter(Mandatory=$true)][string]$Share,
        [Parameter(Mandatory=$true)][string]$Filename,
        [string]$Namespace = 'Shares',
        [string]$Domain = (Get-WmiObject Win32_ComputerSystem).Domain
    )
 
    $Files = Get-ConflictFiles -Namespace $Namespace -Share $Share -Filename $Filename
    if ( $Files ) {
        $NewSearch = $true
        while ( $NewSearch ) {
            $NewSearch = $false
            $FileNumber = 0
            foreach ( $File in $Files ) {
                $FileNumber++
                $OriginalFile = $File.Path -replace "^.*\\$Namespace\\", "\\$Domain\$Namespace\"
                Write-Host "("$FileNumber" )" $OriginalFile -ForegroundColor Green
                Write-Host "        Moved on" $File.PreservedTime "        Reason : " $File.PreservedReason -ForegroundColor Yellow
            }
            Write-Host "Found" $Files.count "files!" -ForegroundColor Yellow
            $title = ""
            $message = "Restore all files, some files, modify the query, or exit?"
 
            $a = New-Object System.Management.Automation.Host.ChoiceDescription "Restore &all", `
                "Restore all files (newest files overwrite old)."
            $s = New-Object System.Management.Automation.Host.ChoiceDescription "&Select restore", `
                "Restore select files from the list using the indicator numbers."
            $f = New-Object System.Management.Automation.Host.ChoiceDescription "Refine &filename", `
                "Modify filename query."
            $e = New-Object System.Management.Automation.Host.ChoiceDescription "&Exit", `
                "Exit"
 
            $options = [System.Management.Automation.Host.ChoiceDescription[]]( $a, $s, $f, $e )
            $result = $host.ui.PromptForChoice( $title, $message, $options, 3 )
 
            switch ( $result ) {
                0 {
                    Restore-ConflictFiles -Namespace $Namespace -Share $Share -Files $Files
                    $Files = Get-ConflictFiles -Namespace $Namespace -Share $Share -Filename $Filename
                }
                1 {
                    $FilesToRestore = Read-Host -Prompt 'Enter the file numbers to restore, separate with comma (2,5,8,4)'
                    $FilesToRestore = $FilesToRestore.Split(',')
                    $FileNumber = 0
                    foreach ( $File in $Files ) {
                        $FileNumber++
                        foreach ( $Number in $FilesToRestore ) {
                            if ( $Number -as [int] -eq $FileNumber ) {
                                Restore-ConflictFile -Namespace $Namespace -Share $Share -File $File
                            }
                        }
                    }
                }
                2 {
                    $Filename = Read-Host -Prompt 'Enter the new filename to search'
                    $Files = Get-ConflictFiles -Namespace $Namespace -Share $Share -Filename $Filename
                    $NewSearch = $true
                }
                3 { Return }
            }
        }
        Write-Host "Done!" -ForegroundColor Green
    } else {
        Write-Host "No Files Found" -ForegroundColor Green
    }
}
