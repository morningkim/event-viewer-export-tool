# Event Viewer Image Export

Windows 이벤트 뷰어에서 `Winlogon` 로그온/로그오프 기록 화면을 열고, 제출용 PNG 이미지로 저장하는 도구입니다.

## 배포용 실행 파일

기본 배포 파일:

- `EventViewerImageExport.exe`

더블클릭하면 입력 창이 열리고, 시간 범위와 `Logon` 또는 `Logoff`를 선택한 뒤 PNG를 저장합니다.

기본 저장 위치:

```text
C:\codex_artifacts
```

예시 결과 파일:

- `2026-05-07_logon.png`
- `2026-05-07_logoff.png`

## 이벤트 기준

- `Logon`: `Microsoft-Windows-Winlogon`, `Event ID 7001`
- `Logoff`: `Microsoft-Windows-Winlogon`, `Event ID 7002`

## 사용 방법

1. `EventViewerImageExport.exe`를 더블클릭합니다.
2. 아래 값을 입력합니다.
   - `StartTime`
   - `EndTime`
   - `Mode`
3. `OK`를 누르면 Event Viewer가 열리고 PNG가 저장됩니다.

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

## 명령줄 실행

원하면 명령줄에서도 실행할 수 있습니다.

```text
EventViewerImageExport.exe --start 2026-05-07 19:20:00 --end 2026-05-07 19:30:00 --mode Logoff
```

선택 인수:

- `--output <폴더경로>`
- `--delay <밀리초>`
- `--keep-evtx`

## 저장소 구성

- `EventViewerImageExport.exe`
- `src/EventViewerImageExport.cs`
- `build_exe.bat`
- `event_viewer_export.ps1`
- `run_event_viewer_export.bat`

`ps1`과 `bat`는 기존 스크립트 버전이고, 현재 배포 기준은 `exe`입니다.

## 동작 조건

- Windows 데스크톱 환경
- Event Viewer(`eventvwr.exe`) 사용 가능 환경
- 대화형 로그인 세션

다음 경우에는 실패하거나 결과가 불안정할 수 있습니다.

- 잠금 화면 상태
- 원격 비대화형 세션
- PowerShell 또는 이벤트 로그 접근이 차단된 환경

## 문제 해결

- 결과 이미지가 저장되지 않으면:
  - 지정한 시간 범위 안에 `Winlogon 7001` 또는 `7002`가 실제로 있는지 확인하십시오.
- 원하는 이벤트와 다른 화면이 나오면:
  - 시간 범위를 더 좁혀서 다시 실행하십시오.
