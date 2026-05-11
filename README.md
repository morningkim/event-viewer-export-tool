# Event Viewer Export

Windows 시스템 로그에서 `Winlogon` 로그온/로그오프 기록을 찾아, 사용자가 직접 Event Viewer를 열 수 있도록 실제 로그 파일과 클릭용 바로가기, 안내 파일을 만드는 도구입니다.

## 현재 방식

이 도구는 더 이상 `eventvwr.exe`를 자동 실행하지 않습니다.

대신 아래 파일을 생성합니다.

- 실제 로그 파일 `.evtx`
- 사용자가 직접 클릭할 `.url`
- 어떤 이벤트를 클릭해야 하는지 적힌 `_guide.txt`

즉 흐름은 이렇습니다.

1. `run_event_viewer_export.bat` 실행
2. 시간 범위와 `Logon/Logoff` 선택
3. 결과 파일 생성
4. 사용자가 `.url` 또는 `.evtx`를 직접 더블클릭
5. Event Viewer에서 안내된 `Winlogon` 이벤트를 직접 클릭

## 배포 기준

필요한 파일:

- `run_event_viewer_export.bat`
- `event_viewer_export.ps1`

두 파일은 반드시 같은 폴더에 있어야 합니다.

## 이벤트 기준

- `Logon`: `Microsoft-Windows-Winlogon / Event ID 7001`
- `Logoff`: `Microsoft-Windows-Winlogon / Event ID 7002`

## 사용 방법

1. `run_event_viewer_export.bat`를 더블클릭합니다.
2. 입력 창에서 아래 값을 넣습니다.
   - `StartTime`
   - `EndTime`
   - `Mode`
3. 생성된 파일 중 `.url` 또는 `.evtx`를 더블클릭합니다.
4. Event Viewer에서 `_guide.txt`에 적힌 이벤트를 클릭합니다.

권장 시간 형식:

```text
yyyy-MM-dd HH:mm:ss
```

예시:

```text
StartTime: 2026-05-07 19:20:00
EndTime:   2026-05-07 19:30:00
Mode:      Logoff
```

## 생성 파일

기본 저장 위치:

```text
C:\codex_artifacts
```

예시:

- `2026-05-07_logoff.evtx`
- `2026-05-07_logoff_open_event_viewer.url`
- `2026-05-07_logoff_guide.txt`

## 직접 실행

배치 파일 대신 PowerShell로 직접 실행할 수도 있습니다.

```powershell
powershell -NoProfile -Command "$p='.\event_viewer_export.ps1'; $s=Get-Content -LiteralPath $p -Raw -Encoding UTF8; & ([scriptblock]::Create($s)) -StartTime '2026-05-07 19:20:00' -EndTime '2026-05-07 19:30:00' -Mode Logoff"
```

## 장점

- 실제 Event Viewer 화면을 사용합니다.
- 실제 Windows 로그 파일을 엽니다.
- 자동 `eventvwr.exe` 실행을 피합니다.

## 주의 사항

- Event Viewer는 사용자가 직접 열어야 합니다.
- `_guide.txt`에 적힌 시각과 `Event ID`를 기준으로 직접 클릭해야 합니다.
