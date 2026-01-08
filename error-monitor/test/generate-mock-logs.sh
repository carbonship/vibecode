#!/bin/bash

################################################################################
# 목업 로그 생성 스크립트
#
# 테스트를 위한 다양한 시나리오의 로그 파일을 생성합니다:
#   - 정상 상태 (NORMAL)
#   - 경고 상태 (WARNING)
#   - 위험 상태 (CRITICAL)
#   - 점진적 증가
#   - 급격한 스파이크
################################################################################

set -euo pipefail

# 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 테스트 로그 파일
TEST_LOG_DIR="${PROJECT_ROOT}/test/logs"
mkdir -p "$TEST_LOG_DIR"

# 오류 타입 배열
ERROR_TYPES=(
    "ERROR"
    "FATAL"
    "DatabaseException"
    "SQLException"
    "PaymentFailed"
    "PaymentException"
    "AuthError"
    "AuthenticationFailed"
    "NullPointerException"
    "IOException"
    "TimeoutException"
)

################################################################################
# 유틸리티 함수
################################################################################

# 랜덤 타임스탬프 생성 (최근 N분 내)
generate_timestamp() {
    local minutes_ago=$1
    date -d "${minutes_ago} minutes ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || \
    date -v-${minutes_ago}M '+%Y-%m-%d %H:%M:%S' 2>/dev/null
}

