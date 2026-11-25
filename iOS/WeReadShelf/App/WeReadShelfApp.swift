import SwiftUI

@main
struct WeReadShelfApp: App {
    @State private var store = LibraryStore()

    var body: some Scene {
        WindowGroup {
            LibraryView(store: store)
                .task { await store.start() }
        }
    }
}

struct APIKeySettings: View {
    let store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""

    private var canSave: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !store.isSavingAPIKey && !store.isRefreshing
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("微信读书") {
                    LabeledContent("连接状态", value: store.hasAPIKey ? "已保存 API Key" : "尚未连接")
                    SecureField("API Key", text: $apiKey, prompt: Text("wrk-…"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(store.isSavingAPIKey)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .onChange(of: apiKey) { store.clearAPIKeyError() }

                    Link("在微信读书获取 API Key", destination: URL(string: "https://weread.qq.com/r/weread-skills")!)
                }

                Section {
                    Button(action: save) {
                        if store.isSavingAPIKey {
                            ProgressView("正在验证 API Key…")
                        } else {
                            Text("验证并保存")
                        }
                    }
                    .disabled(!canSave)

                    if let error = store.apiKeyErrorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .disabled(store.isSavingAPIKey)
                }
            }
        }
        .interactiveDismissDisabled(store.isSavingAPIKey)
    }

    private func save() {
        guard canSave else { return }
        let candidate = apiKey
        Task {
            if await store.saveAPIKey(candidate) {
                apiKey = ""
                dismiss()
            }
        }
    }
}
