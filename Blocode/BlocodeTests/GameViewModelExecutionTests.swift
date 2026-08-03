//
//  GameViewModelExecutionTests.swift
//  BlocodeTests
//
//  GameViewModel의 실행 엔진(이동/회전/반복/조건문/함수/기믹)을 작은 커스텀 맵으로 직접 검증.
//  실제 69개 스테이지 JSON은 StageDataIntegrityTests에서 구조적으로 검증하고,
//  여기서는 화면 없이 엔진 로직 자체가 정확한지에 집중한다.
//
//  주의: handleSuccess()가 실제 ProgressService.shared(SwiftData, 영구 저장)에 기록을 남긴다.
//  실제 챕터 진행도와 절대 충돌하지 않도록 stage id는 전부 "unittest_"로 시작하는
//  가짜 식별자만 사용한다(ChapterCatalog/실제 스테이지는 "ch{N}_stage{M}" 형식만 조회하므로 무해).

import XCTest
@testable import Blocode

@MainActor
final class GameViewModelExecutionTests: XCTestCase {

    // MARK: - 테스트 픽스처 생성

    /// 커스텀 맵 + GameViewModel + (headless) GameScene을 한 번에 구성
    /// scene에 0이 아닌 size를 주고 setupMap()을 한 번 호출해야 characterNode가 만들어져서
    /// teleportCharacter 등 노드 의존 로직도 정확히 동작함(뷰 프레젠테이션 없이도 안전 — GameScene의
    /// setupMap/updateCharacterTransform은 size가 0일 때만 조용히 스킵하도록 가드되어 있음)
    private func makeFixture(
        grid: [[Int]],
        start: Position,
        startDirection: Direction = .up,
        goal: Position,
        items: [Position]? = nil,
        switches: [SwitchGate]? = nil,
        portals: [PortalPair]? = nil,
        threeStar: Int = 99,
        twoStar: Int = 99,
        idSuffix: String = UUID().uuidString
    ) -> (viewModel: GameViewModel, scene: GameScene) {
        let mapData = MapData(
            grid: grid, start: start, startDirection: startDirection, goal: goal,
            items: items, switches: switches, portals: portals
        )
        let stage = Stage(
            id: "unittest_\(idSuffix)",
            chapter: 0,
            stageNumber: 0,
            name: "Unit Test Stage",
            mapData: mapData,
            starThresholds: StarThresholds(threeStar: threeStar, twoStar: twoStar)
        )
        let viewModel = GameViewModel(stage: stage)
        let scene = GameScene(mapData: mapData)
        scene.size = CGSize(width: 400, height: 400)
        scene.setupMap()
        viewModel.scene = scene
        return (viewModel, scene)
    }

    /// run() 이후 gameState가 .running을 벗어날 때까지 대기 (실제 이동 애니메이션 지연을 실시간으로 기다림)
    private func waitUntilFinished(_ viewModel: GameViewModel, timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while viewModel.gameState == .running {
            if Date() > deadline {
                XCTFail("실행이 \(timeout)초 안에 끝나지 않음 (gameState=\(viewModel.gameState))")
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)  // 20ms
        }
    }

    // MARK: - 기본 이동/회전

