//
//  ChapterView.swift
//  Blocode
//
//  Created by 조준희 on 5/10/26.
//

import SwiftUI

// MARK: - ChapterView
/// 특정 챕터의 스테이지 목록을 표시하는 화면
struct ChapterView: View {

    @Binding var navPath: NavigationPath    // 화면 이동 제어

    /// 챕터 화면 상태/로직 — 스테이지 로딩·진행 계산은 ViewModel이 담당 (MVVM)
    @StateObject private var vm: ChapterViewModel

    /// 다크/라이트 모드 감지 — 잠긴 스테이지 아이콘의 베벨 강도를 다크에서만 조정하는 데 사용
    @Environment(\.colorScheme) private var colorScheme
    @State private var retryConfirmInfo: RetryConfirmInfo? = nil  // 재도전 확인 팝업 (nil이면 숨김)
    @State private var pressedStageNumber: Int?   = nil  // 눌린 스테이지 아이콘 번호 추적
    @State private var lockInfo: LockInfo?         = nil  // 잠금 안내 팝업 (nil이면 숨김)

    init(navPath: Binding<NavigationPath>, chapter: Int) {
        self._navPath = navPath
        // ViewModel 초기화 (스테이지 로딩은 VM 생성 시 수행)
        self._vm = StateObject(wrappedValue: ChapterViewModel(chapter: chapter))
    }

    // MARK: - 챕터 색상 (챕터 번호 → 색상)
    /// 챕터 색상 — ChapterCatalog(단일 원본)에서 조회, 헤더 배경과 스테이지 아이콘에 사용
    /// (색상 값 자체는 카탈로그가 보유 — 화면별 색상 이중 정의 제거)
    var chapterColor: Color {
        ChapterCatalog.chapter(vm.chapter)?.color ?? Color.accentColor
    }

