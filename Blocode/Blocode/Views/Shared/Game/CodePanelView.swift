//
//  CodePanelView.swift
//  Blocode
//
//  Created by 조준희 on 5/10/26.
//

import SwiftUI

// MARK: - CodePanelView
/// 게임 화면 하단 코드 편집 패널
/// 코드 블럭 리스트 + 팔레트 + 컨트롤 바로 구성
///
/// 드래그 관련 상태(dragType, dragPosition, dragInsertIndex)는
/// StageView에서 Binding으로 받아 고스트 블럭 오버레이와 공유
struct CodePanelView: View {

    @ObservedObject var viewModel: GameViewModel  // 게임 상태 / 블럭 관리
    let stage: Stage                              // 별 기준 표시용

    // 드래그 상태 — StageView의 ghost block과 공유
    @Binding var dragType: BlockType?
    @Binding var dragPosition: CGPoint
    @Binding var dragInsertIndex: Int
    @Binding var codeListFrame: CGRect
    @Binding var rowMidYs: [Int: CGFloat]

    // 코드 리스트 내부 순서 변경(재정렬) 드래그 상태 — StageView의 reorder ghost와 공유
    @Binding var reorderIndex: Int?
    @Binding var reorderPosition: CGPoint
    @Binding var reorderTargetIndex: Int

    @Binding var navPath: NavigationPath      // 컨트롤 바 설정 초기화 시 홈 복귀용
    @Binding var isPanelExpanded: Bool        // 패널 확장/최소화 — StageView와 공유 (stageInfoBar·맵 크기와 연동)

    /// true면 확장/축소 토글 자체를 없애고 코드 리스트를 항상 펼친 상태로 고정
    /// (아이폰 가로모드 wideGameLayout 전용 — 이미 좌우 분할로 공간이 넉넉해 축소 기능이 필요 없음)
    var alwaysExpanded: Bool = false

    // MARK: - Body

    var body: some View {
        #if os(macOS)
        macOSBody
        #else
        iOSBody
        #endif
    }

