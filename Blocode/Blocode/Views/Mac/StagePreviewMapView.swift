//
//  StagePreviewMapView.swift
//  Blocode
//
//  Created by 조준희 on 7/16/26.
//

// 맥 챕터 브라우저 + 아이패드 챕터 브라우저가 공용으로 쓰는 스테이지 미리보기 맵
// (코드 자체가 플랫폼 무관 SwiftUI+SpriteKit이라 iOS/macOS 둘 다 컴파일, 아이폰은 이 타입을 아무도 호출하지 않음)
#if os(macOS) || os(iOS)
import SwiftUI
import SpriteKit

// MARK: - StagePreviewMapView
/// 스테이지 미리보기용 맵 — 실제 게임 화면(StageView.mapView)과 동일한 GameScene을 재사용해
/// 타일·캐릭터·색상이 완전히 동일하게 보이도록 함 (플레이는 불가, 정적 표시 전용)
struct StagePreviewMapView: View {
    let stage: Stage

    @State private var scene: GameScene?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let scene {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .background(Color.mapBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.separatorColor, lineWidth: 1)
                    )
                    .allowsHitTesting(false)  // 미리보기는 플레이 불가 — 터치 통과
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.mapBackground)
            }
        }
        .onAppear { setupScene() }
        // 스테이지 전환은 호출부의 .id(stage.id)가 뷰 자체를 새로 만들어 처리 (scene은 항상 onAppear로 새로 생성됨)
        .onChange(of: colorScheme) { _, newScheme in
            scene?.updateColorScheme(isDark: newScheme == .dark)
        }
    }

    private func setupScene() {
        guard scene == nil else { return }
        let newScene = GameScene(mapData: stage.mapData)
        newScene.updateColorScheme(isDark: colorScheme == .dark)
        scene = newScene
    }
}
#endif
