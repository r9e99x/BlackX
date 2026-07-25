//
//  ChapterBrowsePane.swift
//  Blocode
//
//  Created by 조준희 on 7/16/26.
//

// macOS 전용 — MacContentShell에서 분리된 챕터 브라우저 (iOS/iPadOS는 컴파일 제외)
#if os(macOS)
import SwiftUI

// MARK: - ChapterBrowsePane
/// 챕터 브라우징 중 메인 사이드바 자리를 대체하는 3단 컬럼
/// 좌: 챕터 목록(메인 사이드바 폭·배경과 동일) / 중: 스테이지 목록(챕터색 헤더 포함) / 우: 스테이지 미리보기
struct ChapterBrowsePane: View {
    let chapterNumber: Int
    let onBackToMap: () -> Void
    let onSelectChapter: (Int) -> Void
    let onStart: (Int, Int) -> Void

    @StateObject private var vm: ChapterViewModel
    @StateObject private var chapterSelectVM = ChapterSelectViewModel()
    @State private var selectedStage: Int?
    @State private var lockInfo: LockInfo? = nil
    @State private var pressedStageNumber: Int? = nil

    init(chapterNumber: Int, onBackToMap: @escaping () -> Void,
         onSelectChapter: @escaping (Int) -> Void, onStart: @escaping (Int, Int) -> Void) {
        self.chapterNumber = chapterNumber
        self.onBackToMap = onBackToMap
        self.onSelectChapter = onSelectChapter
        self.onStart = onStart
        _vm = StateObject(wrappedValue: ChapterViewModel(chapter: chapterNumber))
    }

    private var chapterColor: Color {
        ChapterCatalog.chapter(chapterNumber)?.color ?? .accentColor
    }

    var body: some View {
        HStack(spacing: 0) {
            chapterListColumn
            Divider()
            stageListColumn
                .frame(width: 340)
            Divider()
            stagePreview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        // 잠긴 챕터/스테이지 탭 시 해금 조건 팝업 (표시 패턴은 공용 모디파이어)
        .lockInfoPopup($lockInfo)
        .onAppear {
            if selectedStage == nil {
                selectedStage = vm.currentStageNumber ?? 1
            }
        }
    }

    // MARK: 1열 — 챕터 목록 (메인 사이드바 자리를 대체 → 폭·배경을 사이드바와 통일)

    private var chapterListColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBackToMap) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("CHAPTERS").tracking(1)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(16)

            ForEach(chapterSelectVM.chapters) { chapter in
                let unlocked = chapterSelectVM.isUnlocked(chapter)
                Button {
                    guard unlocked else {
                        SoundService.shared.play(.lockButton)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            lockInfo = LockInfo(title: "아직 잠겨 있어요",
                                                message: chapterSelectVM.lockMessage(for: chapter),
                                                accentColor: chapter.color)
                        }
                        return
                    }
                    guard chapter.number != chapterNumber else { return }
                    SoundService.shared.play(.buttonTap)
                    onSelectChapter(chapter.number)
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(unlocked ? chapter.color : Color.lockedBackground)
                                .frame(width: 28, height: 28)
                            if unlocked {
                                Text("\(chapter.number)").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            } else {
                                Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(chapter.title).font(.system(size: 13, weight: .semibold))
                            if unlocked {
                                Text("\(chapterSelectVM.chapterStars(chapter)) / \(chapter.stageCount * 3) stars")
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(chapter.number == chapterNumber ? Color.appBackground : Color.clear)
            }
            Spacer()
        }
        .frame(width: 240)
        .background(Color.cardBackground)
    }

    // MARK: 2열 — 스테이지 목록 (챕터색 헤더 포함)

    private var stageListColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                chapterColorHeader

