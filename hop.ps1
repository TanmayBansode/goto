$bookmarkFile = "$env:USERPROFILE\hop_bookmarks.txt"

function Load-Bookmarks {
    $bookmarks = @{}
    if (Test-Path $bookmarkFile) {
        $lines = Get-Content $bookmarkFile
        foreach ($line in $lines) {
            $parts = $line -split '\|'
            if ($parts.Length -eq 5) {
                $bookmarks[$parts[0]] = @{
                    Path         = $parts[1]
                    Category     = $parts[2]
                    LastAccessed = $parts[3]
                    AccessCount  = [int]$parts[4]
                }
            }
        }
    }
    else {
        Write-Host "No bookmark file found." -ForegroundColor Yellow
    }
    return $bookmarks
}

function Save-Bookmarks {
    param ($bookmarks)
    Remove-Item -Path $bookmarkFile -Force -ErrorAction SilentlyContinue
    $bookmarks.GetEnumerator() | ForEach-Object {
        "$($_.Key)|$($_.Value.Path)|$($_.Value.Category)|$($_.Value.LastAccessed)|$($_.Value.AccessCount)" | Out-File -FilePath $bookmarkFile -Append
    }
}

function Add-Bookmark {
    param ($name, $path, $category)

    if (!$category) {
        $category = "general"
    }

    Write-Debug "Adding bookmark: $name, $path, $category"
    $bookmarks = Load-Bookmarks
    if ($bookmarks[$name]) {
        Write-Host "Bookmark '$name' already exists. Use 'hop remove $name' to remove it." -ForegroundColor Red
        return
    }

    if (Test-Path $path) {
        $bookmarks[$name] = @{
            Path         = $path
            Category     = $category
            LastAccessed = ""
            AccessCount  = 0
        }
        Save-Bookmarks $bookmarks
        Write-Host "Bookmark '$name' added under category '$category' at $path" -ForegroundColor Green
    }
    else {
        Write-Host "Invalid path: $path" -ForegroundColor Red
    }
}

function Go-To-Bookmark {
    param ($name)
    $bookmarks = Load-Bookmarks
    if ($bookmarks.ContainsKey($name)) {
        Set-Location $bookmarks[$name].Path
        $bookmarks[$name].LastAccessed = Get-Date
        $bookmarks[$name].AccessCount++
        Save-Bookmarks $bookmarks
        Write-Host "Navigated to bookmark '$name' at $($bookmarks[$name].Path)" -ForegroundColor Cyan
    }
    else {
        Write-Host "Bookmark '$name' not found." -ForegroundColor Red
    }
}

function List-Bookmarks {
    param ($word, $category = "")
    $bookmarks = Load-Bookmarks
    $filtered = if ($category) {
        $bookmarks.GetEnumerator() | Where-Object { $_.Value.Category -eq $category }
    }
    elseif ($word) {
        $bookmarks.GetEnumerator() | Where-Object { $_.Key -like "*$word*" }
    }
    else {
        $bookmarks.GetEnumerator()
    }
    $filtered | ForEach-Object {
        Write-Host -NoNewline $_.Key -ForegroundColor Green
        Write-Host -NoNewline " "
        Write-Host $_.Value.Path -ForegroundColor Cyan
    }
}

function Show-Stats {
    $bookmarks = Load-Bookmarks
    if ($bookmarks.Count -eq 0) {
        Write-Host "No bookmarks found." -ForegroundColor Yellow
        return
    }

    $bookmarks.GetEnumerator() | ForEach-Object {
        $lastAccessed = if ($_.Value.LastAccessed) {
            [DateTime]$_.Value.LastAccessed -as [DateTime]
        } else {
            "Never"
        }

        [PSCustomObject]@{
            Bookmark      = $_.Key 
            Path          = $_.Value.Path
            Category      = $_.Value.Category
            'Last Access' = $lastAccessed
            'Access Count' = $_.Value.AccessCount
        }
    } | Format-Table -AutoSize -Wrap
}



