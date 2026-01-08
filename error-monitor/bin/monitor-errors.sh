#!/bin/bash

################################################################################
# 오류 로그 이상 감지 모니터링 시스템 (복합 알고리즘)
#
# 기능:
#   - 통계적 이상치 감지 (이동평균 + 표준편차)
#   - 변화율 분석 (Rate of Change)
#   - 연속 증가 추세 감지
#   - 오류 타입별 가중치 적용
#   - 시간대별 베이스라인 비교
#   - 다단계 알림 (NORMAL/WARNING/CRITICAL)
#
# 작성자: Error Monitor System
# 버전: 1.0.0
################################################################################

set -euo pipefail

# 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 설정 파일 로드
CONFIG_FILE="${PROJECT_ROOT}/config/monitor.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
else
    echo "ERROR: 설정 파일을 찾을 수 없습니다: $CONFIG_FILE"
    exit 1
fi

# 디렉토리 변수
DATA_DIR="${PROJECT_ROOT}/data"
LOGS_DIR="${PROJECT_ROOT}/logs"
LIB_DIR="${PROJECT_ROOT}/lib"

# 상태 파일
HISTORY_FILE="${DATA_DIR}/error_history.dat"
BASELINE_FILE="${DATA_DIR}/baseline.dat"
EWMA_STATE_FILE="${DATA_DIR}/ewma.state"
LAST_ALERT_FILE="${DATA_DIR}/last_alert.dat"

# 로그 파일
MONITOR_LOG="${LOGS_DIR}/monitor.log"
ALERT_LOG="${LOGS_DIR}/alerts.log"

# 기본값 (config에서 오버라이드 가능)
LOG_FILE="${LOG_FILE:-/var/log/app/error.log}"
WINDOW_SIZE="${WINDOW_SIZE:-12}"
SIGMA_MULTIPLIER="${SIGMA_MULTIPLIER:-2.5}"
CHANGE_RATE_THRESHOLD="${CHANGE_RATE_THRESHOLD:-100}"
ALERT_COOLDOWN="${ALERT_COOLDOWN:-3600}"

# 색상 코드
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# 유틸리티 함수
################################################################################

log_message() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$MONITOR_LOG"

    if [[ "$VERBOSE" == "true" ]]; then
        case "$level" in
            ERROR)   echo -e "${RED}[${level}]${NC} ${message}" ;;
            WARNING) echo -e "${YELLOW}[${level}]${NC} ${message}" ;;
            INFO)    echo -e "${GREEN}[${level}]${NC} ${message}" ;;
            *)       echo "[${level}] ${message}" ;;
        esac
    fi
}

get_time_slot() {
    # 요일_시간 형식 (예: Mon_09)
    date '+%a_%H'
}

ensure_directories() {
    mkdir -p "$DATA_DIR" "$LOGS_DIR"
}

################################################################################
# 로그 분석 함수
################################################################################

count_errors_in_window() {
    local log_file=$1
    local minutes=${2:-5}

    if [[ ! -f "$log_file" ]]; then
        log_message ERROR "로그 파일을 찾을 수 없습니다: $log_file"
        echo "0"
        return 1
    fi

    # 최근 N분간의 로그 추출
    local time_threshold=$(date -d "${minutes} minutes ago" '+%Y-%m-%d %H:%M' 2>/dev/null || \
                          date -v-${minutes}M '+%Y-%m-%d %H:%M' 2>/dev/null)

    # ERROR, FATAL, Exception 패턴 카운트
    local count=$(grep -E "(ERROR|FATAL|Exception|exception)" "$log_file" 2>/dev/null | \
                  grep "$time_threshold" 2>/dev/null | wc -l | tr -d ' ')

    echo "${count:-0}"
}

