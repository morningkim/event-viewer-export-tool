# Event Viewer Image Export

Windows 시스템 로그에서 `Winlogon` 로그온/로그오프 기록을 읽어, 이벤트 뷰어와 비슷한 형태의 PNG 이미지를 직접 생성하는 도구입니다.

## 왜 이 방식으로 바꿨나

이전 버전은 `bat -> PowerShell -> eventvwr.exe 자동 실행 -> 화면 캡처` 방식이었고, 일부 보안 제품에서 이를 탐지했습니다.

현재 버전은:

- `eventvwr.exe`를 실행하지 않습니다.
- 이벤트 로그를 직접 읽습니다.
- PNG 이미지를 직접 생성합니다.

즉 제출용 이미지는 만들되, 탐지 포인트였던 `Event Viewer 자동 실행`은 제거했습니다.

## 배포 기준

현재 배포 기준은 `bat + ps1` 조합입니다.

필요한 파일:

- `run_event_viewer_export.bat`
- `event_viewer_export.ps1`

두 파일은 반드시 같은 폴더에 있어야 합니다.

## 무엇을 생성하나

- `Logon`: `Microsoft-Windows-Winlogon / Event ID 7001`
- `Logoff`: `Microsoft-Windows-Winlogon / Event ID 7002`

지정한 시간 범위의 시스템 로그를 읽고, 선택된 이벤트와 주변 이벤트를 포함한 뷰어 스타일 PNG를 저장합니다.

## 사용 방법

1. `run_event_viewer_export.bat`를 더블클릭합니다.
2. 입력 창에서 아래 값을 넣습니다.
   - `StartTime`
   - `EndTime`
   - `Mode`
3. `OK`를 누르면 PNG가 생성됩니다.

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

## 직접 실행

배치 파일 대신 PowerShell로 직접 실행할 수도 있습니다.

```powershell
powershell -NoProfile -File .\event_viewer_export.ps1 -StartTime '2026-05-07 19:20:00' -EndTime '2026-05-07 19:30:00' -Mode Logoff
```

## 동작 조건

- Windows 데스크톱 환경
- PowerShell 사용 가능 환경
- 시스템 이벤트 로그 읽기 가능 환경

## 주의 사항

- 이 도구는 실제 Event Viewer 창을 캡처하지 않습니다.
- 대신 제출용으로 보기 쉬운 뷰어 스타일 이미지를 생성합니다.
- 아주 좁은 시간 범위를 넣을수록 원하는 이벤트가 더 정확하게 보입니다.

## 문제 해결

- 결과 이미지가 저장되지 않으면:
  - 지정한 시간 범위 안에 `Winlogon 7001` 또는 `7002`가 실제로 있는지 확인하십시오.
- 원하는 이벤트가 안 보이면:
  - 시간 범위를 더 좁혀서 다시 실행하십시오.