# 랜덤 오류 타입 선택
random_error_type() {
    local idx=$((RANDOM % ${#ERROR_TYPES[@]}))
    echo "${ERROR_TYPES[$idx]}"
}

# 로그 라인 생성
generate_log_line() {
    local timestamp=$1
    local error_type=$2
    local message=$3

    echo "[$timestamp] [$error_type] ${message} - RequestID: $(uuidgen 2>/dev/null || echo "REQ-$RANDOM-$RANDOM")"
}

################################################################################
# 시나리오 1: 정상 상태 (NORMAL)
################################################################################

generate_normal_scenario() {
    local output_file="${TEST_LOG_DIR}/normal.log"
    echo "정상 상태 로그 생성 중..."

    > "$output_file"  # 파일 초기화

    # 최근 1시간 로그 생성 (5분 간격, 각 간격당 40-60개 오류)
    for i in {60..5}; do
        local error_count=$((40 + RANDOM % 20))  # 40-60개

        for ((j=0; j<error_count; j++)); do
            local timestamp=$(generate_timestamp $i)
            local error_type=$(random_error_type)
            local message="Normal operation error in service module"

            generate_log_line "$timestamp" "$error_type" "$message" >> "$output_file"
        done
    done

    # 현재 시간 (최근 5분) - 정상 범위 (50개)
    for ((j=0; j<50; j++)); do
        local timestamp=$(generate_timestamp 2)
        local error_type=$(random_error_type)
        local message="Current normal error in service"

        generate_log_line "$timestamp" "$error_type" "$message" >> "$output_file"
    done

    echo "✅ 정상 상태 로그 생성 완료: $output_file"
    echo "   총 라인 수: $(wc -l < "$output_file")"
}

################################################################################
# 시나리오 2: 경고 상태 (WARNING) - 2배 증가
################################################################################

generate_warning_scenario() {
    local output_file="${TEST_LOG_DIR}/warning.log"
    echo "경고 상태 로그 생성 중..."

    > "$output_file"

    # 과거 로그 (정상 범위: 40-60개)
    for i in {60..10}; do
        local error_count=$((40 + RANDOM % 20))

        for ((j=0; j<error_count; j++)); do
            local timestamp=$(generate_timestamp $i)
            local error_type=$(random_error_type)
            local message="Background service error"

            generate_log_line "$timestamp" "$error_type" "$message" >> "$output_file"
        done
    done

    # 최근 5분 - 2배 증가 (120개)
    for ((j=0; j<120; j++)); do
        local timestamp=$(generate_timestamp 2)
        local error_type=$(random_error_type)
        local message="Increased error rate detected"

        generate_log_line "$timestamp" "$error_type" "$message" >> "$output_file"
    done

    echo "⚠️  경고 상태 로그 생성 완료: $output_file"
    echo "   총 라인 수: $(wc -l < "$output_file")"
}

################################################################################
# 시나리오 3: 위험 상태 (CRITICAL) - 5배 증가
################################################################################

generate_critical_scenario() {
    local output_file="${TEST_LOG_DIR}/critical.log"
    echo "위험 상태 로그 생성 중..."

    > "$output_file"

    # 과거 로그 (정상 범위: 40-60개)
    for i in {60..10}; do
        local error_count=$((40 + RANDOM % 20))

        for ((j=0; j<error_count; j++)); do
            local timestamp=$(generate_timestamp $i)
            local error_type=$(random_error_type)
            local message="Normal background error"

            generate_log_line "$timestamp" "$error_type" "$message" >> "$output_file"
        done
    done

    # 최근 5분 - 5배 급증 (250개)
    # 주요 오류 타입 집중
    for ((j=0; j<150; j++)); do
        local timestamp=$(generate_timestamp 2)
        local message="DATABASE CONNECTION FAILED - Pool exhausted"

        generate_log_line "$timestamp" "DatabaseException" "$message" >> "$output_file"
    done

    for ((j=0; j<50; j++)); do
        local timestamp=$(generate_timestamp 2)
        local message="PAYMENT PROCESSING FAILED - Gateway timeout"

        generate_log_line "$timestamp" "PaymentFailed" "$message" >> "$output_file"
    done

    for ((j=0; j<50; j++)); do
        local timestamp=$(generate_timestamp 2)
        local message="FATAL ERROR - Service unavailable"

        generate_log_line "$timestamp" "FATAL" "$message" >> "$output_file"
    done

    echo "🚨 위험 상태 로그 생성 완료: $output_file"
    echo "   총 라인 수: $(wc -l < "$output_file")"
}

################################################################################
# 시나리오 4: 점진적 증가 (TREND)
################################################################################

generate_gradual_increase_scenario() {
    local output_file="${TEST_LOG_DIR}/gradual.log"
    echo "점진적 증가 로그 생성 중..."

    > "$output_file"

    # 시간대별로 점진적 증가
    local base_count=40

    for i in {60..5}; do
        # 시간이 지날수록 증가 (40 -> 150)
        local progress=$((60 - i))
        local error_count=$((base_count + progress * 2))

        for ((j=0; j<error_count; j++)); do
            local timestamp=$(generate_timestamp $i)
            local error_type=$(random_error_type)
            local message="Gradually increasing error rate"

            generate_log_line "$timestamp" "$error_type" "$message" >> "$output_file"
        done
    done

    echo "📈 점진적 증가 로그 생성 완료: $output_file"
    echo "   총 라인 수: $(wc -l < "$output_file")"
}

################################################################################
# 시나리오 5: 급격한 스파이크 (SPIKE)
################################################################################

generate_spike_scenario() {
    local output_file="${TEST_LOG_DIR}/spike.log"
    echo "급격한 스파이크 로그 생성 중..."

    > "$output_file"

    # 평소에는 정상
    for i in {60..6}; do
        local error_count=$((45 + RANDOM % 10))

        for ((j=0; j<error_count; j++)); do
            local timestamp=$(generate_timestamp $i)
            local error_type=$(random_error_type)
            local message="Normal operation"

            generate_log_line "$timestamp" "$error_type" "$message" >> "$output_file"
        done
    done

    # 갑자기 급증 (500개)
    for ((j=0; j<500; j++)); do
        local timestamp=$(generate_timestamp 2)
        local error_type=$(random_error_type)
        local message="SUDDEN SPIKE - System overload"

        generate_log_line "$timestamp" "$error_type" "$message" >> "$output_file"
    done

    echo "💥 급격한 스파이크 로그 생성 완료: $output_file"
    echo "   총 라인 수: $(wc -l < "$output_file")"
}

################################################################################
# 시나리오 6: 특정 오류 타입 급증
################################################################################

generate_specific_error_scenario() {
    local output_file="${TEST_LOG_DIR}/specific_error.log"
    echo "특정 오류 타입 급증 로그 생성 중..."

    > "$output_file"

    # 과거 로그 (정상)
    for i in {60..10}; do
        local error_count=$((45 + RANDOM % 10))

        for ((j=0; j<error_count; j++)); do
            local timestamp=$(generate_timestamp $i)
            local error_type=$(random_error_type)
            local message="Mixed error types"

            generate_log_line "$timestamp" "$error_type" "$message" >> "$output_file"
        done
    done

    # 최근 5분 - PaymentFailed만 급증 (50개)
    for ((j=0; j<50; j++)); do
        local timestamp=$(generate_timestamp 2)
        local message="Payment gateway connection refused"

        generate_log_line "$timestamp" "PaymentFailed" "$message" >> "$output_file"
    done

    # 기타 오류는 정상 수준
    for ((j=0; j<30; j++)); do
        local timestamp=$(generate_timestamp 2)
        local error_type=$(random_error_type)
        local message="Other normal errors"

        generate_log_line "$timestamp" "$error_type" "$message" >> "$output_file"
    done

    echo "💳 특정 오류 급증 로그 생성 완료: $output_file"
    echo "   총 라인 수: $(wc -l < "$output_file")"
}

################################################################################
# 메인 함수
################################################################################

main() {
    echo "================================="
    echo "목업 로그 생성 시작"
    echo "================================="
    echo ""

    generate_normal_scenario
    generate_warning_scenario
    generate_critical_scenario
    generate_gradual_increase_scenario
    generate_spike_scenario
    generate_specific_error_scenario

    echo ""
    echo "================================="
    echo "✅ 모든 목업 로그 생성 완료!"
    echo "================================="
    echo ""
    echo "생성된 파일 목록:"
    ls -lh "$TEST_LOG_DIR"/*.log
    echo ""
    echo "테스트 방법:"
    echo "  ./test/run-tests.sh"
}

main "$@"