                ForEach(vm.stages) { stage in
                    let locked = vm.isLocked(stage)
                    let cleared = vm.isCleared(stage)
                    Button {
                        if locked {
                            SoundService.shared.play(.lockButton)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                lockInfo = LockInfo(title: "아직 잠겨 있어요",
                                                    message: vm.lockMessage(for: stage),
                                                    accentColor: chapterColor)
                            }
                        } else {
                            SoundService.shared.play(.buttonTap)
                            selectedStage = stage.stageNumber
                        }
                    } label: {
                        HStack(spacing: 14) {
                            stageIcon(stage: stage, locked: locked, cleared: cleared,
                                      isPressed: pressedStageNumber == stage.stageNumber)
                            Text(stage.name).font(.system(size: 14, weight: .medium))
                                .foregroundStyle(locked ? .secondary : .primary)
                            Spacer()
                            if !locked {
                                StarRatingView(earned: vm.stars(stage), size: 11)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .opacity(locked ? 0.72 : 1.0)
                    .onPressState(isPressed: Binding(
                        get: { pressedStageNumber == stage.stageNumber },
                        set: { pressed in pressedStageNumber = pressed ? stage.stageNumber : nil }
                    ))
                }
            }
        }
    }

    /// 스테이지 아이콘 — iOS ChapterView.stageIcon과 동일한 3D 3레이어 구조 + 눌림 효과
    private func stageIcon(stage: Stage, locked: Bool, cleared: Bool, isPressed: Bool) -> some View {
        let isCurrent = vm.isCurrent(stage)
        let faceColor: Color = locked ? Color.lockedBackground : (isCurrent ? Color.slateButtonFace : chapterColor)
        let iconSize: CGFloat = 36
        let radius: CGFloat = 12
        let topD: CGFloat = 1
        let botD: CGFloat = 2

        return ThreeDSurface(topDepth: topD, bottomDepth: botD, isPressed: isPressed) {
            ZStack {
                RoundedRectangle(cornerRadius: radius).fill(faceColor)
                RoundedRectangle(cornerRadius: radius).fill(Color.white.opacity(isCurrent ? 0.18 : 0.32))
            }
            .frame(width: iconSize, height: iconSize)
        } bottomBack: {
            ZStack {
                RoundedRectangle(cornerRadius: radius).fill(faceColor)
                RoundedRectangle(cornerRadius: radius).fill(Color.black.opacity(0.28))
            }
            .frame(width: iconSize, height: iconSize)
        } front: {
            ZStack {
                RoundedRectangle(cornerRadius: radius).fill(faceColor)
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 13)).foregroundStyle(Color.primary.opacity(0.55))
                } else if cleared {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(stage.stageNumber)").font(.system(size: 16, weight: .bold, design: .serif)).italic()
                        .foregroundStyle(.white)
                }
            }
            .frame(width: iconSize, height: iconSize)
        }
        .frame(width: iconSize, height: iconSize + topD + botD)
    }

    /// 챕터 색상 헤더 — iOS ChapterView.chapterHeader와 동일한 앞/뒤 2겹 depth 기법
    /// (별 아이콘 행 + "N / M stars" 숫자 텍스트까지 iOS의 starProgressBar와 동일하게 표시)
    private var chapterColorHeader: some View {
        let depth: CGFloat = 5
        let total = vm.totalStars()
        let maxStar = vm.stages.count * 3

        return VStack(alignment: .leading, spacing: 6) {
            Text("CHAPTER \(String(format: "%02d", chapterNumber))")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.7)).tracking(1)
            Text(vm.chapterTitle).font(.system(size: 24, weight: .bold)).foregroundStyle(.white)

            HStack(alignment: .top, spacing: 8) {
                // 별이 많은 챕터는 한 줄에 다 안 들어가므로 자동으로 다음 줄로 감싸는 레이아웃 사용
                // (헤더 가로 폭은 그대로, 넘치는 별만 두 번째 줄로 — StarRatingView는 단일 줄이라 여기선 미사용)
                macWrappingStarRow(earned: total, total: maxStar, size: 9, spacing: 2, lineSpacing: 4)
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
                // 뒷면 — 어둡게, depth만큼 아래로 (3D 효과, iOS와 동일 기법)
                RoundedRectangle(cornerRadius: 16).fill(chapterColor)
                    .overlay(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.28)))
                    .padding(.top, depth)
                // 앞면 — depth만큼 짧게 (뒷면이 아래로 보이게)
                RoundedRectangle(cornerRadius: 16).fill(chapterColor)
                    .padding(.bottom, depth)
            }
        }
        .padding(16)
    }

    /// 챕터 헤더용 별 행 — WrapLayout으로 감싸서 폭을 넘으면 다음 줄로 자동 배치
    /// (별 색상/아이콘 로직은 StarRatingView와 동일하게 유지, 컨테이너만 wrap 가능하도록 교체)
    private func macWrappingStarRow(earned: Int, total: Int, size: CGFloat, spacing: CGFloat, lineSpacing: CGFloat) -> some View {
        WrapLayout(spacing: spacing, lineSpacing: lineSpacing) {
            ForEach(0..<total, id: \.self) { i in
                Image(systemName: i < earned ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i < earned ? Color.starGold : Color.primary.opacity(0.20))
            }
        }
    }

    // MARK: 3열 — 스테이지 미리보기

    @State private var isStartPressed = false

    @ViewBuilder
    private var stagePreview: some View {
        if let stageNumber = selectedStage,
           let stage = vm.stages.first(where: { $0.stageNumber == stageNumber }) {
            let locked = vm.isLocked(stage)
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("STAGE \(chapterNumber)-\(stageNumber)")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(1)
                        Text(stage.name).font(.system(size: 22, weight: .bold))
                    }
                    Spacer()
                    StarRatingView(earned: vm.stars(stage), size: 13)
                }

                // 실제 게임 화면과 동일한 SpriteKit 맵 렌더링 재사용 (타일·캐릭터 완전히 동일하게 표시)
                // .id(stage.id)로 스테이지 전환 시 뷰를 확실히 새로 만들어 이전 맵이 남는 문제 방지
                // 바깥 VStack이 .leading 정렬이라 360pt로 제한된 맵이 왼쪽에 붙으므로, 남은 폭 안에서 가운데 정렬
                StagePreviewMapView(stage: stage)
                    .id(stage.id)
                    .aspectRatio(1.0, contentMode: .fit)
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 12) {
                    previewInfoCard(label: "★ 3 = \(stage.starThresholds.threeStar) blocks")
                    previewInfoCard(label: bestRecordLabel(stage: stage))
                }

                Spacer(minLength: 0)

                // 시작하기 버튼 — iOS 3D 버튼과 동일한 ThreeDSurface + 눌림 효과
                Button {
                    SoundService.shared.play(.buttonTap)
                    onStart(chapterNumber, stageNumber)
                } label: {
                    let frontH: CGFloat = 54
                    let topD: CGFloat = 0.8
                    let botD: CGFloat = 2.5
                    let cr: CGFloat = 16
                    ThreeDSurface(topDepth: topD, bottomDepth: botD, isPressed: isStartPressed) {
                        RoundedRectangle(cornerRadius: cr).fill(Color.slateButtonTopBack)
                            .frame(maxWidth: .infinity).frame(height: frontH)
                    } bottomBack: {
                        RoundedRectangle(cornerRadius: cr).fill(Color.slateButtonBottomBack)
                            .frame(maxWidth: .infinity).frame(height: frontH)
                    } front: {
                        ZStack {
                            RoundedRectangle(cornerRadius: cr)
                                .fill(locked ? Color.systemGray3Color : Color.slateButtonFace)
                            HStack {
                                Image(systemName: "play.fill")
                                Text(vm.isCleared(stage) ? "다시 도전" : "시작하기").fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity).frame(height: frontH)
                    }
                    .frame(maxWidth: .infinity).frame(height: frontH + topD + botD)
                }
                .buttonStyle(.plain)
                .onPressState(isPressed: $isStartPressed)
                .disabled(locked)
            }
            .padding(32)
        } else {
            Text("스테이지를 선택하세요")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 최고 기록 라벨 — 저장된 진행 기록이 있으면 최소 블럭 수, 없으면 "-"
    /// (데이터 조회는 ChapterViewModel에 위임 — 뷰가 ProgressService에 직접 접근하지 않음)
    private func bestRecordLabel(stage: Stage) -> String {
        let best = vm.bestBlockCount(stage)
        return "최고 기록: \(best > 0 ? "\(best)" : "-") blocks"
    }

    private func previewInfoCard(label: String) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.statCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - WrapLayout
/// 자식 뷰를 가로로 채우다가 폭을 넘으면 다음 줄로 감싸는 간단한 flow 레이아웃
/// 챕터 헤더의 별 아이콘 행 전용 — 별이 많은 챕터에서 헤더 밖으로 넘치는 문제 방지
private struct WrapLayout: Layout {
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
#endif
