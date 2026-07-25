//
//  GameViewModel.swift
//  Blocode
//
//  Created by 조준희 on 5/10/26.
//

import Foundation
import SwiftUI   // codeBlocks.move(fromOffsets:toOffset:)가 SwiftUI 확장이라 필요
import Combine

// MARK: - GameState
/// 게임의 현재 상태 — 뷰에서 상태에 따라 UI 분기 처리
enum GameState {
    case idle       // 대기 중 (블럭 편집 가능)
    case running    // 실행 중 (블럭 순서대로 캐릭터 이동 중)
    case success    // 클리어 성공
    case failure    // 실패 (벽 충돌 등)
}

// MARK: - GameViewModel
/// 게임 상태, 코드 블럭 목록, 실행 로직을 관리하는 ViewModel
/// View ↔ GameScene 사이의 중간 역할
/// @MainActor: 모든 상태·실행 로직이 항상 메인 스레드에서만 처리됨을 보장
/// (수동 MainActor.run/DispatchQueue 디스패치 없이 @Published 접근이 안전해짐)
@MainActor
final class GameViewModel: ObservableObject {

    // MARK: - Published 프로퍼티 (View에서 감지)

    /// 현재 게임 상태 — 상태 변경 시 UI 자동 갱신
    @Published var gameState: GameState = .idle

    /// 사용자가 추가한 코드 블럭 목록 (순서대로 실행)
    @Published var codeBlocks: [Block] = []

    /// 현재 실행 중인 블럭 경로 (하이라이트용) — nil이면 하이라이트 없음
    /// 경로 형식: [최상위 인덱스], [최상위, 자식], [최상위, 자식, 손자]
    /// (단일 Int는 중첩 블럭 실행 시 최상위 인덱스 공간과 충돌하므로 경로로 추적)
    @Published var currentBlockPath: [Int]? = nil

    /// 실패한 블럭 경로 (빨간 하이라이트용) — nil이면 표시 안 함 (형식은 currentBlockPath와 동일)
    @Published var failedBlockPath: [Int]? = nil

    /// 실패 이유 메시지 — 토스트 배너에 표시
    @Published var failureMessage: String = ""

    /// 클리어 시 획득한 별 수 — ClearOverlayView에 전달
    @Published var clearedStars: Int = 0

    /// 클리어 시 걸린 시간 (초) — 타이머로 측정
    @Published var elapsedTime: TimeInterval = 0

    /// 도전 횟수 — run() 호출 시마다 증가
    @Published var attemptCount: Int = 0

    /// 캐릭터가 시작 위치에서 벗어났는지 (리셋 버튼 아이콘 결정용)
    @Published var characterMoved: Bool = false

    /// 수집한 보석 위치 집합 (기믹 스테이지 전용) — 상단바 보석 카운터 표시 + 별점 계산에 사용
    /// (기믹 없는 스테이지는 stage.mapData.items가 nil이라 항상 빈 상태로 아무 영향 없음)
    @Published var collectedItems: Set<Position> = []

    // MARK: - 내부 상태

    /// 현재 스테이지 데이터 — 별점 기준, 맵 정보 포함
    private(set) var stage: Stage

    /// 스테이지 로딩 실패 여부 — true이면 View가 폴백 UI를 표시
    /// (init에서 한 번만 결정되며 이후 변하지 않음)
    let loadFailed: Bool

    /// GameScene 참조 (캐릭터 이동 명령용) — weak으로 순환 참조 방지
    weak var scene: GameScene?

    /// 열린 문 위치 집합 (기믹 스테이지 전용, 내부 판정용) — 이동 가능 여부 계산에만 쓰이고 UI에 직접 노출 안 됨
    private var openedGates: Set<Position> = []

    /// 실행 속도 배율 — SettingsService에서 실시간으로 읽어옴
    private var executionSpeed: Double { SettingsService.shared.executionSpeed }

    /// 실행 시간 측정 타이머
    private var timer: Timer?
    /// 타이머 시작 시각
    private var startTime: Date?

    // MARK: - 초기화

    /// 스테이지 데이터로 ViewModel 초기화 (프리뷰/테스트용 — 직접 주입)
    init(stage: Stage) {
        self.stage = stage
        self.loadFailed = false
    }

