# Personal Files installer helper. Runs only after UAC elevation by the user.
# This installs a self-signed test build; it does not modify Windows system fonts.
param([Parameter(Mandatory=$true)][string]$PackageRoot)
$ErrorActionPreference = 'Stop'
$failureLog = Join-Path $PackageRoot 'FilesDev-install-error.txt'
try {
    $root = (Resolve-Path -LiteralPath $PackageRoot).Path
    $certificate = Join-Path $root 'FilesApp_SelfSigned.cer'
    if (-not (Test-Path -LiteralPath $certificate)) { throw 'Installer signing certificate is missing.' }
    $packages = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
        $_.Extension -in @('.msix','.appx') -and $_.FullName -notmatch '[\\/]Dependencies[\\/]'
    })
    if ($packages.Count -ne 1) { throw "Expected exactly one FilesDev app package, found $($packages.Count)." }
    $package = $packages[0]
    # Windows PowerShell 5.1 needs FileSystem explicitly for ZipFile.OpenRead.
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
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

    # Never uninstall an existing FilesDev package or reset its application data.
    # Same-version rebuilds are blocked by Windows (0x80073CFB).
    $incomingVersion = [version]$identity.Version
    $installed = @(Get-AppxPackage -Name 'FilesDev' -ErrorAction Stop)
    foreach ($entry in $installed) {
        if ([version]$entry.Version -ge $incomingVersion) {
            throw "Installed FilesDev version $($entry.Version) is not older than setup version $incomingVersion. Refusing to uninstall or overwrite user data."
        }
    }

    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificate)
    $trusted = Get-ChildItem 'Cert:\LocalMachine\TrustedPeople' | Where-Object Thumbprint -eq $cert.Thumbprint
    if (-not $trusted) {
        Write-Host 'Installing the build-only publisher certificate into LocalMachine TrustedPeople.'
        Import-Certificate -FilePath $certificate -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' | Out-Null
    }

    # Install a Windows App Runtime dependency only when absent. Reinstalling
    # the shared framework during a FilesDev update can collide with unrelated
    # running Windows apps (0x80073D02 / ERROR_PACKAGES_IN_USE).
    $dependencies = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
        $_.Extension -in @('.msix','.appx') -and
        $_.FullName -match '[\\/]Dependencies[\\/]x64[\\/]'
    } | Select-Object -ExpandProperty FullName)
    $installedRuntime = @(Get-AppxPackage -Name 'Microsoft.WindowsAppRuntime.2' -ErrorAction Stop)
    $args = @{ Path = $package.FullName; ErrorAction = 'Stop' }
    if ($installedRuntime.Count -eq 0) {
        if ($dependencies.Count -eq 0) {
            throw 'Required x64 Windows App Runtime dependency is not installed or included.'
        }
        $args.DependencyPath = $dependencies
        Write-Host 'Windows App Runtime is absent; installing included x64 dependency.'
    }
    else {
        Write-Host 'Windows App Runtime is installed; not servicing shared framework packages.'
    }
    # Do not force-close FilesDev or unrelated apps. Windows can defer an in-use
    # FilesDev update until the app is next launched.
    if ($installed.Count -gt 0) {
        $args.DeferRegistrationWhenPackagesAreInUse = $true
    }
    Add-AppxPackage @args
    Write-Host 'FilesDev installation completed successfully.'
    exit 0
}
catch {
    $details = $_ | Out-String
    $message = 'INSTALL FAILED: ' + $_.Exception.Message + [Environment]::NewLine + $details
    try { [System.IO.File]::WriteAllText($failureLog, $message, [System.Text.Encoding]::UTF8) } catch {}
    Write-Host $message
    exit 1
}
