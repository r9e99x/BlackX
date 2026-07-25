//
//  ClearOverlayView.swift
//  Blocode
//
//  Created by 조준희 on 5/10/26.
//

import SwiftUI

// MARK: - ClearOverlayView
/// 스테이지 클리어 시 전체 화면으로 표시되는 결과 오버레이
/// 별 3개: 특별 레이아웃 (컨페티 + "beautiful solution.") / 별 1~2개: 일반 레이아웃
struct ClearOverlayView: View {

    let stars: Int               // 획득한 별 수 (1~3)
    let elapsedTime: TimeInterval // 클리어까지 걸린 시간 (초)
    let attemptCount: Int        // 도전 횟수
    let blockCount: Int          // 사용한 블럭 수
    let stageLabel: String       // 스테이지 레이블 (예: "1-5")
    let stageName: String        // 스테이지 이름 (예: "지그재그")
    let threeStarCut: Int        // 별 3개 기준 블럭 수
    let isLastStage: Bool        // 챕터 마지막 스테이지 여부 (다음 버튼 레이블 결정)
    var itemHint: String? = nil  // 보석을 다 못 모아서 별 3개를 놓쳤을 때 안내 문구 (nil이면 표시 안 함, 기존 호출부는 무수정으로 컴파일)
    let onClose: () -> Void      // 닫기 버튼 — 스테이지 선택으로
    let onRetry: () -> Void      // 다시 도전
    let onNext: () -> Void       // 다음 스테이지 or 챕터 목록 (별 3개용)
    let onFinish: () -> Void     // 마무리 버튼 (별 1~2개 + 마지막 스테이지 전용)

    // 애니메이션 상태 — 순차적으로 true로 변경하여 입장 연출
    @State private var starVisible    = [false, false, false]  // 별 1~3 개별 애니메이션
    @State private var contentVisible = false                   // 메인 콘텐츠 표시 여부
    @State private var buttonsVisible = false                   // 버튼 영역 표시 여부

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // 앱 배경색으로 전체 덮기
            Color.appBackground.ignoresSafeArea()

            // 별 3개: 특별 레이아웃 / 별 1~2개: 일반 레이아웃
            // 와이드 화면(아이패드·맥)에선 콘텐츠를 중앙 560pt로 제한 (아이폰 영향 없음)
            Group {
                if stars == 3 {
                    threeStarLayout
                } else {
                    lowStarLayout
                }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)

            #if os(macOS)
            // 맥 전용: 콘텐츠가 창 가운데 560pt로 좁혀지므로, X버튼만 창 전체 기준 우상단에 별도 고정
            // (레이아웃 내부의 X버튼은 숨김 처리해 중복 방지 — closeButton/embeddedCloseButton 참고)
            VStack {
                HStack {
                    Spacer()
                    macTopRightCloseButton
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            #endif
        }
        .onAppear { animateIn() }  // 화면 등장 시 순차 애니메이션 시작
    }