    /// 챕터/스테이지 번호로 ViewModel 초기화 (프로덕션)
    /// 데이터 소스(StageLoader) 접근은 View가 아닌 ViewModel의 책임
    init(chapter: Int, stageNumber: Int) {
        if let loaded = StageLoader.load(chapter: chapter, stage: stageNumber) {
            self.stage = loaded
            self.loadFailed = false
        } else {
            // 로딩 실패 — 타입 불변식(비옵셔널 Stage) 유지를 위한 안전 플레이스홀더
            // (실제로는 View가 loadFailed를 보고 폴백 UI를 띄우므로 사용되지 않음)
            self.stage = Stage.placeholder(chapter: chapter, stageNumber: stageNumber)
            self.loadFailed = true
        }
    }

    /// 다음 스테이지 존재 여부 — 챕터 마지막 스테이지이면 false
    /// (데이터 접근은 StageLoader(Service)에 위임)
    var hasNextStage: Bool {
        StageLoader.load(chapter: stage.chapter, stage: stage.stageNumber + 1) != nil
    }

    // MARK: - 블럭 관리

    /// 팔레트에서 블럭 추가 — idle 상태일 때만 허용
    func addBlock(_ type: BlockType) {
        guard gameState == .idle else { return }
        let block = Block(type: type)
        codeBlocks.append(block)
        SoundService.shared.play(.blockAdd)
    }

    /// 특정 인덱스의 블럭 삭제 — idle 상태이고 유효한 인덱스일 때만 허용
    func removeBlock(at index: Int) {
        guard gameState == .idle,
              codeBlocks.indices.contains(index) else { return }
        codeBlocks.remove(at: index)
    }

    /// 블럭 순서 변경 (드래그 앤 드롭) — idle 상태일 때만 허용
    func moveBlock(from source: IndexSet, to destination: Int) {
        guard gameState == .idle else { return }
        codeBlocks.move(fromOffsets: source, toOffset: destination)
        SoundService.shared.play(.blockReorder)
    }

    /// 컨테이너 블럭(repeat / if / function)에 자식 블럭 추가
    func addChildBlock(_ type: BlockType, to parentIndex: Int) {
        guard gameState == .idle,
              codeBlocks.indices.contains(parentIndex),
              codeBlocks[parentIndex].hasChildren else { return }  // repeat·if·function 모두 허용
        let child = Block(type: type)
        codeBlocks[parentIndex].children?.append(child)
    }

    /// 컨테이너 블럭(repeat / if / function)의 자식 블럭 삭제
    func removeChildBlock(at childIndex: Int, from parentIndex: Int) {
        guard gameState == .idle,
              codeBlocks.indices.contains(parentIndex),
              codeBlocks[parentIndex].hasChildren,  // repeat·if·function 모두 허용
              let children = codeBlocks[parentIndex].children,
              children.indices.contains(childIndex) else { return }
        codeBlocks[parentIndex].children?.remove(at: childIndex)
    }

    /// if 블럭의 조건(pathClear / pathBlocked) 변경
    func setIfCondition(_ condition: IfCondition, at index: Int) {
        guard gameState == .idle,
              codeBlocks.indices.contains(index),
              codeBlocks[index].type == .ifBlock else { return }
        codeBlocks[index].ifCondition = condition
    }

    // MARK: - 중첩 블럭 관리 (컨테이너 블럭의 자식 컨테이너 조작)

    /// 자식 컨테이너(repeat/if)에 손자 블럭 추가
    func addGrandchildBlock(_ type: BlockType, parentIndex: Int, childIndex: Int) {
        guard gameState == .idle,
              codeBlocks.indices.contains(parentIndex),
              let children = codeBlocks[parentIndex].children,
              children.indices.contains(childIndex),
              children[childIndex].hasChildren else { return }
        codeBlocks[parentIndex].children?[childIndex].children?.append(Block(type: type))
    }

    /// 자식 컨테이너(repeat/if)에서 손자 블럭 삭제
    func removeGrandchildBlock(grandchildIndex: Int, parentIndex: Int, childIndex: Int) {
        guard gameState == .idle,
              codeBlocks.indices.contains(parentIndex),
              let children = codeBlocks[parentIndex].children,
              children.indices.contains(childIndex),
              let grandchildren = children[childIndex].children,
              grandchildren.indices.contains(grandchildIndex) else { return }
        codeBlocks[parentIndex].children?[childIndex].children?.remove(at: grandchildIndex)
    }

