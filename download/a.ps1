# Function to capture a screenshot across all monitors and save it as a PNG file
function capture-screenshot {
    param (
        $saveFolder = "C:\temp",
        $fileName = "screenshot_$(Get-Date -format 'yyyyMMddHHmmss').png"
    )

    # Ensure the save folder exists
    if (-not (Test-Path $saveFolder)) {
        New-Item $saveFolder -ItemType Directory | Out-Null
    }

    $filePath = Join-Path $saveFolder $fileName

    # Take screenshot across all displays using .NET libraries
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $screens = [System.Windows.Forms.Screen]::AllScreens
    $top = ($screens | ForEach-Object { $_.Bounds.Top } | Measure-Object -Minimum).Minimum
    $left = ($screens | ForEach-Object { $_.Bounds.Left } | Measure-Object -Minimum).Minimum
    $width = ($screens | ForEach-Object { $_.Bounds.Right } | Measure-Object -Maximum).Maximum - $left
    $height = ($screens | ForEach-Object { $_.Bounds.Bottom } | Measure-Object -Maximum).Maximum - $top

    $bounds = [Drawing.Rectangle]::FromLTRB($left, $top, $width, $height)
    $bitmap = New-Object Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size)
    $bitmap.Save($filePath, [Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()

    # Return the file path
    if (Test-Path $filePath) {
        return $filePath
    } else {
        Write-Host "Failed to capture screenshot."
        return ""
    }
}

# Function to send a file to the server
function upload-file {
    param (
        $filePath,
        $serverUrl
    )

    if (-not (Test-Path $filePath)) {
        Write-Host "File not found: $filePath"
        return $false
    }

    try {
        $fileName = [System.IO.Path]::GetFileName($filePath)
        $boundary = "----Boundary$(Get-Random)"
        
        # Create a temporary directory under user's profile folder
        $userFolder = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
        $tempFolder = Join-Path $userFolder "MyUploadedFiles"
        if (-not (Test-Path $tempFolder)) {
            New-Item -Path $tempFolder -ItemType Directory | Out-Null
        }

        $tempFile = Join-Path $tempFolder "tempfile"
        $UTF8woBOM = New-Object "System.Text.UTF8Encoding" -ArgumentList @($false)

        # Construct multipart data
        $sw = New-Object System.IO.StreamWriter($tempFile, $false, $UTF8woBOM)
        $sw.Write("--$boundary`r`nContent-Disposition: form-data; name=`"up_file`"; filename=`"$fileName`"`r`n")
        $sw.Write("Content-Type: application/octet-stream`r`n`r`n")
        $sw.Close()

        $fs = New-Object System.IO.FileStream($tempFile, [System.IO.FileMode]::Append)
        $bw = New-Object System.IO.BinaryWriter($fs)
        $fileBinary = [System.IO.File]::ReadAllBytes($filePath)
        $bw.Write($fileBinary)
        $bw.Close()

        $sw = New-Object System.IO.StreamWriter($tempFile, $true, $UTF8woBOM)
        $sw.Write("`r`n--$boundary--`r`n")
        $sw.Close()

        # Send the POST request
        Invoke-RestMethod -Method POST -Uri $serverUrl -ContentType "multipart/form-data; boundary=$boundary" -InFile $tempFile
        Remove-Item $tempFile
        Write-Host "File successfully uploaded to the server."
        return $true
    } catch {
        Write-Host "Error during file upload: $_"
        return $false
    }
}

# Main script
$screenshotPath = capture-screenshot
if ($screenshotPath -ne "") {
    $serverUrl = "http://localhost:8000/upload" # Replace with your server's URL
    if (upload-file -filePath $screenshotPath -serverUrl $serverUrl) {
        # Delete the local screenshot file after successful upload
        Remove-Item $screenshotPath -Force
        Write-Host "Local screenshot file deleted: $screenshotPath"
    } else {
        Write-Host "Failed to upload screenshot. File was not deleted."
    }
}
