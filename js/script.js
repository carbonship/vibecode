// 스크롤 함수
function scrollToSection(sectionId) {
    const section = document.getElementById(sectionId);
    if (section) {
        section.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
}

// 계산기 열기 (상품 카드에서)
function openCalculator(insuranceType) {
    // 계산기 섹션으로 스크롤
    scrollToSection('calculator');

    // 보험 종류 자동 선택
    setTimeout(() => {
        const selectElement = document.getElementById('insurance-type');
        if (selectElement) {
            selectElement.value = insuranceType;
        }
    }, 500);
}

// 보험료 계산 함수
function calculateInsurance() {
    // 입력값 가져오기
    const insuranceType = document.getElementById('insurance-type').value;
    const gender = document.getElementById('gender').value;
    const age = parseInt(document.getElementById('age').value);
    const coverage = parseInt(document.getElementById('coverage').value);
    const period = document.getElementById('period').value;
    const smoker = document.getElementById('smoker').checked;

    // 입력값 검증
    if (!insuranceType) {
        alert('보험종류를 선택해주세요.');
        return;
    }
    if (!gender) {
        alert('성별을 선택해주세요.');
        return;
    }
    if (!age || age < 0 || age > 100) {
        alert('나이를 올바르게 입력해주세요. (0-100)');
        return;
    }
    if (!coverage) {
        alert('보장금액을 선택해주세요.');
        return;
    }
    if (!period) {
        alert('보장기간을 선택해주세요.');
        return;
    }

    // 기본 보험료 계산
    let basePrice = calculateBasePrice(insuranceType, age, gender);

    // 보장금액에 따른 조정
    let coverageMultiplier = coverage / 5000;

    // 보장기간에 따른 조정
    let periodMultiplier = 1.0;
    if (period === '10') periodMultiplier = 0.8;
    else if (period === '20') periodMultiplier = 1.0;
    else if (period === '30') periodMultiplier = 1.2;
    else if (period === '100') periodMultiplier = 1.5;

    // 흡연 여부에 따른 조정
    let smokerMultiplier = smoker ? 1.3 : 1.0;

    // 최종 보험료 계산
    let finalPrice = Math.round(basePrice * coverageMultiplier * periodMultiplier * smokerMultiplier / 100) * 100;

    // 결과 표시
    displayResult(insuranceType, finalPrice, gender, age, coverage, period, smoker);
}

// 보험 종류와 나이, 성별에 따른 기본 보험료 계산
function calculateBasePrice(insuranceType, age, gender) {
    let basePrice = 20000;

    // 보험 종류별 기본료
    const insurancePrices = {
        '실손의료보험': 25000,
        '암보험': 35000,
        '운전자보험': 18000,
        '치아보험': 22000,
        '종신보험': 45000,
        '연금보험': 100000
    };

    basePrice = insurancePrices[insuranceType] || 20000;

    // 나이에 따른 조정
    if (age < 30) {
        basePrice *= 0.8;
    } else if (age < 40) {
        basePrice *= 1.0;
    } else if (age < 50) {
        basePrice *= 1.3;
    } else if (age < 60) {
        basePrice *= 1.6;
    } else {
        basePrice *= 2.0;
    }

    // 성별에 따른 조정 (여성이 평균적으로 약간 저렴)
    if (gender === 'female') {
        basePrice *= 0.95;
    }

    return basePrice;
}

// 결과 표시 함수
function displayResult(insuranceType, price, gender, age, coverage, period, smoker) {
    const resultContainer = document.getElementById('calculator-result');

    const genderText = gender === 'male' ? '남성' : '여성';
    const smokerText = smoker ? '흡연자' : '비흡연자';
    const periodText = period === '100' ? '100세까지' : `${period}년`;

    resultContainer.innerHTML = `
        <div class="result-content">
            <div class="result-header">
                <div class="result-icon">
                    <svg width="60" height="60" viewBox="0 0 60 60" fill="none">
                        <circle cx="30" cy="30" r="28" fill="#E8F5E9"/>
                        <path d="M25 30l5 5 10-10" stroke="#43A047" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                </div>
                <h3 class="result-title">예상 보험료 계산 완료</h3>
                <p class="result-subtitle">${insuranceType}</p>
            </div>

            <div class="result-price">
                <div class="result-price-label">월 납입 보험료</div>
                <div class="result-price-amount">${price.toLocaleString()}</div>
                <div class="result-price-unit">원</div>
            </div>

            <div class="result-details">
                <h4>계산 조건</h4>
                <div class="detail-row">
                    <span class="detail-label">보험종류</span>
                    <span class="detail-value">${insuranceType}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">성별 / 나이</span>
                    <span class="detail-value">${genderText} / 만 ${age}세</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">보장금액</span>
                    <span class="detail-value">${(coverage * 10000).toLocaleString()}원</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">보장기간</span>
                    <span class="detail-value">${periodText}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">흡연여부</span>
                    <span class="detail-value">${smokerText}</span>
                </div>
            </div>

            <div class="result-actions">
                <button class="btn-primary btn-large" onclick="applyInsurance()">가입 신청하기</button>
                <button class="btn-outline btn-large" onclick="resetCalculator()">다시 계산하기</button>
            </div>
        </div>
    `;
}

// 가입 신청 함수
function applyInsurance() {
    alert('가입 신청 페이지로 이동합니다.\n(실제 서비스에서는 가입 페이지로 연결됩니다)');
}

// 계산기 초기화 함수
function resetCalculator() {
    document.getElementById('insurance-type').value = '';
    document.getElementById('gender').value = '';
    document.getElementById('age').value = '';
    document.getElementById('coverage').value = '';
    document.getElementById('period').value = '';
    document.getElementById('smoker').checked = false;

    const resultContainer = document.getElementById('calculator-result');
    resultContainer.innerHTML = `
        <div class="result-empty">
            <svg width="80" height="80" viewBox="0 0 80 80" fill="none">
                <circle cx="40" cy="40" r="35" fill="#F5F5F5"/>
                <path d="M40 25v30M25 40h30" stroke="#BDBDBD" stroke-width="3" stroke-linecap="round"/>
            </svg>
            <p>정보를 입력하고<br>계산하기 버튼을 눌러주세요</p>
        </div>
    `;
}

// 페이지 로드 시 실행
document.addEventListener('DOMContentLoaded', function() {
    // 스크롤 애니메이션
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver(function(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
        });
    }, observerOptions);

    // 애니메이션 대상 요소 관찰
    const animatedElements = document.querySelectorAll('.product-card, .benefit-card');
    animatedElements.forEach(el => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(30px)';
        el.style.transition = 'opacity 0.6s ease-out, transform 0.6s ease-out';
        observer.observe(el);
    });

    // 네비게이션 링크 클릭 이벤트
    document.querySelectorAll('.nav-list a').forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const targetId = this.getAttribute('href').substring(1);
            scrollToSection(targetId);
        });
    });
});

// 숫자 입력 필드 검증
document.addEventListener('DOMContentLoaded', function() {
    const ageInput = document.getElementById('age');
    if (ageInput) {
        ageInput.addEventListener('input', function() {
            if (this.value < 0) this.value = 0;
            if (this.value > 100) this.value = 100;
        });
    }
});