    /// 자식 if 블럭의 조건 변경
    func setChildIfCondition(_ condition: IfCondition, parentIndex: Int, childIndex: Int) {
        guard gameState == .idle,
              codeBlocks.indices.contains(parentIndex),
              let children = codeBlocks[parentIndex].children,
              children.indices.contains(childIndex),
              children[childIndex].type == .ifBlock else { return }
        codeBlocks[parentIndex].children?[childIndex].ifCondition = condition
    }

    /// 자식 repeat 블럭의 반복 횟수 변경
    func setChildRepeatCount(_ count: Int, parentIndex: Int, childIndex: Int) {
        guard gameState == .idle,
              codeBlocks.indices.contains(parentIndex),
              let children = codeBlocks[parentIndex].children,
              children.indices.contains(childIndex),
              children[childIndex].type == .repeatBlock else { return }
        codeBlocks[parentIndex].children?[childIndex].repeatCount = max(1, min(10, count))
    }

    // MARK: - 3단 중첩 블럭 관리 (손자 컨테이너의 자식 = 증손자 조작)

    /// 손자 컨테이너(repeat/if)에 증손자 블럭 추가
    func addGreatGrandchildBlock(_ type: BlockType, parentIndex: Int, childIndex: Int, grandchildIndex: Int) {
        guard gameState == .idle,
              codeBlocks.indices.contains(parentIndex),
              let children = codeBlocks[parentIndex].children,
              children.indices.contains(childIndex),
              let grandchildren = children[childIndex].children,
              grandchildren.indices.contains(grandchildIndex),
              grandchildren[grandchildIndex].hasChildren else { return }
        codeBlocks[parentIndex].children?[childIndex].children?[grandchildIndex].children?.append(Block(type: type))
    }

    /// 손자 컨테이너(repeat/if)에서 증손자 블럭 삭제
    func removeGreatGrandchildBlock(greatGrandchildIndex: Int, parentIndex: Int, childIndex: Int, grandchildIndex: Int) {
        guard gameState == .idle,
              codeBlocks.indices.contains(parentIndex),
              let children = codeBlocks[parentIndex].children,
              children.indices.contains(childIndex),
              let grandchildren = children[childIndex].children,
              grandchildren.indices.contains(grandchildIndex),
              let greatGrandchildren = grandchildren[grandchildIndex].children,
              greatGrandchildren.indices.contains(greatGrandchildIndex) else { return }
        codeBlocks[parentIndex].children?[childIndex].children?[grandchildIndex].children?.remove(at: greatGrandchildIndex)
    }

    /// 손자 if 블럭의 조건 변경
    func setGrandchildIfCondition(_ condition: IfCondition, parentIndex: Int, childIndex: Int, grandchildIndex: Int) {
        guard gameState == .idle,
              codeBlocks.indices.contains(parentIndex),
              let children = codeBlocks[parentIndex].children,
              children.indices.contains(childIndex),
              let grandchildren = children[childIndex].children,
              grandchildren.indices.contains(grandchildIndex),
              grandchildren[grandchildIndex].type == .ifBlock else { return }
        codeBlocks[parentIndex].children?[childIndex].children?[grandchildIndex].ifCondition = condition
    }

    /// 손자 repeat 블럭의 반복 횟수 변경
    func setGrandchildRepeatCount(_ count: Int, parentIndex: Int, childIndex: Int, grandchildIndex: Int) {
        guard gameState == .idle,
              codeBlocks.indices.contains(parentIndex),
              let children = codeBlocks[parentIndex].children,
              children.indices.contains(childIndex),
              let grandchildren = children[childIndex].children,
              grandchildren.indices.contains(grandchildIndex),
              grandchildren[grandchildIndex].type == .repeatBlock else { return }
        codeBlocks[parentIndex].children?[childIndex].children?[grandchildIndex].repeatCount = max(1, min(10, count))
    }

