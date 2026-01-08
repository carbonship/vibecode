#!/bin/bash

################################################################################
# 모니터링 시스템 테스트 스크립트
#
# 다양한 시나리오로 모니터링 시스템을 테스트합니다
################################################################################

set -euo pipefail

# 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 색상
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 테스트 로그 디렉토리
TEST_LOG_DIR="${PROJECT_ROOT}/test/logs"
TEST_DATA_DIR="${PROJECT_ROOT}/test/data"

mkdir -p "$TEST_DATA_DIR"

################################################################################
# 테스트 준비
################################################################################

setup_test() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}테스트 환경 설정${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo ""

    # 목업 로그 생성
    if [[ ! -f "${TEST_LOG_DIR}/normal.log" ]]; then
        echo "목업 로그 생성 중..."
        "${SCRIPT_DIR}/generate-mock-logs.sh"
    else
        echo "✅ 목업 로그 파일이 이미 존재합니다."
    fi

    echo ""
}

cleanup_test_data() {
    # 테스트용 데이터 파일 초기화
    rm -f "${PROJECT_ROOT}/data/error_history.dat"
    rm -f "${PROJECT_ROOT}/data/last_alert.dat"
    rm -f "${PROJECT_ROOT}/data/ewma.state"
}

################################################################################
# 테스트 실행
################################################################################

run_test() {
    local test_name=$1
    local log_file=$2
    local expected_severity=$3

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}테스트: $test_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # 설정 파일 임시 수정 (테스트용 로그 파일 지정)
    local original_config="${PROJECT_ROOT}/config/monitor.conf"
    local test_config="${PROJECT_ROOT}/config/monitor.conf.test"

    cp "$original_config" "$test_config"

    # LOG_FILE 경로 변경
    sed -i.bak "s|LOG_FILE=.*|LOG_FILE=\"$log_file\"|" "$test_config"

    # 테스트 실행
    local output
    local exit_code

    CONFIG_FILE="$test_config" \
    DATA_DIR="$TEST_DATA_DIR" \
    "$PROJECT_ROOT/bin/monitor-errors.sh" > /tmp/test_output.log 2>&1 || exit_code=$?

    output=$(cat /tmp/test_output.log)

    # 결과 검증
    echo "$output"
    echo ""

    if echo "$output" | grep -q "$expected_severity"; then
        echo -e "${GREEN}✅ 테스트 통과: 예상된 심각도 '$expected_severity' 감지됨${NC}"
    else
        echo -e "${RED}❌ 테스트 실패: 예상 '$expected_severity', 실제 결과를 확인하세요${NC}"
    fi

    echo ""

    # 정리
    rm -f "$test_config" "${test_config}.bak"
    cleanup_test_data
}

################################################################################
# 개별 테스트 케이스
################################################################################

test_normal_scenario() {
    run_test \
        "시나리오 1: 정상 상태" \
        "${TEST_LOG_DIR}/normal.log" \
        "NORMAL"
}

test_warning_scenario() {
    run_test \
        "시나리오 2: 경고 상태 (2배 증가)" \
        "${TEST_LOG_DIR}/warning.log" \
        "WARNING"
}

test_critical_scenario() {
    run_test \
        "시나리오 3: 위험 상태 (5배 증가)" \
        "${TEST_LOG_DIR}/critical.log" \
        "CRITICAL"
}

test_gradual_scenario() {
    run_test \
        "시나리오 4: 점진적 증가" \
        "${TEST_LOG_DIR}/gradual.log" \
        "WARNING\|CRITICAL"
}

test_spike_scenario() {
    run_test \
        "시나리오 5: 급격한 스파이크" \
        "${TEST_LOG_DIR}/spike.log" \
        "CRITICAL"
}

test_specific_error_scenario() {
    run_test \
        "시나리오 6: 특정 오류 타입 급증" \
        "${TEST_LOG_DIR}/specific_error.log" \
        "WARNING\|CRITICAL"
}

################################################################################
# 통합 테스트
################################################################################

run_all_tests() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                       ║${NC}"
    echo -e "${GREEN}║        오류 모니터링 시스템 통합 테스트               ║${NC}"
    echo -e "${GREEN}║                                                       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    setup_test

    test_normal_scenario
    sleep 1

    test_warning_scenario
    sleep 1

    test_critical_scenario
    sleep 1

    test_gradual_scenario
    sleep 1

    test_spike_scenario
    sleep 1

    test_specific_error_scenario

    echo ""
    echo -e "${GREEN}=================================${NC}"
    echo -e "${GREEN}✅ 모든 테스트 완료!${NC}"
    echo -e "${GREEN}=================================${NC}"
    echo ""
}

################################################################################
# 대화형 테스트
################################################################################

interactive_test() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  대화형 테스트 모드"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "테스트할 시나리오를 선택하세요:"
    echo ""
    echo "  1) 정상 상태"
    echo "  2) 경고 상태 (2배 증가)"
    echo "  3) 위험 상태 (5배 증가)"
    echo "  4) 점진적 증가"
    echo "  5) 급격한 스파이크"
    echo "  6) 특정 오류 타입 급증"
    echo "  7) 모든 테스트 실행"
    echo "  0) 종료"
    echo ""
    read -rp "선택 (0-7): " choice

    case $choice in
        1) test_normal_scenario ;;
        2) test_warning_scenario ;;
        3) test_critical_scenario ;;
        4) test_gradual_scenario ;;
        5) test_spike_scenario ;;
        6) test_specific_error_scenario ;;
        7) run_all_tests ;;
        0) echo "종료합니다."; exit 0 ;;
        *) echo "잘못된 선택입니다."; interactive_test ;;
    esac

    echo ""
    read -rp "계속하시겠습니까? (y/n): " continue
    if [[ "$continue" =~ ^[Yy]$ ]]; then
        interactive_test
    fi
}

################################################################################
# 메인
################################################################################

main() {
    if [[ $# -eq 0 ]]; then
        # 인자가 없으면 대화형 모드
        interactive_test
    else
        case $1 in
            all)
                run_all_tests
                ;;
            normal)
                setup_test
                test_normal_scenario
                ;;
            warning)
                setup_test
                test_warning_scenario
                ;;
            critical)
                setup_test
                test_critical_scenario
                ;;
            gradual)
                setup_test
                test_gradual_scenario
                ;;
            spike)
                setup_test
                test_spike_scenario
                ;;
            specific)
                setup_test
                test_specific_error_scenario
                ;;
            *)
                echo "사용법: $0 [all|normal|warning|critical|gradual|spike|specific]"
                echo ""
                echo "인자 없이 실행하면 대화형 모드로 실행됩니다."
                exit 1
                ;;
        esac
    fi
}

main "$@"
