<#
================================================================================
 migrate_to_domain.ps1
 ワークグループのPCをドメイン(MAIN001)に参加させ、既存のローカルユーザーの
 プロファイルを、データをコピーせずにそのままドメインアカウントへ引き継ぐ。

 ※このファイルは「UTF-8 (BOM付き)」で保存すること。BOMが無いと
   Windows PowerShell 5.1 で日本語コメントが文字化けし、構文エラーになる。
   VS Code で編集した場合は右下の文字コードを「UTF-8 with BOM」にして保存する。
================================================================================

 ■ 各段階（Phase）の概要
   どの段階も「管理者として実行」したPowerShellで実行する。

   Check    確認のみ（何も変更しない）。いつ実行してもよい。
            EMAのターミナル（SYSTEM）からも実行できる（run_check.cmd を使う）。
   Join     ローカル管理者で実行。tmpadmin を作成し、DNS・時刻を確認してドメインに参加、再起動。
            すでにドメイン参加済みの場合は tmpadmin の作成だけ行う。
   Remap    .\tmpadmin で実行。ドメインユーザーがまだ一度もサインインしていないこと。
            旧プロファイル（フォルダとレジストリ）にドメインユーザーの権限を付け、
            ドメインユーザーが旧プロファイルを使うように登録し、ローカルユーザーを無効化して再起動。
   Cleanup  ドメイン管理者で実行（tmpadmin では実行しない）。
            tmpadmin とそのプロファイルを削除し、DNS再登録・gpupdate を行い、確認結果を表示。
   Rollback Remap を取り消す（.\tmpadmin かドメイン管理者で実行）。実行後に再起動。

 ■ 作業手順（例: MOUSE-015 / ローカル usr_0064 → MAIN001\usr_0064）
   ★印はスクリプトでは実行できない手作業。

   ★1. 利用者に準備してもらう
         - Edge（Chrome等）の同期をオンにする、または保存パスワードをエクスポートする
           （ブラウザの保存パスワード・資格情報マネージャー・EFS暗号化は引き継げないため）
         - 作業中のファイルを保存して、アプリを閉じる

     2. tmpadmin を作成する（利用者 usr_0064 でサインインしたまま、管理者PowerShellで）
         cd C:\EMAAgent
         .\migrate_to_domain.ps1 -Phase Join -LocalUser usr_0064 -DomainUser MAIN001\usr_0064
           → tmpadmin のパスワードを聞かれるので入力する
           → ドメイン参加済みなので tmpadmin の作成だけで終わる
         （手作業で作る場合）
         net user tmpadmin <一時パスワード> /add
         net localgroup Administrators tmpadmin /add

   ★3. usr_0064 をサインアウトし、.\tmpadmin でサインインする
         - サインイン画面で「他のユーザー」→ ユーザー名に .\tmpadmin
         - usr_0064 と MAIN001\usr_0064 のどちらでもサインインしないこと

     4. プロファイルを引き継ぐ（tmpadmin の管理者PowerShellで）
         cd C:\EMAAgent
         .\migrate_to_domain.ps1 -Phase Remap -LocalUser usr_0064 -DomainUser MAIN001\usr_0064 -MakeAdmin -DryRun
         .\migrate_to_domain.ps1 -Phase Remap -LocalUser usr_0064 -DomainUser MAIN001\usr_0064 -MakeAdmin
           → -MakeAdmin: 元のローカルユーザーが管理者だったので、ドメインユーザーも管理者にする
           → icacls の「アクセスが拒否されました」は互換用のフォルダ（Application Data,
             My Documents, Cookies, SendTo, Content.IE5 など）なので無視してよい
           → 最後に Enter を押すと再起動する

   ★5. 利用者に MAIN001\usr_0064 でサインインしてもらい、確認する
         - 壁紙・デスクトップ・タスクバーが元のままか
         - スタートメニュー・設定アプリが開くか
           （開かない場合は usr_0064 のPowerShellで以下を実行）
           Get-AppxPackage | % { Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue }
         - よく使うアプリ・共有フォルダ・ブラウザ（同期/インポート）
         - 「一時プロファイルでサインインしています」と出たら、すぐサインアウトして
           tmpadmin で -Phase Rollback を実行し、ログを確認する

     6. 後片付け（ドメイン管理者で昇格したPowerShellで）
         .\migrate_to_domain.ps1 -Phase Cleanup -LocalUser usr_0064 -DomainUser MAIN001\usr_0064
           → 「tmpadmin profile is in use」と出たら再起動してから再実行

     7. 最終確認（EMAのターミナルからでよい）
         C:\EMAAgent\run_check.cmd usr_0064 MAIN001\usr_0064
           → Domain user の項目が「already re-mapped」になっていればOK
   ★    自分のPCから: DNS登録 / GPO用セキュリティグループ / EMA Connected / 4625が出ていないこと

   ★8. 数日後、問題がなければ無効化したローカルユーザーを削除する
         Remove-LocalUser usr_0064
         ※ C:\Users\usr_0064 フォルダはドメインユーザーが使用中なので絶対に消さない

 ■ ドメイン未参加のPCの場合
   手順2の Join でドメイン参加まで行い、自動で再起動する。再起動後は手順3から同じ。

 ■ 実行例（その他）
   .\migrate_to_domain.ps1 -Phase Check -LocalUser usr_012 -DomainUser MAIN001\usr_0012 -CompareSid S-1-5-21-2644483170-2825088604-812525569
     → -CompareSid に他のPCのマシンSIDを渡すと、イメージ複製（sysprep無し）かどうかを判定する
   .\migrate_to_domain.ps1 -Phase Rollback -LocalUser usr_012 -DomainUser MAIN001\usr_0012

 ■ ログ
   <LogDir>\migrate_<Phase>_<PC名>_<日時>.txt（既定: C:\Windows\Temp）

 ■ EMAのターミナルについて
   SYSTEMで動き、入力を受け付けないため、使えるのは Check だけ。
   Join / Remap / Cleanup はパスワード入力や再起動確認があるので、実機かRDPで実行する。