    /// 특정 위치에 블럭 삽입 (팔레트 드래그-앤-드롭 위치 지정 삽입)
    func insertBlock(_ type: BlockType, at index: Int) {
        guard gameState == .idle else { return }
        let block = Block(type: type)
        // 인덱스가 범위를 벗어나지 않도록 클램핑
        let safeIndex = min(max(0, index), codeBlocks.count)
        codeBlocks.insert(block, at: safeIndex)
        SoundService.shared.play(.blockAdd)
    }

    /// repeat 블럭의 반복 횟수 변경 (1~10회로 제한 — 자식/손자 조작 함수와 동일 규칙)
    func setRepeatCount(_ count: Int, at index: Int) {
        guard codeBlocks.indices.contains(index),
              codeBlocks[index].isRepeatBlock else { return }
        codeBlocks[index].repeatCount = max(1, min(10, count))
    }

    /// 현재 사용된 총 블럭 수 (별점 계산용) — flatCount로 repeat 내부 블럭 포함
    var totalBlockCount: Int {
        codeBlocks.reduce(0) { $0 + $1.flatCount }
    }

    // MARK: - 실행 제어

    /// 코드 블럭 실행 시작 — idle 상태이고 블럭이 있을 때만 동작
    func run() {
        guard gameState == .idle, !codeBlocks.isEmpty else { return }

        gameState = .running
        failedBlockPath = nil
        failureMessage = ""
        characterMoved = true   // 실행 시작 = 캐릭터 이동 시작
        attemptCount += 1       // 도전 횟수 증가
        startTimer()            // 클리어 시간 측정 시작

        // 블럭 순서대로 비동기 실행 → 완료 시 idle 복귀
        // (@MainActor 클래스라 Task도 메인에서 실행됨)
        Task {
            await executeBlocks(codeBlocks, parentPath: [])
            // 성공/실패 처리가 안 됐으면 (목표 미도달로 자연 종료) idle로 복귀
            if gameState == .running {
                gameState = .idle
                currentBlockPath = nil
                stopTimer()
            }
        }
    }

    /// 캐릭터만 리셋 — 블럭 목록은 유지
    func reset() {
        gameState = .idle
        stopTimer()
        currentBlockPath = nil
        failedBlockPath = nil
        failureMessage = ""
        characterMoved = false
        // 기믹 상태 초기화 (기믹 없는 스테이지는 항상 빈 상태라 무해)
        collectedItems = []
        openedGates = []
        // 캐릭터를 시작 위치로 되돌림 (기믹 스테이지는 씬이 보석 재등장·문 다시 닫힘까지 함께 복원)
        scene?.resetCharacter()
    }

    /// 전체 초기화 — 캐릭터 + 블럭 + 도전 횟수 모두 삭제
    func fullReset() {
        reset()
        codeBlocks = []    // 블럭 목록 초기화
        attemptCount = 0   // 도전 횟수 초기화
    }

    // MARK: - 블럭 실행 로직

