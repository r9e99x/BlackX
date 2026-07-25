//
//  OnboardingView.swift
//  Blocode
//
//  Created by 조준희 on 5/10/26.
//

import SwiftUI

// MARK: - OnboardingPage 모델
/// 온보딩 슬라이드 한 장의 데이터
private struct OnboardingPage {
    let illustration: AnyView  // 슬라이드별 일러스트 뷰
    let title: String          // 큰 제목 (Georgia Italic)
    let description: String    // 설명 텍스트
}

// MARK: - OnboardingView
/// 앱 첫 실행 시 표시되는 온보딩 화면
/// UserDefaults의 "hasSeenOnboarding" 키로 표시 여부를 관리
struct OnboardingView: View {

    /// 온보딩 완료 콜백 — BlocodeApp에서 ContentView로 전환하는 데 사용
    var onFinish: () -> Void

    /// 현재 표시 중인 슬라이드 인덱스
    @State private var currentPage = 0

    // MARK: - 슬라이드 데이터
    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                illustration: AnyView(welcomeIllustration),
                title: "Blocode에\n오신 걸 환영해요.",
                description: "블럭으로 코드를 짜고\n캐릭터를 움직여보세요."
            ),
            OnboardingPage(
                illustration: AnyView(blockIllustration),
                title: "블럭을 탭해\n코드를 만드세요",
                description: "팔레트에서 블럭을 탭하면 추가되고,\n드래그해서 순서를 바꿀 수 있어요."
            ),
            OnboardingPage(
                illustration: AnyView(runIllustration),
                title: "실행 버튼으로\n캐릭터를 움직여요",
                description: "블럭 순서대로 캐릭터가 움직여요.\n목표 지점에 도달하면 클리어!"
            ),
            OnboardingPage(
                illustration: AnyView(gimmickIllustration),
                title: "챕터 6부터는\n특별한 칸도 만나요",
                description: "보석을 모으고, 스위치로 문을 열고,\n포탈로 순간이동도 해보세요."
            ),
            OnboardingPage(
                illustration: AnyView(starIllustration),
                title: "별을 모아\n스테이지를 클리어해요",
                description: "적은 블럭으로 클리어할수록\n더 많은 별을 얻을 수 있어요."
            ),
        ]
    }

    // MARK: - 본문

    var body: some View {
        GeometryReader { rootGeo in
            // 세로 공간이 부족한 경우(아이폰 가로모드) — 하단 버튼 크기도 같이 줄여야
            // 슬라이드 콘텐츠 키운 만큼 다시 잘리지 않음. pageContent 내부와 동일한 기준
            let isCompactHeight = rootGeo.size.height < 500

            ZStack {
                // 앱 배경색
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: 상단 바 (페이지 카운터 + 건너뛰기)
                    topBar

                // MARK: 슬라이드 콘텐츠
                #if os(iOS)
                if isPadIdiom {
                    // 아이패드: 기존처럼 스와이프 가능한 슬라이드 형식 유지 — 다만 TabView(.page)가
                    // 컨테이너 크기를 명시적으로 안 주면 옆 페이지가 살짝 보이는 버그가 있어서
                    // GeometryReader로 각 페이지 크기를 화면에 정확히 맞춰 그 버그만 고침
                    GeometryReader { geo in
                        TabView(selection: $currentPage) {
                            ForEach(pages.indices, id: \.self) { i in
                                pageContent(pages[i])
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .tag(i)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                } else {
                    // 아이폰: 페이지 스타일 탭뷰로 스와이프 전환 (기존과 완전히 동일, 무변경)
                    TabView(selection: $currentPage) {
                        ForEach(pages.indices, id: \.self) { i in
                            pageContent(pages[i])
                                .tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
                #else
                // macOS: 페이지 스타일 TabView 미지원 — 현재 페이지만 표시하고 "다음" 버튼으로 전환
                pageContent(pages[currentPage])
                    .id(currentPage)                  // 페이지 전환 시 뷰 교체로 페이드 효과 적용
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
                    .frame(maxHeight: .infinity)
                #endif

                    // MARK: 하단 (점 인디케이터 + 버튼)
                    // 아이패드에서 상단바·콘텐츠는 화면 전체 폭을 쓰지만, 버튼까지 그만큼 길어지면
                    // 어색해서 여기만 따로 640pt로 제한(맥·아이폰은 이미 아래 전체 캡에 걸려 있어 무변화)
                    bottomBar(isCompactHeight: isCompactHeight)
                        .frame(maxWidth: 640)
                        .frame(maxWidth: .infinity)
                }
                // 맥은 온보딩 콘텐츠를 중앙 640pt로 제한(기존 그대로), 아이패드는 상단바·콘텐츠가
                // 화면 전체 폭을 쓰게 둠(건너뛰기 버튼이 화면 진짜 코너에 위치하도록, 버튼 폭은 위에서 별도 제한)
                .frame(maxWidth: isPadIdiom ? .infinity : 640)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 상단 바

    private var topBar: some View {
        HStack {
            Spacer()

            // 건너뛰기 버튼 — 오른쪽 정렬
            // buttonStyle(.plain) 필수 — 없으면 맥에서 네이티브 회색 버튼 모양으로 렌더링됨
            Button {
                finish()
            } label: {
                Text("건너뛰기")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(currentPage < pages.count - 1 ? 1 : 0)  // 마지막 슬라이드에서는 숨김
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - 슬라이드 콘텐츠

    private func pageContent(_ page: OnboardingPage) -> some View {
        GeometryReader { geo in
            // 세로 공간이 부족한 경우(아이폰 가로모드) — 일러스트/텍스트가 예전 세로모드 크기
            // 그대로 나오면 위아래로 잘림. 폭이 아니라 "높이"로 판단해야 아이패드 가로모드
            // (높이 충분)와 정확히 구분되고, 다른 화면 전부 무변화로 유지됨
            let isCompactHeight = geo.size.height < 500

            VStack(spacing: 0) {

                Spacer(minLength: 0)

                // 일러스트 영역 — 원본 크기(280×280)로 배치한 뒤, 세로 공간이 부족할 때만
                // scaleEffect로 통째로 축소(내부에 절대좌표 장식 요소가 있어 frame만 줄이면
                // 그 요소들이 밖으로 잘려나감 — 비율 그대로 축소해야 안전)
                page.illustration
                    .frame(width: 280, height: 280)
                    .scaleEffect(isCompactHeight ? 0.62 : 1.0)
                    .frame(height: isCompactHeight ? 174 : 280)

                Spacer(minLength: 0)

                // 텍스트 영역 — 하단 정렬
                VStack(alignment: .leading, spacing: isCompactHeight ? 5 : 10) {
                    // 큰 제목 — Georgia Italic + 기울임 변환
                    Text(page.title)
                        .font(.custom("Georgia-Italic", size: isCompactHeight ? 25 : 36))
                        .foregroundStyle(.primary)
                        .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.10, d: 1, tx: 0, ty: 0))
                        .fixedSize(horizontal: false, vertical: true)

                    // 설명 텍스트
                    Text(page.description)
                        .font(.system(size: isCompactHeight ? 13 : 15, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineSpacing(isCompactHeight ? 2 : 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.bottom, isCompactHeight ? 10 : 32)
            }
            // 콘텐츠 자체는 예전과 동일하게 640pt로 제한하고 가운데 정렬 — 아이패드에서 페이지
            // 슬롯 자체는 화면 전체 폭이어야 옆 페이지 피킹 버그가 안 생기지만(호출부에서 처리),
            // 그 안의 텍스트·일러스트까지 전체 폭으로 늘어나면 텍스트가 왼쪽에 치우쳐 보이고
            // 코드블럭 미리보기 카드도 과하게 넓어져서 이렇게 안쪽 콘텐츠만 따로 좁힘
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 하단 바

    private func bottomBar(isCompactHeight: Bool) -> some View {
        VStack(spacing: isCompactHeight ? 10 : 20) {

            // 점 인디케이터
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i == currentPage ? Color.primary : Color.primary.opacity(0.2))
                        .frame(width: i == currentPage ? 18 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.25), value: currentPage)
                }
            }

            // 다음 / 시작하기 버튼
            nextButton(isCompactHeight: isCompactHeight)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, isCompactHeight ? 16 : 40)
    }

    // MARK: - 다음 버튼 (3D 다크 스타일)

    @State private var isNextPressed = false

    private func nextButton(isCompactHeight: Bool) -> some View {
        // 아이폰 가로모드(세로 공간 부족)에서는 슬라이드 콘텐츠를 키운 만큼 버튼은 살짝 줄임
        let frontH:  CGFloat = isCompactHeight ? 42 : 56
        let topD:    CGFloat = isCompactHeight ? 0.6 : 0.8
        let botD:    CGFloat = isCompactHeight ? 1.8 : 2.5
        let cr:      CGFloat = isCompactHeight ? 14 : 18
        let fontSize: CGFloat = isCompactHeight ? 14 : 17
        let isLast   = currentPage == pages.count - 1
        let label    = isLast ? "시작하기" : "다음  ›"

        // 어두운 다크 버튼 색상 — 라이트: darkInk/bevel*과 동일 값 / 다크: 슬레이트 톤으로 전환
        // (darkInk/bevelTopBack/bevelBottomBack은 라이트·다크 무관 고정값이라 다크모드 배경과
        // 충돌했음 — 다른 다크 버튼들과 동일하게 slateButton* 다이나믹 컬러로 교체)
        let frontColor   = Color.slateButtonFace
        let topBackColor = Color.slateButtonTopBack
        let botBackColor = Color.slateButtonBottomBack

        return Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                if isLast { finish() }
                else { currentPage += 1 }
            }
        } label: {
            ThreeDSurface(topDepth: topD, bottomDepth: botD, isPressed: isNextPressed) {
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
                    RoundedRectangle(cornerRadius: cr).fill(frontColor)
                    if isNextPressed {
                        RoundedRectangle(cornerRadius: cr).fill(Color.black.opacity(0.10))
                    }
                    Text(label)
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: frontH)
            }
            .frame(maxWidth: .infinity)
            .frame(height: frontH + topD + botD)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in withAnimation(.easeInOut(duration: 0.08)) { isNextPressed = true } }
            .onEnded   { _ in withAnimation(.easeInOut(duration: 0.08)) { isNextPressed = false } }
        )
    }

    // MARK: - 온보딩 완료 처리

    /// UserDefaults에 완료 기록 후 콜백 호출
    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        onFinish()
    }

    // MARK: - 슬라이드 일러스트

    // ① 환영 일러스트 — 앱 아이콘 + 장식 별
    private var welcomeIllustration: some View {
        ZStack {
            // 장식 원형 배경
            Circle()
                .fill(Color(red: 147/255, green: 201/255, blue: 163/255).opacity(0.18))
                .frame(width: 200, height: 200)

            VStack(spacing: 16) {
                // 미니 3D 블럭 아이콘 (홈 화면과 동일)
                miniBlockIcon(size: 72, topD: 1.5, botD: 2.5, cr: 18)

                Text("Blocode")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("block by block.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // 장식 별
            Text("✦")
                .font(.system(size: 14))
                .foregroundStyle(Color.bevelBottomBack)
                .offset(x: -90, y: -60)
            Text("✦")
                .font(.system(size: 9))
                .foregroundStyle(Color.bevelBottomBack)
                .offset(x: 85, y: -80)
            Text("✦")
                .font(.system(size: 11))
                .foregroundStyle(Color.bevelBottomBack)
                .offset(x: 100, y: 20)
        }
        .frame(maxWidth: .infinity)
    }

    // ② 블럭 일러스트 — 코드 블럭 목록 모형
    private var blockIllustration: some View {
        VStack(spacing: 0) {
            // 코드 카드 모형
            VStack(spacing: 0) {
                mockBlockRow(number: 1, label: "앞으로",
                             color: Color(red: 124/255, green: 196/255, blue: 158/255),
                             icon: "arrow.up")
                Divider().opacity(0.3)
                mockBlockRow(number: 2, label: "repeat  3",
                             color: Color(red: 168/255, green: 141/255, blue: 192/255),
                             icon: "repeat")
                Divider().opacity(0.3)
                mockBlockRow(number: 3, label: "앞으로",
                             color: Color(red: 124/255, green: 196/255, blue: 158/255),
                             icon: "arrow.up")
                Divider().opacity(0.3)
                mockBlockRow(number: 4, label: "오른쪽 회전",
                             color: Color(red: 142/255, green: 176/255, blue: 200/255),
                             icon: "arrow.turn.up.right")
            }
            .background(
                // UIColor.systemBackground와 동일 값 (라이트 흰색 / 다크 검정 — 크로스플랫폼)
                Color.dynamic(light: (1.0, 1.0, 1.0), dark: (0.0, 0.0, 0.0))
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 4)
            .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
    }

    /// 블럭 행 모형 — 실제 BlockRowView 없이 간단히 표현
    private func mockBlockRow(number: Int, label: String, color: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            // 번호
            Text("\(number)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)

            // 3D 블럭 (단순화)
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // ③ 실행 일러스트 — 실행 버튼 + 캐릭터 이동 표시
    private var runIllustration: some View {
        VStack(spacing: 24) {
            // 실행 버튼 모형 (3D 스타일)
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color(red: 124/255, green: 196/255, blue: 158/255).opacity(0.3))
                    .frame(width: 160, height: 56)
                    .offset(y: 4)

                RoundedRectangle(cornerRadius: 30)
                    .fill(Color(red: 124/255, green: 196/255, blue: 158/255))
                    .frame(width: 160, height: 56)

                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("실행")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
            }

            // 이동 방향 화살표 이미지
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            Color(red: 124/255, green: 196/255, blue: 158/255)
                                .opacity(1.0 - Double(i) * 0.2)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // ④ 기믹 일러스트 — 보석/스위치/포탈 아이콘 (게임 화면과 동일한 색상)
    private var gimmickIllustration: some View {
        HStack(spacing: 24) {
            gimmickIcon(label: "보석") {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color(red: 0.42, green: 0.82, blue: 0.68))  // GameScene.itemColor와 동일
            }
            gimmickIcon(label: "스위치") {
                Circle()
                    .fill(Color(red: 0.93, green: 0.62, blue: 0.28))  // GameScene.switchColor와 동일
                    .frame(width: 32, height: 32)
            }
            gimmickIcon(label: "포탈") {
                ZStack {
                    Circle()
                        .stroke(Color(red: 0.62, green: 0.45, blue: 0.85), lineWidth: 3)  // GameScene.portalColor와 동일
                        .frame(width: 38, height: 38)
                    Circle()
                        .fill(Color(red: 0.62, green: 0.45, blue: 0.85).opacity(0.5))
                        .frame(width: 18, height: 18)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 기믹 아이콘 하나 — 원형 카드 배경 + 아이콘 + 라벨 (holder 클로저로 아이콘 모양만 교체)
    private func gimmickIcon<Content: View>(label: String, @ViewBuilder icon: () -> Content) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.cardBackground)
                    .frame(width: 76, height: 76)
                    .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 3)
                icon()
            }
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // ⑤ 별 일러스트 — 별 3개 + 클리어 카드
    private var starIllustration: some View {
        VStack(spacing: 20) {
            // 별 3개
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "star.fill")
                        .font(.system(size: i == 1 ? 52 : 36))
                        .foregroundStyle(Color(red: 242/255, green: 183/255, blue: 64/255))
                        .offset(y: i == 1 ? -10 : 0)
                        .shadow(color: Color(red: 242/255, green: 183/255, blue: 64/255).opacity(0.35),
                                radius: 8, x: 0, y: 4)
                }
            }

            // 클리어 배지
            Text("CLEAR!")
                .font(.system(size: 13, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color(red: 124/255, green: 196/255, blue: 158/255))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(red: 124/255, green: 196/255, blue: 158/255).opacity(0.15))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 미니 블럭 아이콘 (환영 슬라이드용)

    /// 홈 화면과 동일한 3D 블럭 아이콘
    /// 캐릭터/앱 로고와 동일한 다이나믹 컬러 세트 사용(라이트: darkInk/bevel*/arrowCream과 동일 값,
    /// 다크: 밝은 몸체 — nextButton과 같은 이유로 고정 라이트색 대신 다크모드 대응 색상으로 교체)
    private func miniBlockIcon(size: CGFloat, topD: CGFloat, botD: CGFloat, cr: CGFloat) -> some View {
        let frontColor   = Color.characterBody
        let topBackColor = Color.characterTopBack
        let botBackColor = Color.characterBottomBack
        let arrowColor   = Color.characterArrow

        return ThreeDSurface(topDepth: topD, bottomDepth: botD) {
            RoundedRectangle(cornerRadius: cr).fill(topBackColor)
                .frame(width: size, height: size)
        } bottomBack: {
            RoundedRectangle(cornerRadius: cr).fill(botBackColor)
                .frame(width: size, height: size)
        } front: {
            ZStack {
                RoundedRectangle(cornerRadius: cr).fill(frontColor)
                Image(systemName: "arrow.up")
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(arrowColor)
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size + topD + botD)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onFinish: {})
}