    /// iOS/iPadOS 배치 — 코드 카드(핸들+확장·축소) → 팔레트 → 컨트롤 바 (기존 그대로)
    private var iOSBody: some View {
        VStack(spacing: 0) {

            // ── 패널 카드 (핸들 + 코드 리스트) ──
            VStack(spacing: 0) {

                // 드래그 핸들 — 탭으로 패널 확장/최소화 토글 (항상 펼침 모드에선 토글 자체가 없으니 숨김)
                if !alwaysExpanded {
                    dragHandle
                }

                if alwaysExpanded || isPanelExpanded {
                    // ─── 확장 상태: 코드 리스트 헤더 + 리스트 ───
                    codeListHeader
                    codeBlockList
                    Spacer(minLength: 8)
                } else {
                    // ─── 최소화 상태: 가로 칩 요약 + 남은 공간을 흡수하는 Spacer ───
                    // 예전엔 이 공간을 StageView의 외부 Spacer가 흡수해서 맵과 카드 사이에
                    // 빈 배경만 보였는데, 이제 카드 내부에서 흡수하므로 카드 자체가 팔레트
                    // 바로 위까지 자연스럽게 늘어나 보임(맵-카드 사이 빈 공간 제거)
                    Group {
                        collapsedChipRow
                            .padding(.bottom, 6)
                        Spacer(minLength: 0)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .background(Color.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
            .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 2)
            .animation(.spring(duration: 0.3), value: isPanelExpanded)

            // ── 팔레트 (카드 밖, 앱 배경에 직접) ──
            paletteView
                // 실행 중에는 팔레트 비활성화 + 흐리게
                .allowsHitTesting(viewModel.gameState != .running)
                .opacity(viewModel.gameState == .running ? 0.4 : 1.0)
                .padding(.top, 8)

            // 컨트롤 바
            ControlBarView(viewModel: viewModel, navPath: $navPath)
                .padding(.top, 6)
                .padding(.bottom, 24)
        }
    }

    #if os(macOS)
    /// 맥 전용 배치 — 팔레트를 코드 영역 위에 배치하고, 확장/축소 토글 없이 코드 리스트가 남은 세로 공간을 전부 사용
    private var macOSBody: some View {
        VStack(spacing: 10) {

            // ── 팔레트 (코드 영역 위) ──
            paletteView
                .allowsHitTesting(viewModel.gameState != .running)
                .opacity(viewModel.gameState == .running ? 0.4 : 1.0)

            // ── 코드 리스트 (확장/축소 토글 없이 항상 펼침, 남은 세로 공간 전부 사용) ──
            // 되돌리기/실행/설정은 StageView 상단바(별점 옆)로 이동했으므로 여기선 ControlBarView 미사용
            VStack(spacing: 0) {
                codeListHeader
                codeBlockList
            }
            .background(Color.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
    #endif

    /// 블럭 팔레트 — 스테이지별 허용 블럭만 표시 / 탭 추가 / 드래그 삽입 지원 (플랫폼 공용)
    private var paletteView: some View {
        PaletteView(
            availableBlocks: viewModel.availableBlocks,
            onSelect: { type in
                // 탭: 코드 리스트 맨 뒤에 추가
                viewModel.addBlock(type)
            },
            onDragStart: { type, pt in
                // 드래그 시작: idle 상태일 때만 허용
                guard viewModel.gameState == .idle else { return }
                withAnimation(.spring(duration: 0.2)) {
                    dragType = type
                    dragPosition = pt
                    dragInsertIndex = calculateInsertIndex(for: pt.y)
                }
            },
            onDragChange: { _, pt in
                // 드래그 중: 위치와 삽입 인덱스 갱신
                dragPosition = pt
                dragInsertIndex = calculateInsertIndex(for: pt.y)
            },
            onDragEnd: { type, location in
                // 코드 리스트 영역 안에서 손을 뗐을 때만 삽입 (영역 밖이면 취소)
                if codeListFrame.contains(location) {
                    withAnimation(.spring(duration: 0.2)) {
                        viewModel.insertBlock(type, at: dragInsertIndex)
                    }
                }
                withAnimation(.spring(duration: 0.2)) {
                    dragType = nil  // 고스트 블럭 제거 (삽입했든 취소했든)
                }
            }
        )
    }

    // MARK: - 드래그 핸들 (확장/최소화 토글)

    private var dragHandle: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                isPanelExpanded.toggle()
            }
        } label: {
            // 확장 상태: 아래 화살표 / 최소화 상태: 위 화살표
            Image(systemName: isPanelExpanded ? "chevron.down" : "chevron.up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.28))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 코드 리스트 헤더

    /// "CODE" 레이블 + 현재 블럭 수 뱃지 + 별 3개 기준
    private var codeListHeader: some View {
        HStack {
            // "CODE" 레이블
            Text("CODE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            // 현재 총 블럭 수 캡슐 뱃지
            Text("\(viewModel.totalBlockCount)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.tertiaryBackground)
                .clipShape(Capsule())

            Spacer()

            // 별 3개 기준 블럭 수 표시
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.starGold)
                Text("3 = \(stage.starThresholds.threeStar) blocks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    // MARK: - 코드 블럭 리스트

    /// 사용자가 추가한 코드 블럭을 세로 리스트로 표시
    private var codeBlockList: some View {
        Group {
            if viewModel.codeBlocks.isEmpty {
                Group {
                    // 드래그 중 코드 영역 안이면 "여기에 놓기" 드롭존, 평소엔 안내 메시지
                    if let dragType, codeListFrame.contains(dragPosition) {
                        // 드롭존 — 점선 박스 + 블럭 색 (블럭이 없으니 삽입선 대신 영역 강조)
                        RoundedRectangle(cornerRadius: 14)
                            .fill(dragType.blockColor.opacity(0.10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(dragType.blockColor,
                                                  style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                            }
                            .overlay {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    Text("여기에 놓기")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(dragType.blockColor)
                            }
                            .padding(.horizontal, 16)
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "plus.square.dashed")
                                .font(.system(size: 26))
                                .foregroundStyle(Color.tertiaryLabelColor)
                            Text("아래 팔레트에서 블럭을 추가하세요")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
            } else {
                // 순서 변경 중인 블럭의 색상 — 재정렬 삽입 인디케이터 표시용
                let reorderColor = reorderIndex.flatMap { viewModel.codeBlocks.indices.contains($0) ? viewModel.codeBlocks[$0].type.blockColor : nil }

                // List의 onMove 기본 재정렬은 시스템 흰 카드 고스트가 앱의 3D 블럭 스타일과 안 맞아서
                // ScrollView+LazyVStack과 커스텀 드래그(BlockRowView.onReorderDrag*)로 교체 —
                // 팔레트 삽입 드래그와 동일한 ghost 오버레이 방식(StageView.reorderGhost)을 그대로 재사용
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(viewModel.codeBlocks.enumerated()), id: \.element.id) { offset, block in
                            // 삽입 인디케이터 — 첫 번째 위치 (팔레트 삽입 / 순서 변경 공용)
                            if let dragType, codeListFrame.contains(dragPosition), dragInsertIndex == 0 && offset == 0 {
                                insertionIndicator(color: dragType.blockColor)
                            }
                            if let reorderColor, codeListFrame.contains(reorderPosition), reorderTargetIndex == 0 && offset == 0 {
                                insertionIndicator(color: reorderColor)
                            }

                            // 블럭 행 뷰
                            BlockRowView(
                                block: block,
                                index: offset,
                                // 실행 중이고 현재 경로의 최상위 인덱스와 일치하면 활성 표시
                                // (자식/손자 실행 중에도 부모 행 하이라이트 유지)
                                isActive: viewModel.currentBlockPath?.first == offset && viewModel.gameState == .running,
                                isFailed: viewModel.failedBlockPath?.first == offset,
                                // 이 행 내부에서 실행 중인 자식의 상대 경로 — [자식] 또는 [자식, 손자]
                                // (다른 행이 실행 중이면 빈 배열 → 자식 하이라이트 없음)
                                activeChildPath: (viewModel.gameState == .running && viewModel.currentBlockPath?.first == offset)
                                    ? Array((viewModel.currentBlockPath ?? []).dropFirst()) : [],
                                // 이 행 내부에서 실패한 자식의 상대 경로 (형식 동일)
                                failedChildPath: viewModel.failedBlockPath?.first == offset
                                    ? Array((viewModel.failedBlockPath ?? []).dropFirst()) : [],
                                onDelete: { viewModel.removeBlock(at: offset) },
                                onAddChild: { childType in
                                    viewModel.addChildBlock(childType, to: offset)
                                },
                                onRemoveChild: { childIndex in
                                    viewModel.removeChildBlock(at: childIndex, from: offset)
                                },
                                onRepeatCountChange: { count in
                                    viewModel.setRepeatCount(count, at: offset)
                                },
                                onIfConditionChange: { condition in
                                    viewModel.setIfCondition(condition, at: offset)
                                },
                                onAddGrandchild: { type, childIndex in
                                    viewModel.addGrandchildBlock(type, parentIndex: offset, childIndex: childIndex)
                                },
                                onRemoveGrandchild: { gcIdx, childIndex in
                                    viewModel.removeGrandchildBlock(grandchildIndex: gcIdx, parentIndex: offset, childIndex: childIndex)
                                },
                                onSetChildIfCondition: { condition, childIndex in
                                    viewModel.setChildIfCondition(condition, parentIndex: offset, childIndex: childIndex)
                                },
                                onSetChildRepeatCount: { count, childIndex in
                                    viewModel.setChildRepeatCount(count, parentIndex: offset, childIndex: childIndex)
                                },
                                onAddGreatGrandchild: { type, childIndex, gcIdx in
                                    viewModel.addGreatGrandchildBlock(type, parentIndex: offset, childIndex: childIndex, grandchildIndex: gcIdx)
                                },
                                onRemoveGreatGrandchild: { ggcIdx, childIndex, gcIdx in
                                    viewModel.removeGreatGrandchildBlock(greatGrandchildIndex: ggcIdx, parentIndex: offset, childIndex: childIndex, grandchildIndex: gcIdx)
                                },
                                onSetGrandchildIfCondition: { condition, childIndex, gcIdx in
                                    viewModel.setGrandchildIfCondition(condition, parentIndex: offset, childIndex: childIndex, grandchildIndex: gcIdx)
                                },
                                onSetGrandchildRepeatCount: { count, childIndex, gcIdx in
                                    viewModel.setGrandchildRepeatCount(count, parentIndex: offset, childIndex: childIndex, grandchildIndex: gcIdx)
                                },
                                onReorderDragStart: { pt in
                                    guard viewModel.gameState == .idle else { return }
                                    withAnimation(.spring(duration: 0.2)) {
                                        reorderIndex = offset
                                        reorderPosition = pt
                                        reorderTargetIndex = calculateInsertIndex(for: pt.y)
                                    }
                                },
                                onReorderDragChange: { pt in
                                    reorderPosition = pt
                                    reorderTargetIndex = calculateInsertIndex(for: pt.y)
                                },
                                onReorderDragEnd: { location in
                                    // 코드 리스트 영역 안에서 손을 뗐을 때만 순서 변경 (영역 밖이면 취소)
                                    if let source = reorderIndex, codeListFrame.contains(location) {
                                        withAnimation(.spring(duration: 0.2)) {
                                            viewModel.moveBlock(from: IndexSet(integer: source), to: reorderTargetIndex)
                                        }
                                    }
                                    withAnimation(.spring(duration: 0.2)) {
                                        reorderIndex = nil  // 고스트 제거 (이동했든 취소했든)
                                    }
                                }
                            )
                            .padding(.horizontal, 12)
                            // 각 행의 중간 Y 좌표를 preference로 보고 (드래그 인덱스 계산용)
                            .background(GeometryReader { geo in
                                Color.clear.preference(
                                    key: RowMidYKey.self,
                                    value: [offset: geo.frame(in: .global).midY]
                                )
                            })

                            // 삽입 인디케이터 — 현재 블럭 다음 위치 (팔레트 삽입 / 순서 변경 공용)
                            if let dragType, codeListFrame.contains(dragPosition), dragInsertIndex == offset + 1 {
                                insertionIndicator(color: dragType.blockColor)
                            }
                            if let reorderColor, codeListFrame.contains(reorderPosition), reorderTargetIndex == offset + 1 {
                                insertionIndicator(color: reorderColor)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        // 이 뷰가 렌더링되는 시점은 항상 isPanelExpanded == true(그 외엔 collapsedChipRow가 대신 표시됨)라,
        // 플랫폼/화면 폭 구분 없이 항상 남은 세로 공간을 전부 사용 — 아이폰은 StageView가 확장 시 맵을 줄여서
        // 이 공간을 만들어줌(예전엔 고정 160pt라 블럭이 많아지면 좁은 창 안에서만 스크롤됐음)
        .frame(maxHeight: .infinity)
        // 코드 리스트 글로벌 프레임 추적 (드래그 감지용)
        // size가 아닌 frame(위치+크기) 변화를 추적 — 빈 상태에선 size가 안 바뀌어
        // 좌표 갱신이 누락돼 영역 판정이 어긋났음(빈 영역 드래그 추가 불가)
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { codeListFrame = geo.frame(in: .global) }
                .onChange(of: geo.frame(in: .global)) { codeListFrame = geo.frame(in: .global) }
        })
    }

    // MARK: - 최소화 상태 칩 요약 뷰

    /// 패널 최소화 시 블럭들을 작은 칩 형태로 가로 스크롤로 표시
    private var collapsedChipRow: some View {
        HStack(spacing: 0) {
            // 가로 스크롤 칩 행
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if viewModel.codeBlocks.isEmpty {
                        // 블럭 없음 안내
                        Text("블럭 없음")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    } else {
                        // 각 블럭을 작은 칩으로 표시
                        ForEach(Array(viewModel.codeBlocks.enumerated()), id: \.element.id) { _, block in
                            blockChip(block)
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.leading, 16)
            }

            // 블럭 수 뱃지 — 스크롤 영역 오른쪽에 고정
            HStack(spacing: 4) {
                Text("\(viewModel.totalBlockCount)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.tertiaryBackground)
                    .clipShape(Capsule())
                Text("blocks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 8)
            .padding(.trailing, 16)
        }
        .frame(height: 36)
    }

    /// 블럭 하나를 작은 캡슐 칩으로 표시 — 아이콘 (+ repeat 횟수)
    private func blockChip(_ block: Block) -> some View {
        HStack(spacing: 3) {
            Image(systemName: block.type.shortIconName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
            // repeat 블럭은 반복 횟수도 표시
            if block.type == .repeatBlock {
                Text("×\(block.repeatCount ?? 2)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(block.type.blockColor)
        .clipShape(Capsule())
    }

    // MARK: - 삽입 인디케이터

    /// 드래그 중 삽입 위치를 표시하는 가로 선 + 도트
    private func insertionIndicator(color: Color) -> some View {
        HStack(spacing: 0) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(color)
                .frame(height: 2)
        }
        .padding(.horizontal, 12)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.15), value: dragInsertIndex)
    }

    // MARK: - 드래그 삽입 인덱스 계산

    /// 드래그 Y 좌표를 기반으로 삽입될 인덱스 계산
    private func calculateInsertIndex(for globalY: CGFloat) -> Int {
        if rowMidYs.isEmpty { return 0 }
        // 인덱스 오름차순으로 정렬
        let sorted = rowMidYs.sorted { $0.key < $1.key }
        // 드래그 위치가 행 중간 Y보다 위면 해당 행 앞에 삽입
        for (i, entry) in sorted.enumerated() {
            if globalY < entry.value { return i }
        }
        // 모든 행보다 아래면 맨 뒤에 삽입
        return sorted.count
    }
}
