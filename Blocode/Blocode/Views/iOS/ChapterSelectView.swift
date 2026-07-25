//
//  ChapterSelectView.swift
//  Blocode
//
//  Created by 조준희 on 5/10/26.
//

import SwiftUI

// MARK: - ChapterSelectView
/// 모든 챕터를 지그재그 맵 형태로 표시하는 화면
struct ChapterSelectView: View {

    @Binding var navPath: NavigationPath  // 뒤로가기 및 다음 화면 이동용

    /// 챕터 선택 화면 상태/로직 — 챕터 목록·잠금·별점 계산은 ViewModel이 담당 (MVVM)
    @StateObject private var vm = ChapterSelectViewModel()

    /// 각 챕터 카드 중심의 X 비율 (지그재그 배치) — 화면 너비 기준 0.0~1.0
    /// 챕터 수(10개)만큼 값을 다 채워둠 — 5개만 두고 순환시키면 인덱스4→5(마지막→처음) 전환에서
    /// 좌우 진폭이 거의 없어져(0.30→0.26) 지그재그가 끊겨 보이는 문제가 있었음
    private let xCenterFracs: [CGFloat] = [0.26, 0.70, 0.22, 0.68, 0.30, 0.72, 0.24, 0.66, 0.28, 0.74]

    /// 챕터 인덱스의 X 비율 — 챕터 수가 배열 길이를 넘어도 순환 접근해 인덱스 크래시 방지
    private func xCenterFrac(_ index: Int) -> CGFloat {
        xCenterFracs[index % xCenterFracs.count]
    }

    private let cardSize: CGFloat   = 90    // 챕터 카드 크기
    private let rowSpacing: CGFloat = 158   // 카드 상단 간격 (세로 간격)
    private let topPad: CGFloat     = 8     // 맵 상단 패딩

    /// 전체 맵 스크롤 영역 높이 계산
    private var totalMapHeight: CGFloat {
        topPad + CGFloat(vm.chapters.count) * rowSpacing + 60
    }

    /// 스크롤 시 헤더 축소 여부
    @State private var isCompact        = false
    @State private var pressedChapterId: Int? = nil  // 눌린 챕터 카드 ID 추적
    @State private var lockInfo: LockInfo? = nil     // 잠금 안내 팝업 (nil이면 숨김)

    /// 다크/라이트 모드 감지 — 잠긴 카드 자물쇠 밝기를 다크에서만 스테이지 아이콘과 맞추는 데 사용
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // 고정 헤더 — 스크롤 내려가면 축소
            header