    func test_moveForward_reachesGoalDirectly() async throws {
        // 3x3, 가운데 세로줄만 바닥. (1,2)에서 위로 두 칸 가면 (1,0) 골인
        let grid = [[0, 1, 0], [0, 1, 0], [0, 1, 0]]
        let (vm, scene) = makeFixture(grid: grid, start: Position(x: 1, y: 2), goal: Position(x: 1, y: 0))
        vm.codeBlocks = [Block(type: .moveForward), Block(type: .moveForward)]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)
    }

    func test_moveForward_intoWall_fails() async throws {
        let grid = [[0, 1, 0], [0, 1, 0], [0, 1, 0]]
        let (vm, scene) = makeFixture(grid: grid, start: Position(x: 1, y: 2), goal: Position(x: 1, y: 0))
        // 오른쪽으로 돌면 (2,2)는 벽 — 충돌 실패해야 함
        vm.codeBlocks = [Block(type: .turnRight), Block(type: .moveForward)]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .failure)
        XCTAssertEqual(vm.failedBlockPath, [1])  // 두 번째(인덱스 1) 블럭에서 실패
    }

    func test_moveBackward_movesOppositeOfFacingDirection() async throws {
        let grid = [[0, 1, 0], [0, 1, 0], [0, 1, 0]]
        // 아래(down)를 보고 있으면 뒤로 이동 = 위로 이동
        let (vm, scene) = makeFixture(grid: grid, start: Position(x: 1, y: 2), startDirection: .down, goal: Position(x: 1, y: 0))
        vm.codeBlocks = [Block(type: .moveBackward), Block(type: .moveBackward)]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)
    }

    // MARK: - repeat 블럭

    func test_repeatBlock_movesMultipleTilesWithSingleChild() async throws {
        // 세로 5칸 복도, repeat(4)[moveForward]로 정확히 4칸 이동해 골인
        let grid = [[0, 1, 0], [0, 1, 0], [0, 1, 0], [0, 1, 0], [0, 1, 0]]
        let (vm, scene) = makeFixture(grid: grid, start: Position(x: 1, y: 4), goal: Position(x: 1, y: 0))
        vm.codeBlocks = [Block(type: .repeatBlock, repeatCount: 4, children: [Block(type: .moveForward)])]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)
        XCTAssertEqual(vm.totalBlockCount, 1)  // flatCount — repeat 횟수와 무관하게 자식 1개만 카운트
    }

    func test_repeatBlock_stopsEarlyOnceGoalReached() async throws {
        // repeat 횟수가 필요 이상으로 커도(예: 10) 목표 도달 즉시 성공 처리되고 남은 반복은 실행 안 됨
        let grid = [[0, 1, 0], [0, 1, 0], [0, 1, 0]]
        let (vm, scene) = makeFixture(grid: grid, start: Position(x: 1, y: 2), goal: Position(x: 1, y: 0))
        vm.codeBlocks = [Block(type: .repeatBlock, repeatCount: 10, children: [Block(type: .moveForward)])]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)  // 2칸만에 골인, 나머지 8회 반복은 벽에 부딪히지 않고 조용히 스킵됨
    }

    // MARK: - if 블럭 (벽따라가기 패턴)

    func test_ifBlock_wallFollowPattern_navigatesCorner() async throws {
        // ㄴ자 경로: (0,3)→(0,2)→(0,1)에서 막히면 우회전→(1,1)→(2,1)=골
        let grid = [
            [0, 0, 0],  // y=0
            [1, 1, 1],  // y=1
            [1, 0, 0],  // y=2
            [1, 0, 0],  // y=3
        ]
        let (vm, scene) = makeFixture(grid: grid, start: Position(x: 0, y: 3), goal: Position(x: 2, y: 1))
        // repeat(4)[ if(pathBlocked){turnRight}, moveForward ] — 이 코드베이스의 핵심 "벽따라가기" 패턴
        let ifBlock = Block(type: .ifBlock, children: [Block(type: .turnRight)], ifCondition: .pathBlocked)
        vm.codeBlocks = [
            Block(type: .repeatBlock, repeatCount: 4, children: [ifBlock, Block(type: .moveForward)])
        ]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)
        XCTAssertEqual(vm.totalBlockCount, 2)  // if(자식 turnRight 1개) + moveForward 1개 = 2
    }

    func test_ifBlock_pathClearCondition_onlyRunsWhenNotBlocked() async throws {
        let grid = [[0, 1, 0], [0, 1, 0], [0, 1, 0]]
        let (vm, scene) = makeFixture(grid: grid, start: Position(x: 1, y: 2), goal: Position(x: 1, y: 0))
        // 앞이 뚫려 있을 때만 moveForward 실행 — 뚫려 있으므로 실행되어 한 칸 전진
        let ifBlock = Block(type: .ifBlock, children: [Block(type: .moveForward)], ifCondition: .pathClear)
        vm.codeBlocks = [ifBlock, Block(type: .moveForward)]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)
    }

    func test_ifBlock_conditionFalse_skipsChildren() async throws {
        let grid = [[0, 1, 0], [0, 1, 0], [0, 1, 0]]
        let (vm, scene) = makeFixture(grid: grid, start: Position(x: 1, y: 2), goal: Position(x: 1, y: 0))
        // 앞이 막혀 있을 때만 실행되는 if인데 실제로는 뚫려 있으므로 turnRight는 건너뛰고
        // 계속 위로 두 번 이동해서 골인해야 함(turnRight가 실행됐다면 벽에 부딪혀 실패했을 것)
        let ifBlock = Block(type: .ifBlock, children: [Block(type: .turnRight)], ifCondition: .pathBlocked)
        vm.codeBlocks = [ifBlock, Block(type: .moveForward), Block(type: .moveForward)]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)
    }

    // MARK: - function 블럭

    func test_functionBlock_actsAsTransparentWrapper() async throws {
        let grid = [[0, 1, 0], [0, 1, 0], [0, 1, 0]]
        let (vm, scene) = makeFixture(grid: grid, start: Position(x: 1, y: 2), goal: Position(x: 1, y: 0))
        let function = Block(type: .functionBlock, children: [Block(type: .moveForward), Block(type: .moveForward)])
        vm.codeBlocks = [function]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)
        XCTAssertEqual(vm.totalBlockCount, 2)  // function 자체는 0, 자식 2개만 카운트 — 호출 비용 없음
    }

    // MARK: - 보석 획득 (collectItem)

    func test_collectItem_succeedsOnItemTile() async throws {
        let grid = [[1, 1, 1]]  // 가로 1행 3칸
        let (vm, scene) = makeFixture(
            grid: grid, start: Position(x: 0, y: 0), startDirection: .right, goal: Position(x: 2, y: 0),
            items: [Position(x: 1, y: 0)]
        )
        vm.codeBlocks = [Block(type: .moveForward), Block(type: .collectItem), Block(type: .moveForward)]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)
        XCTAssertEqual(vm.collectedItems, [Position(x: 1, y: 0)])
    }

    func test_collectItem_failsWhenNoItemOnCurrentTile() async throws {
        let grid = [[1, 1, 1]]
        let (vm, scene) = makeFixture(
            grid: grid, start: Position(x: 0, y: 0), startDirection: .right, goal: Position(x: 2, y: 0),
            items: [Position(x: 1, y: 0)]
        )
        // 시작 칸(0,0)에는 보석이 없으므로 즉시 실패해야 함
        vm.codeBlocks = [Block(type: .collectItem)]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .failure)
    }

    func test_collectItem_cannotBeCollectedTwice() async throws {
        let grid = [[1, 1, 1]]
        let (vm, scene) = makeFixture(
            grid: grid, start: Position(x: 0, y: 0), startDirection: .right, goal: Position(x: 2, y: 0),
            items: [Position(x: 1, y: 0)]
        )
        // 같은 칸에서 collectItem을 두 번 실행 — 두 번째는 이미 수집했으므로 실패해야 함
        vm.codeBlocks = [Block(type: .moveForward), Block(type: .collectItem), Block(type: .collectItem)]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .failure)
        XCTAssertEqual(vm.failedBlockPath, [2])
    }

    // MARK: - 스위치/문 (activateSwitch)

    func test_activateSwitch_opensGateForPassage() async throws {
        // (2,0)은 원본 grid에서 벽(0) — 스위치로 열기 전까지 통행 불가
        let grid = [[1, 1, 0]]
        let (vm, scene) = makeFixture(
            grid: grid, start: Position(x: 0, y: 0), startDirection: .right, goal: Position(x: 2, y: 0),
            switches: [SwitchGate(switchAt: Position(x: 1, y: 0), gateAt: Position(x: 2, y: 0))]
        )
        vm.codeBlocks = [Block(type: .moveForward), Block(type: .activateSwitch), Block(type: .moveForward)]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)
    }

    func test_activateSwitch_failsWhenNotOnSwitchTile() async throws {
        let grid = [[1, 1, 0]]
        let (vm, scene) = makeFixture(
            grid: grid, start: Position(x: 0, y: 0), startDirection: .right, goal: Position(x: 2, y: 0),
            switches: [SwitchGate(switchAt: Position(x: 1, y: 0), gateAt: Position(x: 2, y: 0))]
        )
        // 시작 칸(0,0)엔 스위치가 없으므로 즉시 실패
        vm.codeBlocks = [Block(type: .activateSwitch)]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .failure)
    }

    func test_activateSwitch_reactivatingAlreadyOpenGate_stillSucceeds() async throws {
        // 문은 한 번 열리면 계속 열려 있으므로, 스위치를 두 번 눌러도 실패가 아니어야 함(무해한 재작동)
        let grid = [[1, 1, 0]]
        let (vm, scene) = makeFixture(
            grid: grid, start: Position(x: 0, y: 0), startDirection: .right, goal: Position(x: 2, y: 0),
            switches: [SwitchGate(switchAt: Position(x: 1, y: 0), gateAt: Position(x: 2, y: 0))]
        )
        vm.codeBlocks = [
            Block(type: .moveForward),
            Block(type: .activateSwitch),
            Block(type: .activateSwitch),  // 재작동 — 실패 아님
            Block(type: .moveForward),
        ]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)
    }

    // MARK: - 포탈

    func test_portal_teleportsToDestinationAutomatically() async throws {
        // (1,0) 입장 시 포탈로 (3,0)=골로 자동 순간이동 — 블럭 1개(moveForward)만으로 클리어
        let grid = [[1, 1, 1, 1]]
        let (vm, scene) = makeFixture(
            grid: grid, start: Position(x: 0, y: 0), startDirection: .right, goal: Position(x: 3, y: 0),
            portals: [PortalPair(a: Position(x: 1, y: 0), b: Position(x: 3, y: 0))]
        )
        vm.codeBlocks = [Block(type: .moveForward)]

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)
    }

    // MARK: - 별점 계산

    func test_starCount_threeStarsWhenAtOrBelowThreshold() async throws {
        let grid = [[0, 1, 0], [0, 1, 0], [0, 1, 0]]
        let (vm, scene) = makeFixture(
            grid: grid, start: Position(x: 1, y: 2), goal: Position(x: 1, y: 0),
            threeStar: 2, twoStar: 4
        )
        vm.codeBlocks = [Block(type: .moveForward), Block(type: .moveForward)]  // 정확히 threeStar 기준

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)
        XCTAssertEqual(vm.clearedStars, 3)
    }

    func test_starCount_cappedAtTwoWhenItemsNotFullyCollected() async throws {
        // 블럭 수는 별 3개 기준을 만족해도, 보석이 있는데 하나도 안 모으면 최대 별 2개
        let grid = [[1, 1, 1]]
        let (vm, scene) = makeFixture(
            grid: grid, start: Position(x: 0, y: 0), startDirection: .right, goal: Position(x: 2, y: 0),
            items: [Position(x: 1, y: 0)],
            threeStar: 5, twoStar: 5
        )
        vm.codeBlocks = [Block(type: .moveForward), Block(type: .moveForward)]  // 보석을 안 모으고 그냥 통과

        vm.run()
        try await waitUntilFinished(vm)

        XCTAssertEqual(vm.gameState, .success)
        XCTAssertLessThanOrEqual(vm.clearedStars, 2)
    }

    // MARK: - 리셋

    func test_reset_clearsGimmickStateButKeepsCodeBlocks() async throws {
        let grid = [[1, 1, 1]]
        let (vm, scene) = makeFixture(
            grid: grid, start: Position(x: 0, y: 0), startDirection: .right, goal: Position(x: 2, y: 0),
            items: [Position(x: 1, y: 0)]
        )
        vm.codeBlocks = [Block(type: .moveForward), Block(type: .collectItem), Block(type: .moveForward)]

        vm.run()
        try await waitUntilFinished(vm)
        XCTAssertEqual(vm.collectedItems, [Position(x: 1, y: 0)])

        vm.reset()

        XCTAssertEqual(vm.gameState, .idle)
        XCTAssertTrue(vm.collectedItems.isEmpty)          // 기믹 상태는 초기화됨
        XCTAssertEqual(vm.codeBlocks.count, 3)             // 코드 블럭은 그대로 유지
    }

    func test_fullReset_alsoClearsCodeBlocksAndAttemptCount() async throws {
        let grid = [[0, 1, 0], [0, 1, 0], [0, 1, 0]]
        let (vm, scene) = makeFixture(grid: grid, start: Position(x: 1, y: 2), goal: Position(x: 1, y: 0))
        vm.codeBlocks = [Block(type: .moveForward), Block(type: .moveForward)]

        vm.run()
        try await waitUntilFinished(vm)
        XCTAssertEqual(vm.attemptCount, 1)

        vm.fullReset()

        XCTAssertTrue(vm.codeBlocks.isEmpty)
        XCTAssertEqual(vm.attemptCount, 0)
    }
}