function Show-Recent {
    $bookmarks = Load-Bookmarks
    $recent = $bookmarks.GetEnumerator() | Where-Object { $_.Value.LastAccessed -ne "" } | Sort-Object { $_.Value.LastAccessed } -Descending | Select-Object -First 10
    Write-Host "Recently Accessed Bookmarks:" -ForegroundColor Cyan
    $recent | ForEach-Object { Write-Host "$($_.Key) -> Last Accessed: $($_.Value.LastAccessed)" }
}

function Show-Frequent {
    $bookmarks = Load-Bookmarks
    $frequent = $bookmarks.GetEnumerator() | Sort-Object { $_.Value.AccessCount } -Descending | Select-Object -First 10
    Write-Host "Frequently Accessed Bookmarks:" -ForegroundColor Cyan
    $frequent | ForEach-Object { Write-Host "$($_.Key) -> Access Count: $($_.Value.AccessCount)" }
}

function Clear-Bookmarks {
    Write-Host "WARNING: This action will delete all bookmarks permanently!" -ForegroundColor Yellow
    $confirmation = Read-Host "Are you sure you want to proceed? Type 'yes' to confirm"
    
    if ($confirmation -eq "yes") {
        Remove-Item -Path $bookmarkFile -Force -ErrorAction SilentlyContinue
        Write-Host "All bookmarks cleared." -ForegroundColor Red
    } else {
        Write-Host "Operation canceled. No bookmarks were cleared." -ForegroundColor Green
    }
}


function Remove-Bookmark {
    param ($name)
    $bookmarks = Load-Bookmarks
    if ($bookmarks.ContainsKey($name)) {
        $bookmarks.Remove($name)
        Save-Bookmarks $bookmarks
        Write-Host "Bookmark '$name' removed." -ForegroundColor Yellow
    }
    else {
        Write-Host "Bookmark '$name' not found." -ForegroundColor Red
    }
}

function Show-Help {
    Write-Host " Usage:" -ForegroundColor Green
    Write-Host "  hop add <name> <path> <category>  - Adds a bookmark (default category: general)" -ForegroundColor White
    Write-Host "  hop to <name>                    - Goes to the saved bookmark" -ForegroundColor White
    Write-Host "  hop list <word>                  - Lists bookmarks with optional search word" -ForegroundColor White
    Write-Host "  hop list -c <category>           - Lists bookmarks in a specific category" -ForegroundColor White
    Write-Host "  hop stats                        - Displays detailed bookmark stats" -ForegroundColor White
    Write-Host "  hop recent                       - Displays last 10 accessed bookmarks" -ForegroundColor White
    Write-Host "  hop frequent                     - Displays top 10 frequently accessed bookmarks" -ForegroundColor White
    Write-Host "  hop remove <name>                - Removes a specific bookmark" -ForegroundColor White
    Write-Host "  hop clear                        - Clears all bookmarks" -ForegroundColor White
    Write-Host "  hop help                         - Displays this help" -ForegroundColor White
}

if ($args.Length -eq 0) {
    Show-Help
}
elseif ($args[0] -eq "help") {
    Show-Help
}
elseif ($args[0] -eq "add" -and $args[1] -and $args[2]) {
    Add-Bookmark -name $args[1] -path $args[2] -category $args[3] 
}
elseif ($args[0] -eq "to" -and $args[1]) {
    Go-To-Bookmark -name $args[1]
}
elseif ($args[0] -eq "list") {
    if ($args[1] -eq "-c" -and $args[2]) {
        List-Bookmarks -category $args[2]
    }
    else {
        List-Bookmarks $args[1]
    }
}
elseif ($args[0] -eq "stats") {
    Show-Stats
}
elseif ($args[0] -eq "recent") {
    Show-Recent
}
elseif ($args[0] -eq "frequent") {
    Show-Frequent
}
elseif ($args[0] -eq "remove" -and $args[1]) {
    Remove-Bookmark -name $args[1]
}
elseif ($args[0] -eq "clear") {
    Clear-Bookmarks
}
else {
    Write-Host "Unknown command. Use 'hop help' for instructions." -ForegroundColor Red
}
