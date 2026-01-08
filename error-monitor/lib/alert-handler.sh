#!/bin/bash

################################################################################
# 알림 핸들러
#
# 다양한 채널로 알림 전송:
#   - 콘솔 출력
#   - Slack
#   - Email
#   - 로그 파일
################################################################################

set -euo pipefail

SEVERITY=$1
RESULT=$2

# 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 설정 로드
CONFIG_FILE="${PROJECT_ROOT}/config/monitor.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# 색상
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

################################################################################
# 결과 파싱
################################################################################

declare -A data
IFS='|' read -ra PARTS <<< "$RESULT"
for part in "${PARTS[@]}"; do
    IFS='=' read -r key value <<< "$part"
    data[$key]=$value
done

################################################################################
# 콘솔 알림
################################################################################

send_console_alert() {
    local emoji
    local color

    case "$SEVERITY" in
        CRITICAL)
            emoji="🚨"
            color="$RED"
            ;;
        WARNING)
            emoji="⚠️ "
            color="$YELLOW"
            ;;
        *)
            emoji="ℹ️ "
            color="$NC"
            ;;
    esac

    echo ""
    echo -e "${color}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${color}${emoji}  오류 급증 감지! [${SEVERITY}]${NC}"
    echo -e "${color}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "시간: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "현재 오류 수: ${data[current]}"
    echo "평균: ${data[mean]}"
    echo "변화율: ${data[change_rate]}%"
    echo "가중치 점수: ${data[weighted_score]}"
    echo ""

    if [[ "${data[type_alerts]}" != "none" ]]; then
        echo "오류 타입별 알림:"
        echo "${data[type_alerts]}" | tr ' ' '\n' | while read -r alert; do
            echo "  • $alert"
        done
        echo ""
    fi

    echo -e "${color}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

################################################################################
# Slack 알림
################################################################################

send_slack_alert() {
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        return
    fi

    local color_code
    case "$SEVERITY" in
        CRITICAL) color_code="danger" ;;
        WARNING)  color_code="warning" ;;
        *)        color_code="good" ;;
    esac

    local emoji
    case "$SEVERITY" in
        CRITICAL) emoji=":rotating_light:" ;;
        WARNING)  emoji=":warning:" ;;
        *)        emoji=":information_source:" ;;
    esac

    # Slack 메시지 구성
    local message=$(cat <<EOF
{
  "attachments": [
    {
      "color": "$color_code",
      "title": "${emoji} 오류 급증 감지 [${SEVERITY}]",
      "text": "시스템에서 비정상적인 오류 증가가 감지되었습니다.",
      "fields": [
        {
          "title": "현재 오류 수",
          "value": "${data[current]}",
          "short": true
        },
        {
          "title": "평균",
          "value": "${data[mean]}",
          "short": true
        },
        {
          "title": "변화율",
          "value": "${data[change_rate]}%",
          "short": true
        },
        {
          "title": "가중치 점수",
          "value": "${data[weighted_score]}",
          "short": true
        },
        {
          "title": "심각도 점수",
          "value": "${data[score]}/8",
          "short": true
        },
        {
          "title": "발생 시간",
          "value": "$(date '+%Y-%m-%d %H:%M:%S')",
          "short": true
        }
      ],
      "footer": "Error Monitor System",
      "ts": $(date +%s)
    }
  ]
}
EOF
)

    if [[ "$DRY_RUN" != "true" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "$message" \
            "$SLACK_WEBHOOK_URL" \
            --silent --show-error || echo "Slack 알림 전송 실패"
    else
        echo "[DRY RUN] Slack 메시지: $message"
    fi
}

################################################################################
# Email 알림
################################################################################

send_email_alert() {
    if [[ "$EMAIL_ENABLED" != "true" ]]; then
        return
    fi

    local subject="[${SEVERITY}] 오류 급증 감지 - $(date '+%Y-%m-%d %H:%M')"

    local body=$(cat <<EOF
오류 모니터링 시스템에서 비정상적인 오류 증가를 감지했습니다.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  알림 정보
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

심각도: ${SEVERITY}
발생 시간: $(date '+%Y-%m-%d %H:%M:%S')
종합 점수: ${data[score]}/8

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  통계 정보
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

현재 오류 수: ${data[current]}
평균: ${data[mean]}
통계 임계값: ${data[threshold]}
변화율: ${data[change_rate]}%
가중치 점수: ${data[weighted_score]}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  권장 조치
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. 로그 파일 확인: ${LOG_FILE}
2. 최근 배포나 설정 변경 확인
3. 서버 리소스 모니터링
4. 데이터베이스 연결 상태 확인

이 메시지는 자동으로 발송되었습니다.
Error Monitor System
EOF
)

    if [[ "$DRY_RUN" != "true" ]]; then
        # sendmail 또는 mail 명령 사용
        if command -v mail &> /dev/null; then
            echo "$body" | mail -s "$subject" "$EMAIL_TO"
        elif command -v sendmail &> /dev/null; then
            echo "Subject: $subject
From: $EMAIL_FROM
To: $EMAIL_TO

$body" | sendmail -t
        else
            echo "Email 전송 도구를 찾을 수 없습니다 (mail 또는 sendmail 필요)"
        fi
    else
        echo "[DRY RUN] Email 제목: $subject"
        echo "[DRY RUN] Email 본문:"
        echo "$body"
    fi
}

################################################################################
# 메인
################################################################################

main() {
    # 콘솔 알림 (항상 표시)
    send_console_alert

    # Slack 알림
    send_slack_alert

    # Email 알림
    send_email_alert
}

main