    var body: some View {
        // GeometryReader는 safe area를 소비하지 않으므로 여기서 실제 상단 인셋을 읽고,
        // 내부 VStack만 상단 safe area를 무시해 헤더가 status bar 영역까지 확장되게 한다
        // (기존 UIApplication 기반 조회는 macOS에서 컴파일 불가 + 폴백 상수 의존이라 교체)
        GeometryReader { geo in
            if geo.size.width >= LayoutBreakpoint.wide {
                // ── 와이드(아이폰 가로모드): 좌측 챕터 헤더 패널 + 우측 스테이지 목록 분할 ──
                // 헤더는 세로모드의 풀블리드 배너 대신, 맥/아이패드의 챕터 브라우저와 동일한
                // "작은 둥근 카드" 스타일(wideChapterHeaderCard)을 사용 — 세로모드 chapterHeader는 무변경
                HStack(alignment: .top, spacing: 0) {
                    // 왼쪽 — 뒤로가기 + 챕터 카드 (맥/아이패드는 별도 챕터목록 컬럼에 뒤로가기가 있지만
                    // 아이폰엔 그 컬럼이 없어서 카드 위에 별도로 배치)
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: geo.safeAreaInsets.top + 16)

                        Button {
                            SoundService.shared.play(.buttonTap)
                            if !navPath.isEmpty { navPath.removeLast() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .bold))
                                Text("CHAPTERS").tracking(1)
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                        wideChapterHeaderCard

                        // 카드 아래 빈 공간의 정중앙에 챕터 한 줄 설명 배치
                        // (양쪽에 Spacer를 둬서 남는 공간을 정확히 반씩 나눠 가운데 정렬)
                        // 폰트는 홈 화면 인용구(ContentView.quoteSection)와 완전히 동일하게 맞춤 —
                        // 한글은 .italic()이나 .design(.serif)가 안 먹혀서(한글 서체엔 진짜 이탤릭이
                        // 없음), 인용구와 동일하게 Georgia-Italic 폰트 이름 + 수동 기울임 변환을 사용
                        Spacer(minLength: 0)
                        if let description = ChapterCatalog.chapter(vm.chapter)?.description {
                            Text(description)
                                .font(.custom("Georgia-Italic", size: 22))
                                .foregroundStyle(Color.primary.opacity(0.55))
                                .multilineTextAlignment(.center)
                                .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.12, d: 1, tx: 0, ty: 0))
                                .padding(.horizontal, 32)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: 380)
                    .frame(maxHeight: .infinity, alignment: .top)

                    // 오른쪽 — 스테이지 목록 (중앙 640pt 제한)
                    ScrollView(showsIndicators: false) {
                        stageList
                            .frame(maxWidth: 640)
                            .frame(maxWidth: .infinity)
                            .padding(.top, geo.safeAreaInsets.top + 16)
                            .padding(.bottom, 48)
                    }
                }
                .ignoresSafeArea(edges: .top)
            } else {
                // ── 컴팩트(아이폰): 기존 세로 스택 ──
                VStack(spacing: 0) {
                    chapterHeader(safeAreaTop: geo.safeAreaInsets.top)   // 고정 헤더 (챕터 색상 배경)

                    // 스테이지 목록 스크롤
                    ScrollView(showsIndicators: false) {
                        stageList
                            .padding(.top, 8)
                            .padding(.bottom, 48)
                    }
                }
                .ignoresSafeArea(edges: .top)    // 헤더가 status bar 영역까지 확장
            }
        }
        .hideNavigationBar()  // iOS 전용 API 래퍼 (macOS no-op)
        .background(Color.appBackground.ignoresSafeArea())
        // 잠긴 스테이지 탭 시 해금 조건 팝업 (표시 패턴은 공용 모디파이어)
        .lockInfoPopup($lockInfo)
        // 이미 클리어한 스테이지 탭 시 재도전 확인 팝업 (잠금 안내와 동일한 커스텀 카드 스타일 — 시스템 기본 Alert 미사용)
        .retryConfirmPopup($retryConfirmInfo)
    }

    // MARK: - 챕터 헤더 (컬러 배경)

    /// 챕터 색상 배경과 제목, 별 진행도를 표시하는 헤더
    /// - Parameter safeAreaTop: 상단 safe area 높이 (body의 GeometryReader에서 전달 — macOS에선 0)
    private func chapterHeader(safeAreaTop: CGFloat) -> some View {
        let depth: CGFloat = 5  // 3D 효과 깊이
        // 하단 모서리만 둥근 모양
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: 28,
            bottomTrailingRadius: 28, topTrailingRadius: 0
        )

        return VStack(alignment: .leading, spacing: 0) {

            // status bar 공간 확보 (ignoresSafeArea로 인해 수동 처리)
            Spacer().frame(height: safeAreaTop)

            // 뒤로가기 버튼
            Button {
                            SoundService.shared.play(.buttonTap)
                            if !navPath.isEmpty { navPath.removeLast() }
                        } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                    Text("CHAPTER \(String(format: "%02d", vm.chapter))")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)  // 자간 넓게
                }
                .foregroundStyle(Color.primary.opacity(0.55))
            }
            .buttonStyle(.plain)
            .padding(.top, 16)

            // 챕터 제목 (한국어)
            Text(vm.chapterTitle)
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 6)

            // 별 진행도 바 (개별 별 + 총계)
            starProgressBar
                .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32 + depth)   // depth만큼 여유 확보
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .top) {
                // 뒷면 — 어둡게, depth만큼 아래로 (3D 효과)
                shape.fill(chapterColor)
                    .overlay(shape.fill(Color.black.opacity(0.28)))
                    .padding(.top, depth)

                // 앞면 — depth만큼 짧게 (뒷면이 아래로 보이게)
                shape.fill(chapterColor)
                    .padding(.bottom, depth)
            }
        }
    }

    // MARK: - 와이드(아이폰 가로모드) 챕터 카드 헤더
    // 맥 ChapterBrowsePane·아이패드 IPadChapterBrowsePane의 chapterColorHeader와 동일한
    // "작은 둥근 카드 + 앞/뒤 2겹 depth" 스타일 — 세로모드 chapterHeader(풀블리드 배너)와는 별개

    private var wideChapterHeaderCard: some View {
        let depth: CGFloat = 5
        let total = vm.totalStars()
        let maxStar = vm.stages.count * 3

        return VStack(alignment: .leading, spacing: 6) {
            Text("CHAPTER \(String(format: "%02d", vm.chapter))")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.7)).tracking(1)
            Text(vm.chapterTitle).font(.system(size: 24, weight: .bold)).foregroundStyle(.white)

            HStack(alignment: .top, spacing: 8) {
                // 별이 많은 챕터는 한 줄에 다 안 들어가므로 자동으로 다음 줄로 감싸는 레이아웃 사용
                chapterWrappingStarRow(earned: total, total: maxStar, size: 9, spacing: 2, lineSpacing: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(total) / \(maxStar)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("stars")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .fixedSize()
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16 + depth)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .top) {
                // 뒷면 — 어둡게, depth만큼 아래로 (3D 효과, 맥/아이패드와 동일 기법)
                RoundedRectangle(cornerRadius: 16).fill(chapterColor)
                    .overlay(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.28)))
                    .padding(.top, depth)
                // 앞면 — depth만큼 짧게 (뒷면이 아래로 보이게)
                RoundedRectangle(cornerRadius: 16).fill(chapterColor)
                    .padding(.bottom, depth)
            }
        }
        .padding(.horizontal, 16)
    }

    /// 챕터 헤더용 별 행 — WrapLayout으로 감싸서 폭을 넘으면 다음 줄로 자동 배치
    /// (세로모드 starProgressBar·가로모드 wideChapterHeaderCard 공용, 맥 macWrappingStarRow·
    ///  아이패드 wrappingStarRow와 동일한 로직을 이 파일에 독립 구현)
    private func chapterWrappingStarRow(earned: Int, total: Int, size: CGFloat, spacing: CGFloat, lineSpacing: CGFloat) -> some View {
        ChapterWrapLayout(spacing: spacing, lineSpacing: lineSpacing) {
            ForEach(0..<total, id: \.self) { i in
                Image(systemName: i < earned ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i < earned ? Color.starGold : Color.primary.opacity(0.20))
            }
        }
    }

    // MARK: - 별 진행도 바

    /// 챕터 전체 별 획득 현황을 시각화하는 바 (개별 별 아이콘 + 숫자)
    private var starProgressBar: some View {
        let total  = vm.totalStars()       // 현재 획득 별
        let maxStar = vm.stages.count * 3  // 챕터 최대 별 수 (스테이지 수 × 3)

        return HStack(alignment: .top, spacing: 8) {
            // 별 아이콘 — 한 줄에 다 안 들어가면 다음 줄로 자동 감싸기
            // (예전엔 .clipped()로 넘치는 별을 그냥 잘라서 보여줬는데, 스테이지 수 많은 챕터에서
            // 오른쪽 별 몇 개가 통째로 안 보이는 문제가 있었음 — 와이드 카드 헤더와 동일한 방식으로 통일)
            chapterWrappingStarRow(earned: total, total: maxStar, size: 10, spacing: 2, lineSpacing: 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 숫자 요약 (X / Y stars) — .fixedSize()로 텍스트가 절대 압축되지 않음
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(total) / \(maxStar)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("stars")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.55))
            }
            .fixedSize()
        }
    }

    // MARK: - 스테이지 목록

    /// 모든 스테이지를 세로로 나열하는 리스트 (구분선 포함)
    private var stageList: some View {
        VStack(spacing: 0) {
            ForEach(vm.stages) { stage in
                stageRow(stage)

                // 구분선 (마지막 스테이지 제외)
                if stage.stageNumber < vm.stages.count {
                    Divider()
                        .padding(.leading, 76)   // 아이콘 너비 맞춤 들여쓰기
                        .padding(.trailing, 20)
                }
            }
        }
    }

    // MARK: - 스테이지 행

    /// 스테이지 하나를 표시하는 행 (아이콘 + 텍스트 + 별점 or "지금 여기")
    private func stageRow(_ stage: Stage) -> some View {
        let locked    = vm.isLocked(stage)
        let cleared   = vm.isCleared(stage)
        let earned    = vm.stars(stage)
        let isCurrent = vm.isCurrent(stage)  // 현재 진행 위치 여부

        return Button {
            if locked {
                // 잠긴 스테이지: 전용 잠금 사운드 + 해금 조건 팝업 표시
                SoundService.shared.play(.lockButton)
                withAnimation(.easeInOut(duration: 0.2)) {
                    lockInfo = LockInfo(
                        title: "아직 잠겨 있어요",
                        message: vm.lockMessage(for: stage),
                        accentColor: chapterColor
                    )
                }
            } else if cleared {
                // 클리어했으면 재도전 확인 팝업 표시 — "다시 하기" 선택 시 스테이지로 이동 후 팝업 닫기
                SoundService.shared.play(.buttonTap)
                withAnimation(.easeInOut(duration: 0.2)) {
                    retryConfirmInfo = RetryConfirmInfo(
                        title: "이미 클리어한 스테이지예요",
                        message: "\(stage.name) — 다시 도전하겠습니까?",
                        accentColor: chapterColor,
                        onRetry: {
                            navPath.append(AppRoute.stage(chapter: stage.chapter, number: stage.stageNumber))
                            withAnimation(.easeInOut(duration: 0.2)) { retryConfirmInfo = nil }
                        }
                    )
                }
            } else {
                SoundService.shared.play(.buttonTap)
                navPath.append(AppRoute.stage(chapter: stage.chapter, number: stage.stageNumber))
            }
        } label: {
            HStack(spacing: 16) {

                // 3D 스테이지 아이콘 (숫자 / 체크 / 자물쇠)
                stageIcon(number: stage.stageNumber,
                          locked: locked, cleared: cleared, isCurrent: isCurrent,
                          isPressed: pressedStageNumber == stage.stageNumber)

                // 스테이지 텍스트 정보
                VStack(alignment: .leading, spacing: 3) {
                    // "STAGE 01" 형식 서브타이틀
                    Text("STAGE \(String(format: "%02d", stage.stageNumber))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    // 스테이지 이름
                    Text(stage.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(locked ? .secondary : .primary)
                }

                Spacer()

                // 오른쪽 콘텐츠 — 현재 위치이면 "지금 여기", 아니면 별점
                if isCurrent {
                    Text("지금 여기")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                } else if !locked {
                    // 획득한 별 수에 따라 채워진 별 / 빈 별 표시
                    StarRatingView(earned: earned)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .opacity(locked ? 0.72 : 1.0)
        // 눌림 상태 추적
        .onPressState(isPressed: Binding(
            get: { pressedStageNumber == stage.stageNumber },
            set: { pressed in pressedStageNumber = pressed ? stage.stageNumber : nil }
        ))
    }

    // MARK: - 스테이지 아이콘 (챕터 버튼과 동일한 3D 구조)

    /// 스테이지 번호/상태를 표시하는 3D 아이콘
    private func stageIcon(number: Int, locked: Bool, cleared: Bool, isCurrent: Bool, isPressed: Bool = false) -> some View {
        // "지금 여기" 아이콘 앞면 — 라이트: darkInk와 동일 / 다크: 슬레이트 (다크 배경에 묻히지 않도록)
        let darkFace = Color.slateButtonFace

        let faceColor: Color = {
            if locked    { return Color.lockedBackground }
            if isCurrent { return darkFace }
            return chapterColor
        }()

        // 다크모드 여부 — 잠긴 아이콘 베벨 강도를 챕터 선택 화면의 잠긴 챕터 카드와 맞추는 데 사용
        let isDark = colorScheme == .dark

        let iconSize: CGFloat = 52
        let radius:   CGFloat = 18
        let topDepth: CGFloat = 1
        let botDepth: CGFloat = 2

        return ThreeDSurface(topDepth: topDepth, bottomDepth: botDepth, isPressed: isPressed) {
            // ① 위 뒷면
            // 잠긴 아이콘은 다크모드에서만 챕터 선택 화면 잠긴 카드와 동일한 0.18로 낮춤 (라이트는 기존 0.32 유지)
            ZStack {
                RoundedRectangle(cornerRadius: radius).fill(faceColor)
                RoundedRectangle(cornerRadius: radius)
                    .fill(Color.white.opacity((isCurrent || (locked && isDark)) ? 0.18 : 0.32))
            }
            .frame(width: iconSize, height: iconSize)
        } bottomBack: {
            // ② 아래 뒷면 — 진행 중(isCurrent)이면 단색, 아니면 faceColor + 그림자
            Group {
                if isCurrent {
                    // 라이트: 기존 탄색 유지 / 다크: 앞면(슬레이트)보다 약간 어두운 그림자 톤
                    // (slateButtonBottomBack 다크 값과 동일, Color.dynamic 크로스플랫폼 헬퍼 사용)
                    RoundedRectangle(cornerRadius: radius)
                        .fill(Color.dynamic(light: (195/255, 189/255, 172/255),
                                            dark: (56/255, 61/255, 76/255)))
                } else {
                    // 잠긴 아이콘은 다크모드에서만 챕터 선택 화면 잠긴 카드와 동일한 0.10으로 낮춤 (라이트는 기존 0.28 유지)
                    ZStack {
                        RoundedRectangle(cornerRadius: radius).fill(faceColor)
                        RoundedRectangle(cornerRadius: radius)
                            .fill(Color.black.opacity((locked && isDark) ? 0.10 : 0.28))
                    }
                }
            }
            .frame(width: iconSize, height: iconSize)
        } front: {
            // ③ 앞면 — faceColor + (눌림 시 그림자) + 상태 아이콘
            ZStack {
                RoundedRectangle(cornerRadius: radius).fill(faceColor)
                if isPressed {
                    RoundedRectangle(cornerRadius: radius).fill(Color.black.opacity(0.10))
                }
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.primary.opacity(0.55))
                } else if cleared {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .italic()
                        .foregroundStyle(.white)
                }
            }
            .frame(width: iconSize, height: iconSize)
        }
        .frame(width: iconSize, height: iconSize + topDepth + botDepth)
    }
}

// MARK: - ChapterWrapLayout
/// 자식 뷰를 가로로 채우다가 폭을 넘으면 다음 줄로 감싸는 간단한 flow 레이아웃
/// 세로모드 starProgressBar·가로모드 wideChapterHeaderCard 공용 (맥 WrapLayout·아이패드 IPadWrapLayout과 동일한 구현)
private struct ChapterWrapLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        y += lineHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var path = NavigationPath()
    ChapterView(navPath: $path, chapter: 1)
}
