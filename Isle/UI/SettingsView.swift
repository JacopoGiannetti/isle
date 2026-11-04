import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(Lang.self) private var lang
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase
    @State private var notifications: UNAuthorizationStatus?
    @State private var confirmDelete = false
    private let cloud = Cloud.status

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(selection: Binding(get: { lang.id }, set: { lang.id = $0 })) {
                        ForEach(Lang.ID.allCases) { id in
                            Text("\(id.flag)  \(id.label)").tag(id)
                        }
                    } label: {
                        Label(L("Lingua"), systemImage: "globe")
                    }
                    .font(.cozy(16, .semibold))
                    .foregroundStyle(Theme.ink)
                } footer: {
                    footer(L("Cambia la lingua dell'app. Vale subito, senza chiudere."))
                }
                .listRowBackground(Theme.paper)

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    } label: {
                        row(L("Notifiche"), "bell", external: true) {
                            if let notifications {
                                Text(L([.authorized, .provisional, .ephemeral].contains(notifications) ? "Attive" : "Spente"))
                                    .font(.cozy(15, .medium))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                } footer: {
                    footer(L("Promemoria, arrivi e tempeste. Si accendono e si spengono dalle impostazioni di iPhone."))
                }
                .listRowBackground(Theme.paper)

                Section {
                    Button {
                        Task { await Cloud.sync() }
                    } label: {
                        row("iCloud", "icloud") {
                            if cloud.syncing {
                                ProgressView()
                            } else if let account = cloud.account {
                                Text(L(!account ? "Non attivo" : cloud.failed ? "Non riuscito" : "Attivo"))
                                    .font(.cozy(15, .medium))
                                    .foregroundStyle(account && cloud.failed ? Theme.red : Theme.muted)
                            }
                        }
                    }
                    .disabled(cloud.syncing)
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        footer(cloudFooter)
                        #if DEBUG
                        if let error = cloud.error {
                            Text(error)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.red)
                                .textSelection(.enabled)
                        }
                        #endif
                    }
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
                        row(L("Rivedi l'introduzione"), "sparkles")
                    }
                    if let url = Brand.supportURL {
                        Link(destination: url) { row(L("Contatta il supporto"), "envelope", external: true) }
                    }
                    if let url = Brand.reviewURL {
                        Link(destination: url) { row(L("Lascia una recensione"), "star", external: true) }
                    }
                } footer: {
                    footer(L("Riparte il volo tra le nuvole, come alla prima apertura."))
                }
                .listRowBackground(Theme.paper)

                Section {
                    Link(destination: Brand.privacyURL) {
                        row(L("Informativa sulla privacy"), "hand.raised", external: true)
                    }
                    Link(destination: Brand.termsURL) {
                        row(L("Termini di utilizzo"), "doc.text", external: true)
                    }
                } footer: {
                    footer(L("Isle non ha account e non legge mai le tue isole: restano su questo iPhone e nel tuo iCloud privato, che puoi vedere solo tu."))
                }
                .listRowBackground(Theme.paper)

                Section {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label(L("Cancella tutti i dati"), systemImage: "trash")
                            .font(.cozy(16, .semibold))
                            .foregroundStyle(Theme.red)
                    }
                    .confirmationDialog(L("Cancellare tutti i dati?"), isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button(L("Cancella tutto"), role: .destructive) {
                            dismiss()
                            Task {
                                try? await Task.sleep(for: .milliseconds(350))
                                withAnimation(.easeInOut(duration: 0.6)) { store.deleteAll() }
                            }
                        }
                        Button(L("Annulla"), role: .cancel) {}
                    } message: {
                        Text(L("Isole, risposte, piante e animali spariscono da questo iPhone e da iCloud. Non si può annullare."))
                    }
                } footer: {
                    Text(Brand.version)
                        .font(.cozy(12, .medium))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)
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
        .presentationDetents([.large])
        .task(id: phase) {
            guard phase == .active else { return }
            notifications = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            await Cloud.sync()
        }
    }

    private var cloudFooter: String {
        guard cloud.account != false else {
            return L("Accedi a iCloud nelle impostazioni di iPhone per salvare lì anche le isole: tornano se reinstalli l'app o cambi iPhone.")
        }
        let text = L("Le isole si salvano anche nel tuo iCloud privato: tornano se reinstalli l'app o cambi iPhone.")
        guard let last = cloud.last else { return text }
        let when = last.formatted(Date.RelativeFormatStyle(presentation: .named).locale(Locale(identifier: Lang.code)))
        return text + " " + Lf("Ultimo salvataggio: %@.", when)
    }

    private func row<Trailing: View>(_ title: String, _ icon: String, external: Bool = false,
                                     @ViewBuilder trailing: () -> Trailing = { EmptyView() }) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.cozy(16, .semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            trailing()
            if external {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func footer(_ text: String) -> some View {
        Text(text).font(.cozy(13, .medium))
    }
}
