<#
DAIMON Tool Executor: HOST_INVENTORY
Exact allowed operation : read-only inventory of this PC for research planning (PROJECT SI-001): CPU, RAM, GPU/VRAM,
                          disks, runtimes (Ollama/Python/Git/Node), local model files, and top processes by memory.
Input schema            : none beyond -BusRoot.
Path/scope restriction  : CIM / registry reads, '<tool> --version', GET http://127.0.0.1:11434/api/tags (local only),
                          file listing of known model folders (names and sizes only, no contents).
                          Writes only <bus_root>\results\HOST_INVENTORY-<timestamp>.json.
Never                   : starts/stops services, installs, pulls or runs models, reads secrets or file contents.
Exit codes              : 0 = report written.
#>
param(
  [string]$BusRoot = 'C:\Users\teppe\.local\daimon\bus'
)
$ErrorActionPreference = 'Continue'

function Ver([string]$cmd, [string]$arg = '--version') {
  $c = Get-Command $cmd -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $c) { return $null }
  $v = (@(& $c.Source $arg 2>&1) | Select-Object -First 1) -as [string]
  return [ordered]@{ path = $c.Source; version = ($v -replace '\s+', ' ').Trim() }
}
function DirSizeGiB([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { return $null }
  $s = (Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
  return [math]::Round([double]$s / 1GB, 2)
}

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = @(Get-CimInstance Win32_Processor)
$load = @($cpu | ForEach-Object { $_.LoadPercentage })

# VRAM: Win32_VideoController.AdapterRAM caps at 4 GiB; the display-class registry key has the 64-bit value.
$vramByDesc = @{}
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue |
  ForEach-Object {
    $p = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
    if ($p.DriverDesc -and $p.'HardwareInformation.qwMemorySize') { $vramByDesc[[string]$p.DriverDesc] = [math]::Round([double]$p.'HardwareInformation.qwMemorySize' / 1GB, 2) }
  }
$gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object {
  [ordered]@{ name = $_.Name; driver = $_.DriverVersion; status = $_.Status
    vram_gib = if ($vramByDesc.ContainsKey([string]$_.Name)) { $vramByDesc[[string]$_.Name] } else { [math]::Round([double]$_.AdapterRAM / 1GB, 2) } }
})
# All display-class devices incl. disabled / driverless ones (a discrete GPU can be hidden from Win32_VideoController).
$displayDevices = @(Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | ForEach-Object {
  [ordered]@{ name = $_.FriendlyName; status = [string]$_.Status; present = $_.Present } })
$pciVendors = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match '^PCI\\VEN_(10DE|1002)' } |
  ForEach-Object { [ordered]@{ name = $_.FriendlyName; class = [string]$_.Class; status = [string]$_.Status } })
$nvsmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
$nvidia = if ($nvsmi) { @(& $nvsmi.Source --query-gpu=name,memory.total,memory.used,utilization.gpu,driver_version --format=csv,noheader 2>&1) } else { $null }

$disks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
  [ordered]@{ drive = $_.DeviceID; label = $_.VolumeName; size_gib = [math]::Round($_.Size / 1GB, 1); free_gib = [math]::Round($_.FreeSpace / 1GB, 1) } })
$physical = @(Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object {
  [ordered]@{ name = $_.FriendlyName; media = [string]$_.MediaType; bus = [string]$_.BusType; size_gib = [math]::Round($_.Size / 1GB, 1) } })

# Ollama: local API only (no start, no pull).
$ollamaApi = $null
try {
  $tags = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 3
  $ollamaApi = [ordered]@{ running = $true; models = @($tags.models | ForEach-Object {
    [ordered]@{ name = $_.name; size_gib = [math]::Round([double]$_.size / 1GB, 2); family = $_.details.family
      parameter_size = $_.details.parameter_size; quantization = $_.details.quantization_level; modified = $_.modified_at } }) }
} catch { $ollamaApi = [ordered]@{ running = $false; error = $_.Exception.GetType().Name } }

