//
//  LockInfoOverlay.swift
//  Blocode
//
//  Created by 조준희 on 6/26/26.
//

import SwiftUI

// MARK: - LockInfo
/// 잠금 안내 팝업에 표시할 내용 (제목 / 조건 문구 / 강조 색)
struct LockInfo: Identifiable {
    let id = UUID()
    let title: String        // 팝업 제목
    let message: String      // 해금 조건 안내 문구
    let accentColor: Color   // 강조 색 (챕터 색)
}

// MARK: - LockInfoOverlay
/// 잠긴 챕터/스테이지를 탭했을 때 해금 조건을 안내하는 커스텀 팝업
/// 배경을 어둡게 덮고 가운데 카드로 조건을 보여줌 (배경 탭 또는 확인 버튼으로 닫음)
struct LockInfoOverlay: View {

    let info: LockInfo       // 표시할 잠금 안내 내용
    let onClose: () -> Void  // 닫기 콜백

    @State private var isConfirmPressed = false  // 확인 버튼 눌림 상태 (3D 효과)
    private let confirmTopDepth: CGFloat = 0.8   // 확인 버튼 위 뒷면 두께
    private let confirmBotDepth: CGFloat = 2.5   // 확인 버튼 아래 뒷면 두께 (그림자)

    var body: some View {
        ZStack {
            // 배경 딤 — 탭하면 닫힘
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // 안내 카드
            VStack(spacing: 18) {
                // 자물쇠 아이콘 (원형 배경 + 강조 색)
                ZStack {
                    Circle()
                        .fill(info.accentColor.opacity(0.18))
                        .frame(width: 64, height: 64)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(info.accentColor)
                }
                .padding(.top, 4)

                // 제목
                Text(info.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.primary)

                // 해금 조건 문구
                Text(info.message)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                // 확인 버튼 (3D + 눌림 효과)
                // 색상: 라이트는 기존 darkInk+탄색 베벨 그대로 / 다크는 슬레이트 톤 (slateButton* 다이나믹 컬러)
                Button {
                    SoundService.shared.play(.buttonTap)
                    onClose()
                } label: {
                    ThreeDSurface(topDepth: confirmTopDepth, bottomDepth: confirmBotDepth, isPressed: isConfirmPressed) {
                        // ① 위 뒷면 — 라이트 #807869 / 다크 밝은 슬레이트
                        RoundedRectangle(cornerRadius: 25).fill(Color.slateButtonTopBack)
                            .frame(maxWidth: .infinity).frame(height: 50)
                    } bottomBack: {
                        // ② 아래 뒷면 (그림자) — 라이트 #beb59f / 다크 더 밝은 슬레이트
                        RoundedRectangle(cornerRadius: 25).fill(Color.slateButtonBottomBack)
                            .frame(maxWidth: .infinity).frame(height: 50)
                    } front: {
                        // ③ 앞면 — (라이트 darkInk / 다크 슬레이트) + (눌림 시 그림자) + 텍스트
                        ZStack {
                            RoundedRectangle(cornerRadius: 25).fill(Color.slateButtonFace)
                            if isConfirmPressed {
                                RoundedRectangle(cornerRadius: 25).fill(Color.black.opacity(0.10))
                            }
                            Text("확인")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50 + confirmTopDepth + confirmBotDepth)
                }
                .buttonStyle(.plain)
                .onPressState(isPressed: $isConfirmPressed)
                .padding(.top, 2)
            }
            .padding(24)
            .frame(maxWidth: 300)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - RetryConfirmInfo
/// "이미 클리어한 스테이지 다시 도전" 확인 팝업에 표시할 내용
struct RetryConfirmInfo: Identifiable {
    let id = UUID()
    let title: String        // 팝업 제목
    let message: String      // 안내 문구 (스테이지 이름 등)
    let accentColor: Color   // 강조 색 (챕터 색)
    let onRetry: () -> Void  // "다시 하기" 선택 시 실행할 동작
}

// MARK: - RetryConfirmOverlay
/// 이미 클리어한 스테이지를 탭했을 때 재도전 여부를 물어보는 커스텀 팝업
/// LockInfoOverlay와 동일한 카드 스타일 — 시스템 기본 Alert 대신 앱 톤에 맞춘 UI로 통일
struct RetryConfirmOverlay: View {

    let info: RetryConfirmInfo
    let onCancel: () -> Void  // "취소" 또는 배경 탭 시 닫기 콜백

    @State private var isRetryPressed = false  // "다시 하기" 버튼 눌림 상태 (3D 효과)
    private let retryTopDepth: CGFloat = 0.8
    private let retryBotDepth: CGFloat = 2.5

    var body: some View {
        ZStack {
            // 배경 딤 — 탭하면 취소
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            // 안내 카드
            VStack(spacing: 18) {
                // 체크 아이콘 (원형 배경 + 강조 색) — 이미 클리어했음을 시각화
                ZStack {
                    Circle()
                        .fill(info.accentColor.opacity(0.18))
                        .frame(width: 64, height: 64)
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(info.accentColor)
                }
                .padding(.top, 4)

                // 제목
                Text(info.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.primary)

                // 안내 문구
                Text(info.message)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                // "다시 하기" 버튼 (3D + 눌림 효과) — LockInfoOverlay의 확인 버튼과 동일 스타일
                Button {
                    info.onRetry()
                } label: {
                    ThreeDSurface(topDepth: retryTopDepth, bottomDepth: retryBotDepth, isPressed: isRetryPressed) {
                        RoundedRectangle(cornerRadius: 25).fill(Color.slateButtonTopBack)
                            .frame(maxWidth: .infinity).frame(height: 50)
                    } bottomBack: {
                        RoundedRectangle(cornerRadius: 25).fill(Color.slateButtonBottomBack)
                            .frame(maxWidth: .infinity).frame(height: 50)
                    } front: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 25).fill(Color.slateButtonFace)
                            if isRetryPressed {
                                RoundedRectangle(cornerRadius: 25).fill(Color.black.opacity(0.10))
                            }
                            Text("다시 하기")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50 + retryTopDepth + retryBotDepth)
                }
                .buttonStyle(.plain)
                .onPressState(isPressed: $isRetryPressed)
                .padding(.top, 2)

                // "취소" 버튼 — 보조 액션이라 3D 없이 텍스트로만 (다시 하기와 위계 구분)
                Button(action: onCancel) {
                    Text("취소")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 300)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - 재도전 확인 팝업 표시 패턴 공용화
/// lockInfoPopup과 동일한 구조 — retryConfirmInfo가 nil이 아니면 오버레이로 표시, 닫힐 때 애니메이션과 함께 nil 복귀
private struct RetryConfirmPopupModifier: ViewModifier {
    @Binding var retryConfirmInfo: RetryConfirmInfo?

    func body(content: Content) -> some View {
        content.overlay {
            if let info = retryConfirmInfo {
                RetryConfirmOverlay(info: info) {
                    withAnimation(.easeInOut(duration: 0.2)) { retryConfirmInfo = nil }
                }
                .transition(.opacity)
            }
        }
    }
}

extension View {
    /// 재도전 확인 팝업 오버레이 — 값이 있으면 표시, 취소/배경 탭 시 nil로 닫힘
    /// (onRetry 실행 시 닫는 것은 호출부 책임 — RetryConfirmInfo.onRetry 안에서 nil 대입)
    func retryConfirmPopup(_ retryConfirmInfo: Binding<RetryConfirmInfo?>) -> some View {
        modifier(RetryConfirmPopupModifier(retryConfirmInfo: retryConfirmInfo))
    }
}

// MARK: - 잠금 팝업 표시 패턴 공용화
/// "lockInfo가 nil이 아니면 오버레이로 팝업 표시 + 닫기 시 애니메이션과 함께 nil 복귀" 패턴을
/// 한 곳에서 관리 — 챕터 선택/챕터 상세/맥 챕터맵/맥 브라우저가 동일하게 사용
private struct LockInfoPopupModifier: ViewModifier {
    @Binding var lockInfo: LockInfo?

    func body(content: Content) -> some View {
        content.overlay {
            if let info = lockInfo {
                LockInfoOverlay(info: info) {
                    withAnimation(.easeInOut(duration: 0.2)) { lockInfo = nil }
                }
                .transition(.opacity)
            }
        }
    }
}

extension View {
    /// 잠금 안내 팝업 오버레이 — 값이 있으면 표시, 확인/배경 탭 시 nil로 닫힘
    func lockInfoPopup(_ lockInfo: Binding<LockInfo?>) -> some View {
        modifier(LockInfoPopupModifier(lockInfo: lockInfo))
    }
}

// MARK: - Preview
#Preview {
    LockInfoOverlay(
        info: LockInfo(
            title: "아직 잠겨 있어요",
            message: "이전 챕터에서 별 12개를 모으고\n종합 스테이지를 클리어하면 열려요",
            accentColor: Color(red: 0.58, green: 0.76, blue: 0.88)
        ),
        onClose: {}
    )
}
