import SwiftUI

@main
struct WeReadApp: App {
    private static let widgetEvents: Set<String> = ["\(ReadingList.urlScheme)://"]
    @State private var store = LibraryStore()

    var body: some Scene {
        Window("微信读书书单", id: "library") {
            LibraryView(store: store)
                .frame(minWidth: 640, minHeight: 390)
                .handlesExternalEvents(preferring: Self.widgetEvents, allowing: Self.widgetEvents)
                .task { await store.start() }
        }
        .defaultSize(width: 720, height: 500)
        .handlesExternalEvents(matching: Self.widgetEvents)

        Settings {
            APIKeySettings(store: store)
        }
    }
}

private struct APIKeySettings: View {
    let store: LibraryStore
    @State private var apiKey = ""
    @FocusState private var keyFieldFocused: Bool

    var body: some View {
        Form {
            Section("微信读书") {
                LabeledContent("连接状态") {
                    Label(
                        store.hasAPIKey ? "已保存 API Key" : "尚未连接",
                        systemImage: store.hasAPIKey ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(store.hasAPIKey ? Color.accentColor : .secondary)
                }

                SecureField("API Key", text: $apiKey, prompt: Text("wrk-…"))
                    .focused($keyFieldFocused)
                    .disabled(store.isSavingAPIKey)
                    .onChange(of: apiKey) { store.clearAPIKeyError() }
                    .onSubmit(save)

                Link("在微信读书获取 API Key", destination: URL(string: "https://weread.qq.com/r/weread-skills")!)
            }

            Section {
                HStack {
                    if store.isSavingAPIKey {
                        ProgressView().controlSize(.small)
                        Text("正在验证 API Key…")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("验证并保存", action: save)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                }

                if let error = store.apiKeyErrorMessage {
                    Label {
                        Text(error)
                    } icon: {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 285)
        .onAppear { keyFieldFocused = !store.hasAPIKey }
        .onDisappear { apiKey = "" }
    }

    private var canSave: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !store.isSavingAPIKey && !store.isRefreshing
    }

    private func save() {
        guard canSave else { return }
        let candidate = apiKey
        Task {
            if await store.saveAPIKey(candidate) {
                apiKey = ""
                keyFieldFocused = false
            }
        }
    }
}