    #if os(macOS)
    /// 맥 전용 — 창 우상단 절대 위치에 고정되는 닫기 버튼 (스타일은 기존 X버튼과 동일)
    private var macTopRightCloseButton: some View {
        Button {
            SoundService.shared.play(.buttonTap)
            onClose()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.secondary)
                .frame(width: 40, height: 40)
                .background(
                    Color.dynamic(light: (1.0, 1.0, 1.0),
                                  dark: (0.18, 0.19, 0.23))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    #endif

    // MARK: - 별 3개 레이아웃

    private var threeStarLayout: some View {
        VStack(spacing: 0) {
            // 닫기 버튼 (오른쪽 상단) — 맥은 창 우상단에 별도 고정되므로 여기선 숨김(중복 방지)
            #if !os(macOS)
            closeButton
                .padding(.horizontal, 24)
                .padding(.top, 16)
            #endif

            Spacer(minLength: 0)

            // 스테이지 레이블 (예: "STAGE 1-5 CLEARED")
            Text("STAGE \(stageLabel) CLEARED")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(2.5)
                .opacity(contentVisible ? 1 : 0)

            // 메인 메시지 — "beautiful solution."
            VStack(spacing: -6) {
                Text("beautiful")
                    .font(.custom("Georgia-Italic", size: 50))
                    .foregroundStyle(Color.primary)
                Text("solution.")
                    .font(.custom("Georgia-Italic", size: 50))
                    .foregroundStyle(Color.accentMint)  // 민트 그린
            }
            .multilineTextAlignment(.center)
            .padding(.top, 6)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 12)  // 아래에서 올라오는 효과

            // 캐릭터 + 컨페티 영역
            ZStack {
                confettiView   // 배경 컨페티 도트
                characterIcon  // 캐릭터 아이콘
            }
            .frame(height: 150)
            .padding(.vertical, 20)
            .opacity(contentVisible ? 1 : 0)

            // 별 3개 행 — 순차적으로 등장
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { i in starView(index: i) }
            }
            .padding(.bottom, 28)

            // 스탯 카드 3개 (블럭 수 / 시간 / 도전 횟수)
            HStack(spacing: 10) {
                statCard(label: "BLOCKS", value: "\(blockCount)", sub: "최적")
                statCard(label: "TIME",   value: formattedTime,   sub: "걸린 시간")
                statCard(label: "TRIES",  value: "\(attemptCount)", sub: "도전 횟수")
            }
            .padding(.horizontal, 24)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 10)

            Spacer(minLength: 0)

            // 하단 버튼 영역
            VStack(spacing: 14) {
                // 다음 스테이지 / 챕터 목록 버튼
                Button {
                    SoundService.shared.play(.buttonTap)
                    onNext()
                } label: {
                    Text(isLastStage ? "챕터 목록으로" : "다음 스테이지로")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.slateButtonFace)  // 라이트: 기존 다크 브라운 / 다크: 슬레이트
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .buttonStyle(.plain)

                // 다시 도전 버튼 (텍스트 버튼)
                Button {
                    SoundService.shared.play(.buttonTap)
                    onRetry()
                } label: {
                    Text("다시 도전하기")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(buttonsVisible ? 1 : 0)
            .offset(y: buttonsVisible ? 0 : 8)  // 아래에서 올라오는 효과
        }
    }

    // MARK: - 별 1~2개 레이아웃

    private var lowStarLayout: some View {
        VStack(spacing: 0) {

            // 상단 — 스테이지 레이블 + 닫기 버튼
            HStack {
                Text("STAGE \(stageLabel)  —  \(stageName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
                // x 버튼으로 닫기 — 맥은 창 우상단에 별도 고정되므로 여기선 숨김(중복 방지)
                #if !os(macOS)
                Button {
                    SoundService.shared.play(.buttonTap)
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.secondary)  // UIColor.secondaryLabel과 동일 톤 (크로스플랫폼)
                        .frame(width: 40, height: 40)
                        .background(
                            // Color.dynamic 크로스플랫폼 헬퍼 (값은 기존과 동일)
                            Color.dynamic(light: (1.0, 1.0, 1.0),
                                          dark: (0.18, 0.19, 0.23))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                #endif
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)  // status bar 공간 확보
            .opacity(contentVisible ? 1 : 0)

            Spacer(minLength: 0)

            // 메인 메시지 — 별 수에 따라 다른 메시지
            VStack(spacing: 8) {
                Text(stars == 2 ? "거의 다!" : "클리어!")
                    .font(.custom("Georgia-Italic", size: 52))
                    .foregroundStyle(Color.primary)

                Text(stars == 2
                     ? "한 번만 더 — 별 3개에 도전해봐요"
                     : "조금 더 줄여봐요 — 별 2개까지 파이팅")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                // 보석을 다 못 모아서 별 3개를 놓쳤을 때만 추가 안내 (기믹 없는 스테이지는 itemHint가 항상 nil이라 무해)
                if let itemHint {
                    Text(itemHint)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.accentMint)
                        .padding(.top, 2)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 12)

            // 결과 카드 (별 + 블럭수 + 시간)
            lowStarCard
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 10)

            Spacer(minLength: 0)

            // 하단 버튼 2개
            HStack(spacing: 12) {
                // 왼쪽 — 다시 (라이트: 기존 다크 브라운 / 다크: 슬레이트)
                Button {
                    SoundService.shared.play(.buttonTap)
                    onRetry()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Text("다시")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.slateButtonFace)
                    .clipShape(RoundedRectangle(cornerRadius: 27))
                }
                .buttonStyle(.plain)

                // 오른쪽 — 넘어가기 / 마무리 (마지막 스테이지면 onFinish로 스테이지 목록 이동)
                Button {
                    SoundService.shared.play(.buttonTap)
                    if isLastStage { onFinish() } else { onNext() }
                } label: {
                    Text(isLastStage ? "마무리" : "넘어가기")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            // Color.dynamic 크로스플랫폼 헬퍼 (값은 기존과 동일)
                            Color.dynamic(light: (251/255, 246/255, 232/255),
                                          dark: (0.18, 0.19, 0.23))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 27))
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(buttonsVisible ? 1 : 0)
            .offset(y: buttonsVisible ? 0 : 8)
        }
    }

    // 별 1~2개용 결과 카드 — 별 + 이번 시도 블럭 수 + 3개 기준 + 시간
    private var lowStarCard: some View {
        VStack(spacing: 0) {
            // 별 표시
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in starView(index: i) }
            }
            .padding(.vertical, 20)

            Divider().padding(.horizontal, 16)

            // 이번 시도 블럭 수
            cardRow(
                label: "이번 시도",
                value: "\(blockCount) blocks",
                valueColor: .primary
            )

            Divider().padding(.horizontal, 16)

            // 별 3개 컷 — 목표 블럭 수 표시
            cardRow(
                label: "★ 3 컷",
                value: "\(threeStarCut) blocks",
                valueColor: Color.accentMint  // 민트 그린으로 강조
            )

            Divider().padding(.horizontal, 16)

            // 걸린 시간
            cardRow(
                label: "걸린 시간",
                value: formattedTime,
                valueColor: .secondary
            )
        }
        .background(
            // Color.dynamic 크로스플랫폼 헬퍼 (값은 기존과 동일)
            Color.dynamic(light: (251/255, 246/255, 232/255),  // 라이트: #fbf6e8
                          dark: (0.14, 0.15, 0.18))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 3)
    }

    /// 카드 내 한 행 — 레이블(왼쪽) + 값(오른쪽)
    private func cardRow(label: String, value: String, valueColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - 공통 서브뷰

    #if !os(macOS)
    /// 오른쪽 상단 닫기 버튼 (x 아이콘) — 맥은 macTopRightCloseButton으로 대체
    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                SoundService.shared.play(.buttonTap)
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.secondary)  // UIColor.secondaryLabel과 동일 톤 (크로스플랫폼)
                    .frame(width: 40, height: 40)
                    .background(
                        // Color.dynamic 크로스플랫폼 헬퍼 (값은 기존과 동일)
                        Color.dynamic(light: (1.0, 1.0, 1.0),
                                      dark: (0.18, 0.19, 0.23))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
    #endif

    /// 캐릭터 아이콘 — 3D 다크 블럭 + 화살표 (별 3개 레이아웃 중앙에 표시)
    private var characterIcon: some View {
        let size: CGFloat = 64   // 아이콘 크기
        let cr:   CGFloat = 16   // 모서리 반지름
        let topD: CGFloat = 1.5  // 위 뒷면 두께
        let botD: CGFloat = 4    // 아래 뒷면 두께

        // 홈 화면 미니 아이콘/게임 캐릭터와 동일한 다이나믹 컬러 세트 사용
        // (라이트: 기존 darkInk+탄색 베벨+크림 화살표 / 다크: 밝은 몸체+쿨 그레이 베벨+다크 화살표)
        return ThreeDSurface(topDepth: topD, bottomDepth: botD) {
            // ① 위 뒷면 — 라이트 #807869 / 다크 쿨 그레이
            ZStack {
                RoundedRectangle(cornerRadius: cr)
                    .fill(Color.characterTopBack)
            }
            .frame(width: size, height: size)
        } bottomBack: {
            // ② 아래 뒷면 — 라이트 #beb59f / 다크 쿨 그레이 (그림자 효과)
            ZStack {
                RoundedRectangle(cornerRadius: cr)
                    .fill(Color.characterBottomBack)
            }
            .frame(width: size, height: size)
        } front: {
            // ③ 앞면 — (라이트 다크 브라운 / 다크 회백색) + 화살표
            ZStack {
                RoundedRectangle(cornerRadius: cr)
                    .fill(Color.characterBody)
                // 화살표 모양으로 방향 표시 (라이트 크림 / 다크 다크잉크)
                arrowShape(frameSize: size, scale: 0.38)
                    .fill(Color.characterArrow)
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size + topD + botD)
    }

    /// 위쪽 화살표 Path 생성 — 머리 + 줄기 형태
    private func arrowShape(frameSize: CGFloat, scale: CGFloat) -> Path {
        let s  = frameSize * scale
        let cx = frameSize / 2  // 중심 x
        let cy = frameSize / 2  // 중심 y
        let hw  = s * 0.62      // 화살 머리 반폭
        let sw  = s * 0.22      // 줄기 반폭
        let top = cy - s * 0.90 // 꼭짓점 y
        let hy  = cy - s * 0.08 // 머리·줄기 경계 y
        let bot = cy + s * 0.72 // 줄기 아래 y

        return Path { path in
            path.move(to:    CGPoint(x: cx,      y: top))  // 꼭짓점
            path.addLine(to: CGPoint(x: cx - hw, y: hy))   // 머리 왼쪽
            path.addLine(to: CGPoint(x: cx - sw, y: hy))   // 줄기 왼쪽 위
            path.addLine(to: CGPoint(x: cx - sw, y: bot))  // 줄기 왼쪽 아래
            path.addLine(to: CGPoint(x: cx + sw, y: bot))  // 줄기 오른쪽 아래
            path.addLine(to: CGPoint(x: cx + sw, y: hy))   // 줄기 오른쪽 위
            path.addLine(to: CGPoint(x: cx + hw, y: hy))   // 머리 오른쪽
            path.closeSubpath()
        }
    }

    /// 컨페티 뷰 — 색깔 도트들이 캐릭터 주변에 흩어지는 효과
    private var confettiView: some View {
        // (x오프셋, y오프셋, 색상, 크기) 튜플 배열
        let dots: [(CGFloat, CGFloat, Color, CGFloat)] = [
            (-70, -20, Color(red: 0.55, green: 0.82, blue: 0.68), 8),
            (-50,  30, Color(red: 0.55, green: 0.65, blue: 0.90), 9),
            (-80,  50, Color(red: 0.95, green: 0.72, blue: 0.30), 8),
            ( 60, -30, Color(red: 0.85, green: 0.50, blue: 0.50), 8),
            ( 75,  20, Color(red: 0.65, green: 0.52, blue: 0.82), 9),
            ( 55,  50, Color(red: 0.55, green: 0.82, blue: 0.68), 7),
            (-30, -50, Color(red: 0.95, green: 0.72, blue: 0.30), 7),
            ( 30, -45, Color(red: 0.85, green: 0.50, blue: 0.50), 8),
        ]
        return ZStack {
            ForEach(0..<dots.count, id: \.self) { i in
                let (x, y, color, size) = dots[i]
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: size, height: size)
                    .offset(x: x, y: y)
                    // contentVisible 상태에 따라 페이드 인 + 스케일 업 애니메이션
                    .opacity(contentVisible ? 1 : 0)
                    .scaleEffect(contentVisible ? 1 : 0.3)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.6)
                        .delay(0.3 + Double(i) * 0.04),  // 각 도트마다 약간씩 늦게 등장
                        value: contentVisible
                    )
            }
        }
    }

    /// 별 하나 — 인덱스가 stars보다 작으면 채워진 별 (골드), 크면 빈 별
    private func starView(index: Int) -> some View {
        let filled = index < stars
        return Image(systemName: filled ? "star.fill" : "star")
            .font(.system(size: 38))
            .foregroundStyle(
                filled
                    ? Color(red: 0.95, green: 0.72, blue: 0.24)  // 골드
                    : Color.primary.opacity(0.18)                  // 연한 빈 별
            )
            // starVisible[index]가 true일 때 스케일/불투명도/회전 애니메이션으로 등장
            .scaleEffect(starVisible[index] ? 1.0 : 0.3)
            .opacity(starVisible[index] ? 1.0 : 0)
            .rotationEffect(.degrees(starVisible[index] ? 0 : -20))
    }

    /// 스탯 카드 — 레이블 + 큰 숫자 + 보조 텍스트
    private func statCard(label: String, value: String, sub: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.0)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            Text(sub)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            // Color.dynamic 크로스플랫폼 헬퍼 (값은 기존과 동일)
            Color.dynamic(light: (251/255, 246/255, 232/255),
                          dark: (0.14, 0.15, 0.18))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    /// 경과 시간을 "MM:SS" 형식 문자열로 변환
    private var formattedTime: String {
        let total   = Int(elapsedTime)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - 애니메이션

    /// 화면 등장 시 콘텐츠 → 별 → 버튼 순서로 순차 애니메이션 실행
    private func animateIn() {
        // ① 콘텐츠 (메시지, 캐릭터, 스탯) 등장
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            contentVisible = true
        }
        // ② 별 3개 순차 등장 (0.12초 간격)
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.12) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                    starVisible[i] = true
                }
            }
        }
        // ③ 버튼 영역 등장 (콘텐츠 등장 후 0.65초 대기)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                buttonsVisible = true
            }
        }
    }
}

// MARK: - Preview

#Preview("별 3개") {
    ClearOverlayView(
        stars: 3, elapsedTime: 42, attemptCount: 2,
        blockCount: 4, stageLabel: "1-5", stageName: "뒤로 한 칸",
        threeStarCut: 4, isLastStage: false, onClose: {}, onRetry: {}, onNext: {}, onFinish: {}
    )
}

#Preview("별 2개") {
    ClearOverlayView(
        stars: 2, elapsedTime: 78, attemptCount: 4,
        blockCount: 7, stageLabel: "1-4", stageName: "지그재그",
        threeStarCut: 5, isLastStage: false, onClose: {}, onRetry: {}, onNext: {}, onFinish: {}
    )
}

#Preview("별 1개") {
    ClearOverlayView(
        stars: 1, elapsedTime: 120, attemptCount: 6,
        blockCount: 9, stageLabel: "1-3", stageName: "한 발 더",
        threeStarCut: 5, isLastStage: false, onClose: {}, onRetry: {}, onNext: {}, onFinish: {}
    )
}
