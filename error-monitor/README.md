# 오류 로그 이상 감지 모니터링 시스템

금융 서비스를 위한 복합 알고리즘 기반 오류 로그 모니터링 시스템입니다.

## 🎯 주요 기능

- **복합 알고리즘 이상 감지**
  - 통계적 이상치 감지 (이동평균 + 표준편차)
  - 변화율 분석 (Rate of Change)
  - 연속 증가 추세 감지
  - 오류 타입별 가중치 적용

- **스마트 알림**
  - 다단계 심각도 (NORMAL/WARNING/CRITICAL)
  - 알림 쿨다운으로 중복 방지
  - Slack, Email 연동 지원

- **쉘 스크립트 기반**
  - 별도 시스템 구축 불필요
  - cron으로 자동화 가능
  - 경량화된 구조

## 📁 프로젝트 구조

```
error-monitor/
├── bin/
│   └── monitor-errors.sh      # 메인 모니터링 스크립트
├── config/
│   └── monitor.conf            # 설정 파일
├── lib/
│   └── alert-handler.sh        # 알림 핸들러
├── data/                       # 상태 데이터 (자동 생성)
│   ├── error_history.dat
│   ├── baseline.dat
│   └── last_alert.dat
├── logs/                       # 로그 파일 (자동 생성)
│   ├── monitor.log
│   └── alerts.log
├── test/
│   ├── generate-mock-logs.sh   # 목업 로그 생성
│   ├── run-tests.sh            # 테스트 스크립트
│   └── logs/                   # 테스트용 로그
└── README.md                   # 이 파일
```

## 🚀 빠른 시작

### 1. 설치

```bash
cd /path/to/your/project
git clone <repository> error-monitor
cd error-monitor
```

### 2. 실행 권한 부여

```bash
chmod +x bin/monitor-errors.sh
chmod +x lib/alert-handler.sh
chmod +x test/generate-mock-logs.sh
chmod +x test/run-tests.sh
```

### 3. 설정 파일 편집

```bash
vi config/monitor.conf
```

**필수 설정:**
```bash
# 모니터링할 로그 파일 경로
LOG_FILE="/var/log/app/error.log"

# 상세 로그 출력 여부
VERBOSE=true
```

### 4. 테스트 실행

```bash
# 목업 로그 생성
./test/generate-mock-logs.sh

# 테스트 실행 (대화형 모드)
./test/run-tests.sh

# 또는 모든 테스트 자동 실행
./test/run-tests.sh all
```

### 5. 수동 실행

```bash
./bin/monitor-errors.sh
```

### 6. 자동화 설정 (cron)

```bash
# crontab 편집
crontab -e

# 5분마다 실행
*/5 * * * * /path/to/error-monitor/bin/monitor-errors.sh

# 매 시간 정각에 실행
0 * * * * /path/to/error-monitor/bin/monitor-errors.sh
```

## 📊 알고리즘 상세

### 1. 통계적 이상치 감지

```
임계값 = 평균 + (K × 표준편차)

- 평균: 최근 N개 윈도우의 평균
- 표준편차: 데이터 분산 정도
- K: 민감도 (기본 2.5)
```

**점수:** 이상 감지시 +3점

### 2. 변화율 분석

```
변화율 = (현재 - 평균) / 평균 × 100%

- 임계값: 100% (2배 증가)
```

**점수:** 임계값 초과시 +2점

### 3. 연속 증가 추세

```
최근 5개 데이터 포인트 중 4개 이상 연속 증가
```

**점수:** 추세 감지시 +1점

### 4. 가중치 점수

```
가중치 점수 = Σ(오류타입별 개수 × 가중치)

- FATAL: 10점
- PaymentFailed: 9점
- DatabaseException: 8점
- AuthError: 7점
```

**점수:** 가중치 50 초과시 +2점

### 종합 판정

| 총점 | 심각도 | 조치 |
|------|--------|------|
| 0-2  | NORMAL | 정상 범위 |
| 3-4  | WARNING | 경고 알림 전송 |
| 5+   | CRITICAL | 즉시 알림 전송 |

## ⚙️ 설정 가이드

