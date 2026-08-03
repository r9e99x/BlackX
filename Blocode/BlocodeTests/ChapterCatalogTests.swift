//
//  ChapterCatalogTests.swift
//  BlocodeTests
//
//  ChapterCatalog(챕터 메타데이터 단일 원본)의 내부 일관성을 검증.
//  과거 "같은 값이 여러 곳에 흩어져 있어 한 곳만 고치면 어긋나는" 버그가 있었기 때문에
//  이 데이터 자체가 스스로 모순되지 않는지를 회귀 테스트로 고정해둔다.

import XCTest
@testable import Blocode

final class ChapterCatalogTests: XCTestCase {

    func test_chapterNumbers_areSequentialStartingAtOne() {
        let numbers = ChapterCatalog.all.map(\.number)
        XCTAssertEqual(numbers, Array(1...numbers.count), "챕터 번호가 1부터 순서대로 연속이어야 함")
    }

    func test_chapterNumbers_haveNoDuplicates() {
        let numbers = ChapterCatalog.all.map(\.number)
        XCTAssertEqual(Set(numbers).count, numbers.count, "중복된 챕터 번호가 있음")
    }

    func test_firstChapter_requiresNoStars() {
        XCTAssertEqual(ChapterCatalog.chapter(1)?.requiredStarsFromPrev, 0, "챕터 1은 항상 개방이어야 함")
    }

    func test_subsequentChapters_requirePositiveStars() {
        for info in ChapterCatalog.all where info.number > 1 {
            XCTAssertGreaterThan(
                info.requiredStarsFromPrev, 0,
                "챕터 \(info.number)은 이전 챕터 별 조건이 있어야 함(0이면 사실상 해금 조건 없음)"
            )
        }
    }

    func test_requiredStars_neverExceedsPreviousChapterMaxPossibleStars() {
        // 이전 챕터 최대 별점(스테이지 수 × 3)보다 해금 기준이 크면 절대 못 깨는 챕터가 됨
        for info in ChapterCatalog.all where info.number > 1 {
            guard let prev = ChapterCatalog.chapter(info.number - 1) else {
                XCTFail("챕터 \(info.number - 1)을 찾을 수 없음")
                continue
            }
            let maxPossible = prev.stageCount * 3
            XCTAssertLessThanOrEqual(
                info.requiredStarsFromPrev, maxPossible,
                "챕터 \(info.number)의 해금 기준(\(info.requiredStarsFromPrev))이 챕터 \(prev.number)의 만점(\(maxPossible))을 넘어 영원히 잠김"
            )
        }
    }

    func test_stageCounts_sumToKnownTotal() {
        // 2026-07-18 챕터 6~10 신설 이후 총 69개 스테이지 — 값이 바뀌면 의도적인지 확인 필요
        let total = ChapterCatalog.all.reduce(0) { $0 + $1.stageCount }
        XCTAssertEqual(total, 69, "전체 스테이지 수가 69개가 아님 — 챕터 구성이 변경됐다면 이 숫자도 함께 갱신할 것")
    }

    func test_everyChapter_hasNonEmptyTitleAndDescription() {
        for info in ChapterCatalog.all {
            XCTAssertFalse(info.title.isEmpty, "챕터 \(info.number)의 title이 비어있음")
            XCTAssertFalse(info.description.isEmpty, "챕터 \(info.number)의 description이 비어있음")
            XCTAssertGreaterThan(info.stageCount, 0, "챕터 \(info.number)의 stageCount가 0 이하")
        }
    }
}
