# Set up the HTTP listener on port 80
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:8081/")  # Listen on port 8080
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
    # Add more types as needed
}

# Define the directory from which to serve files (current directory)
$baseDirectory = Get-Location

# Serve files
while ($listener.IsListening) {
    $context = $listener.GetContext()
    $response = $context.Response
    # Extract file path from the request URL
    $requestedPath = $context.Request.Url.AbsolutePath
    $filePath = $requestedPath.TrimStart("/")  # Remove leading slash

    # Handle the case when no file is requested (default to 'main.html')
    if ($filePath -eq "") {
        $filePath = "main.html"  # Default file if no file is requested
    }

    # Combine the base directory with the requested file path
    $fullPath = Join-Path $baseDirectory $filePath

    # Check if the file exists
    if (Test-Path $fullPath) {
        # Get the file extension
        $fileExtension = [System.IO.Path]::GetExtension($filePath).ToLower()

        # Set content type based on the file extension
        if ($mimeTypes.ContainsKey($fileExtension)) {
            $response.ContentType = $mimeTypes[$fileExtension]
        } else {
            $response.ContentType = "application/octet-stream"  # Default for unknown file types
        }

        # Read and serve the file content
        if ($fileExtension -eq ".html" -or $fileExtension -eq ".txt") {
            # Read the text files as UTF-8
            $buffer = [System.Text.Encoding]::UTF8.GetBytes((Get-Content -Path $fullPath -Raw -Encoding UTF8))  # Read as UTF-8
        } else {
            # For binary files (like images)
            $buffer = [System.IO.File]::ReadAllBytes($fullPath)
        }

        # Set the content length and send the response
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
    } else {
        # If the file doesn't exist, return 404
        $response.StatusCode = 404
        $response.ContentType = "text/plain"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes("404 - File Not Found")
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
    }

    $response.OutputStream.Close()
}
