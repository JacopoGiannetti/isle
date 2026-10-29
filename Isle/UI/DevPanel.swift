#if DEBUG
import SwiftUI
import UserNotifications

/// Strumenti per vedere l'isola crescere senza aspettare giorni veri.
struct DevPanel: View {
    let controller: WorldController
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var hour = Clock.hourOverride ?? Clock.hour()
    @State private var fixedHour = Clock.hourOverride != nil
    @State private var notifications = "…"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Prova").font(.cozy(24, .bold)).padding(.top, 20)
            HStack {
                Button("+1 giorno") { controller.devAdvance(days: 1) }
                Button("+7 giorni") { controller.devAdvance(days: 7) }
                Button("+30 giorni") { controller.devAdvance(days: 30) }
            }
            .buttonStyle(.bordered)
            HStack {
                Button("+3 ore") { controller.devAdvance(hours: 3) }
                Button("+1 giorno di silenzio") { controller.devAdvance(hours: 24) }
            }
            .buttonStyle(.bordered)
            Toggle("Ora fissa", isOn: $fixedHour)
                .onChange(of: fixedHour) { _, on in Clock.hourOverride = on ? hour : nil }
            if fixedHour {
                Slider(value: $hour, in: 0...23.99)
                    .onChange(of: hour) { _, v in Clock.hourOverride = v }
                Text(String(format: "%02d:%02d", Int(hour), Int(hour.truncatingRemainder(dividingBy: 1) * 60)))
                    .font(.cozy(14, .semibold)).foregroundStyle(Theme.muted)
            }
            HStack {
                Button("Meteorite", role: .destructive) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        Store.shared.update(controller.habitID) { h in h.answers.removeAll { $0.day == Clock.today } }
                        _ = controller.answer(yes: store.habit(controller.habitID)?.kind == .quit)
                    }
                }
                Button("Azzera orologio") { Clock.offset = 0; controller.refresh(animated: false) }
            }
            .buttonStyle(.bordered)
            Text("Notifiche: \(notifications)")
                .font(.cozy(13, .medium)).foregroundStyle(Theme.muted)
            Button("Notifica di prova tra 10 secondi") {
                Task {
                    await Notifier.test()
                    await loadNotifications()
                }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding(.horizontal, 20)
        .task { await loadNotifications() }
    }

    private func loadNotifications() async {
        let c = UNUserNotificationCenter.current()
        let status = await c.notificationSettings().authorizationStatus
        let pending = await c.pendingNotificationRequests().count
        let word = switch status {
        case .authorized: "permesse"
        case .denied: "negate"
        case .notDetermined: "mai chieste"
        case .provisional: "provvisorie"
        case .ephemeral: "temporanee"
        @unknown default: "?"
        }
        let offset = Clock.offset == 0 ? "" : String(format: " · orologio avanti di %.1f giorni", Clock.offset / 86400)
        notifications = "\(word), \(pending) in coda\(offset)"
    }
}
#endif
