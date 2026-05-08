# Event Viewer Image Export

Windows Event Viewer에서 `Winlogon` 로그온/로그오프 기록 화면을 자동으로 열고, 제출용 PNG 이미지로 저장하는 도구입니다.

## 포함 파일

- `event_viewer_export.ps1`
  - 실제 동작을 수행하는 PowerShell 스크립트
- `run_event_viewer_export.bat`
  - 더블클릭 실행용 배치 파일

## 지원 대상

- Windows 데스크톱 환경
- Event Viewer(`eventvwr.exe`) 사용 가능 환경
- 대화형 로그인 세션

다음 환경에서는 동작이 불안정하거나 실패할 수 있습니다.

- 잠금 화면 상태
- 원격 비대화형 세션
- 보안 정책상 PowerShell 실행이 차단된 환경

## 사용 방법

1. `run_event_viewer_export.bat`를 더블클릭합니다.
2. 입력 창에서 아래 값을 넣습니다.
   - `StartTime`
   - `EndTime`
   - `Mode`
3. `OK`를 누르면 Event Viewer가 자동으로 열리고 PNG가 저장됩니다.

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

## 이벤트 기준

- `Logon`: `Microsoft-Windows-Winlogon`, `Event ID 7001`
- `Logoff`: `Microsoft-Windows-Winlogon`, `Event ID 7002`

## 저장 위치

기본 저장 위치:

```text
C:\codex_artifacts
```

예시 결과 파일:

- `2026-05-07_logon.png`
- `2026-05-07_logoff.png`

임시 `.evtx` 파일은 기본적으로 작업 후 삭제됩니다.

## 직접 실행

배치 파일 대신 PowerShell로 직접 실행할 수도 있습니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\event_viewer_export.ps1 -StartTime '2026-05-07 19:20:00' -EndTime '2026-05-07 19:30:00' -Mode Logoff
```

## 배포 방법

배포할 때는 `dist` 폴더 안의 파일만 전달하면 됩니다.

## 문제 해결

- `powershell.exe`를 찾을 수 없다고 나오면:
  - `run_event_viewer_export.bat`의 기본 경로는 `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe` 입니다.
- 결과 이미지가 저장되지 않으면:
  - 지정한 시간 범위 안에 `Winlogon 7001/7002` 이벤트가 실제로 있는지 확인하십시오.
- 원하는 이벤트와 다른 화면이 나오면:
  - 시간 범위를 더 좁혀서 다시 실행하십시오.
