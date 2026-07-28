//
//  Block.swift
//  Blocode
//
//  Created by 조준희 on 5/10/26.
//

import Foundation
import SwiftUI

// MARK: - IfCondition
/// if 블럭의 조건 타입 — 앞 칸 상태를 기준으로 자식 블럭 실행 여부 결정
enum IfCondition: String, Codable {
    case pathClear   = "pathClear"    // 앞 칸이 이동 가능하면 자식 블럭 실행 (기본값)
    case pathBlocked = "pathBlocked"  // 앞 칸이 막혀있으면 자식 블럭 실행

    /// 조건 설명 텍스트 (블럭 행에 표시)
    var displayName: String {
        switch self {
        case .pathClear:   return "앞이 뚫려있으면"
        case .pathBlocked: return "앞이 막혀있으면"
        }
    }
}

// MARK: - BlockType
/// 코드 블럭의 종류를 정의하는 열거형
/// 실제 프로그래밍 언어의 기본 명령어와 1:1 대응
enum BlockType: String, Codable, CaseIterable {
    case moveForward   = "moveForward"   // 앞으로 이동
    case moveBackward  = "moveBackward"  // 뒤로 이동
    case turnLeft      = "turnLeft"      // 왼쪽으로 90도 회전
    case turnRight     = "turnRight"     // 오른쪽으로 90도 회전
    case repeatBlock   = "repeat"        // 반복 (자식 블럭들을 N번 반복 실행)
    case ifBlock       = "if"            // 조건문 (앞 칸 상태에 따라 자식 블럭 실행)
    case functionBlock = "function"      // 함수 (자식 블럭들을 서브루틴으로 묶어 실행)
    case collectItem   = "collectItem"   // 보석 획득 (현재 칸에 보석이 있을 때만 성공, 아니면 실패 — 챕터6+ 전용)
    case activateSwitch = "activateSwitch" // 스위치 작동 (현재 칸에 스위치가 있을 때만 성공, 아니면 실패 — 챕터7+ 전용)

    /// 화면에 표시할 블럭 이름 (한국어)
    var displayName: String {
        switch self {
        case .moveForward:    return "앞으로"
        case .moveBackward:   return "뒤로"
        case .turnLeft:       return "왼쪽 회전"
        case .turnRight:      return "오른쪽 회전"
        case .repeatBlock:    return "반복"
        case .ifBlock:        return "만약에"
        case .functionBlock:  return "함수"
        case .collectItem:    return "보석 획득"
        case .activateSwitch: return "스위치 작동"
        }
    }

    /// SF Symbols 아이콘 이름 — 블럭 행과 팔레트에서 사용
    var iconName: String {
        switch self {
        case .moveForward:    return "arrow.up"
        case .moveBackward:   return "arrow.down"
        case .turnLeft:       return "arrow.counterclockwise"
        case .turnRight:      return "arrow.clockwise"
        case .repeatBlock:    return "repeat"
        case .ifBlock:        return "arrow.triangle.branch"  // 분기 경로 아이콘
        case .functionBlock:  return "curlybraces"            // 코드 함수 아이콘
        case .collectItem:    return "diamond.fill"           // 맵 위 보석 마커와 동일한 다이아몬드 모양
        case .activateSwitch: return "hand.tap.fill"          // 스위치를 누르는 동작을 표현
        }
    }

    /// 팔레트 카드에 표시할 짧은 이름
    var shortName: String {
        switch self {
        case .moveForward:    return "앞으로"
        case .moveBackward:   return "뒤로"
        case .turnLeft:       return "왼쪽"
        case .turnRight:      return "오른쪽"
        case .repeatBlock:    return "반복"
        case .ifBlock:        return "만약에"
        case .functionBlock:  return "함수"
        case .collectItem:    return "획득"
        case .activateSwitch: return "스위치"
        }
    }

    /// 블럭 파스텔 색상 헬퍼
    /// 라이트: 전달받은 RGB 그대로 (기존 고정 파스텔 — 절대 변경 금지)
    /// 다크: 같은 색조를 22% 어둡게(×0.78) — 다크 패널 위에서 튀지 않도록 톤 다운 (챕터 카드와 동일 강도)
    /// (Color.dynamic — iOS/macOS 공용 크로스플랫폼 헬퍼 사용)
    private static func pastel(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color.dynamic(light: (red, green, blue),
                      dark: (red * 0.78, green * 0.78, blue * 0.78))
    }

