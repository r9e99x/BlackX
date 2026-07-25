//
//  MacContentShell.swift
//  Blocode
//
//  Created by 조준희 on 7/2/26.
//

// macOS 전용 최상위 화면 — iOS/iPadOS는 이 파일 전체가 컴파일에서 제외됨
// (ContentView/ChapterSelectView/ChapterView 등 기존 iOS 화면은 이 파일에서 전혀 참조하지 않음)
// 색상·3D 효과·눌림 효과는 전부 iOS와 동일한 공용 컴포넌트(ThreeDSurface/AppColors/onPressState/
// LockInfoOverlay/StarRatingView)를 그대로 재사용해 라이트·다크 모드 모두 iOS와 동일하게 유지한다.
// 챕터 브라우저(ChapterBrowsePane)와 미리보기 맵(StagePreviewMapView)은 별도 파일로 분리됨 (Views/Mac/)
#if os(macOS)
import SwiftUI

// MARK: - MacContentShell
/// 좌측 고정 사이드바(홈/챕터/설정) + 우측 콘텐츠 전환 구조
/// 챕터를 브라우징 중일 때는 사이드바 자리를 챕터 목록이 대신 차지한다(3단 컬럼)
/// 게임 화면(StageView) 진입 시에는 이 셸을 벗어나 전체 화면으로 전환하고,
/// 뒤로가기 시 셸로 복귀한다 (StageView의 onReturnToChapterList로 연결)
struct MacContentShell: View {

    /// 사이드바 최상위 섹션
    private enum Section: Hashable {
        case home, chapters, settings
    }

    @State private var section: Section = .home
    /// 챕터 섹션 내부 상태 — nil이면 지그재그 지도, 값이 있으면 해당 챕터의 3단 브라우저
    /// (값이 있을 때는 메인 사이드바 대신 챕터 목록이 그 자리를 대체함)
    @State private var browsingChapter: Int? = nil
    /// 게임 화면(StageView) 진입/복귀 전용 스택 — 사이드바 셸과는 별개의 스택
    @State private var navPath = NavigationPath()

    @StateObject private var homeVM = HomeViewModel()
    @StateObject private var chapterSelectVM = ChapterSelectViewModel()
    @ObservedObject private var settings = SettingsService.shared