$ollamaHome = if ($env:OLLAMA_MODELS) { $env:OLLAMA_MODELS } else { Join-Path $env:USERPROFILE '.ollama\models' }
$manifestRoot = Join-Path $ollamaHome 'manifests'
$manifests = if (Test-Path -LiteralPath $manifestRoot) {
  @(Get-ChildItem -LiteralPath $manifestRoot -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    $rel = $_.FullName.Substring($manifestRoot.Length + 1) -split '\\'
    if ($rel.Count -ge 2) { "$($rel[-2]):$($rel[-1])" } }) } else { @() }

# Other local model files (names and sizes only) in well-known folders.
$modelDirs = @(
  (Join-Path $env:USERPROFILE '.cache\lm-studio\models'), (Join-Path $env:USERPROFILE '.lmstudio\models'),
  (Join-Path $env:USERPROFILE 'models'), (Join-Path $env:USERPROFILE '.cache\huggingface\hub'),
  (Join-Path $env:USERPROFILE '.cache\llama.cpp'),
  # DAIMON's own local models (FUJITSU_LOCAL_ROUTER llama.cpp, Galaxy model staging).
  (Join-Path $env:USERPROFILE '.local\daimon\local-router\models'), (Join-Path $env:USERPROFILE '.local\daimon\galaxy-local-ai\models'))
$modelFiles = @(foreach ($d in $modelDirs) {
  if (Test-Path -LiteralPath $d) {
    Get-ChildItem -LiteralPath $d -Recurse -File -Include *.gguf, *.safetensors, *.bin -ErrorAction SilentlyContinue |
      Where-Object { $_.Length -gt 100MB } | ForEach-Object { [ordered]@{ file = $_.FullName; size_gib = [math]::Round($_.Length / 1GB, 2) } }
  } })

$top = @(Get-Process -ErrorAction SilentlyContinue | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 | ForEach-Object {
  [ordered]@{ name = $_.ProcessName; ram_mib = [math]::Round($_.WorkingSet64 / 1MB, 0) } })

$report = [ordered]@{
  schema_version = '1.0'; tool = 'HOST_INVENTORY'; generated_at = [DateTimeOffset]::Now.ToString('o')
  hostname = $env:COMPUTERNAME; model = "$($cs.Manufacturer) $($cs.Model)"
  os = "$($os.Caption) $($os.Version)"
  cpu = @($cpu | ForEach-Object { [ordered]@{ name = $_.Name.Trim(); cores = $_.NumberOfCores; threads = $_.NumberOfLogicalProcessors; max_mhz = $_.MaxClockSpeed } })
  cpu_load_percent = $load
  ram_gib = [ordered]@{ total = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2); free = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    commit_limit = [math]::Round($os.TotalVirtualMemorySize / 1MB, 2); commit_free = [math]::Round($os.FreeVirtualMemory / 1MB, 2) }
  gpus = $gpus; display_devices = $displayDevices; nvidia_or_amd_pci_devices = $pciVendors; nvidia_smi = $nvidia
  logical_disks = $disks; physical_disks = $physical
  runtimes = [ordered]@{ ollama = (Ver 'ollama'); python = (Ver 'python'); py_launcher = (Ver 'py'); git = (Ver 'git'); node = (Ver 'node')
    nvcc = (Ver 'nvcc'); llama_cli = (Ver 'llama-cli')
    daimon_local_router_llama = (Ver (Join-Path $env:USERPROFILE '.local\daimon\local-router\runtime-b10536\llama-cli.exe')) }
  ollama_api = $ollamaApi; ollama_models_dir = $ollamaHome; ollama_models_dir_gib = (DirSizeGiB $ollamaHome); ollama_manifests = $manifests
  other_model_files = $modelFiles
  top_processes_by_ram = $top
  secret_recorded = $false
}

$resultDir = Join-Path $BusRoot 'results'
New-Item -ItemType Directory -Force -Path $resultDir | Out-Null
$path = Join-Path $resultDir ("HOST_INVENTORY-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$json = $report | ConvertTo-Json -Depth 6
$json | Set-Content -LiteralPath $path -Encoding utf8
$json | Write-Output
exit 0