    /// 블럭 고유 색상 — 라이트: 기존 파스텔 톤 그대로 / 다크: ×0.78 톤 다운
    /// (팔레트 카드·코드 행·최소화 칩·자식 행·드래그 고스트가 전부 이 색에서 파생되므로 한 곳만 관리)
    var blockColor: Color {
        switch self {
        case .moveForward:    return Self.pastel(124/255, 196/255, 158/255) // 민트 그린
        case .moveBackward:   return Self.pastel(207/255, 127/255, 122/255) // 살먼 로즈
        case .turnLeft:       return Self.pastel(142/255, 176/255, 200/255) // 뮤트 블루
        case .turnRight:      return Self.pastel(142/255, 176/255, 200/255) // 뮤트 블루
        case .repeatBlock:    return Self.pastel(168/255, 141/255, 192/255) // 라벤더
        case .ifBlock:        return Self.pastel(240/255, 196/255, 100/255) // 골든 옐로우
        case .functionBlock:  return Self.pastel(94/255,  198/255, 208/255) // 틸
        case .collectItem:    return Self.pastel(0.42, 0.82, 0.68)          // 민트 보석 — GameScene.itemColor와 동일 톤
        case .activateSwitch: return Self.pastel(0.93, 0.62, 0.28)          // 주황 스위치 — GameScene.switchColor와 동일 톤
        }
    }

    /// 연한 배경색 (블럭 행 하이라이트용) — 불투명도 12%로 적용
    var lightColor: Color {
        blockColor.opacity(0.12)
    }
}

// MARK: - Block
/// 사용자가 코드 순서 영역에 추가하는 하나의 코드 블럭
struct Block: Identifiable, Codable {
    var id: UUID          // SwiftUI 리스트 식별자 — ForEach에서 고유 키로 사용
    var type: BlockType   // 블럭 종류

    /// repeat 블럭일 때만 사용: 반복 횟수 (스테퍼로 조절, 기본값 2)
    var repeatCount: Int?

    /// repeat / if / function 블럭일 때 사용: 자식 블럭 목록
    var children: [Block]?

    /// if 블럭일 때만 사용: 조건 타입 (기본값 .pathClear)
    var ifCondition: IfCondition?

    // MARK: - 초기화
    init(type: BlockType,
         repeatCount: Int? = nil,
         children: [Block]? = nil,
         ifCondition: IfCondition? = nil) {
        self.id = UUID()  // 항상 새로운 고유 ID 생성
        self.type = type

        // 자식 블럭을 갖는 컨테이너 타입 (repeat / if / function)
        let isContainer = (type == .repeatBlock || type == .ifBlock || type == .functionBlock)

        // repeat 블럭: 기본 반복 횟수 2
        self.repeatCount = (type == .repeatBlock) ? (repeatCount ?? 2) : nil

        // 컨테이너 블럭: 빈 자식 배열로 초기화
        self.children = isContainer ? (children ?? []) : nil

        // if 블럭: 기본 조건 pathBlocked (앞이 막혀있으면)
        self.ifCondition = (type == .ifBlock) ? (ifCondition ?? .pathBlocked) : nil
    }

    // MARK: - 헬퍼

    /// 자식 블럭 영역을 표시해야 하는 컨테이너 블럭 여부
    /// repeat / if / function 모두 자식 블럭을 가짐
    var hasChildren: Bool {
        type == .repeatBlock || type == .ifBlock || type == .functionBlock
    }

    /// repeat 블럭 여부 확인 (반복 횟수 스테퍼 표시 조건)
    var isRepeatBlock: Bool {
        type == .repeatBlock
    }

    /// 실행 시 실제로 처리되는 총 블럭 수 (별점 계산용)
    /// 컨테이너 블럭은 자식 블럭 수만 카운트 (컨테이너 자체는 제외)
    var flatCount: Int {
        switch type {
        case .repeatBlock, .ifBlock, .functionBlock:
            // 자식 블럭들의 flatCount를 재귀적으로 합산
            return children?.reduce(0) { $0 + $1.flatCount } ?? 0
        default:
            // 일반 블럭은 1개로 카운트
            return 1
        }
    }
}