count_errors_by_type() {
    local log_file=$1
    local minutes=${2:-5}

    declare -A error_counts
    local time_threshold=$(date -d "${minutes} minutes ago" '+%Y-%m-%d %H:%M' 2>/dev/null || \
                          date -v-${minutes}M '+%Y-%m-%d %H:%M' 2>/dev/null)

    # 오류 타입별 카운트
    while IFS= read -r line; do
        for error_type in "${!ERROR_WEIGHTS[@]}"; do
            if [[ "$line" =~ $error_type ]]; then
                ((error_counts[$error_type]++)) || error_counts[$error_type]=1
            fi
        done
    done < <(grep "$time_threshold" "$log_file" 2>/dev/null | grep -E "(ERROR|FATAL|Exception)")

    # 결과 출력 (타입:개수)
    for error_type in "${!error_counts[@]}"; do
        echo "${error_type}:${error_counts[$error_type]}"
    done
}

################################################################################
# 통계 계산 함수
################################################################################

calculate_mean() {
    local -n arr=$1
    local sum=0
    local count=${#arr[@]}

    if [[ $count -eq 0 ]]; then
        echo "0"
        return
    fi

    for val in "${arr[@]}"; do
        sum=$(echo "$sum + $val" | bc)
    done

    echo "scale=2; $sum / $count" | bc
}

calculate_stddev() {
    local -n arr=$1
    local mean=$2
    local variance=0
    local count=${#arr[@]}

    if [[ $count -eq 0 ]]; then
        echo "0"
        return
    fi

    for val in "${arr[@]}"; do
        local diff=$(echo "$val - $mean" | bc)
        variance=$(echo "$variance + ($diff * $diff)" | bc)
    done

    variance=$(echo "scale=2; $variance / $count" | bc)
    echo "scale=2; sqrt($variance)" | bc
}

################################################################################
# 알고리즘 1: 통계적 이상치 감지
################################################################################

detect_statistical_anomaly() {
    local current=$1
    local -n hist_data=$2

    if [[ ${#hist_data[@]} -lt 3 ]]; then
        log_message INFO "히스토리 데이터 부족 (최소 3개 필요)"
        echo "0|0|0|insufficient_data"
        return 0
    fi

    local mean=$(calculate_mean hist_data)
    local stddev=$(calculate_stddev hist_data "$mean")
    local threshold=$(echo "$mean + ($SIGMA_MULTIPLIER * $stddev)" | bc)

    local is_anomaly=$(echo "$current > $threshold" | bc -l)

    log_message INFO "통계 분석 - 평균:$mean, 표준편차:$stddev, 임계값:$threshold, 현재:$current"

    echo "$is_anomaly|$mean|$threshold|$stddev"
}

################################################################################
# 알고리즘 2: 변화율 감지
################################################################################

detect_rate_change() {
    local current=$1
    local mean=$2

    if [[ $(echo "$mean == 0" | bc -l) -eq 1 ]]; then
        # 평균이 0이면 현재값이 임계값 이상인지만 체크
        if [[ $current -ge $CHANGE_RATE_THRESHOLD ]]; then
            echo "1|999|sudden_spike"
        else
            echo "0|0|normal"
        fi
        return
    fi

    local change_rate=$(echo "scale=2; ($current - $mean) / $mean * 100" | bc)
    local is_anomaly=$(echo "$change_rate > $CHANGE_RATE_THRESHOLD" | bc -l)

    log_message INFO "변화율 분석 - 변화율:${change_rate}%, 임계값:${CHANGE_RATE_THRESHOLD}%"

    echo "$is_anomaly|$change_rate|rate_change"
}

################################################################################
# 알고리즘 3: 연속 증가 추세 감지
################################################################################

detect_trend() {
    local -n hist_data=$1
    local trend_window=5

    if [[ ${#hist_data[@]} -lt $trend_window ]]; then
        echo "0|0|insufficient_data"
        return 0
    fi

    local increase_count=0
    local start_idx=$((${#hist_data[@]} - trend_window))

    for ((i=start_idx; i<${#hist_data[@]}-1; i++)); do
        local curr=${hist_data[$i]}
        local next=${hist_data[$i+1]}

        if (( $(echo "$next > $curr" | bc -l) )); then
            ((increase_count++))
        fi
    done

    # 5개 중 4개 이상 증가면 추세로 판단
    local is_trend=0
    if [[ $increase_count -ge 4 ]]; then
        is_trend=1
    fi

    log_message INFO "추세 분석 - 연속증가:${increase_count}/$(($trend_window-1))"

    echo "$is_trend|$increase_count|trend"
}

################################################################################
# 알고리즘 4: 오류 타입별 가중치 분석
################################################################################

calculate_weighted_score() {
    local log_file=$1

    declare -A error_counts
    local weighted_score=0
    local alerts=()

    # 오류 타입별 카운트
    while IFS=: read -r error_type count; do
        error_counts[$error_type]=$count
    done < <(count_errors_by_type "$log_file" 5)

    # 가중치 적용
    for error_type in "${!error_counts[@]}"; do
        local count=${error_counts[$error_type]}
        local weight=${ERROR_WEIGHTS[$error_type]:-1}
        local threshold=${ERROR_THRESHOLDS[$error_type]:-999}

        weighted_score=$(echo "$weighted_score + ($count * $weight)" | bc)

        if (( count >= threshold )); then
            alerts+=("${error_type}:${count}회")
        fi
    done

    log_message INFO "가중치 점수: $weighted_score"

    # alerts 배열을 문자열로 변환
    local alerts_str="${alerts[*]}"
    echo "$weighted_score|${alerts_str:-none}"
}

################################################################################
# 복합 이상 감지 (종합 판단)
################################################################################

detect_anomaly() {
    local current=$1
    local log_file=$2

    # 히스토리 로드
    declare -a hist_array
    if [[ -f "$HISTORY_FILE" ]]; then
        mapfile -t hist_array < "$HISTORY_FILE"
    fi

    # 알고리즘 1: 통계적 이상치
    IFS='|' read -r stat_anomaly mean threshold stddev < <(detect_statistical_anomaly "$current" hist_array)

    # 알고리즘 2: 변화율
    IFS='|' read -r rate_anomaly change_rate _ < <(detect_rate_change "$current" "$mean")

    # 알고리즘 3: 추세
    IFS='|' read -r trend_anomaly trend_count _ < <(detect_trend hist_array)

    # 알고리즘 4: 가중치 점수
    IFS='|' read -r weighted_score type_alerts < <(calculate_weighted_score "$log_file")

    # 종합 점수 계산
    local total_score=0

    [[ $stat_anomaly -eq 1 ]] && total_score=$((total_score + 3))
    [[ $rate_anomaly -eq 1 ]] && total_score=$((total_score + 2))
    [[ $trend_anomaly -eq 1 ]] && total_score=$((total_score + 1))
    [[ $(echo "$weighted_score > 50" | bc -l) -eq 1 ]] && total_score=$((total_score + 2))

    # 심각도 판정
    local severity="NORMAL"
    local status_code=0

    if [[ $total_score -ge 5 ]]; then
        severity="CRITICAL"
        status_code=2
    elif [[ $total_score -ge 3 ]]; then
        severity="WARNING"
        status_code=1
    fi

    # 결과 구조화
    local result="severity=$severity"
    result+="|score=$total_score"
    result+="|current=$current"
    result+="|mean=$mean"
    result+="|threshold=$threshold"
    result+="|change_rate=$change_rate"
    result+="|weighted_score=$weighted_score"
    result+="|type_alerts=$type_alerts"

    log_message INFO "이상 감지 결과: $result"

    echo "$result"
    return $status_code
}

################################################################################
# 히스토리 관리
################################################################################

update_history() {
    local current=$1

    # 히스토리 파일에 추가
    echo "$current" >> "$HISTORY_FILE"

    # 최대 윈도우 크기 유지 (최근 N개만 보관)
    local max_history=$((WINDOW_SIZE * 2))
    if [[ -f "$HISTORY_FILE" ]]; then
        local line_count=$(wc -l < "$HISTORY_FILE")
        if [[ $line_count -gt $max_history ]]; then
            tail -n "$max_history" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp"
            mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
        fi
    fi
}

################################################################################
# 알림 관리
################################################################################

should_send_alert() {
    local severity=$1

    # CRITICAL은 항상 전송
    if [[ "$severity" == "CRITICAL" ]]; then
        return 0
    fi

    # 쿨다운 체크
    if [[ -f "$LAST_ALERT_FILE" ]]; then
        local last_alert_time=$(cat "$LAST_ALERT_FILE")
        local current_time=$(date +%s)
        local elapsed=$((current_time - last_alert_time))

        if [[ $elapsed -lt $ALERT_COOLDOWN ]]; then
            log_message INFO "알림 쿨다운 중 (${elapsed}초 경과 / ${ALERT_COOLDOWN}초 필요)"
            return 1
        fi
    fi

    return 0
}

send_alert() {
    local severity=$1
    local result=$2

    if ! should_send_alert "$severity"; then
        return
    fi

    # 알림 스크립트 호출
    local alert_script="${LIB_DIR}/alert-handler.sh"
    if [[ -x "$alert_script" ]]; then
        "$alert_script" "$severity" "$result"
    else
        log_message WARNING "알림 스크립트를 찾을 수 없습니다: $alert_script"
    fi

    # 알림 로그 기록
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $severity | $result" >> "$ALERT_LOG"

    # 마지막 알림 시간 저장
    date +%s > "$LAST_ALERT_FILE"
}

################################################################################
# 리포트 생성
################################################################################

generate_report() {
    local severity=$1
    local result=$2

    # 결과 파싱
    declare -A data
    IFS='|' read -ra PARTS <<< "$result"
    for part in "${PARTS[@]}"; do
        IFS='=' read -r key value <<< "$part"
        data[$key]=$value
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  오류 모니터링 리포트"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📅 시간: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "🎯 심각도: $severity"
    echo "📊 종합 점수: ${data[score]}/8"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  통계"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    printf "%-20s : %s\n" "현재 오류 수" "${data[current]}"
    printf "%-20s : %s\n" "평균" "${data[mean]}"
    printf "%-20s : %s\n" "통계 임계값" "${data[threshold]}"
    printf "%-20s : %s%%\n" "변화율" "${data[change_rate]}"
    printf "%-20s : %s\n" "가중치 점수" "${data[weighted_score]}"
    echo ""

    if [[ "${data[type_alerts]}" != "none" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  오류 타입별 알림"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "${data[type_alerts]}" | tr ' ' '\n' | while read -r alert; do
            echo "  • $alert"
        done
        echo ""
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

################################################################################
# 메인 함수
################################################################################

main() {
    ensure_directories

    log_message INFO "모니터링 시작"

    # 현재 오류 수 카운트
    local current_errors=$(count_errors_in_window "$LOG_FILE" 5)

    log_message INFO "최근 5분간 오류 수: $current_errors"

    # 이상 감지 수행
    local result
    result=$(detect_anomaly "$current_errors" "$LOG_FILE")
    local status=$?

    # 결과에서 심각도 추출
    local severity=$(echo "$result" | grep -oP 'severity=\K[^|]+')

    # 리포트 생성
    if [[ "$VERBOSE" == "true" ]] || [[ $status -gt 0 ]]; then
        generate_report "$severity" "$result"
    fi

    # 알림 전송
    if [[ $status -gt 0 ]]; then
        send_alert "$severity" "$result"
    fi

    # 히스토리 업데이트
    update_history "$current_errors"

    log_message INFO "모니터링 완료 (상태코드: $status)"

    return $status
}

# 스크립트 실행
main "$@"