#>
param(
    [Parameter(Mandatory)][ValidateSet('Check', 'Join', 'Remap', 'Cleanup', 'Rollback')][string]$Phase,
    [Parameter(Mandatory)][string]$LocalUser,
    [Parameter(Mandatory)][string]$DomainUser,
    [string]$DomainSid,                                  # 名前でSIDに変換できない場合にSIDを直接指定
    [string]$DomainName = 'Main001.bones',
    [string]$NetbiosName = 'MAIN001',
    [string]$DC = 'BoneHead-03.Main001.bones',
    [string]$TempAdmin = 'tmpadmin',
    [string[]]$CompareSid,                               # Check用: 比較する他PCのマシンSID（複製判定）
    [switch]$MakeAdmin,                                  # Remap用: ドメインユーザーをローカル管理者にする
    [switch]$DryRun,                                     # 確認のみ（変更しない）
    [string]$LogDir = 'C:\Windows\Temp'                # ログ保存先（EMAから実行する場合は C:\EMAAgent）
)

$ErrorActionPreference = 'Stop'
$log = Join-Path $LogDir "migrate_${Phase}_$($env:COMPUTERNAME)_$(Get-Date -Format yyyyMMdd_HHmmss).txt"
Start-Transcript -Path $log | Out-Null

$plRoot = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
$adminsSid = 'S-1-5-32-544'
$adminsName = ((New-Object Security.Principal.SecurityIdentifier($adminsSid)).Translate([Security.Principal.NTAccount]).Value -split '\\')[-1]

