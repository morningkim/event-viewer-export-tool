# Event Viewer Image Export

Windows 이벤트 뷰어에서 `Winlogon` 로그온/로그오프 기록 화면을 열고, 제출용 PNG 이미지로 저장하는 도구입니다.

## 배포 기준

현재 배포 기준은 `bat + ps1` 조합입니다.

필요한 파일:

- `run_event_viewer_export.bat`
- `event_viewer_export.ps1`

두 파일은 반드시 같은 폴더에 있어야 합니다.  
사용자는 `run_event_viewer_export.bat`를 더블클릭해서 실행합니다.

## 무엇을 하나

- `Logon`: `Microsoft-Windows-Winlogon / Event ID 7001`
- `Logoff`: `Microsoft-Windows-Winlogon / Event ID 7002`

지정한 시간 범위의 이벤트를 찾아 Event Viewer를 열고, 그 화면을 PNG로 저장합니다.

## 사용 방법

1. `run_event_viewer_export.bat`를 더블클릭합니다.
2. 입력 창에서 아래 값을 넣습니다.
   - `StartTime`
   - `EndTime`
   - `Mode`
3. `OK`를 누르면 PNG 저장 작업이 진행됩니다.

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

## 저장소 구성

- `run_event_viewer_export.bat`
- `event_viewer_export.ps1`
- `README.md`
- `event_viewer_export_dist.zip`

`exe`와 C# 소스는 저장소에 남아 있지만, 현재 배포 기준은 아닙니다.

## 동작 조건

- Windows 데스크톱 환경
- PowerShell 사용 가능 환경
- Event Viewer(`eventvwr.exe`) 사용 가능 환경
- 대화형 로그인 세션

다음 경우에는 실패하거나 결과가 불안정할 수 있습니다.

- 잠금 화면 상태
- 원격 비대화형 세션
- PowerShell 실행 차단
- 보안 제품이 `eventvwr.exe` 자동 실행을 차단하는 환경

## 문제 해결

- `powershell.exe`를 찾을 수 없다고 나오면:
  - `run_event_viewer_export.bat`는 `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`를 사용합니다.
- 결과 이미지가 저장되지 않으면:
  - 지정한 시간 범위 안에 `Winlogon 7001` 또는 `7002`가 실제로 있는지 확인하십시오.
- 보안 제품이 차단하면:
  - `eventvwr.exe` 자동 실행이 탐지된 것입니다. 이 경우 현재 방식은 예외 처리 없이는 계속 막힐 수 있습니다.
