//
//  MapDataTests.swift
//  BlocodeTests
//

import XCTest
@testable import Blocode

final class MapDataTests: XCTestCase {

    // MARK: - Direction 회전

    func test_turnedRight_cyclesClockwise() {
        XCTAssertEqual(Direction.up.turnedRight, .right)
        XCTAssertEqual(Direction.right.turnedRight, .down)
        XCTAssertEqual(Direction.down.turnedRight, .left)
        XCTAssertEqual(Direction.left.turnedRight, .up)
    }

    func test_turnedLeft_cyclesCounterClockwise() {
        XCTAssertEqual(Direction.up.turnedLeft, .left)
        XCTAssertEqual(Direction.left.turnedLeft, .down)
        XCTAssertEqual(Direction.down.turnedLeft, .right)
        XCTAssertEqual(Direction.right.turnedLeft, .up)
    }

    func test_turnedRightThenLeft_returnsToOriginal() {
        for direction: Direction in [.up, .down, .left, .right] {
            XCTAssertEqual(direction.turnedRight.turnedLeft, direction)
        }
    }

    // MARK: - Position 이동

    func test_next_movesOneTileInFacingDirection() {
        let pos = Position(x: 2, y: 2)
        XCTAssertEqual(pos.next(direction: .up),    Position(x: 2, y: 1))
        XCTAssertEqual(pos.next(direction: .down),  Position(x: 2, y: 3))
        XCTAssertEqual(pos.next(direction: .left),  Position(x: 1, y: 2))
        XCTAssertEqual(pos.next(direction: .right), Position(x: 3, y: 2))
    }

    func test_previous_movesOppositeOfFacingDirection() {
        let pos = Position(x: 2, y: 2)
        XCTAssertEqual(pos.previous(direction: .up),    pos.next(direction: .down))
        XCTAssertEqual(pos.previous(direction: .right), pos.next(direction: .left))
    }

    // MARK: - MapData 경계/타일 판정

    private func makeMap(grid: [[Int]], start: Position = Position(x: 0, y: 0), goal: Position = Position(x: 0, y: 0)) -> MapData {
        MapData(grid: grid, start: start, startDirection: .up, goal: goal)
    }

    func test_isInBounds_trueInsideGridFalseOutside() {
        let map = makeMap(grid: [[1, 1], [1, 1]])
        XCTAssertTrue(map.isInBounds(Position(x: 0, y: 0)))
        XCTAssertTrue(map.isInBounds(Position(x: 1, y: 1)))
        XCTAssertFalse(map.isInBounds(Position(x: 2, y: 0)))
        XCTAssertFalse(map.isInBounds(Position(x: 0, y: -1)))
    }

    func test_isFloor_matchesGridValue() {
        let map = makeMap(grid: [[0, 1], [1, 0]])
        XCTAssertFalse(map.isFloor(Position(x: 0, y: 0)))  // 벽
        XCTAssertTrue(map.isFloor(Position(x: 1, y: 0)))   // 바닥
        XCTAssertTrue(map.isFloor(Position(x: 0, y: 1)))   // 바닥
        XCTAssertFalse(map.isFloor(Position(x: 1, y: 1)))  // 벽
    }

    func test_isFloor_outOfBoundsIsFalse() {
        let map = makeMap(grid: [[1, 1], [1, 1]])
        XCTAssertFalse(map.isFloor(Position(x: 5, y: 5)))
    }

    func test_isGoal_matchesGoalPositionOnly() {
        let map = makeMap(grid: [[1, 1], [1, 1]], goal: Position(x: 1, y: 1))
        XCTAssertTrue(map.isGoal(Position(x: 1, y: 1)))
        XCTAssertFalse(map.isGoal(Position(x: 0, y: 0)))
    }

    func test_widthAndHeight_matchGridDimensions() {
        let map = makeMap(grid: [[1, 1, 1], [1, 1, 1]])
        XCTAssertEqual(map.width, 3)
        XCTAssertEqual(map.height, 2)
    }
}