function Step([string]$m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Ok([string]$m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail([string]$m) { throw $m }
function Me { [Security.Principal.WindowsIdentity]::GetCurrent().Name }

function Assert-Elevated {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Fail 'Run this in an elevated PowerShell (Run as administrator).' }
}
function Get-LocalSidObj { (New-Object Security.Principal.NTAccount("$env:COMPUTERNAME\$LocalUser")).Translate([Security.Principal.SecurityIdentifier]) }
function Get-DomainSidObj {
    if ($DomainSid) { return New-Object Security.Principal.SecurityIdentifier($DomainSid) }
    (New-Object Security.Principal.NTAccount($DomainUser)).Translate([Security.Principal.SecurityIdentifier])
}
function Test-SecureChannel {
    $out = nltest /sc_query:$NetbiosName 2>&1 | Out-String
    return ($out -match 'NERR_Success')
}
function Get-DcOffset {
    # DCとの時刻差（秒・絶対値）を返す。測定できなければ $null
    $sc = w32tm /stripchart /computer:$DC /samples:2 /dataonly 2>&1 | Out-String
    $m = [regex]::Matches($sc, '([+-]\d+\.\d+)s') | Select-Object -Last 1
    if ($m) { return [math]::Abs([double]$m.Groups[1].Value) }
    return $null
}
function Get-LocalIPv4 {
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' } | Select-Object -ExpandProperty IPAddress
}
function Test-PendingReboot {
    $r = @()
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $r += 'Windows servicing' }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $r += 'Windows Update' }
    $cn = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName').ComputerName
    $acn = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName').ComputerName
    if ($cn -ne $acn) { $r += "computer rename ($acn -> $cn)" }
    return $r
}
function Confirm-Continue([string]$msg) {
    $a = Read-Host "$msg [y/N]"
    if ($a -notmatch '^(y|yes)$') { Fail 'Cancelled by user.' }
}

# ---- レジストリ権限の付与（再帰）----
# レジストリは親キーに権限を付けても既存のサブキーには反映されないため、全キーをたどって付ける。
# （MOUSE-014で一番上だけに付けたところ、サインイン直後にサインアウトされる不具合が出た）
$script:ok = 0; $script:ng = 0
function Grant-Tree([Microsoft.Win32.RegistryKey]$Parent, [string]$Name, [string]$Path, $Rule) {
    $rights = [System.Security.AccessControl.RegistryRights]'ChangePermissions, ReadKey'
    $k = $null
    try { $k = $Parent.OpenSubKey($Name, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, $rights) }
    catch { $script:ng++; Warn "registry open failed: $Path"; return }
    if (-not $k) { return }
    try { $acl = $k.GetAccessControl(); $acl.AddAccessRule($Rule); $k.SetAccessControl($acl); $script:ok++ }
    catch { $script:ng++; Warn "registry ACL failed: $Path" }
    foreach ($sub in $k.GetSubKeyNames()) { Grant-Tree $k $sub "$Path\$sub" $Rule }
    $k.Close()
}
function Grant-Hive([string]$File, [string]$Mount, $SidObj) {
    if (-not (Test-Path $File -PathType Leaf)) { Warn "hive not found (skipped): $File"; return }
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule($SidObj, 'FullControl', 'ContainerInherit', 'None', 'Allow')
    reg load "HKU\$Mount" $File | Out-Null
    try {
        $script:ok = 0; $script:ng = 0
        Grant-Tree ([Microsoft.Win32.Registry]::Users) $Mount "HKU\$Mount" $rule
        Ok "hive $File : $($script:ok) keys granted, $($script:ng) failed"
    }
    finally {
        [gc]::Collect(); [gc]::WaitForPendingFinalizers(); Start-Sleep -Seconds 1
        reg unload "HKU\$Mount" | Out-Null
    }
}

