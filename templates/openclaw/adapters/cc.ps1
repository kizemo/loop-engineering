# templates/openclaw/adapters/cc.ps1
# Claude Code hook adapter (Windows PowerShell 7+).
# Behavior: read stdin → IPC call to server → fallback spawn server + retry.
#
# stdin:  JSON {"tool_name": "Bash", "tool_input": {...}, "cwd": "..."}
# stdout: (none expected)
# stderr: blocker reason on exit=2, ipc-failed on exit=1
# exit:   0 = allow, 2 = block, 1 = infra error (CC surfaces stderr to user)
#
# Env:
#   LOOPX_GUARD_SOCK  override Windows named-pipe path (default \\.\pipe\loopx-guard)
#   LOOPX_GUARD_PID   override PID file path (default $env:TEMP\loopx-guard.pid)

$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$serverScript = Join-Path $scriptDir '..\ipc\server.ts'
$pidFile = if ($env:LOOPX_GUARD_PID) { $env:LOOPX_GUARD_PID } else { Join-Path $env:TEMP 'loopx-guard.pid' }

# Read stdin (PreToolUse hook payload).
# IMPORTANT: parens around `[Console]::In` force PowerShell to evaluate the
# property accessor each call. Without parens, the cached TextReader returns
# 0 bytes (already-EOF) in -File mode. Don't name it `$input` — that's the
# reserved automatic enumerator for pipeline input.
$rawInput = ([Console]::In).ReadToEnd()

# Parse stdin: CC sends {tool_name, tool_input, cwd}; IPC needs {toolName, params, cwd}.
# Fail-soft allow on parse failure.
$parsed = $null
if (-not [string]::IsNullOrWhiteSpace($rawInput)) {
  try {
    $ev = $rawInput | ConvertFrom-Json -ErrorAction Stop
    $toolName = if ($ev.tool_name) { [string]$ev.tool_name } elseif ($ev.toolName) { [string]$ev.toolName } else { 'unknown' }
    $params = if ($ev.tool_input) { $ev.tool_input } elseif ($ev.params) { $ev.params } else { @{} }
    $cwdVal = if ($ev.cwd) { [string]$ev.cwd } else { $null }
    $paramsJson = $params | ConvertTo-Json -Compress -Depth 10
    if ($null -eq $paramsJson) { $paramsJson = '{}' }
    $cwdJson = if ($cwdVal) { '"' + ($cwdVal -replace '\\', '\\\\') + '"' } else { 'null' }
    $parsed = "{`"toolName`":`"$toolName`",`"params`":$paramsJson,`"cwd`":$cwdJson}"
  } catch {
    # Parse failed → fail-soft allow.
    exit 0
  }
}

if (-not $parsed) { exit 0 }

# Invoke node with the IPC call script. Use env to avoid quote-escape soup.
# Pipe the script to node (PowerShell here-strings don't pass as stdin to &).
# Use Start-Process -Wait -PassThru to capture the real exit code; piping
# `$script | & node` leaves $LASTEXITCODE reflecting Out-Default, not node.
$ipcScript = @'
import { pathToFileURL } from 'node:url';

// Use forward slashes. Node ESM on Windows accepts 'F:/foo/bar.ts' and avoids
// the JS octal-escape issue with 'F:\foo\bar.ts' (the '\s', '\0' literals
// trigger strict-mode parse errors).
const scriptDir = (process.env.CC_SCRIPT_DIR || '').replace(/\\/g, '/');
const clientUrl = pathToFileURL(scriptDir + '/../ipc/client.ts').href;
const { ipcCheck } = await import(clientUrl);

let req;
try { req = JSON.parse(process.env.CC_PAYLOAD); }
catch (e) {
  process.stderr.write('cc.ps1: ipc-payload-parse-failed: ' + e.message + '\n');
  process.exit(1);
}
try {
  const r = await ipcCheck(req);
  const blocker = r.results && r.results.find(x => x.block);
  if (blocker) {
    process.stderr.write(blocker.reason || '[' + blocker.check + '] BLOCKED\n');
    process.exit(2);
  }
  process.exit(0);
} catch (e) {
  process.stderr.write('ipc-failed: ' + e.message + '\n');
  process.exit(1);
}
'@

# Temp script file to feed node via stdin (Start-Process -RedirectStandardInput).
$scriptFile = [System.IO.Path]::GetTempFileName()

function Invoke-Ipc {
  param([string]$Payload)
  $env:CC_SCRIPT_DIR = $scriptDir
  $env:CC_PAYLOAD = $Payload
  # Write the script to a temp file; node reads it via stdin redirect.
  # We use [System.IO.File]::WriteAllText to avoid BOM/encoding surprises.
  [System.IO.File]::WriteAllText($scriptFile, $ipcScript, [System.Text.UTF8Encoding]::new($false))
  $proc = Start-Process -FilePath 'node' `
    -ArgumentList '--input-type=module' `
    -RedirectStandardInput $scriptFile `
    -Wait -PassThru -NoNewWindow
  return $proc.ExitCode
}

# Clear env vars regardless of how we exit (prevent leak to spawned server).
function Cleanup-Env {
  Remove-Item Env:CC_SCRIPT_DIR -ErrorAction SilentlyContinue
  Remove-Item Env:CC_PAYLOAD -ErrorAction SilentlyContinue
}

# 1. Try IPC.
$exit_code = Invoke-Ipc -Payload $parsed
Cleanup-Env

# 2. Fallback: spawn if no live server PID, then re-call.
if ($exit_code -eq 1) {
  $needStart = $true
  if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
      $needStart = $false
    }
  }
  if ($needStart) {
    $proc = Start-Process node -ArgumentList $serverScript -NoNewWindow -PassThru
    if ($proc) {
      $proc.Id | Out-File -FilePath $pidFile -Encoding ASCII -Force
    }
    Start-Sleep -Seconds 2
  }
  $exit_code = Invoke-Ipc -Payload $parsed
  Cleanup-Env
}

# Clean up temp script file.
Remove-Item $scriptFile -ErrorAction SilentlyContinue

exit $exit_code