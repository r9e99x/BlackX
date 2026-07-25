//
//  SoundService.swift
//  Blocode
//
//  Created by 조준희 on 7/25/26.
//

import AVFoundation

// MARK: - SoundEffect
/// 재생 가능한 효과음 종류 — Resources/Sounds의 파일명(.m4a)과 1:1 대응
enum SoundEffect: String {
    case blockAdd          // 코드블럭 추가
    case blockReorder      // 코드블럭 순서 변경
    case buttonTap         // 일반 버튼 클릭
    case gameFail          // 실행 실패(벽 충돌 등)
    case itemCollect       // 보석 획득
    case switchActivate    // 스위치 작동
    case clearThreeStar    // 별 3개 클리어
    case clearLowStar      // 별 1~2개 클리어
    case lockButton        // 잠긴 챕터/스테이지 탭
    case portal            // 포탈 이동
}

// MARK: - SoundService
/// 효과음 재생을 담당하는 싱글톤 — SettingsService.soundEnabled 설정을 따름
/// 모든 효과음 파일을 미리 로드해 재생 시점에 디코딩 지연 없이 즉시 재생되게 함
final class SoundService {

    static let shared = SoundService()

    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private var musicPlayer: AVAudioPlayer?  // 배경음악 — 효과음과 달리 루프 재생되는 단일 플레이어

    private init() {
        let allEffects: [SoundEffect] = [
            .blockAdd, .blockReorder, .buttonTap, .gameFail,
            .itemCollect, .switchActivate, .clearThreeStar, .clearLowStar,
            .lockButton, .portal
        ]
        for effect in allEffects {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "m4a") else {
                continue
            }
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            players[effect] = player
        }

        if let url = Bundle.main.url(forResource: "backgroundMusic", withExtension: "mp3") {
            musicPlayer = try? AVAudioPlayer(contentsOf: url)
            musicPlayer?.numberOfLoops = -1  // 무한 반복 — 끝나면 처음부터 다시 재생
            musicPlayer?.prepareToPlay()
        }
    }

    /// 효과음 재생 — 설정에서 효과음이 꺼져 있으면 아무 동작 안 함
    func play(_ effect: SoundEffect) {
        guard SettingsService.shared.soundEnabled else { return }
        guard let player = players[effect] else { return }
        // 재생 중에 다시 호출되면(연속 탭 등) 처음부터 재시작
        player.currentTime = 0
        player.play()
    }

    /// 배경음악 재생 시작 — 설정에서 배경음악이 꺼져 있으면 아무 동작 안 함 (이미 재생 중이면 그대로 이어짐)
    func startBackgroundMusic() {
        guard SettingsService.shared.musicEnabled else { return }
        musicPlayer?.play()
    }

    /// 배경음악 정지 — 다음에 다시 켜면 처음부터 재생되도록 위치 초기화
    func stopBackgroundMusic() {
        musicPlayer?.stop()
        musicPlayer?.currentTime = 0
    }

    /// 설정 화면의 배경음악 토글에서 호출 — on이면 재생 시작, off면 정지
    func setMusicEnabled(_ enabled: Bool) {
        if enabled {
            startBackgroundMusic()
        } else {
            stopBackgroundMusic()
        }
    }
}