    /// 블럭 배열을 순서대로 실행 (재귀 지원 — 컨테이너 블럭 처리)
    /// - Parameters:
    ///   - blocks: 실행할 블럭 배열
    ///   - parentPath: 부모 컨테이너까지의 경로 (최상위 호출은 빈 배열) — 하이라이트 경로 계산용
    private func executeBlocks(_ blocks: [Block], parentPath: [Int]) async {
        for (offset, block) in blocks.enumerated() {

            // 실행 중단됐으면 멈춤 (stop() 호출 등)
            guard gameState == .running else { return }

            // 현재 블럭의 경로 — 부모 경로에 자신의 인덱스를 추가
            // (최상위 인덱스 공간과 충돌하지 않는 경로 기반 식별)
            let path = parentPath + [offset]

            // 현재 실행 중인 블럭 하이라이트 갱신 (경로 기반)
            currentBlockPath = path

            // 블럭 종류에 따라 실행
            switch block.type {
            case .moveForward:
                // 앞으로 이동 — 실패 시 실패 처리 후 종료
                let success = await moveCharacter(direction: .forward)
                if !success {
                    // 라인 번호는 사용자에게 보이는 최상위 행 번호(1-based) 기준
                    handleFailure(at: path, message: "벽에 부딪혔어요 · 라인 \(path[0] + 1)")
                    return
                }

            case .moveBackward:
                // 뒤로 이동 — 실패 시 실패 처리 후 종료
                let success = await moveCharacter(direction: .backward)
                if !success {
                    // 라인 번호는 사용자에게 보이는 최상위 행 번호(1-based) 기준
                    handleFailure(at: path, message: "벽에 부딪혔어요 · 라인 \(path[0] + 1)")
                    return
                }

            case .turnLeft:
                // 왼쪽으로 90도 회전
                await turnCharacter(left: true)

            case .turnRight:
                // 오른쪽으로 90도 회전
                await turnCharacter(left: false)

            case .repeatBlock:
                // repeat 블럭: 자식 블럭들을 repeatCount번 반복 실행
                let count = block.repeatCount ?? 1
                let children = block.children ?? []
                for _ in 0..<count {
                    guard gameState == .running else { return }
                    // 자식 블럭을 재귀적으로 실행 (자신의 경로를 부모 경로로 전달)
                    await executeBlocks(children, parentPath: path)
                }

            case .ifBlock:
                // if 블럭: 앞 칸 상태를 확인하고 조건이 참이면 자식 블럭 실행
                let condition = block.ifCondition ?? .pathClear
                let shouldExecute = checkIfCondition(condition)
                if shouldExecute {
                    let children = block.children ?? []
                    await executeBlocks(children, parentPath: path)
                }

            case .functionBlock:
                // function 블럭: 자식 블럭들을 서브루틴으로 실행
                // 추후 챕터4 UI에서 함수 정의-호출 분리 구조로 확장 예정
                let children = block.children ?? []
                await executeBlocks(children, parentPath: path)

            case .collectItem:
                // 보석 획득 — 현재 칸에 아직 안 모은 보석이 있을 때만 성공, 아니면 벽 부딪힘과 동일하게 실패
                if !collectItemAtCurrentPosition() {
                    handleFailure(at: path, message: "여기엔 보석이 없어요 · 라인 \(path[0] + 1)")
                    return
                }

            case .activateSwitch:
                // 스위치 작동 — 현재 칸에 스위치가 있을 때만 성공, 아니면 벽 부딪힘과 동일하게 실패
                if !activateSwitchAtCurrentPosition() {
                    handleFailure(at: path, message: "여기엔 스위치가 없어요 · 라인 \(path[0] + 1)")
                    return
                }
            }

            // 각 블럭 실행 후 목표 도달 여부 확인
            // 자식 재귀 안에서 이미 성공/실패 처리가 끝났으면 중복 처리하지 않도록 running일 때만 검사
            // (중첩 클리어 시 handleSuccess가 깊이만큼 반복 호출돼 recordClear가 중복 저장되던 문제 수정)
            guard gameState == .running else { return }
            if checkGoal() {
                handleSuccess()
                return
            }
        }
    }

    // MARK: - 팔레트 블럭 목록

    /// 현재 스테이지 팔레트에 표시할 블럭 타입 목록
    /// Stage.paletteBlocks를 래핑 — CodePanelView/PaletteView에서 사용
    var availableBlocks: [BlockType] {
        stage.paletteBlocks
    }

    // MARK: - 기믹 표시용 (StageView 상단바 보석 카운터 / ClearOverlayView 안내 문구)

    /// 보석을 다 못 모아서 별 3개를 놓쳤을 때만 안내 문구 반환 (기믹 없는 스테이지·전부 수집 시 nil)
    var itemHint: String? {
        guard let items = stage.mapData.items, !items.isEmpty,
              collectedItems.count < items.count else { return nil }
        return "보석 \(collectedItems.count)/\(items.count)개 — 전부 모으면 별 3개!"
    }

    // MARK: - 조건문 평가

    /// ifBlock 조건 평가: 앞 칸 이동 가능 여부를 확인 (GameScene 메인스레드 접근)
    /// - Parameter condition: 확인할 조건 타입 (pathClear / pathBlocked)
    /// - Returns: 조건이 참이면 true (자식 블럭 실행), 거짓이면 false (자식 블럭 스킵)
    private func checkIfCondition(_ condition: IfCondition) -> Bool {
        // @MainActor라 scene(메인 전용)에 직접 접근 가능 (별도 디스패치 불필요)
        guard let scene = scene else {
            // scene이 없으면 조건 판단 불가 → false 반환 (실행 안 함)
            return false
        }
        // 현재 방향 기준 한 칸 앞 위치 계산
        let nextPos = scene.characterPosition.next(direction: scene.characterDirection)
        let walkable = isWalkable(nextPos)
        switch condition {
        case .pathClear:   return walkable   // 뚫려있으면 실행
        case .pathBlocked: return !walkable  // 막혀있으면 실행
        }
    }

