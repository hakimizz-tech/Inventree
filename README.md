## Laptop Inventory Script

Run the following commands in a their respective os  terminal to generate the formatted device report. paste the output directly into the inventory form.

### Windows 10 & 11
```powershell
[PSCustomObject]@{ 'Device Hostname' = $env:COMPUTERNAME; 'Make & Model' = "$((Get-CimInstance Win32_ComputerSystem).Manufacturer)$((Get-CimInstance Win32_ComputerSystem).Model)"; 'Serial Number (S/N)' = (Get-CimInstance Win32_BIOS).SerialNumber; 'Processor (CPU)' = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name; 'RAM (GB)' = [math]::Round(((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory) / 1GB, 2); 'Storage (GB)' = [math]::Round(((Get-CimInstance Win32_DiskDrive | Where-Object MediaType -match 'hard' | Measure-Object -Property Size -Sum).Sum) / 1GB, 2); 'GPU / Graphics' = (Get-CimInstance Win32_VideoController).Name -join ', '; 'Operating System' = (Get-CimInstance Win32_OperatingSystem).Caption; 'Purchase Date' = "Not tracked natively (OS Install Date: $((Get-CimInstance Win32_OperatingSystem).InstallDate.ToString('yyyy-MM-dd')))"; 'Warranty Expiration' = "Not tracked natively (Check OEM Website with S/N)"; 'MAC Address' = (Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object IPEnabled | Select-Object -ExpandProperty MACAddress) -join ', ' } | Format-List
```

### windows 7
```powershell
New-Object PSObject -Property @{ 'Device Hostname' = $env:COMPUTERNAME; 'Make & Model' = "$((Get-WmiObject Win32_ComputerSystem).Manufacturer) $((Get-WmiObject Win32_ComputerSystem).Model)"; 'Serial Number (S/N)' = (Get-WmiObject Win32_BIOS).SerialNumber; 'Processor (CPU)' = @(Get-WmiObject Win32_Processor)[0].Name; 'RAM (GB)' = [math]::Round(((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory) / 1GB, 2); 'Storage (GB)' = [math]::Round(((Get-WmiObject Win32_DiskDrive | Where-Object { $_.MediaType -match 'hard' } | Measure-Object -Property Size -Sum).Sum) / 1GB, 2); 'GPU / Graphics' = (Get-WmiObject Win32_VideoController | ForEach-Object { $_.Name }) -join ', '; 'Operating System' = (Get-WmiObject Win32_OperatingSystem).Caption; 'Purchase Date' = "Not tracked natively (OS Install Date: $([Management.ManagementDateTimeConverter]::ToDateTime((Get-WmiObject Win32_OperatingSystem).InstallDate).ToString('yyyy-MM-dd')))"; 'Warranty Expiration' = "Not tracked natively (Check OEM Website with S/N)"; 'MAC Address' = (Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | ForEach-Object { $_.MACAddress }) -join ', ' } | Select-Object 'Device Hostname', 'Make & Model', 'Serial Number (S/N)', 'Processor (CPU)', 'RAM (GB)', 'Storage (GB)', 'GPU / Graphics', 'Operating System', 'Purchase Date', 'Warranty Expiration', 'MAC Address' | Format-List
```

### linux(Ubuntu >= 24.04.4 )
```bash
sudo printf "%-22s : %s\n" \
  "Device Hostname" "$(hostname)" \
  "Make & Model" "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) $(cat /sys/class/dmi/id/product_name 2>/dev/null)" \
  "Serial Number (S/N)" "$(sudo cat /sys/class/dmi/id/product_serial 2>/dev/null)" \
  "Processor (CPU)" "$(lscpu | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')" \
  "RAM (GB)" "$(awk '/MemTotal/ {printf "%.2f", $2/1048576}' /proc/meminfo)" \
  "Storage (GB)" "$(lsblk -b -d -o NAME,TYPE,SIZE | awk '$2=="disk" && $1!~/^(loop|ram|zram)/ {sum+=$3} END {printf "%.2f", sum/1073741824}')" \
  "GPU / Graphics" "$(lspci | awk -F': ' '/VGA compatible controller|3D controller/ {print $2}' | paste -sd ', ' -)" \
  "Operating System" "$(. /etc/os-release && echo "$PRETTY_NAME")" \
  "Purchase Date" "Not tracked natively (OS Install Date: $(stat -c %w / 2>/dev/null | cut -d' ' -f1))" \
  "Warranty Expiration" "Not tracked natively (Check OEM Website with S/N)" \
  "MAC Address" "$(for iface in /sys/class/net/*; do [ ! -d "/sys/devices/virtual/net/$(basename "$iface")" ] && cat "$iface/address" 2>/dev/null; done | grep -Eiv '^00:00:00:00:00:00$|^$' | paste -sd ',' - | sed 's/,/, /g')"
```
