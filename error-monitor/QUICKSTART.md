# 빠른 시작 가이드

## 5분 안에 시작하기

### 1단계: 실행 권한 부여

```bash
cd error-monitor
chmod +x bin/*.sh lib/*.sh test/*.sh
```

### 2단계: 설정 파일 수정

```bash
# config/monitor.conf 파일에서 로그 경로만 변경
vi config/monitor.conf
```

다음 라인을 찾아서 실제 로그 경로로 변경:
```bash
LOG_FILE="/var/log/app/error.log"  # <- 여기를 수정
```

### 3단계: 테스트 실행

```bash
# 목업 데이터로 테스트
./test/run-tests.sh

# 대화형 메뉴에서 "7" 선택 (모든 테스트 실행)
```

### 4단계: 실제 로그로 테스트

```bash
./bin/monitor-errors.sh
```

### 5단계: 자동화 (cron 설정)

```bash
# crontab 편집
crontab -e

# 5분마다 실행 (아래 줄 추가)
*/5 * * * * /home/user/vibecode/error-monitor/bin/monitor-errors.sh
```

---

## 주요 설정 튜닝

### 민감도 조절

```bash
# config/monitor.conf

# 더 민감하게 (더 자주 알림)
SIGMA_MULTIPLIER=2.0
CHANGE_RATE_THRESHOLD=50

# 더 보수적으로 (중요한 것만 알림)
SIGMA_MULTIPLIER=3.0
CHANGE_RATE_THRESHOLD=200
```

### Slack 알림 설정

```bash
# config/monitor.conf

# Slack Webhook URL 입력
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

Webhook URL 생성 방법:
1. Slack 워크스페이스 > 앱 추가
2. "Incoming Webhooks" 검색
3. 채널 선택 후 URL 복사

---

## 문제 해결

### bc 명령어 없음

```bash
# Ubuntu/Debian
sudo apt-get install bc

# CentOS/RHEL
sudo yum install bc
```

### 로그 파일 권한 오류

```bash
# 현재 사용자를 로그 그룹에 추가
sudo usermod -a -G adm $USER

# 또는 sudo로 실행
sudo ./bin/monitor-errors.sh
```

---

## 테스트 시나리오

```bash
# 정상 상태
./test/run-tests.sh normal

# 경고 상태 (2배 증가)
./test/run-tests.sh warning

# 위험 상태 (5배 급증)
./test/run-tests.sh critical
```

---

## 로그 확인

```bash
# 모니터링 로그
tail -f logs/monitor.log

# 알림 히스토리
tail -f logs/alerts.log
```

---

## 다음 단계

- 실제 운영 환경에 배포하기
- 알림 채널 추가 설정
- 오류 타입별 가중치 커스터마이징
- 시간대별 베이스라인 설정

자세한 내용은 [README.md](README.md)를 참고하세요.
