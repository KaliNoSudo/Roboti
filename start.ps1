# Set up the HTTP listener on port 8081
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:8081/")  # Listen on port 8081
$listener.Start()
Write-Host "Listening on http://+:8081/"

# Mapping file extensions to content types
$mimeTypes = @{
    ".html" = "text/html; charset=UTF-8"
    ".css"  = "text/css; charset=UTF-8"
    ".js"   = "application/javascript"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".png"  = "image/png"
    ".gif"  = "image/gif"
    ".txt"  = "text/plain; charset=UTF-8"
    ".mp4"  = "video/mp4"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
}

# Define the base directory (adjust if your files are stored elsewhere)
$baseDirectory = Get-Location
Write-Host "Base directory: $baseDirectory"

# Serve files continuously
while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        # Get and URL decode the requested path to handle spaces correctly
        $requestedPath = $request.Url.AbsolutePath
        $filePath = [System.Net.WebUtility]::UrlDecode($requestedPath.TrimStart("/"))

        # Default file if none is specified
        if ([string]::IsNullOrEmpty($filePath)) {
            $filePath = "main.html"
        }

        # Combine base directory with the requested file path
        $fullPath = Join-Path $baseDirectory $filePath
        Write-Host "Requested file path: $fullPath"

        if (Test-Path $fullPath) {
            # Set the Content-Type header based on file extension
            $fileExtension = [System.IO.Path]::GetExtension($filePath).ToLower()
            if ($mimeTypes.ContainsKey($fileExtension)) {
                $response.ContentType = $mimeTypes[$fileExtension]
            } else {
                $response.ContentType = "application/octet-stream"
            }

            # Read file contents (text or binary)
            if ($fileExtension -eq ".html" -or $fileExtension -eq ".txt") {
                $content = Get-Content -Path $fullPath -Raw -Encoding UTF8
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
            } else {
                $buffer = [System.IO.File]::ReadAllBytes($fullPath)
            }

            # Check for a Range header
            $rangeHeader = $request.Headers["Range"]
            if ($rangeHeader) {
                $range = $rangeHeader -replace "bytes=", ""
                $rangeValues = $range.Split("-")
                $start = if ($rangeValues[0] -ne "") { [int]$rangeValues[0] } else { 0 }
                if ($rangeValues.Length -gt 1 -and $rangeValues[1] -ne "") {
                    $end = [int]$rangeValues[1]
                } else {
                    $end = $buffer.Length - 1
                }

                if ($start -gt $end -or $end -ge $buffer.Length) {
                    $response.StatusCode = 416
                    $response.AddHeader("Content-Range", "bytes */$($buffer.Length)")
                    $errorMsg = "Requested Range Not Satisfiable"
                    $errorBytes = [System.Text.Encoding]::UTF8.GetBytes($errorMsg)
                    $response.ContentLength64 = $errorBytes.Length
                    $response.OutputStream.Write($errorBytes, 0, $errorBytes.Length)
                }
                else {
                    $length = $end - $start + 1
                    $response.StatusCode = 206
                    $response.AddHeader("Content-Range", "bytes $start-$end/$($buffer.Length)")
                    $response.ContentLength64 = $length
                    $response.OutputStream.Write($buffer, $start, $length)
                }
            }
            else {
                # No Range header: serve the entire file
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
        }
        else {
            # File not found
            $response.StatusCode = 404
            $response.ContentType = "text/plain"
            $notFoundMsg = "404 - File Not Found: $filePath"
            Write-Host $notFoundMsg
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($notFoundMsg)
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        }
        $response.OutputStream.Close()
    }
    catch {
        Write-Host "Error: $_"
        try {
            $response.StatusCode = 500
            $response.ContentType = "text/plain"
            $errorMsg = "500 - Internal Server Error"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($errorMsg)
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        }
        catch {
            Write-Host "Error sending 500 response: $_"
        }
    }
}
