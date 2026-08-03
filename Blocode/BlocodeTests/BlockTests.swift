//
//  BlockTests.swift
//  BlocodeTests
//

import XCTest
@testable import Blocode

final class BlockTests: XCTestCase {

    // MARK: - flatCount

    func test_simpleBlock_flatCountIsOne() {
        let block = Block(type: .moveForward)
        XCTAssertEqual(block.flatCount, 1)
    }

    func test_emptyContainer_flatCountIsZero() {
        // 컨테이너 자체는 0으로 카운트, 자식이 없으면 전체 0
        let repeatBlock = Block(type: .repeatBlock, repeatCount: 5, children: [])
        XCTAssertEqual(repeatBlock.flatCount, 0)
    }

    func test_repeatWithChildren_countsChildrenOnlyNotRepeatCount() {
        // repeat(7)[moveForward] → flatCount는 1 (반복 횟수를 곱하지 않음, 자식 1개만 카운트)
        let repeatBlock = Block(
            type: .repeatBlock,
            repeatCount: 7,
            children: [Block(type: .moveForward)]
        )
        XCTAssertEqual(repeatBlock.flatCount, 1)
    }

    func test_ifBlock_countsChildrenOnly() {
        let ifBlock = Block(
            type: .ifBlock,
            children: [Block(type: .turnRight), Block(type: .moveForward)]
        )
        XCTAssertEqual(ifBlock.flatCount, 2)
    }

    func test_functionBlock_countsChildrenOnly_noSpecialWeight() {
        // function은 재사용 개념이 없어 그냥 자식 합만 카운트 (호출 비용 없음)
        let functionBlock = Block(
            type: .functionBlock,
            children: [Block(type: .moveForward), Block(type: .turnLeft), Block(type: .moveForward)]
        )
        XCTAssertEqual(functionBlock.flatCount, 3)
    }

    func test_nestedContainers_flattenRecursively() {
        // repeat(3)[ if(pathBlocked)[ turnRight ], moveForward ] → 자식 2개(if, moveForward)
        // if 안의 turnRight 1개 → 총 flatCount 2 (if 자체 0 + turnRight 1) + moveForward 1 = 2
        let inner = Block(type: .ifBlock, children: [Block(type: .turnRight)])
        let outer = Block(type: .repeatBlock, repeatCount: 10, children: [inner, Block(type: .moveForward)])
        XCTAssertEqual(outer.flatCount, 2)
    }

    func test_threeLevelNesting_flattenRecursively() {
        // function → repeat → if → moveForward (4단 중첩) 도 재귀적으로 정확히 1까지 내려가야 함
        let leaf = Block(type: .moveForward)
        let level3 = Block(type: .ifBlock, children: [leaf])
        let level2 = Block(type: .repeatBlock, repeatCount: 4, children: [level3])
        let level1 = Block(type: .functionBlock, children: [level2])
        XCTAssertEqual(level1.flatCount, 1)
    }

    func test_gimmickBlocks_countAsOne() {
        XCTAssertEqual(Block(type: .collectItem).flatCount, 1)
        XCTAssertEqual(Block(type: .activateSwitch).flatCount, 1)
    }

    // MARK: - 기본값

    func test_repeatBlock_defaultRepeatCountIsTwo() {
        let block = Block(type: .repeatBlock)
        XCTAssertEqual(block.repeatCount, 2)
    }

    func test_ifBlock_defaultConditionIsPathBlocked() {
        let block = Block(type: .ifBlock)
        XCTAssertEqual(block.ifCondition, .pathBlocked)
    }

    func test_nonContainerBlocks_haveNilChildren() {
        XCTAssertNil(Block(type: .moveForward).children)
        XCTAssertNil(Block(type: .turnLeft).children)
    }

    func test_containerBlocks_hasChildrenIsTrue() {
        XCTAssertTrue(Block(type: .repeatBlock).hasChildren)
        XCTAssertTrue(Block(type: .ifBlock).hasChildren)
        XCTAssertTrue(Block(type: .functionBlock).hasChildren)
        XCTAssertFalse(Block(type: .moveForward).hasChildren)
    }

    // MARK: - StarThresholds

    func test_starThresholds_boundaryValues() {
        let thresholds = StarThresholds(threeStar: 4, twoStar: 6)
        XCTAssertEqual(thresholds.stars(for: 4), 3)   // 경계값 — 별 3개
        XCTAssertEqual(thresholds.stars(for: 5), 2)   // threeStar 초과, twoStar 이하 — 별 2개
        XCTAssertEqual(thresholds.stars(for: 6), 2)   // 경계값 — 별 2개
        XCTAssertEqual(thresholds.stars(for: 7), 1)   // twoStar 초과 — 별 1개
        XCTAssertEqual(thresholds.stars(for: 1), 3)   // 최소값도 3개 기준 이하면 3개
    }
}
