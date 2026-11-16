# Personal Files installer helper. Runs only after UAC elevation by the user.
# This installs a self-signed test build; it does not modify Windows system fonts.
param([Parameter(Mandatory=$true)][string]$PackageRoot)
$ErrorActionPreference = 'Stop'
try {
    $root = (Resolve-Path -LiteralPath $PackageRoot).Path
    $certificate = Join-Path $root 'FilesApp_SelfSigned.cer'
    if (-not (Test-Path -LiteralPath $certificate)) { throw 'Installer signing certificate is missing.' }
    $packages = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
        $_.Extension -in @('.msix','.appx') -and $_.FullName -notmatch '[\\/]Dependencies[\\/]'
    })
    if ($packages.Count -ne 1) { throw "Expected exactly one FilesDev app package, found $($packages.Count)." }
    $package = $packages[0]
    Add-Type -AssemblyName System.IO.Compression
    $archive = [System.IO.Compression.ZipFile]::OpenRead($package.FullName)
    try {
        $manifest = $archive.GetEntry('AppxManifest.xml')
        if (-not $manifest) { throw 'AppxManifest.xml is missing from the app package.' }
        $reader = New-Object System.IO.StreamReader($manifest.Open())
        try { [xml]$xml = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $identity = $xml.Package.Identity
        if ($identity.Name -ne 'FilesDev' -or $identity.Publisher -ne 'CN=Files') {
            throw 'Unexpected app identity: only this personal FilesDev build is permitted.'
        }
    } finally { $archive.Dispose() }

    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificate)
    $trusted = Get-ChildItem 'Cert:\LocalMachine\TrustedPeople' | Where-Object Thumbprint -eq $cert.Thumbprint
    if (-not $trusted) {
        Write-Host 'Installing the build-only publisher certificate into LocalMachine TrustedPeople.'
        Import-Certificate -FilePath $certificate -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' | Out-Null
    }

    $dependencyDirs = @(Get-ChildItem -LiteralPath $root -Directory -Recurse | Where-Object Name -eq 'Dependencies')
    $dependencies = @()
    foreach ($dir in $dependencyDirs) {
        $dependencies += @(Get-ChildItem -LiteralPath $dir.FullName -Recurse -File | Where-Object {
            $_.Extension -in @('.msix','.appx') -and ($_.DirectoryName -notmatch '[\\/](arm|arm64|x86)([\\/]|$)')
        } | Select-Object -ExpandProperty FullName)
    }
    $args = @{ Path = $package.FullName; ErrorAction = 'Stop' }
    if ($dependencies.Count -gt 0) { $args.DependencyPath = $dependencies }
    Add-AppxPackage @args
    Write-Host 'FilesDev installation completed successfully.'
    exit 0
}
catch {
    Write-Host ('INSTALL FAILED: ' + $_.Exception.Message)
    exit 1
}
