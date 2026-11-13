param(
 [Parameter(Mandatory=$true)][string]$ConfigPath,
 [ValidateSet('preflight','apply','restore')][string]$Mode='preflight'
)
$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$sdb = Join-Path $config.sdk_path 'tools\sdb.exe'
$parsedAddress = $null
if (-not [Net.IPAddress]::TryParse([string]$config.tv_ip,[ref]$parsedAddress)) { throw 'Invalid TV address.' }
$hostAddress = $parsedAddress.ToString()
if ($config.model -ne 'QN75LS03BAFXZA') { throw 'This profile requires separate review for another model.' }
$buildFolder = (Resolve-Path -LiteralPath $config.build_folder).Path
$resultFolder = (Resolve-Path -LiteralPath $config.result_folder).Path
$serial = $hostAddress + ':26101'
$info = Invoke-RestMethod ('http://' + $hostAddress + ':8001/api/v2/') -TimeoutSec 8
if ($info.device.modelName -ne 'QN75LS03BAFXZA') { throw 'TV model differs; stopping.' }
& $sdb connect $serial
if ($LASTEXITCODE -ne 0) { throw 'Developer connection failed; no upload or settings change attempted.' }
$devices = & $sdb devices
if ($LASTEXITCODE -ne 0 -or -not (($devices -join "`n") -match ([regex]::Escape($serial) + '\s+device\s'))) {
    throw 'TV is not listed as a connected developer device; no upload or settings change attempted.'
}
$token = [Guid]::NewGuid().ToString('N').Substring(0,12)
$remote = '/home/owner/share/tmp/sdk_tools/cf-inspect-' + $token
$local = Join-Path $resultFolder ('Frame-inspect-' + $token + '.txt')
$source = @'
set -u
printf 'CLEANFRAME_INSPECT_BEGIN\n'
id
uname -m
sed -n '/^Version=/p;/^Model=/p' /etc/prd_info.ini
cat /etc/tizen-release
printf '\nDOTNET\n'
ls -d /usr/share/dotnet/shared/Microsoft.NETCore.App/* 2>/dev/null || true
printf '\nNATIVE_LIBRARIES\n'
ls -l /usr/lib/libaul.so.0 /usr/lib/libbundle.so.0 /usr/lib/libapp-context-manager-common.so /usr/lib/libcapi-appfw-app-operation-tv.so.0 /usr/lib/libvconf.so.0 2>/dev/null || true
printf '\nINSTALLED_LAUNCHER\n'
# Launcher identity is checked inside the owner-configured helper.
printf '\nHOME_PREFERENCE_READS\n'
for k in db/appfw/home_appid db/appfw/startup_appid db/appfw/booting_appid_backup db/first_screen/type db/menu/smart_hub/ontvsetting/auto_start; do
  printf '\nKEY=%s\n' "$k"
  vconftool get "$k"
  printf 'GET_EXIT=%s\n' "$?"
done
printf '\nAVAILABLE_QUERY_TOOLS\n'
command -v vconftool aul_test dotnet
printf '\nNATIVE_HOME_OPERATION_QUERY\n'
/usr/bin/aul_test get_default_app 'http://tizen.org/appcontrol/operation/main' '' ''
printf 'OPERATION_QUERY_EXIT=%s\n' "$?"
printf '\nDOTNET_ACTIVATION\n'
/usr/bin/dotnet --info 2>&1 || true
printf 'CLEANFRAME_INSPECT_END\n'
'@
$source = $source.Replace("`r", '') + "`n"
if ($true) {
    foreach ($suffix in @('dll','runtimeconfig.json','deps.json')) {
        $binary = Join-Path $buildFolder ('FrameQuery.' + $suffix)
        if (-not (Test-Path -LiteralPath $binary)) { throw 'Native query build is missing.' }
        & $sdb -s $serial push $binary ('/home/owner/share/tmp/sdk_tools/FrameQuery.' + $suffix)
        if ($LASTEXITCODE -ne 0) { throw 'Native query upload failed.' }
    }
    $source = "printf 'CLEANFRAME_INSPECT_BEGIN\n'`n/usr/bin/dotnet /home/owner/share/tmp/sdk_tools/FrameQuery.dll $Mode`nprintf 'NATIVE_HELPER_EXIT=%s\n' " + '"$?"' + "`nprintf 'CLEANFRAME_INSPECT_END\n'`n"
}
$localSource = Join-Path $resultFolder ('Frame-inspect-' + $token + '.sh')
[IO.File]::WriteAllText($localSource, $source, [Text.UTF8Encoding]::new($false))
& $sdb connect $serial
if ($LASTEXITCODE -ne 0) { throw 'Developer connection failed.' }
& $sdb -s $serial push $localSource ($remote + '.sh')
if ($LASTEXITCODE -ne 0) { throw 'Diagnostic upload failed.' }
$route = [Net.Sockets.UdpClient]::new()
try {
    $route.Connect($hostAddress,9)
    $pcAddress = $route.Client.LocalEndPoint.Address
} finally { $route.Dispose() }
$listener = [Net.Sockets.TcpListener]::new($pcAddress,0)
$process = $null
$client = $null
try {
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    # Same bounded callback transport as upstream run.py; no preference writes.
    $command = 'exec 3<>/dev/tcp/' + $pcAddress + '/' + $port + ';cat ' + $remote + '.sh|bash >&3 2>&3;exec 3>&-'
    $script = '/bin/mkdir /tmp/s-' + $token + ' 2>/dev/null&&{ ' + $command + ';}'
    $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))
    $name = 'new2.tpk`printf${IFS}%s${IFS}' + $payload + '|base64${IFS}-d|bash`.tpk'
    $argument = '0 appinstall tpk ' + $name
    if ([Text.Encoding]::UTF8.GetByteCount($argument) -gt 400) { throw 'Transport exceeds reviewed length.' }
    Write-Host "Waiting up to 18 seconds for diagnostics on ${pcAddress}:$port."
    $accept = $listener.AcceptTcpClientAsync()
    $process = Start-Process -FilePath $sdb -ArgumentList @('-s',$serial,'shell',('"' + $argument + '"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput ($local + '.transport-out') -RedirectStandardError ($local + '.transport-err')
    if (-not $accept.Wait(18000)) { throw 'No callback received. Execution or network return path remains unverified; no Home settings changed.' }
    $client = $accept.Result
    if ($client.Client.RemoteEndPoint.Address.ToString() -ne $hostAddress) { throw 'Unexpected callback peer.' }
    $stream = $client.GetStream()
    $stream.ReadTimeout = 8000
    $buffer = New-Object byte[] 8192
    $memory = [IO.MemoryStream]::new()
    try {
        while (($count = $stream.Read($buffer,0,$buffer.Length)) -gt 0) {
            $memory.Write($buffer,0,$count)
            if ($memory.Length -gt 100000) { throw 'Unexpectedly large diagnostic result.' }
        }
        $result = [Text.Encoding]::UTF8.GetString($memory.ToArray())
    } finally { $memory.Dispose() }
    [IO.File]::WriteAllText($local,$result,[Text.UTF8Encoding]::new($false))
} finally {
    if ($client) { $client.Dispose() }
    $listener.Stop()
    if ($process -and -not $process.HasExited) { $process.Kill() }
}
if (-not $result.Contains('CLEANFRAME_INSPECT_BEGIN') -or -not $result.Contains('CLEANFRAME_INSPECT_END')) { throw 'Incomplete diagnostics; stop and share the error.' }
Write-Output $result
Write-Host "Saved diagnostics: $local"