try {
    Assert-Elevated
    "Phase: $Phase   Running as: $(Me)   Computer: $env:COMPUTERNAME   DryRun: $DryRun"

    # このファイル自体がBOM付きか確認（BOMが無いとPowerShell 5.1で日本語コメントが化ける）
    if (([IO.File]::ReadAllBytes($PSCommandPath)[0..2] -join ',') -eq '239,187,191') { Ok 'script file: UTF-8 with BOM' }
    else { Warn 'script file has NO UTF-8 BOM. Re-save it as "UTF-8 with BOM".' }

    switch ($Phase) {

        # ===== Check: 確認のみ。何も変更しない =====
        'Check' {
            $script:nOk = 0; $script:nWarn = 0; $script:nNg = 0
            function C-Ok([string]$m) { $script:nOk++; Ok $m }
            function C-Warn([string]$m) { $script:nWarn++; Warn $m }
            function C-Ng([string]$m) { $script:nNg++; Write-Host "[NG]   $m" -ForegroundColor Red }
            function C-Info([string]$m) { Write-Host "[INFO] $m" }

            Step 'Computer'
            $cs = Get-CimInstance Win32_ComputerSystem
            $os = Get-CimInstance Win32_OperatingSystem
            C-Info "$($cs.Name)  $($os.Caption) $($os.Version)  Domain=$($cs.Domain)  PartOfDomain=$($cs.PartOfDomain)"
            $pr = Test-PendingReboot
            if ($pr) { C-Ng "reboot pending: $($pr -join ', ')" } else { C-Ok 'no pending reboot' }
            $tz = tzutil /g
            if ($tz -eq 'Tokyo Standard Time') { C-Ok "time zone: $tz" } else { C-Ng "time zone is '$tz' (fix: tzutil /s ""Tokyo Standard Time"")" }

            Step 'Network / DC'
            $ips = Get-LocalIPv4
            C-Info "IPv4: $($ips -join ', ')"
            $dns = (Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses }).ServerAddresses | Select-Object -Unique
            C-Info "DNS servers: $($dns -join ', ')"
            $dcIp = $null
            try { $dcIp = (Resolve-DnsName $DC -Type A -ErrorAction Stop | Where-Object IPAddress | Select-Object -First 1).IPAddress; C-Ok "DC resolves: $DC -> $dcIp" }
            catch { C-Ng "cannot resolve $DC (DNS must point to the DC)" }
            if ($dcIp) {
                $off = Get-DcOffset
                if ($null -eq $off) { C-Warn 'could not measure time offset vs DC' }
                elseif ($off -gt 300) { C-Ng   "clock differs from DC by $([int]$off) s (>5 min, Kerberos will fail)" }
                elseif ($off -gt 60) { C-Warn "clock differs from DC by $([int]$off) s" }
                else { C-Ok   "time offset vs DC: $off s" }
            }

            Step 'Domain membership'
            if ($cs.PartOfDomain) {
                if (Test-SecureChannel) { C-Ok "joined, secure channel OK" }
                else { C-Ng "joined but secure channel broken (Test-ComputerSecureChannel -Repair -Server $DC -Credential $NetbiosName\<admin>)" }
                C-Info "time source: $(w32tm /query /source)"
            }
            else { C-Info 'not joined (WORKGROUP) -> Join needed' }

            try {
                $rec = Resolve-DnsName "$env:COMPUTERNAME.$DomainName" -Type A -DnsOnly -ErrorAction Stop | Where-Object IPAddress
                $recIps = $rec.IPAddress
                if (@($recIps | Where-Object { $ips -contains $_ }).Count -gt 0) { C-Ok "DNS record $env:COMPUTERNAME -> $($recIps -join ', ') (matches this PC)" }
                else { C-Warn "DNS record $env:COMPUTERNAME -> $($recIps -join ', ') does NOT match this PC (stale record or name used by another PC; delete it on the DNS server)" }
            }
            catch { C-Info "no DNS record for $env:COMPUTERNAME.$DomainName" }

            Step 'Machine SID (clone check)'
            $machineSid = (Get-LocalUser | Select-Object -First 1).SID.AccountDomainSid.Value
            C-Info "machine SID: $machineSid"
            if ($CompareSid) {
                if ($CompareSid -contains $machineSid) { C-Ng 'same machine SID as a compared PC (cloned without sysprep)' }
                else { C-Ok 'machine SID differs from compared PCs' }
            }
            else { C-Info 'pass -CompareSid <other PC machine SID> to check for clones' }

            Step "Local user '$LocalUser'"
            $lu = Get-LocalUser -Name $LocalUser -ErrorAction SilentlyContinue
            $localSid = $null; $profilePath = $null
            if (-not $lu) { C-Ng "local user $LocalUser not found" }
            else {
                $localSid = $lu.SID
                C-Info "SID $($localSid.Value)  Enabled=$($lu.Enabled)"
                $isAdmin = try { Get-LocalGroupMember -SID $adminsSid -ErrorAction SilentlyContinue | Where-Object { $_.SID -eq $localSid } } catch { $null }
                C-Info "local admin: $([bool]$isAdmin)  (if True, consider -MakeAdmin at Remap)"
                $lk = Join-Path $plRoot $localSid.Value
                if (Test-Path $lk) {
                    $profilePath = (Get-ItemProperty $lk).ProfileImagePath
                    C-Ok "profile: $profilePath"
                    if (Test-Path "Registry::HKEY_USERS\$($localSid.Value)") { C-Warn "$LocalUser is signed in now (must be signed out before Remap)" }
                    foreach ($b in @{ Chrome = 'AppData\Local\Google\Chrome\User Data'; Edge = 'AppData\Local\Microsoft\Edge\User Data'; Firefox = 'AppData\Roaming\Mozilla\Firefox\Profiles' }.GetEnumerator()) {
                        if (Test-Path (Join-Path $profilePath $b.Value)) { C-Warn "$($b.Key) data found: saved passwords will NOT carry over (turn on sync / export first)" }
                    }
                }
                else { C-Ng "no profile for $LocalUser (nothing to migrate)" }
            }

            Step "Domain user '$DomainUser'"
            if ($cs.PartOfDomain -or $DomainSid) {
                try {
                    $domSid = Get-DomainSidObj
                    C-Ok "resolves to $($domSid.Value)"
                    $dk = Join-Path $plRoot $domSid.Value
                    if (Test-Path $dk) {
                        $dp = (Get-ItemProperty $dk).ProfileImagePath
                        if ($profilePath -and $dp -eq $profilePath) { C-Ok "already re-mapped to $dp (migration done)" }
                        else { C-Ng "already has its own profile: $dp (delete it before Remap if it holds nothing needed)" }
                    }
                    else { C-Ok 'no existing profile (ready for Remap)' }
                }
                catch { C-Ng "cannot resolve $DomainUser (wrong name? or pass -DomainSid)" }
            }
            else { C-Info 'PC not joined yet: domain user is checked after Join' }

            Step 'Other'
            if (Get-LocalUser -Name $TempAdmin -ErrorAction SilentlyContinue) { C-Info "$TempAdmin exists" } else { C-Info "$TempAdmin does not exist (Join creates it)" }
            $ema = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'EMA|Endpoint Management' }
            if ($ema) { $ema | ForEach-Object { C-Info "service $($_.DisplayName): $($_.Status)" } } else { C-Warn 'EMA agent service not found' }

            Step 'Summary'
            Write-Host ("OK={0}  WARN={1}  NG={2}" -f $script:nOk, $script:nWarn, $script:nNg)
            if ($script:nNg -gt 0) { Write-Host 'Fix NG items before continuing.' -ForegroundColor Red }
            elseif (-not $cs.PartOfDomain) { 'NEXT: -Phase Join' }
            else { "NEXT: sign in as .\$TempAdmin and run -Phase Remap (or Cleanup if already migrated)" }
            return
        }

        # ===== Join: tmpadmin作成、DNS・時刻確認、ドメイン参加 =====
        'Join' {
            Step 'Pre-check'
            $cs = Get-CimInstance Win32_ComputerSystem
            "Domain: $($cs.Domain)   PartOfDomain: $($cs.PartOfDomain)"
            "TimeZone: $(tzutil /g)"
            if ((tzutil /g) -ne 'Tokyo Standard Time') { Warn 'Time zone is not Tokyo Standard Time. Fix with: tzutil /s "Tokyo Standard Time"' }

            $lu = Get-LocalUser -Name $LocalUser -ErrorAction SilentlyContinue
            if (-not $lu) { Fail "Local user '$LocalUser' not found." }
            Ok "local user $LocalUser exists (Enabled=$($lu.Enabled))"

            try { $ip = (Resolve-DnsName $DC -Type A -ErrorAction Stop | Select-Object -First 1).IPAddress; Ok "DNS: $DC -> $ip" }
            catch { Fail "Cannot resolve $DC. Check the DNS server (ipconfig /all) - it must point to the DC." }

            $off = Get-DcOffset
            if ($null -eq $off) { Warn 'could not measure time offset vs DC' }
            elseif ($off -gt 300) { Fail "Clock differs from DC by $([int]$off) s (>5 min). Fix the time first (Set-Date / tzutil)." }
            else { Ok "time offset vs DC: $off s" }

            $pr = Test-PendingReboot
            if ($pr) { Fail "Reboot pending: $($pr -join ', '). Reboot first." }

            Step "Temporary admin '$TempAdmin'"
            if (Get-LocalUser -Name $TempAdmin -ErrorAction SilentlyContinue) { Ok "$TempAdmin already exists" }
            elseif ($DryRun) { "would create $TempAdmin" }
            else {
                $pw = Read-Host "Password for $TempAdmin" -AsSecureString
                New-LocalUser -Name $TempAdmin -Password $pw -PasswordNeverExpires -AccountNeverExpires -Description 'temporary admin for domain migration' | Out-Null
                Add-LocalGroupMember -SID $adminsSid -Member $TempAdmin
                Ok "$TempAdmin created and added to $adminsName"
            }

            if ($cs.PartOfDomain) {
                if (Test-SecureChannel) { Ok "already joined to $($cs.Domain), secure channel OK" }
                else { Warn "joined to $($cs.Domain) but secure channel is broken. Repair: Test-ComputerSecureChannel -Repair -Server $DC -Credential $NetbiosName\<admin>" }
                "`nNEXT: sign out, sign in as .\$TempAdmin, then run -Phase Remap."
                return
            }

            if ($DryRun) { "`nDry run OK. Nothing changed."; return }

            Step 'Join domain'
            $cred = Get-Credential -Message "Domain admin to join $DomainName (e.g. $NetbiosName\administrator)"
            Add-Computer -DomainName $DomainName -Server $DC -Credential $cred -Force
            Ok "joined $DomainName"
            "`nNEXT: after reboot sign in as .\$TempAdmin (NOT as $LocalUser or $DomainUser), then run -Phase Remap."
            Read-Host 'Press Enter to reboot now'
            Restart-Computer -Force
        }

        # ===== Remap: 旧プロファイルをドメインユーザーに引き継ぐ =====
        'Remap' {
            Step 'Pre-check'
            $me = Me
            if ($me -match "\\$([regex]::Escape($LocalUser))$" -or $me -ieq $DomainUser) { Fail "Do not run Remap as $me. Sign in as .\$TempAdmin." }

            $cs = Get-CimInstance Win32_ComputerSystem
            if (-not $cs.PartOfDomain) { Fail 'This PC is not domain-joined yet. Run -Phase Join first.' }
            if (-not (Test-SecureChannel)) { Fail "Secure channel to $NetbiosName is not OK (nltest /sc_query:$NetbiosName). Fix that first." }
            Ok "domain $($cs.Domain), secure channel OK"

            $localSid = Get-LocalSidObj
            $domSid = Get-DomainSidObj
            "Local  : $env:COMPUTERNAME\$LocalUser  $($localSid.Value)"
            "Domain : $DomainUser  $($domSid.Value)"

            $localKey = Join-Path $plRoot $localSid.Value
            $domKey = Join-Path $plRoot $domSid.Value
            if (-not (Test-Path $localKey)) { Fail "No profile found for $LocalUser." }
            $profilePath = (Get-ItemProperty $localKey).ProfileImagePath
            "Profile: $profilePath"

            if (Test-Path $domKey) {
                Fail ("$DomainUser already has a profile: $((Get-ItemProperty $domKey).ProfileImagePath)`n" +
                    "Check it holds nothing needed, delete it (sysdm.cpl > Advanced > User Profiles), then re-run.")
            }
            foreach ($s in $localSid.Value, $domSid.Value) {
                if (Test-Path "Registry::HKEY_USERS\$s") { Fail "Profile hive for $s is loaded (user signed in?). Sign out / reboot and re-run." }
            }
            Ok 'checks passed'
            if ($DryRun) { "`nDry run OK. Nothing changed."; return }

            Step 'Backup ProfileList'
            $bak = "C:\Windows\Temp\ProfileList_backup_$(Get-Date -Format yyyyMMdd_HHmmss).reg"
            reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" $bak /y | Out-Null
            Ok $bak

            Step 'Folder permissions (may take a few minutes; "Access is denied" on legacy junctions is normal)'
            icacls $profilePath /grant "*$($domSid.Value):(OI)(CI)F" /T /C /Q | Out-Null
            icacls $profilePath /setowner "*$($domSid.Value)" /C /Q | Out-Null
            Ok 'folder permissions granted'

            Step 'Registry hive permissions (recursive)'
            Grant-Hive "$profilePath\NTUSER.DAT" 'mig_ntuser' $domSid
            Grant-Hive "$profilePath\AppData\Local\Microsoft\Windows\UsrClass.dat" 'mig_usrclass' $domSid

            # ドメインユーザーのSIDでProfileListに登録し、旧プロファイルのフォルダを指すようにする
            # （Sid は新しいSIDに置き換え、RefCount（使用中カウント）は複製しない）
            Step 'ProfileList entry'
            New-Item -Path $domKey | Out-Null
            $src = Get-Item $localKey
            foreach ($name in $src.GetValueNames()) {
                if ($name -in 'Sid', 'RefCount') { continue }
                New-ItemProperty -Path $domKey -Name $name -PropertyType $src.GetValueKind($name) `
                    -Value $src.GetValue($name, $null, 'DoNotExpandEnvironmentNames') | Out-Null
            }
            $bin = New-Object byte[] $domSid.BinaryLength
            $domSid.GetBinaryForm($bin, 0)
            New-ItemProperty -Path $domKey -Name Sid -Value $bin -PropertyType Binary -Force | Out-Null
            Set-ItemProperty -Path $domKey -Name State -Value 0
            Ok "$DomainUser -> $profilePath"

            Step 'Local user / admin rights'
            Disable-LocalUser -Name $LocalUser
            Ok "$LocalUser disabled (kept for rollback)"
            if ($MakeAdmin) {
                Add-LocalGroupMember -SID $adminsSid -Member $DomainUser -ErrorAction SilentlyContinue
                Ok "$DomainUser added to $adminsName"
            }
            else {
                $wasAdmin = try { Get-LocalGroupMember -SID $adminsSid -ErrorAction SilentlyContinue | Where-Object { $_.SID -eq $localSid } } catch { $null }
                if ($wasAdmin) { Warn "$LocalUser was a local admin but $DomainUser is not. Re-run with -MakeAdmin or: net localgroup $adminsName $DomainUser /add" }
            }

            "`nNEXT: reboot, sign in as $DomainUser and check desktop / apps / shares."
            "If 'temporary profile' appears: sign out immediately and run -Phase Rollback."
            "Rollback info: delete $domKey ; Enable-LocalUser $LocalUser"
            Read-Host 'Press Enter to reboot now'
            Restart-Computer -Force
        }

        # ===== Cleanup: tmpadmin削除、DNS再登録、gpupdate、確認 =====
        'Cleanup' {
            Step 'Pre-check'
            if ((Me) -match "\\$([regex]::Escape($TempAdmin))$") { Fail "Do not run Cleanup as $TempAdmin. Sign in as a domain admin (or elevate with domain admin)." }

            Step "Remove $TempAdmin"
            $tu = Get-LocalUser -Name $TempAdmin -ErrorAction SilentlyContinue
            if (-not $tu) { Ok "$TempAdmin does not exist" }
            else {
                $prof = Get-CimInstance Win32_UserProfile | Where-Object { $_.SID -eq $tu.SID.Value }
                if ($prof -and $prof.Loaded) { Fail "$TempAdmin profile is in use. Reboot, then re-run Cleanup." }
                if ($DryRun) { "would remove $TempAdmin and its profile" }
                else {
                    if ($prof) { $prof | Remove-CimInstance; Ok "profile $($prof.LocalPath) removed" }
                    Remove-LocalUser -Name $TempAdmin
                    Ok "$TempAdmin removed"
                }
            }

            Step 'Local user'
            $lu = Get-LocalUser -Name $LocalUser -ErrorAction SilentlyContinue
            if ($lu -and $lu.Enabled -and -not $DryRun) { Disable-LocalUser -Name $LocalUser; Ok "$LocalUser disabled" }
            elseif ($lu) { Ok "$LocalUser Enabled=$($lu.Enabled)" }

            Step 'Domain / DNS / GPO'
            if (Test-SecureChannel) { Ok 'secure channel OK' } else { Warn "secure channel NOT OK (nltest /sc_query:$NetbiosName)" }
            if (-not $DryRun) {
                ipconfig /registerdns | Out-Null; Ok 'DNS re-registration requested'
                gpupdate /force | Out-Null; Ok 'gpupdate done'
            }
            "Time source: $(w32tm /query /source)"

            Step 'Summary'
            Get-LocalUser | Format-Table Name, Enabled -AutoSize | Out-String
            net localgroup $adminsName
            "Check from your PC: Resolve-DnsName $env:COMPUTERNAME.$DomainName ; AD group membership for GPO ; EMA Connected ; no 4625 for $env:COMPUTERNAME`$"
            "Later (after a few days): Remove-LocalUser $LocalUser   (do NOT delete the profile folder - the domain user uses it)"
        }

        # ===== Rollback: Remapを取り消す =====
        'Rollback' {
            $localSid = Get-LocalSidObj
            $domSid = Get-DomainSidObj
            $localKey = Join-Path $plRoot $localSid.Value
            $domKey = Join-Path $plRoot $domSid.Value
            if ((Me) -ieq $DomainUser) { Fail "Do not run Rollback as $DomainUser." }
            if (Test-Path $domKey) {
                $p1 = (Get-ItemProperty $domKey).ProfileImagePath
                $p2 = (Get-ItemProperty $localKey -ErrorAction SilentlyContinue).ProfileImagePath
                if ($p1 -ne $p2) { Fail "$domKey points to '$p1', not to $LocalUser's profile '$p2'. Not touching it." }
                if ($DryRun) { "would delete $domKey" } else { Remove-Item $domKey -Recurse; Ok "deleted $domKey" }
            }
            else { Ok 'no domain ProfileList entry' }
            if (-not $DryRun) { Enable-LocalUser -Name $LocalUser; Ok "$LocalUser enabled" }
            "`nReboot, then $LocalUser can sign in as before."
        }
    }
}
catch {
    Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Stop-Transcript | Out-Null
    "Log: $log"
}