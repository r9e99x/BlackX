//
//  ChapterCatalog.swift
//  Blocode
//
//  Created by 조준희 on 6/24/26.
//

import SwiftUI

// MARK: - ChapterCatalog
/// 모든 챕터 메타데이터의 단일 원본(Source of Truth)
/// 챕터 번호·제목·스테이지 수·색상·다음 챕터 해금 기준을
/// 이 한 곳에서만 정의하고, 화면/뷰모델/서비스가 모두 여기서 읽는다.
/// (예전에는 같은 값이 4~5곳에 흩어져 있어 한 곳만 고치면 어긋나는 문제가 있었음)
///
/// 챕터/스테이지를 추가·변경할 때는 아래 `all` 배열만 수정하면 된다.
enum ChapterCatalog {

    /// 챕터 카드/헤더 색상 생성 헬퍼
    /// 라이트: 전달받은 RGB 그대로 (기존 고정값과 동일 — 절대 변경 금지)
    /// 다크: 같은 색조를 22% 어둡게(×0.78) — 다크 배경에서 카드가 너무 튀지 않도록 톤 다운
    /// (Color.dynamic — iOS/macOS 공용 크로스플랫폼 헬퍼 사용)
    private static func chapterColor(red: Double, green: Double, blue: Double) -> Color {
        Color.dynamic(light: (red, green, blue),
                      dark: (red * 0.78, green * 0.78, blue * 0.78))
    }

    /// 전체 챕터 메타데이터 (챕터 번호 오름차순)
    static let all: [ChapterInfo] = [
        ChapterInfo(id: 1, title: "기본기",  description: "블럭을 조립하는 첫 걸음을 배워요", stageCount: 6,
                    color: chapterColor(red: 0.576, green: 0.788, blue: 0.671), // #93c9ab
                    requiredStarsFromPrev: 0),       // 챕터 1은 항상 개방
        ChapterInfo(id: 2, title: "반복",   description: "반복 블럭으로 긴 길을 짧게 압축해요", stageCount: 8,
                    color: chapterColor(red: 0.58, green: 0.76, blue: 0.88),
                    requiredStarsFromPrev: 12),      // 챕터 1 최대 18개 중 12개 (67%)
        ChapterInfo(id: 3, title: "조건문", description: "if 조건으로 어떤 미로든 뚫어내요", stageCount: 8,
                    color: chapterColor(red: 0.93, green: 0.62, blue: 0.42),
                    requiredStarsFromPrev: 16),      // 챕터 2 최대 24개 중 16개 (67%)
        ChapterInfo(id: 4, title: "함수",   description: "함수로 코드를 깔끔하게 정리해요", stageCount: 7,
                    color: chapterColor(red: 0.45, green: 0.78, blue: 0.62),
                    requiredStarsFromPrev: 16),      // 챕터 3 최대 24개 중 16개 (67%)
        ChapterInfo(id: 5, title: "심화",   description: "지금까지 배운 걸 한 단계 더 깊게", stageCount: 6,
                    color: chapterColor(red: 0.88, green: 0.50, blue: 0.68),
                    requiredStarsFromPrev: 14),      // 챕터 4 최대 21개 중 14개 (67%)
        ChapterInfo(id: 6, title: "보석",   description: "정확한 위치에서 보석을 모아요", stageCount: 7,
                    color: chapterColor(red: 0.71, green: 0.65, blue: 0.89), // 라벤더
                    requiredStarsFromPrev: 12),      // 챕터 5 최대 18개 중 12개 (67%)
        ChapterInfo(id: 7, title: "스위치", description: "스위치를 눌러 닫힌 문을 열어요", stageCount: 7,
                    color: chapterColor(red: 0.30, green: 0.69, blue: 0.67), // 틸
                    requiredStarsFromPrev: 14),      // 챕터 6 최대 21개 중 14개 (67%)
        ChapterInfo(id: 8, title: "포탈",   description: "포탈로 순간이동하는 지름길을 찾아요", stageCount: 7,
                    color: chapterColor(red: 0.94, green: 0.50, blue: 0.45), // 코랄
                    requiredStarsFromPrev: 14),      // 챕터 7 최대 21개 중 14개 (67%)
        ChapterInfo(id: 9, title: "미궁",   description: "여러 기믹이 뒤섞인 종합 미궁이에요", stageCount: 7,
                    color: chapterColor(red: 0.38, green: 0.56, blue: 0.74), // 스틸블루
                    requiredStarsFromPrev: 14),      // 챕터 8 최대 21개 중 14개 (67%)
        ChapterInfo(id: 10, title: "정복",  description: "모든 기술을 총동원하는 최종 관문", stageCount: 6,
                    color: chapterColor(red: 0.85, green: 0.68, blue: 0.30), // 골드
                    requiredStarsFromPrev: 14),      // 챕터 9 최대 21개 중 14개 (67%)
    ]

    /// 챕터 번호로 메타데이터 조회 (없으면 nil)
    static func chapter(_ number: Int) -> ChapterInfo? {
        all.first { $0.number == number }
    }
}