    // MARK: - 기믹 판정 (챕터 6+ 전용 — items/switches/portals가 없는 스테이지는 항상 기존과 동일하게 동작)

    /// 특정 좌표가 이동 가능한지 확인 — 바닥이거나, 열린 문이면 true
    /// (기믹 없는 스테이지는 openedGates가 항상 비어있어 기존 isFloor 판정과 완전히 동일)
    private func isWalkable(_ position: Position) -> Bool {
        guard let scene else { return false }
        if scene.mapData.isFloor(position) { return true }
        return openedGates.contains(position)
    }

    /// 이동 후 도착한 칸의 포탈 효과 적용 (자동 통과) — 보석 획득/스위치 작동은
    /// 자동이 아니라 전용 블럭(collectItem/activateSwitch) 실행 시에만 처리됨
    /// portals가 nil인 스테이지는 아래 블록이 조용히 스킵되므로 완전히 무해
    private func applyTileEffects(at position: Position) {
        guard let scene else { return }

        // 포탈 — 입장하면 짝으로 순간이동 (도착 칸에서는 재귀 적용 없이 1회만 이동)
        if let pair = scene.mapData.portals?.first(where: { $0.a == position || $0.b == position }) {
            let destination = pair.a == position ? pair.b : pair.a
            scene.teleportCharacter(to: destination)
            SoundService.shared.play(.portal)
        }
    }

    /// "보석 획득" 블럭 실행 — 캐릭터의 현재 위치에 아직 수집하지 않은 보석이 있을 때만 성공
    /// (한 번 수집한 칸에서 다시 실행하면 실패 — 보석은 1회성)
    private func collectItemAtCurrentPosition() -> Bool {
        guard let scene else { return false }
        let position = scene.characterPosition
        guard scene.mapData.items?.contains(position) == true,
              !collectedItems.contains(position) else {
            return false
        }
        collectedItems.insert(position)
        scene.collectItem(at: position)
        SoundService.shared.play(.itemCollect)
        return true
    }

    /// "스위치 작동" 블럭 실행 — 캐릭터의 현재 위치에 스위치가 있을 때만 성공(연결된 문을 엶)
    /// 이미 열린 문이어도 스위치 자체는 계속 그 자리에 있으므로 재실행은 실패가 아님(무해한 재작동)
    private func activateSwitchAtCurrentPosition() -> Bool {
        guard let scene else { return false }
        let position = scene.characterPosition
        guard let gate = scene.mapData.switches?.first(where: { $0.switchAt == position })?.gateAt else {
            return false
        }
        if !openedGates.contains(gate) {
            openedGates.insert(gate)
            scene.openGate(at: gate)
        }
        SoundService.shared.play(.switchActivate)
        return true
    }

    // MARK: - 캐릭터 이동 (GameScene에 명령)

