#!/bin/bash

################################################################################
# 간단한 테스트 스크립트
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_LOG_DIR="${PROJECT_ROOT}/test/logs"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "================================="
echo "간단한 테스트 실행"
echo "================================="
echo ""

# 테스트 케이스
tests=(
    "normal:NORMAL:정상 상태"
    "warning:WARNING:경고 상태"
    "critical:CRITICAL:위험 상태"
)

for test in "${tests[@]}"; do
    IFS=':' read -r logname expected desc <<< "$test"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "테스트: $desc"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 임시 데이터 디렉토리
    TEST_DATA_DIR="/tmp/error-monitor-test-$$"
    mkdir -p "$TEST_DATA_DIR"

    # 환경 변수로 설정 전달
    LOG_FILE="${TEST_LOG_DIR}/${logname}.log" \
    DATA_DIR="$TEST_DATA_DIR" \
    VERBOSE=false \
    "$PROJECT_ROOT/bin/monitor-errors.sh" > /tmp/test-output-$$.log 2>&1

    result=$(cat /tmp/test-output-$$.log)

    if echo "$result" | grep -q "$expected"; then
        echo -e "${GREEN}✅ 통과${NC}"
    else
        echo -e "${RED}❌ 실패${NC}"
        echo "예상: $expected"
        echo "결과:"
        tail -20 /tmp/test-output-$$.log
    fi

    # 정리
    rm -rf "$TEST_DATA_DIR"
    rm -f /tmp/test-output-$$.log

    echo ""
done

echo "================================="
echo "테스트 완료"
echo "================================="
