# Claude Code Usage Widget

[![macOS](https://img.shields.io/badge/macOS-12+-blue.svg)](https://www.apple.com/macos/)
[![xbar](https://img.shields.io/badge/xbar-compatible-brightgreen.svg)](https://xbarapp.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

macOS 메뉴바에서 Claude Code API 사용량을 실시간으로 모니터링하는 xbar 플러그인입니다.

## Quick Start

```bash
# 저장소 클론
git clone https://github.com/tesilio/cc-usage-widget.git
cd cc-usage-widget

# 설치 (의존성 + 플러그인 자동 설치)
./install.sh
```

설치 스크립트가 자동으로 처리하는 항목:
- Homebrew 설치 확인 (없으면 설치)
- jq, bc 의존성 설치
- xbar 설치 확인 (없으면 설치 제안)
- 플러그인 복사 및 실행 권한 설정
- Claude Code 인증 상태 확인

## 사전 요구사항

- **macOS** 12 이상
- **Claude Code CLI** 로그인 완료 (`claude login`)

## 기능

| 기능 | 설명 |
|------|------|
| 5시간 블록 사용량 | 메뉴바에 현재 사용률(%) 표시 |
| 주간 사용량 | 7일 누적 사용량 함께 표시 |
| 색상 표시 | 초록(<70%) / 노랑(70-90%) / 빨강(≥90%) |
| 리셋 시간 | 사용량 초기화까지 남은 시간 표시 |
| 자동 토큰 갱신 | OAuth 토큰 만료 시 자동 갱신 |
| 캐싱 | API 호출 최소화를 위한 30초 캐시 |

## 메뉴바 표시

```
72% (14:00)              ← 메뉴바 (5시간 블록 사용량, 리셋 시간)
---
📊 5-Hour Block
   Usage: 72%
   Reset: 2h 15m (14:00)
---
📅 Weekly Usage
   Usage: 45%
   Reset: 3d 12h (2/2)
---
🔄 Refresh
```

## 문제 해결

### "Authentication info not found"

```bash
# Claude Code CLI 로그인
claude login
```

### 플러그인이 메뉴바에 안 보임

```bash
# 플러그인 실행 권한 확인
ls -la ~/Library/Application\ Support/xbar/plugins/claude-usage.30s.sh

# 권한 없으면 추가
chmod +x ~/Library/Application\ Support/xbar/plugins/claude-usage.30s.sh

# xbar 재시작
# 메뉴바에서 xbar → Quit 후 다시 실행
```

### 수동 테스트

```bash
# 스크립트 직접 실행
bash ~/Library/Application\ Support/xbar/plugins/claude-usage.30s.sh
```

### 캐시 초기화

```bash
rm ~/.claude/.cache/usage-api.json
```

## 설정

### 새로고침 간격 변경

파일명의 숫자가 새로고침 간격을 결정합니다:

| 파일명 | 간격 |
|--------|------|
| `claude-usage.30s.sh` | 30초 (기본값) |
| `claude-usage.1m.sh` | 1분 |
| `claude-usage.5m.sh` | 5분 |

```bash
# 1분 간격으로 변경 예시
cd ~/Library/Application\ Support/xbar/plugins
mv claude-usage.30s.sh claude-usage.1m.sh
```

### 색상 임계값 변경

스크립트의 `get_color()` 함수에서 70, 90 값을 수정합니다.

## 수동 설치

install.sh 없이 직접 설치하려면:

```bash
# 의존성 설치
brew install --cask xbar
brew install jq bc

# 플러그인 복사
cp claude-usage.30s.sh ~/Library/Application\ Support/xbar/plugins/
chmod +x ~/Library/Application\ Support/xbar/plugins/claude-usage.30s.sh
```

## 파일 구조

```
cc-usage-widget/
├── claude-usage.30s.sh   # xbar 플러그인 (메인 스크립트)
├── install.sh            # 자동 설치 스크립트
├── README.md
└── LICENSE
```

## 보안

- OAuth 토큰은 macOS Keychain에 암호화 저장
- 캐시에는 사용량 퍼센트와 리셋 시간만 저장 (토큰 미포함)
- 모든 API 통신은 HTTPS

## License

MIT License - [LICENSE](LICENSE) 참조