    /// 앞으로/뒤로 이동 — 성공 여부 반환 (벽이면 false)
    private func moveCharacter(direction: MoveDirection) async -> Bool {
        return await withCheckedContinuation { continuation in
            // @MainActor라 scene(메인 전용)에 직접 접근 가능 (별도 디스패치 불필요)
            guard let scene = scene else {
                continuation.resume(returning: false)
                return
            }

            // 이동 방향에 따라 다음 위치 계산
            let nextPos: Position
            switch direction {
            case .forward:
                // 캐릭터가 바라보는 방향으로 한 칸 이동
                nextPos = scene.characterPosition.next(direction: scene.characterDirection)
            case .backward:
                // 캐릭터가 바라보는 방향의 반대 방향으로 한 칸 이동
                nextPos = scene.characterPosition.previous(direction: scene.characterDirection)
            }

            // 이동 가능 여부 확인 (맵 범위 & 바닥 타일 또는 열린 문)
            guard isWalkable(nextPos) else {
                continuation.resume(returning: false)  // 벽(또는 닫힌 문): 이동 실패
                return
            }

            // 캐릭터 위치 업데이트 및 애니메이션 적용
            scene.characterPosition = nextPos
            scene.updateCharacterTransform(animated: true)

            // 이동 애니메이션 완료 후 도착 칸의 기믹 효과 적용 + 다음 블럭 실행 (속도 배율 적용)
            // asyncAfter는 스레드 점프가 아닌 "애니메이션 대기 시간"이라 그대로 유지
            let delay = 0.3 / executionSpeed
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.applyTileEffects(at: nextPos)
                continuation.resume(returning: true)  // 이동 성공
            }
        }
    }

    /// 캐릭터 좌우 회전 — 애니메이션 완료 후 continuation 재개
    private func turnCharacter(left: Bool) async {
        await withCheckedContinuation { continuation in
            // @MainActor라 scene(메인 전용)에 직접 접근 가능 (별도 디스패치 불필요)
            guard let scene = scene else {
                continuation.resume()
                return
            }
            // 방향 값 갱신 (왼쪽/오른쪽 90도 회전)
            scene.characterDirection = left
                ? scene.characterDirection.turnedLeft
                : scene.characterDirection.turnedRight
            // 회전 애니메이션 적용
            scene.updateCharacterTransform(animated: true)

            // 회전 애니메이션 완료 후 다음 블럭 실행 (속도 배율 적용)
            // asyncAfter는 스레드 점프가 아닌 "애니메이션 대기 시간"이라 그대로 유지
            let delay = 0.2 / executionSpeed
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                continuation.resume()
            }
        }
    }

    // MARK: - 결과 처리

    /// 현재 캐릭터 위치가 목표 지점인지 확인 (@MainActor라 동기 접근)
    private func checkGoal() -> Bool {
        // scene이 없으면 false (클리어 불가)
        scene?.mapData.isGoal(scene?.characterPosition ?? Position(x: -1, y: -1)) ?? false
    }

    /// 클리어 성공 처리 — 별점 계산 후 ProgressService에 기록 저장 (@MainActor라 동기 처리)
    private func handleSuccess() {
        stopTimer()
        // 사용한 블럭 수 기준으로 별점 계산
        var stars = stage.starThresholds.stars(for: totalBlockCount)
        // 보석이 있는 스테이지인데 전부 수집하지 못했으면 별 3개는 주지 않음 (최대 2개)
        // (기믹 없는 스테이지는 items가 nil이라 이 분기 자체가 실행 안 됨 — 기존 계산과 완전히 동일)
        if let items = stage.mapData.items, !items.isEmpty, collectedItems.count < items.count {
            stars = min(stars, 2)
        }
        clearedStars = stars
        currentBlockPath = nil
        gameState = .success
        SoundService.shared.play(stars == 3 ? .clearThreeStar : .clearLowStar)

        // ProgressService에 클리어 기록 저장 (더 좋은 기록이면 갱신)
        ProgressService.shared.recordClear(
            stageId: stage.id,
            stars: stars,
            blockCount: totalBlockCount
        )
    }

    /// 실패 처리 (벽 충돌 등) — 실패 블럭 경로와 메시지 설정 (@MainActor라 동기 처리)
    private func handleFailure(at path: [Int], message: String) {
        stopTimer()
        failedBlockPath = path    // 실패한 블럭 빨간 하이라이트 (경로 기반)
        failureMessage = message  // 토스트 배너 메시지
        gameState = .failure
        SoundService.shared.play(.gameFail)
    }

    // MARK: - 타이머

    /// 클리어 시간 측정 타이머 시작 (0.1초 간격으로 elapsedTime 갱신)
    private func startTimer() {
        startTime = Date()
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            // Timer 콜백은 등록된 런루프(메인)에서 호출되므로 MainActor로 안전하게 단언
            // (동작 동일 — 기존에도 메인 스레드에서 elapsedTime을 갱신했음)
            MainActor.assumeIsolated {
                guard let self = self, let start = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }

    /// 타이머 중지 — 타이머 인스턴스 무효화 및 nil 처리
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - MoveDirection (내부용)
/// 이동 방향 — 앞으로/뒤로만 구분 (회전은 별도 처리)
private enum MoveDirection {
    case forward   // 캐릭터가 바라보는 방향으로 이동
    case backward  // 캐릭터가 바라보는 반대 방향으로 이동
}
