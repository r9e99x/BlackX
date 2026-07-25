//
//  SettingsService.swift
//  Blocode
//
//  Created by 조준희 on 5/10/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - SettingsService
/// 앱 설정값을 UserDefaults에 저장하는 싱글톤
/// @Published 프로퍼티로 SwiftUI 뷰에서 실시간 반응 가능
final class SettingsService: ObservableObject {

    // 앱 전역에서 단일 인스턴스로 사용
    static let shared = SettingsService()

    // MARK: - 테마

    /// 앱 테마 설정 열거형
    enum ThemePreference: String, CaseIterable {
        case light, dark, system

        /// SwiftUI colorScheme 값으로 변환 (system이면 nil → OS 기본 따름)
        var colorScheme: ColorScheme? {
            switch self {
            case .light:  return .light
            case .dark:   return .dark
            case .system: return nil   // nil이면 preferredColorScheme에서 시스템 따름
            }
        }

        /// 설정 화면에 표시할 레이블 (한국어)
        var label: String {
            switch self {
            case .light:  return "라이트"
            case .dark:   return "다크"
            case .system: return "시스템"
            }
        }
    }

    // MARK: - Published 설정값

    /// 앱 테마 — 변경 시 UserDefaults에 자동 저장
    @Published var theme: ThemePreference {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }

    /// 효과음 활성화 여부 — 변경 시 UserDefaults에 자동 저장
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }

    /// 배경음악 활성화 여부 — 변경 시 UserDefaults에 저장 + 즉시 재생/정지 반영
    @Published var musicEnabled: Bool {
        didSet {
            UserDefaults.standard.set(musicEnabled, forKey: "musicEnabled")
            SoundService.shared.setMusicEnabled(musicEnabled)
        }
    }

    /// 블럭 실행 속도 배율 (0.5 / 1.0 / 2.0) — 변경 시 UserDefaults에 자동 저장
    @Published var executionSpeed: Double {
        didSet { UserDefaults.standard.set(executionSpeed, forKey: "executionSpeed") }
    }

    // MARK: - Init

    /// private init으로 외부 인스턴스 생성 방지 (싱글톤 패턴)
    private init() {
        let ud = UserDefaults.standard
        // 저장된 테마 값 로드 (없으면 시스템 기본값)
        let themeRaw = ud.string(forKey: "theme") ?? ThemePreference.system.rawValue
        self.theme          = ThemePreference(rawValue: themeRaw) ?? .system
        // 저장된 효과음 설정 로드 (없으면 기본값 true)
        self.soundEnabled   = ud.object(forKey: "soundEnabled")  as? Bool   ?? true
        // 저장된 배경음악 설정 로드 (없으면 기본값 true)
        self.musicEnabled   = ud.object(forKey: "musicEnabled")  as? Bool   ?? true
        // 저장된 실행 속도 로드 (없으면 기본값 1.0배속)
        self.executionSpeed = ud.object(forKey: "executionSpeed") as? Double ?? 1.0
    }

    // MARK: - 진행도 초기화

    /// 모든 스테이지 클리어 기록 초기화 — ProgressService에 위임
    /// 온보딩도 다시 보게 초기화(hasSeenOnboarding) — BlocodeApp의 @AppStorage가 같은 키를 관찰하므로
    /// 여기서 UserDefaults 값만 바꿔도 앱 진입점이 자동으로 온보딩 화면으로 전환됨
    func resetProgress() {
        ProgressService.shared.resetAll()
        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
    }
}