    var body: some View {
        NavigationStack(path: $navPath) {
            Group {
                if section == .chapters, let chapter = browsingChapter {
                    // 챕터 브라우징 중 — 메인 사이드바 대신 3단 컬럼(챕터목록|스테이지목록|미리보기)
                    ChapterBrowsePane(
                        chapterNumber: chapter,
                        onBackToMap: { withAnimation(.easeInOut(duration: 0.2)) { browsingChapter = nil } },
                        onSelectChapter: { newChapter in
                            withAnimation(.easeInOut(duration: 0.2)) { browsingChapter = newChapter }
                        },
                        onStart: { ch, num in navPath.append(AppRoute.stage(chapter: ch, number: num)) }
                    )
                    .id(chapter)  // 챕터 전환 시 뷰 정체성 갱신 → ViewModel/선택 스테이지 초기화
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                } else {
                    HStack(spacing: 0) {
                        sidebar
                        Divider()
                        contentPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.22), value: browsingChapter)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(windowTitle)
            .navigationDestination(for: AppRoute.self) { route in
                if case .stage(let chapter, let number) = route {
                    StageView(chapter: chapter, number: number, navPath: $navPath,
                              showsOwnBackButton: false) {
                        // "챕터 목록으로" 복귀 — 사이드바 셸의 챕터 브라우저로 이동
                        if !navPath.isEmpty { navPath.removeLast() }
                        section = .chapters
                    }
                    // 스테이지 번호별로 뷰 정체성을 강제 구분 (iOS ContentView와 동일한 처리)
                    // 이게 없으면 다음 스테이지로 넘어갈 때 이전 GameViewModel(코드 블럭 포함)이 재사용됨
                    .id("stage-\(chapter)-\(number)")
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button {
                                if !navPath.isEmpty { navPath.removeLast() }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                                    .frame(width: 30, height: 30)
                                    .background(Color.panelBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
        .preferredColorScheme(settings.theme.colorScheme)
    }

    /// 윈도우 타이틀 바 텍스트 — 현재 섹션/챕터 반영
    private var windowTitle: String {
        switch section {
        case .home: return "Blocode"
        case .chapters:
            if let ch = browsingChapter, let info = ChapterCatalog.chapter(ch) {
                return "Blocode — \(info.title)"
            }
            return "Blocode — 챕터"
        case .settings: return "Blocode — 설정"
        }
    }

    // MARK: - 사이드바

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 로고
            HStack(spacing: 10) {
                miniLogoIcon
                Text("Blocode")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)

            sidebarItem(icon: "house", title: "홈", isSelected: section == .home) {
                withAnimation(.easeInOut(duration: 0.2)) { section = .home }
            }
            sidebarItem(icon: "square.grid.2x2", title: "챕터", isSelected: section == .chapters) {
                withAnimation(.easeInOut(duration: 0.2)) { section = .chapters }
            }
            sidebarItem(icon: "gearshape", title: "설정", isSelected: section == .settings) {
                withAnimation(.easeInOut(duration: 0.2)) { section = .settings }
            }

            Spacer()

            // 하단 통계 요약 (홈 통계와 동일한 데이터 소스)
            statsFooter
                .padding(16)
        }
        .frame(width: 240)
        .background(Color.cardBackground)
    }

    private func sidebarItem(icon: String, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            // 행 전체 폭을 채워야 Spacer가 여백을 차지하고, 그 여백도 탭 가능해짐
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .foregroundStyle(isSelected ? .white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.darkInk : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }

    /// 사이드바 로고 아이콘 — 홈 화면 미니 아이콘과 동일한 다이나믹 컬러 사용
    private var miniLogoIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.characterBody)
            Image(systemName: "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.characterArrow)
        }
        .frame(width: 28, height: 28)
    }

    /// 하단 통계 카드 — 별/연속을 각각 아이콘+굵은값+레이블 한 줄로 표시
    private var statsFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            statsFooterRow(icon: "star.fill", iconColor: Color.starGold,
                           value: "\(homeVM.earnedStars)/\(homeVM.totalPossibleStars)", label: "획득 별")
            statsFooterRow(icon: "flame.fill", iconColor: Color(red: 1.0, green: 0.55, blue: 0.30),
                           value: "\(homeVM.streak)일째", label: "연속")
        }
        .padding(12)
        .background(Color.statCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statsFooterRow(icon: String, iconColor: Color, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(iconColor)
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.primary)
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    // MARK: - 콘텐츠 패널 (섹션에 따라 전환)

    @ViewBuilder
    private var contentPane: some View {
        Group {
            switch section {
            case .home:
                homeContent
            case .chapters:
                // browsingChapter가 nil일 때만 이 분기로 오므로 항상 지도
                chapterMapContent
            case .settings:
                SettingsView(onResetProgress: {
                    navPath = NavigationPath()
                    withAnimation(.easeInOut(duration: 0.2)) { section = .home }
                }, isEmbedded: true)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.18), value: section)
    }

    // MARK: - 홈 콘텐츠

    /// 상단(인용구+통계)은 창 크기에 맞춰 유연하게 리플로우되고,
    /// 버튼은 항상 화면 맨 아래 중앙에 고정
    private var homeContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("오늘의 한 줄").font(.system(size: 13)).foregroundStyle(.secondary)
                    Text("적은 블럭이 좋은 코드.")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .italic()
                    Text(homeVM.dynamicSubtitle)
                        .font(.system(size: 14)).foregroundStyle(.secondary)
                        .padding(.top, 6)

                    HStack(spacing: 12) {
                        statCard(icon: "star.fill", color: Color.starGold,
                                 value: "\(homeVM.earnedStars)/\(homeVM.totalPossibleStars)", label: "획득 별")
                        statCard(icon: "checkmark.seal.fill", color: Color(red: 0.576, green: 0.788, blue: 0.671),
                                 value: "\(homeVM.completedChapters)/\(homeVM.chapterCount)", label: "챕터 완료")
                        statCard(icon: "flame.fill", color: Color(red: 1.0, green: 0.55, blue: 0.30),
                                 value: "\(homeVM.streak)일째", label: "연속")
                    }
                    .padding(.top, 32)
                }
                .padding(48)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 버튼 영역 — 스크롤 밖, 화면 맨 아래 중앙에 고정
            VStack(spacing: 12) {
                continueButton
                browseButton
            }
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 48)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    private func statCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.statCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // iOS statCard와 동일한 그림자
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - 홈 버튼 (iOS ContentView.continueButton/browseButton과 동일한 3D + 눌림 효과)

    @State private var isContinuePressed = false
    @State private var isBrowsePressed = false

    private var continueButton: some View {
        let frontH: CGFloat = 58
        let topD: CGFloat = 0.8
        let botD: CGFloat = 2.5
        let cr: CGFloat = 18
        // 라이트: 기존 값 유지 / 다크: iOS ContentView.continueButton과 동일한 슬레이트 톤
        // (예전엔 Color(red:...) 고정값이라 다크모드에서도 라이트 색 그대로 나오던 버그 — Color.dynamic으로 교체)
        let frontColor = Color.dynamic(light: (0.165, 0.145, 0.125), dark: (72/255, 78/255, 96/255))
        let pressedFrontColor = Color.dynamic(light: (86/255, 80/255, 72/255), dark: (88/255, 95/255, 116/255))
        let next = homeVM.nextStage
        let isFirstTime = homeVM.isFirstTime

        return Button {
            if let next {
                navPath.append(AppRoute.stage(chapter: next.chapter, number: next.stage))
            } else {
                section = .chapters
            }
        } label: {
            ThreeDSurface(topDepth: topD, bottomDepth: botD, isPressed: isContinuePressed) {
                RoundedRectangle(cornerRadius: cr).fill(Color.slateButtonTopBack)
                    .frame(maxWidth: .infinity).frame(height: frontH)
            } bottomBack: {
                RoundedRectangle(cornerRadius: cr).fill(Color.slateButtonBottomBack)
                    .frame(maxWidth: .infinity).frame(height: frontH)
            } front: {
                ZStack {
                    RoundedRectangle(cornerRadius: cr)
                        .fill(isContinuePressed ? pressedFrontColor : frontColor)
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: isFirstTime ? "sparkles" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(isFirstTime ? "시작하기" : "이어서 하기")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        if !isFirstTime, let next {
                            Text("\(next.chapter)-\(next.stage)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity).frame(height: frontH)
            }
            .frame(maxWidth: .infinity).frame(height: frontH + topD + botD)
        }
        .buttonStyle(.plain)
        .onPressState(isPressed: $isContinuePressed)
    }

    private var browseButton: some View {
        let frontH: CGFloat = 52
        let topD: CGFloat = 0.8
        let botD: CGFloat = 2.5
        let cr: CGFloat = 18
        // iOS ContentView.browseButton과 동일한 크림(라이트)/슬레이트(다크) 톤
        // (예전엔 아래 뒷면이 Color(red:...) 고정 베이지라 다크모드에서도 그대로 나오던 버그)
        let frontColor = Color.dynamic(light: (252/255, 249/255, 238/255), dark: (0.22, 0.23, 0.27))
        let topBackColor = Color.dynamic(light: (252/255, 249/255, 238/255), dark: (0.18, 0.19, 0.22))
        let botBackColor = Color.dynamic(light: (196/255, 192/255, 181/255), dark: (0.13, 0.14, 0.17))

        return Button {
            section = .chapters
        } label: {
            ThreeDSurface(topDepth: topD, bottomDepth: botD, isPressed: isBrowsePressed) {
                RoundedRectangle(cornerRadius: cr).fill(topBackColor)
                    .frame(maxWidth: .infinity).frame(height: frontH)
            } bottomBack: {
                RoundedRectangle(cornerRadius: cr).fill(botBackColor)
                    .frame(maxWidth: .infinity).frame(height: frontH)
            } front: {
                ZStack {
                    RoundedRectangle(cornerRadius: cr).fill(frontColor)
                    if isBrowsePressed {
                        RoundedRectangle(cornerRadius: cr).fill(Color.black.opacity(0.06))
                    }
                    Text("챕터 둘러보기")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity).frame(height: frontH)
            }
            .frame(maxWidth: .infinity).frame(height: frontH + topD + botD)
        }
        .buttonStyle(.plain)
        .onPressState(isPressed: $isBrowsePressed)
    }

    // MARK: - 챕터 지도 (지그재그 + 3D + 눌림 + 잠금 팝업)

    @State private var pressedChapterId: Int? = nil
    @State private var lockInfo: LockInfo? = nil

    private var chapterMapContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 제목 — 스크롤 밖에 고정해 항상 좌상단에 위치 (스크롤해도 안 움직임)
            VStack(alignment: .leading, spacing: 4) {
                Text("여정").font(.system(size: 13)).foregroundStyle(.secondary)
                Text("chapter map")
                    .font(.system(size: 30, weight: .bold, design: .serif)).italic()
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
            .padding(.bottom, 20)

            // 지도는 세로 스크롤 (iOS 챕터 지도와 동일한 방향 — 예전엔 가로 스크롤이었으나
            // 챕터가 10개로 늘면서 카드가 옆으로 계속 넓어지는 게 부자연스러워 세로 지그재그로 변경)
            ScrollView(.vertical, showsIndicators: false) {
                zigzagColumn
                    .padding(.horizontal, 40)
            }
        }
        // 잠긴 챕터 탭 시 해금 조건 팝업 (표시 패턴은 공용 모디파이어)
        .lockInfoPopup($lockInfo)
    }

    /// 챕터를 세로로 나열하며 좌우로 지그재그 배치 (iOS ChapterSelectView.mapSection과 동일한 방식 —
    /// GeometryReader로 가로폭을 얻어 카드 중심을 비율(xCenterFrac)로 배치)
    private var zigzagColumn: some View {
        let chapters = chapterSelectVM.chapters
        let cardSize: CGFloat = 100
        // chapterCard의 실제 프레임 폭(cardSize + 20, 라벨 여유분 포함)과 반드시 일치시켜야
        // 점선 연결점이 카드 중심에서 어긋나지 않음
        let cardOuterWidth = cardSize + 20
        let rowSpacing: CGFloat = 172
        let topPad: CGFloat = 8
        // iOS ChapterSelectView.xCenterFracs와 동일한 시퀀스 — 두 플랫폼 챕터 지도가 같은 리듬으로 지그재그 (좌우 진폭이 매 챕터 확실히 바뀌도록 10개 값 전부 채움)
        let xCenterFracs: [CGFloat] = [0.26, 0.70, 0.22, 0.68, 0.30, 0.72, 0.24, 0.66, 0.28, 0.74]
        func xCenterFrac(_ index: Int) -> CGFloat { xCenterFracs[index % xCenterFracs.count] }
        let totalHeight = topPad + CGFloat(chapters.count) * rowSpacing + 60

        return GeometryReader { geo in
            let w = geo.size.width

            ZStack(alignment: .topLeading) {
                // 연결선 (곡선 점선)
                ForEach(0..<max(chapters.count - 1, 0), id: \.self) { i in
                    connectorPath(
                        from: CGPoint(x: xCenterFrac(i) * w, y: topPad + CGFloat(i) * rowSpacing + cardSize),
                        to: CGPoint(x: xCenterFrac(i + 1) * w, y: topPad + CGFloat(i + 1) * rowSpacing)
                    )
                }

                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    chapterCard(chapter, cardSize: cardSize)
                        .offset(
                            x: xCenterFrac(index) * w - cardOuterWidth / 2,
                            y: topPad + CGFloat(index) * rowSpacing
                        )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: totalHeight)
        .padding(.bottom, 40)
    }

    /// 두 챕터 카드를 연결하는 이차 베지어 곡선 점선 (좌→우 이동이면 위로, 우→좌 이동이면 아래로 살짝 휨)
    private func connectorPath(from: CGPoint, to: CGPoint) -> some View {
        let midX = (from.x + to.x) / 2
        let midY = (from.y + to.y) / 2
        let goingRight = to.x > from.x
        let controlPt = CGPoint(x: midX + (goingRight ? -30 : 30), y: midY)
        return Path { p in
            p.move(to: from)
            p.addQuadCurve(to: to, control: controlPt)
        }
        .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 9]))
        .foregroundStyle(Color.primary.opacity(0.20))
    }

    /// 챕터 카드 — iOS ChapterSelectView.chapterNode와 동일한 3D 3레이어 구조 + 눌림 효과
    private func chapterCard(_ chapter: ChapterInfo, cardSize: CGFloat) -> some View {
        let unlocked = chapterSelectVM.isUnlocked(chapter)
        let isPressed = pressedChapterId == chapter.id
        let topD: CGFloat = 2
        let botD: CGFloat = 4

        return VStack(spacing: 7) {
            ThreeDSurface(topDepth: topD, bottomDepth: botD, isPressed: isPressed) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(unlocked ? chapter.color : Color.lockedBackground)
                    RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(unlocked ? 0.32 : 0.18))
                }
                .frame(width: cardSize, height: cardSize)
            } bottomBack: {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(unlocked ? chapter.color : Color.lockedBackground)
                    RoundedRectangle(cornerRadius: 24).fill(Color.black.opacity(unlocked ? 0.28 : 0.10))
                }
                .frame(width: cardSize, height: cardSize)
            } front: {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(unlocked ? chapter.color : Color.lockedBackground)
                    if isPressed {
                        RoundedRectangle(cornerRadius: 24).fill(Color.black.opacity(0.10))
                    }
                    if unlocked {
                        Text("\(chapter.number)")
                            .font(.system(size: 40, weight: .bold, design: .serif)).italic()
                            .foregroundStyle(.white.opacity(0.95))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.primary.opacity(0.30))
                    }
                }
                .frame(width: cardSize, height: cardSize)
            }
            .frame(width: cardSize, height: cardSize + topD + botD)
            .contentShape(Rectangle())
            .onTapGesture {
                if unlocked && chapter.stageCount > 0 {
                    SoundService.shared.play(.buttonTap)
                    browsingChapter = chapter.number
                } else if !unlocked {
                    SoundService.shared.play(.lockButton)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        lockInfo = LockInfo(title: "아직 잠겨 있어요",
                                            message: chapterSelectVM.lockMessage(for: chapter),
                                            accentColor: chapter.color)
                    }
                }
            }
            .onPressState(isPressed: Binding(
                get: { pressedChapterId == chapter.id },
                set: { pressed in pressedChapterId = pressed ? chapter.id : nil }
            ))

            Text(chapter.title).font(.system(size: 13, weight: .medium))
                .foregroundStyle(unlocked ? Color.primary : Color.secondary)

            // 별 진행도 (비율 기반으로 최대 3개 표시 — 환산 계산은 VM 담당, iOS 챕터 지도와 공용)
            StarRatingView(earned: chapterSelectVM.displayStarCount(chapter), size: 11)
                .opacity(unlocked ? 1 : 0.35)
        }
        .frame(width: cardSize + 20)
    }
}
#endif