### 기본 설정

```bash
# config/monitor.conf

# 윈도우 크기 (비교할 과거 데이터 개수)
WINDOW_SIZE=12              # 12 × 5분 = 1시간

# 시그마 배수 (민감도)
SIGMA_MULTIPLIER=2.5        # 2.0=민감, 2.5=표준, 3.0=보수적

# 변화율 임계값 (%)
CHANGE_RATE_THRESHOLD=100   # 100% = 2배 증가

# 알림 쿨다운 (초)
ALERT_COOLDOWN=3600         # 1시간
```

### 알림 설정

#### Slack 연동

```bash
# Slack Webhook URL 설정
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

Slack Webhook URL 생성:
1. Slack Workspace 설정 > 앱 추가
2. "Incoming Webhooks" 검색 및 추가
3. 채널 선택 후 Webhook URL 복사

#### Email 연동

```bash
EMAIL_ENABLED=true
EMAIL_TO="admin@example.com"
EMAIL_FROM="monitor@example.com"
```

시스템에 `mail` 또는 `sendmail` 명령 필요:

```bash
# Ubuntu/Debian
sudo apt-get install mailutils

# CentOS/RHEL
sudo yum install mailx
```

### 오류 타입별 커스터마이징

```bash
# config/monitor.conf

# 가중치 설정 (중요도)
declare -A ERROR_WEIGHTS=(
    ["FATAL"]=10
    ["PaymentFailed"]=9
    ["DatabaseException"]=8
    # 추가 타입...
)

# 개별 임계값 (이 값 이상이면 즉시 알림)
declare -A ERROR_THRESHOLDS=(
    ["FATAL"]=5                # FATAL 5개 이상
    ["PaymentFailed"]=3        # 결제 실패 3개 이상
    ["DatabaseException"]=10   # DB 오류 10개 이상
)
```

## 📈 사용 예시

### 시나리오 1: 정상 상태 모니터링

```bash
$ ./bin/monitor-errors.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  오류 모니터링 리포트
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📅 시간: 2026-01-08 14:30:00
🎯 심각도: NORMAL
📊 종합 점수: 0/8

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  통계
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

현재 오류 수          : 50
평균                  : 48.5
통계 임계값           : 73.2
변화율                : 3.09%
가중치 점수           : 25
```

### 시나리오 2: 경고 상태 (2배 증가)

```bash
$ ./bin/monitor-errors.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  오류 급증 감지! [WARNING]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

시간: 2026-01-08 14:35:00
현재 오류 수: 120
평균: 50.2
변화율: 139.04%
가중치 점수: 60

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 시나리오 3: 위험 상태 (5배 급증)

```bash
$ ./bin/monitor-errors.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚨 오류 급증 감지! [CRITICAL]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

시간: 2026-01-08 14:40:00
현재 오류 수: 250
평균: 49.8
변화율: 402.01%
가중치 점수: 1250

오류 타입별 알림:
  • DatabaseException:150회
  • PaymentFailed:50회
  • FATAL:50회

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 🧪 테스트

### 대화형 테스트

```bash
$ ./test/run-tests.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  대화형 테스트 모드
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

테스트할 시나리오를 선택하세요:

  1) 정상 상태
  2) 경고 상태 (2배 증가)
  3) 위험 상태 (5배 증가)
  4) 점진적 증가
  5) 급격한 스파이크
  6) 특정 오류 타입 급증
  7) 모든 테스트 실행
  0) 종료

선택 (0-7):
```

### 개별 시나리오 테스트

```bash
# 정상 상태
./test/run-tests.sh normal

# 경고 상태
./test/run-tests.sh warning

# 위험 상태
./test/run-tests.sh critical

# 모든 테스트
./test/run-tests.sh all
```

### 목업 로그 재생성

```bash
./test/generate-mock-logs.sh
```

## 🔧 문제 해결

### 로그 파일을 찾을 수 없음

```
ERROR: 로그 파일을 찾을 수 없습니다: /var/log/app/error.log
```

**해결:** `config/monitor.conf`에서 `LOG_FILE` 경로 확인

### bc 명령을 찾을 수 없음

```
bash: bc: command not found
```

**해결:**
```bash
# Ubuntu/Debian
sudo apt-get install bc

