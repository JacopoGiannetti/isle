import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(Lang.self) private var lang
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(L("Lingua"), selection: Binding(get: { lang.id }, set: { lang.id = $0 })) {
                        ForEach(Lang.ID.allCases) { id in
                            Text(id.label).tag(id)
                        }
                    }
                    .font(.cozy(16, .semibold))
                    .foregroundStyle(Theme.ink)
                } footer: {
                    Text(L("Cambia la lingua dell'app. Vale subito, senza chiudere."))
                        .font(.cozy(13, .medium))
                }
                .listRowBackground(Theme.paper)

                Section {
                    Button {
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .milliseconds(350))
                            withAnimation(.easeInOut(duration: 0.6)) { store.seenIntro = false }
                        }
                    } label: {
                        Label(L("Rivedi l'introduzione"), systemImage: "sparkles")
                            .font(.cozy(16, .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                } footer: {
                    Text(L("Riparte il volo tra le nuvole, come alla prima apertura."))
                        .font(.cozy(13, .medium))
                }
                .listRowBackground(Theme.paper)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.cream)
            .navigationTitle(L("Impostazioni"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Fine")) { dismiss() }.tint(Theme.ink)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
