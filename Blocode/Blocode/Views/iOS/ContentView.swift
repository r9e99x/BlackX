//
//  ContentView.swift
//  Blocode
//
//  Created by 조준희 on 5/10/26.
//

import SwiftUI

// MARK: - ContentView (홈 화면)
/// 앱 실행 시 가장 먼저 보이는 홈 화면
/// NavigationStack의 루트 — 모든 화면 전환은 navPath로 제어
struct ContentView: View {

    /// 앱 전역 내비게이션 경로 — append로 이동, removeLast로 뒤로가기
    @State private var navPath = NavigationPath()

    /// 설정 시트 표시 여부 — true이면 SettingsView를 fullScreenCover로 표시
    @State private var showSettings = false

    /// 테마 변경 감지 — SettingsService 변경 시 뷰 자동 갱신
    @ObservedObject private var settings = SettingsService.shared

    /// 홈 화면 상태/로직 — 진행도 가공은 ViewModel이 담당 (MVVM)
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        // 아이패드는 맥과 동일한 사이드바 셸 배치를 쓰는 전용 화면으로 완전히 분기
        // (아이폰·맥은 이 분기를 안 타서 기존 NavigationStack 경로를 그대로 실행함)
        // IPadContentShell 타입 자체가 #if os(iOS) 전용이라 맥 컴파일에서 참조 자체가 없어야 하므로
        // 이 분기는 #if os(iOS)로 감싸고, 맥은 else 쪽만 컴파일되게 함
        #if os(iOS)
        if isPadIdiom {
            IPadContentShell()
        } else {
            defaultBody
        }
        #else
        defaultBody
        #endif
    }

    /// 아이폰(기존 그대로) · 맥이 함께 쓰는 기본 홈 화면 — NavigationStack 기반
    private var defaultBody: some View {
        // 루트 NavigationStack — path 바인딩으로 화면 전환 관리
        NavigationStack(path: $navPath) {
            // 화면 폭에 따라 홈 레이아웃 분기 (아이폰 세로: 세로 스택 / 아이폰 가로·맥: 좌우 분할)
            GeometryReader { geo in
                if geo.size.width >= LayoutBreakpoint.wide {
                    wideHomeContent
                } else {
                    homeContent
                }
            }
            // MARK: 라우트별 목적지 등록
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .chapterSelect:
                    ChapterSelectView(navPath: $navPath)

                case .chapter(let number):
                    ChapterView(navPath: $navPath, chapter: number)

                case .stage(let chapter, let number):
                    // 로딩은 StageView의 ViewModel이 담당 (View 계층 데이터 호출 제거)
                    StageView(chapter: chapter, number: number, navPath: $navPath)
                        .id("stage-\(chapter)-\(number)")
                }
            }
        }
        // 설정에 따라 라이트/다크/시스템 테마 적용
        .preferredColorScheme(settings.theme.colorScheme)
        // 설정 화면 — 모달 표시 (iOS: fullScreenCover / macOS: sheet)
        .fullScreenCoverCompat(isPresented: $showSettings) {
            SettingsView(onResetProgress: {
                // 진행 상황 초기화 후 홈으로 돌아오기 (navPath 초기화)
                navPath = NavigationPath()
            })
        }
    }

    // MARK: - 홈 화면 전체 레이아웃

    private var homeContent: some View {
        VStack(spacing: 0) {

            // MARK: 스크롤 콘텐츠 (헤더 / 인용구 / 통계)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // 헤더 (앱 아이콘 + 타이틀 / 설정 버튼)
                    headerSection

                    // 오늘의 한 줄 인용구 섹션
                    quoteSection
                        .padding(.top, 32)

                    // 통계 카드 3종 (별 / 챕터 / 연속)
                    statsRow
                        .padding(.top, 28)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }

            // MARK: 버튼 영역 — 화면 하단 고정
            buttonSection
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 36)
                .background(Color.appBackground)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .hideNavigationBar()  // iOS 전용 API 래퍼 (macOS no-op)
    }

    // MARK: - 헤더 섹션

    private var headerSection: some View {
        HStack(alignment: .center) {
            // 왼쪽: 미니 앱 아이콘 블럭 + "Blocode" 텍스트
            brandRow

            Spacer()

            // 오른쪽: 설정 버튼
            settingsButton
        }
    }

    /// 로고 + 앱 이름 행 — 컴팩트 헤더와 와이드 레이아웃 왼쪽 열에서 공용 사용
    private var brandRow: some View {
        HStack(spacing: 10) {
            // 미니 3D 블럭 아이콘 — 어두운 색상의 작은 3D 사각형
            miniBlockIcon
            // 앱 이름
            Text("Blocode")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    /// 설정 버튼 — 챕터 선택 화면 홈 버튼과 동일한 스타일
    /// (컴팩트: 헤더 오른쪽 / 와이드: 화면 우상단 오버레이로 공용 사용)
    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.secondary)  // UIColor.secondaryLabel과 동일 톤 (크로스플랫폼)
                .frame(width: 36, height: 36)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 와이드 레이아웃 홈 (아이패드·맥)

    /// 좌: 브랜딩+인용구 / 우: 통계 카드+시작 버튼 — 큰 화면에서 좌우 분할 배치
    private var wideHomeContent: some View {
        ZStack(alignment: .topTrailing) {

            // 중앙 분할 콘텐츠 (최대 1120pt로 제한해 초대형 화면에서도 밀도 유지)
            HStack(alignment: .center, spacing: 56) {

                // ── 왼쪽 열: 로고 + 인용구 ──
                VStack(alignment: .leading, spacing: 0) {
                    brandRow
                    quoteSection
                        .padding(.top, 40)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // ── 오른쪽 열: 통계 카드 + 시작/둘러보기 버튼 ──
                VStack(spacing: 14) {
                    statsRow
                    buttonSection
                        .padding(.top, 8)
                }
                .frame(width: 400)
            }
            .padding(.horizontal, 64)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity, maxHeight: .infinity)  // 화면 중앙 정렬

            // 우상단 설정 버튼 (컴팩트 헤더의 버튼과 동일)
            settingsButton
                .padding(.trailing, 24)
                .padding(.top, 20)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .hideNavigationBar()  // iOS 전용 API 래퍼 (macOS no-op)
    }

    // MARK: - 미니 3D 블럭 아이콘 (헤더 왼쪽)

    private var miniBlockIcon: some View {
        // 3D 효과: 위 뒷면 → 아래 뒷면 → 앞면+내용 (앞면이 마지막 = 최상단)
        let iconSize: CGFloat = 36
        let topD:     CGFloat = 1.0
        let botD:     CGFloat = 2.0
        let cr:       CGFloat = 10

        // 미니 아이콘 색상 — 게임 캐릭터와 동일한 다이나믹 컬러 세트
        // (라이트: 기존 darkInk/베벨/크림 그대로, 다크: 밝은 몸체 + 쿨 그레이 베벨 + 다크 화살표)
        let frontColor   = Color.characterBody        // 라이트 #2a2520 / 다크 회백색 앞면
        let topBackColor = Color.characterTopBack     // 라이트 #807869 / 다크 쿨 그레이 위 뒷면
        let botBackColor = Color.characterBottomBack  // 라이트 #beb59f / 다크 쿨 그레이 아래 뒷면
        let arrowColor   = Color.characterArrow       // 라이트 #f4ecd7 / 다크 다크잉크 화살표

        return ThreeDSurface(topDepth: topD, bottomDepth: botD) {
            // ① 위 뒷면
            RoundedRectangle(cornerRadius: cr)
                .fill(topBackColor)
                .frame(width: iconSize, height: iconSize)
        } bottomBack: {
            // ② 아래 뒷면
            RoundedRectangle(cornerRadius: cr)
                .fill(botBackColor)
                .frame(width: iconSize, height: iconSize)
        } front: {
            // ③ 앞면 + 화살표 — #2a2520 앞면, #f4ecd7 화살표
            ZStack {
                RoundedRectangle(cornerRadius: cr)
                    .fill(frontColor)
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(arrowColor)
            }
            .frame(width: iconSize, height: iconSize)
        }
        .frame(width: iconSize, height: iconSize + topD + botD)
    }

    // MARK: - 인용구 섹션

    private var quoteSection: some View {
        VStack(alignment: .leading, spacing: 6) {

            // 소제목 레이블
            Text("오늘의 한 줄")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            // 메인 인용구 — Georgia Italic 폰트로 감성적 표현
            // (한국어는 시스템 폰트 폴백 + 기울임 변환으로 이탤릭 효과 구현)
            VStack(alignment: .leading, spacing: 0) {
                Text("적은 블럭이")
                    .font(.custom("Georgia-Italic", size: 38))
                    .foregroundStyle(.primary)
                    .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.12, d: 1, tx: 0, ty: 0))
                Text("좋은 코드.")
                    .font(.custom("Georgia-Italic", size: 38))
                    .foregroundStyle(.primary)
                    .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.12, d: 1, tx: 0, ty: 0))
            }

            // 진행도에 따른 동적 서브타이틀
            Text(vm.dynamicSubtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // MARK: - 통계 카드 행

    private var statsRow: some View {
        HStack(spacing: 10) {
            // 획득 별 수 카드
            statCard(
                icon: "star.fill",
                iconColor: Color(red: 1.0, green: 0.82, blue: 0.25),
                value: "\(vm.earnedStars)/\(vm.totalPossibleStars)",
                label: "획득 별"
            )
            // 완료 챕터 수 카드
            statCard(
                icon: "checkmark.seal.fill",
                iconColor: Color(red: 0.576, green: 0.788, blue: 0.671),
                value: "\(vm.completedChapters)/\(vm.chapterCount)",
                label: "챕터 완료"
            )
            // 연속 학습 일수 카드
            statCard(
                icon: "flame.fill",
                iconColor: Color(red: 1.0, green: 0.55, blue: 0.30),
                value: "\(vm.streak)일째",
                label: "연속"
            )
        }
    }

    /// 개별 통계 카드 뷰 — 아이콘 + 값 + 레이블
    private func statCard(
        icon: String,
        iconColor: Color,
        value: String,
        label: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 아이콘
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)

            // 숫자 값
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            // 레이블
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        // 카드 배경 — 팔레트와 동일한 크림색
        .background(Color.statCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - 버튼 섹션

    private var buttonSection: some View {
        VStack(spacing: 12) {

            // "이어서 하기" 3D 다크 버튼
            continueButton

            // "챕터 둘러보기" 크림 버튼
            browseButton
        }
    }

    // MARK: - 이어서 하기 버튼 (3D 어두운 스타일)

    @State private var isContinuePressed = false

    private var continueButton: some View {
        let frontH:   CGFloat = 58
        let topD:     CGFloat = 0.8
        let botD:     CGFloat = 2.5
        let cr:       CGFloat = 18
        // 다크 버튼 색상 — 라이트: 기존 값 그대로 / 다크: 슬레이트 톤으로 전환
        // (다크 배경에서 따뜻한 브라운+탄색 베벨이 충돌하던 문제 수정, Color.dynamic 크로스플랫폼 헬퍼 사용)
        let frontColor = Color.dynamic(light: (0.165, 0.145, 0.125),      // 라이트: 기존 값 유지
                                       dark: (72/255, 78/255, 96/255))    // 다크: 슬레이트 앞면
        // 위 뒷면 색상 — 라이트 #807869 / 다크 밝은 슬레이트
        let topBackColor  = Color.slateButtonTopBack
        // 아래 뒷면 색상 — 라이트 #beb59f / 다크 앞면보다 약간 어두운 슬레이트 (그림자 효과)
        let botBackColor  = Color.slateButtonBottomBack
        // 눌림 시 앞면 색상 — 라이트: 기존 #565048 / 다크: 슬레이트를 살짝 밝게
        let pressedFrontColor = Color.dynamic(light: (86/255, 80/255, 72/255),      // 라이트: 기존 값 유지
                                              dark: (88/255, 95/255, 116/255))      // 다크: 눌림 슬레이트

        // 다음 스테이지 정보 (없으면 모든 완료 상태)
        let next = vm.nextStage
        // 진행 기록이 없으면 "시작하기" 모드
        let isFirstTime = vm.isFirstTime

        return Button {
            if let next = next {
                // 다음 스테이지로 바로 이동
                navPath.append(AppRoute.stage(chapter: next.chapter, number: next.stage))
            } else {
                // 모두 완료 → 챕터 목록으로
                navPath.append(AppRoute.chapterSelect)
            }
        } label: {
            ThreeDSurface(topDepth: topD, bottomDepth: botD, isPressed: isContinuePressed) {
                // ① 위 뒷면
                RoundedRectangle(cornerRadius: cr)
                    .fill(topBackColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: frontH)
            } bottomBack: {
                // ② 아래 뒷면
                RoundedRectangle(cornerRadius: cr)
                    .fill(botBackColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: frontH)
            } front: {
                // ③ 앞면 + 내용
                ZStack {
                    // 눌리면 앞면 색상 변경 (라이트 #565048 / 다크 밝은 슬레이트)
                    RoundedRectangle(cornerRadius: cr)
                        .fill(isContinuePressed ? pressedFrontColor : frontColor)
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: isFirstTime ? "sparkles" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(isContinuePressed
                                                 ? Color(red: 213/255, green: 211/255, blue: 209/255)
                                                 : .white.opacity(0.9))
                            // 진행 기록 없으면 "시작하기", 있으면 "이어서 하기"
                            Text(isFirstTime ? "시작하기" : "이어서 하기")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(isContinuePressed
                                                 ? Color(red: 213/255, green: 211/255, blue: 209/255)
                                                 : .white)
                        }
                        Spacer()
                        // 오른쪽 보조 텍스트 — 첫 실행이면 숨김
                        if !isFirstTime {
                            if let next = next {
                                Text("\(next.chapter)-\(next.stage)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(isContinuePressed
                                                     ? Color(red: 213/255, green: 211/255, blue: 209/255).opacity(0.6)
                                                     : .white.opacity(0.55))
                            } else {
                                Text("완료 ✓")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(isContinuePressed
                                                     ? Color(red: 213/255, green: 211/255, blue: 209/255).opacity(0.6)
                                                     : .white.opacity(0.55))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .frame(height: frontH)
            }
            .frame(maxWidth: .infinity)
            .frame(height: frontH + topD + botD)
        }
        // 눌림 애니메이션
        .buttonStyle(HomeThreeDButtonStyle(isPressed: $isContinuePressed))
    }

    // MARK: - 챕터 둘러보기 버튼 (크림 스타일)

    @State private var isBrowsePressed = false

    private var browseButton: some View {
        let frontH:   CGFloat = 52
        let topD:     CGFloat = 0.8
        let botD:     CGFloat = 2.5
        let cr:       CGFloat = 18
        // 크림 버튼 색상 (Color.dynamic 크로스플랫폼 헬퍼 사용 — 값은 기존과 동일)
        let frontColor = Color.dynamic(light: (252/255, 249/255, 238/255),  // 라이트: #fcf9ee (앞면)
                                       dark: (0.22, 0.23, 0.27))
        // 위 뒷면 색상 — #fcf9ee (연한 크림, 앞면보다 살짝 밝음)
        let topBackColor = Color.dynamic(light: (252/255, 249/255, 238/255),  // 라이트: #fcf9ee
                                         dark: (0.18, 0.19, 0.22))
        // 아래 뒷면 색상 — #c4c0b5 (회베이지, 그림자 효과)
        let botBackColor = Color.dynamic(light: (196/255, 192/255, 181/255),  // 라이트: #c4c0b5
                                         dark: (0.13, 0.14, 0.17))

        return Button {
            navPath.append(AppRoute.chapterSelect)
        } label: {
            ThreeDSurface(topDepth: topD, bottomDepth: botD, isPressed: isBrowsePressed) {
                // ① 위 뒷면
                RoundedRectangle(cornerRadius: cr)
                    .fill(topBackColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: frontH)
            } bottomBack: {
                // ② 아래 뒷면
                RoundedRectangle(cornerRadius: cr)
                    .fill(botBackColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: frontH)
            } front: {
                // ③ 앞면 + 텍스트
                ZStack {
                    RoundedRectangle(cornerRadius: cr)
                        .fill(frontColor)
                    if isBrowsePressed {
                        RoundedRectangle(cornerRadius: cr).fill(Color.black.opacity(0.06))
                    }
                    Text("챕터 둘러보기")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: frontH)
            }
            .frame(maxWidth: .infinity)
            .frame(height: frontH + topD + botD)
        }
        .buttonStyle(HomeThreeDButtonStyle(isPressed: $isBrowsePressed))
    }
}

// MARK: - HomeThreeDButtonStyle
/// 홈 화면 버튼용 3D 눌림 효과 스타일 — 별도의 opacity 변화 없이 위치만 변경
private struct HomeThreeDButtonStyle: ButtonStyle {

    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // isPressed 상태를 바인딩에 동기화 (버튼 눌림 감지)
            .onChange(of: configuration.isPressed) { _, newVal in
                withAnimation(.easeInOut(duration: 0.08)) {
                    isPressed = newVal
                }
            }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