# CentOS/RHEL
sudo yum install bc
```

### 권한 거부

```
Permission denied: ./bin/monitor-errors.sh
```

**해결:**
```bash
chmod +x bin/monitor-errors.sh
chmod +x lib/alert-handler.sh
```

### Slack 알림이 전송되지 않음

1. `SLACK_WEBHOOK_URL`이 올바르게 설정되었는지 확인
2. 네트워크 연결 확인
3. Webhook URL이 유효한지 확인

**테스트:**
```bash
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  YOUR_WEBHOOK_URL
```

## 📋 로그 파일

### 모니터링 로그

```bash
tail -f logs/monitor.log
```

```
[2026-01-08 14:30:00] [INFO] 모니터링 시작
[2026-01-08 14:30:00] [INFO] 최근 5분간 오류 수: 50
[2026-01-08 14:30:00] [INFO] 통계 분석 - 평균:48.5, 표준편차:5.2
[2026-01-08 14:30:00] [INFO] 변화율 분석 - 변화율:3.09%
[2026-01-08 14:30:00] [INFO] 추세 분석 - 연속증가:2/4
[2026-01-08 14:30:00] [INFO] 이상 감지 결과: severity=NORMAL|score=0
[2026-01-08 14:30:00] [INFO] 모니터링 완료 (상태코드: 0)
```

### 알림 로그

```bash
tail -f logs/alerts.log
```

```
[2026-01-08 14:35:00] WARNING | severity=WARNING|score=3|current=120|...
[2026-01-08 14:40:00] CRITICAL | severity=CRITICAL|score=7|current=250|...
```

## 🔒 보안 고려사항

### 금융권 특화

1. **로그 민감정보 마스킹**
   - 필요시 로그 파싱 전 개인정보 제거

2. **알림 로그 암호화**
   - 중요 알림은 암호화 저장 권장

3. **접근 권한 제한**
   ```bash
   chmod 700 error-monitor
   chmod 600 config/monitor.conf
   chmod 600 logs/*.log
   ```

4. **감사 추적**
   - 모든 알림은 `logs/alerts.log`에 기록
   - 로그 로테이션 설정 권장

## 📊 성능 최적화

### 리소스 사용량

- CPU: 최소 (스크립트 실행시만)
- 메모리: ~10MB
- 디스크: ~1MB (히스토리 데이터)

### 대용량 로그 파일 처리

로그 파일이 매우 큰 경우:

```bash
# config/monitor.conf

# 최근 N분만 읽기 (기본: 5분)
# grep으로 필터링하므로 효율적
```

또는 로그 로테이션 설정:

```bash
# /etc/logrotate.d/app-error
/var/log/app/error.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

## 🛠️ 고급 사용법

### 커스텀 로그 형식

로그 형식이 다른 경우, `bin/monitor-errors.sh`의 `count_errors_in_window` 함수 수정:

```bash
# 기본: ERROR|FATAL|Exception 패턴
grep -E "(ERROR|FATAL|Exception|exception)" "$log_file"

# JSON 로그 예시:
jq -r 'select(.level == "error")' "$log_file"

# Apache 로그 예시:
awk '$9 >= 500' "$log_file"  # 5xx 에러만
```

### 시간대별 베이스라인 활성화

```bash
# config/monitor.conf

USE_TIME_BASELINE=true

# 시간대별 정상 범위 정의
declare -A BASELINE_MEAN=(
    ["Mon_09"]=150
    ["Mon_14"]=120
    # ...
)
```

### 드라이런 모드

알림 전송 없이 테스트:

```bash
# config/monitor.conf
DRY_RUN=true
```

## 📞 지원 및 기여

### 문의

- 이슈: GitHub Issues
- 이메일: support@example.com

### 라이선스

MIT License

## 🔄 버전 히스토리

- **v1.0.0** (2026-01-08)
  - 초기 릴리스
  - 복합 알고리즘 구현
  - Slack/Email 알림 지원
  - 테스트 프레임워크 포함