            // 챕터 맵 스크롤 영역
            ScrollView(showsIndicators: false) {
                // 와이드 화면(아이패드·맥)에선 지그재그 맵을 중앙 680pt로 제한 (아이폰에선 영향 없음)
                mapSection
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
            }
            // 스크롤 위치에 따라 헤더 축소 상태 갱신
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, newY in
                withAnimation(.easeInOut(duration: 0.18)) {
                    isCompact = newY > 30  // 30pt 이상 스크롤 시 축소
                }
            }
        }
        .hideNavigationBar()  // iOS 전용 API 래퍼 (macOS no-op)
        .background(Color.appBackground.ignoresSafeArea())
        // 잠긴 챕터 탭 시 해금 조건 팝업 (표시 패턴은 공용 모디파이어)
        .lockInfoPopup($lockInfo)
    }

    // MARK: - 헤더 (고정 + 스크롤 시 축소)

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                // 스크롤 시 "여정" 레이블 숨김 (애니메이션 포함)
                if !isCompact {
                    Text("여정")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                // 타이틀 — 축소 시 폰트 크기 줄어듦
                Text("chapter map")
                    .font(.system(
                        size: isCompact ? 22 : 34,
                        weight: .bold,
                        design: .serif
                    ))
                    .italic()
                    .foregroundStyle(.primary)
            }
            .animation(.easeInOut(duration: 0.18), value: isCompact)

            Spacer()

            // 홈 버튼 — NavigationStack에서 한 단계 뒤로
            Button {
                SoundService.shared.play(.buttonTap)
                if !navPath.isEmpty { navPath.removeLast() }
            } label: {
                Image(systemName: "house")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.secondary)  // UIColor.secondaryLabel과 동일 톤 (크로스플랫폼)
                    .frame(width: 36, height: 36)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        // 와이드 화면에선 헤더 콘텐츠도 맵과 같은 680pt로 제한해 정렬 유지 (아이폰 영향 없음)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, isCompact ? 14 : 24)
        .animation(.easeInOut(duration: 0.18), value: isCompact)
        .background(Color.appBackground)
        // 축소 시 구분 그림자 표시
        .shadow(
            color: Color.black.opacity(isCompact ? 0.07 : 0),
            radius: 8, x: 0, y: 4
        )
    }

    // MARK: - 맵 영역

    /// 지그재그 배치 챕터 노드와 연결선으로 구성된 맵 영역
    private var mapSection: some View {
        GeometryReader { geo in
            let w = geo.size.width  // 화면 너비 — xCenterFracs 계산 기준

            ZStack(alignment: .topLeading) {

                // 포물선 점선 커넥터 — 챕터 간 연결선
                ForEach(0..<vm.chapters.count - 1, id: \.self) { i in
                    connectorPath(
                        from: CGPoint(
                            x: xCenterFrac(i)     * w,
                            y: topPad + CGFloat(i)     * rowSpacing + cardSize  // 현재 챕터 카드 하단
                        ),
                        to: CGPoint(
                            x: xCenterFrac(i + 1) * w,
                            y: topPad + CGFloat(i + 1) * rowSpacing             // 다음 챕터 카드 상단
                        )
                    )
                }

                // 챕터 노드 (카드 + 레이블 + 별)
                ForEach(Array(vm.chapters.enumerated()), id: \.element.id) { i, ch in
                    chapterNode(ch)
                        // 카드 중심을 xCenterFracs 위치에 맞춤
                        .offset(
                            x: xCenterFrac(i) * w - (cardSize + 20) / 2,
                            y: topPad + CGFloat(i) * rowSpacing
                        )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: totalMapHeight)
        .padding(.bottom, 40)
    }

    // MARK: - 포물선 점선 커넥터

    /// 두 챕터 카드를 연결하는 이차 베지어 곡선 점선
    private func connectorPath(from: CGPoint, to: CGPoint) -> some View {
        // 이차 베지어 곡선: 중간 제어점을 수평 방향 반대로 휘어지게
        let midX = (from.x + to.x) / 2
        let midY = (from.y + to.y) / 2
        // 좌→우 이동이면 위로, 우→좌 이동이면 아래로 살짝 휨
        let goingRight = to.x > from.x
        let controlPt = CGPoint(
            x: midX + (goingRight ? -30 : 30),
            y: midY
        )

        return Path { p in
            p.move(to: from)
            p.addQuadCurve(to: to, control: controlPt)
        }
        .stroke(
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 9])
        )
        .foregroundStyle(Color.primary.opacity(0.20))
    }

    // MARK: - 챕터 노드 (카드 + 이름 + 별)

    /// 개별 챕터를 표현하는 3D 카드 + 이름 + 별점 요약 뷰
    private func chapterNode(_ chapter: ChapterInfo) -> some View {
        let unlocked  = vm.isUnlocked(chapter)
        let isPressed = pressedChapterId == chapter.id  // 현재 눌린 카드 여부

        let topD: CGFloat = 2   // 위 뒷면 두께
        let botD: CGFloat = 4   // 아래 뒷면 두께

        return VStack(spacing: 7) {

            // 카드
            ZStack(alignment: .topTrailing) {
                ThreeDSurface(topDepth: topD, bottomDepth: botD, isPressed: isPressed) {
                    // ① 위 뒷면
                    ZStack {
                        RoundedRectangle(cornerRadius: 26).fill(unlocked ? chapter.color : Color.lockedBackground)
                        RoundedRectangle(cornerRadius: 26).fill(Color.white.opacity(unlocked ? 0.32 : 0.18))
                    }
                    .frame(width: cardSize, height: cardSize)
                } bottomBack: {
                    // ② 아래 뒷면
                    ZStack {
                        RoundedRectangle(cornerRadius: 26).fill(unlocked ? chapter.color : Color.lockedBackground)
                        RoundedRectangle(cornerRadius: 26).fill(Color.black.opacity(unlocked ? 0.28 : 0.10))
                    }
                    .frame(width: cardSize, height: cardSize)
                } front: {
                    // ③ 앞면 — 색 + (눌림 시 그림자) + 번호/잠금
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .fill(unlocked ? chapter.color : Color.lockedBackground)
                        if isPressed {
                            RoundedRectangle(cornerRadius: 26).fill(Color.black.opacity(0.10))
                        }
                        if unlocked {
                            Text("\(chapter.number)")
                                .font(.system(size: 48, weight: .bold, design: .serif))
                                .italic()
                                .foregroundStyle(.white.opacity(0.95))
                        } else {
                            // 자물쇠 밝기 — 라이트: 기존 0.30 유지 / 다크: 스테이지 잠금 아이콘과 동일한 0.55
                            Image(systemName: "lock.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.55 : 0.30))
                        }
                    }
                    .frame(width: cardSize, height: cardSize)
                }
                .frame(width: cardSize, height: cardSize + topD + botD)

                // 진행 배지
                if unlocked && chapter.stageCount > 0 {
                    let cleared = vm.clearedStageCount(chapter)
                    Text("\(cleared)/\(chapter.stageCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.13, green: 0.13, blue: 0.13))
                        .clipShape(Capsule())
                        .offset(x: 8, y: -8)
                }
            }
            .frame(width: cardSize + 10, height: cardSize + 10)
            .contentShape(Rectangle())
            .onTapGesture {
                if unlocked && chapter.stageCount > 0 {
                    SoundService.shared.play(.buttonTap)
                    navPath.append(AppRoute.chapter(chapter.number))
                } else if !unlocked {
                    // 잠긴 챕터: 전용 잠금 사운드 + 해금 조건 팝업 표시
                    SoundService.shared.play(.lockButton)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        lockInfo = LockInfo(
                            title: "아직 잠겨 있어요",
                            message: vm.lockMessage(for: chapter),
                            accentColor: chapter.color
                        )
                    }
                }
            }
            // 눌림 상태 추적 — 탭과 동시 실행
            .onPressState(isPressed: Binding(
                get: { pressedChapterId == chapter.id },
                set: { pressed in pressedChapterId = pressed ? chapter.id : nil }
            ))

            // 챕터 이름
            Text(chapter.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(unlocked ? Color.primary : Color.secondary)

            // 별 진행도 (비율 기반으로 최대 3개 표시 — 환산 계산은 VM 담당)
            StarRatingView(earned: vm.displayStarCount(chapter), size: 11)
                .opacity(unlocked ? 1.0 : 0.35)  // 잠긴 챕터는 흐리게
        }
        .frame(width: cardSize + 20)  // 레이블이 카드보다 조금 넓게
    }

}

// MARK: - Preview

#Preview {
    @Previewable @State var path = NavigationPath()
    ChapterSelectView(navPath: $path)
}
