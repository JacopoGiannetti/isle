import SwiftUI

/// "Come funziona Isle": tutte le regole del gioco, a domande. Si apre dal punto interrogativo
/// sull'isola e dalle Impostazioni.
struct GuideView: View {
    @State private var open: String?

    private struct Topic: Identifiable {
        let icon: String
        let tint: Color
        let title: String
        let items: [(q: String, a: String)]
        var id: String { title }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L("Tocca una domanda per leggere la risposta."))
                    .font(.cozy(15, .medium))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 4)
                ForEach(topics) { card($0) }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.cream)
        .navigationTitle(L("Come funziona Isle"))
        .navigationBarTitleDisplayMode(.inline)
        #if DEBUG
        .onAppear {
            if let i = Launch.once("guideOpen").flatMap(Int.init), topics.indices.contains(i) { open = topics[i].items[0].q }
        }
        #endif
    }

    private func card(_ t: Topic) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: t.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(t.tint, in: Circle())
                Text(t.title)
                    .font(.cozy(18, .bold))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.bottom, 6)
            ForEach(Array(t.items.enumerated()), id: \.offset) { i, item in
                if i > 0 { Divider().overlay(Theme.line) }
                question(item.q, item.a, t.tint)
            }
        }
        .padding(16)
        .surface(22)
    }

    private func question(_ q: String, _ a: String, _ tint: Color) -> some View {
        let shown = open == q
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                Haptic.tick()
                withAnimation(.spring(duration: 0.35)) { open = shown ? nil : q }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(q)
                        .font(.cozy(15, .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(shown ? tint : Theme.muted)
                        .rotationEffect(.degrees(shown ? 180 : 0))
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(L(shown ? "Nascondi la risposta" : "Mostra la risposta"))
            if shown {
                Text(a)
                    .font(.cozy(14, .medium))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipped()
    }

    private var topics: [Topic] {
        [
            Topic(icon: "beach.umbrella.fill", tint: Theme.sky, title: L("Le basi"), items: [
                (L("Cos'è Isle?"),
                 L("Ogni abitudine è un'isola. Ogni giorno buono ti dà un seme: lo pianti, l'isola si allarga e le piante attirano gli animali. Più sei costante, più l'isola diventa viva.")),
                (L("Smettere o iniziare qualcosa?"),
                 L("Se vuoi smettere qualcosa, ogni sera Isle ti chiede se ci sei ricaduto: «No» è un giorno buono. Se vuoi iniziare qualcosa, tocchi «Fatto» quando l'hai fatto: ogni giorno, più volte al giorno o qualche volta a settimana.")),
                (L("Quando posso rispondere?"),
                 L("Se smetti qualcosa, la domanda si apre all'ora del promemoria e resta aperta fino a mezzanotte. Se inizi qualcosa, segni quando vuoi. Si risponde solo per oggi: un giorno saltato non si recupera.")),
                (L("Cosa sono i giorni di fila?"),
                 L("I giorni buoni uno dopo l'altro, per le abitudini di ogni giorno. Ripartono da zero con una ricaduta o un giorno senza risposta. Ogni 7 giorni di fila ricevi un seme bonus.")),
            ]),
            Topic(icon: "leaf.fill", tint: Theme.green, title: L("Semi e piante"), items: [
                (L("Come guadagno i semi?"),
                 L("Un giorno buono vale un seme. Se lo fai più volte al giorno, conta la giornata completa; se lo fai qualche volta a settimana, una settimana completa vale 7 semi. In più c'è un seme bonus ogni 7 giorni di fila, e uno quando fai più del previsto (al massimo 2 a settimana).")),
                (L("Come si pianta?"),
                 L("Tocca il seme, scegli una pianta tra quelle sbloccate e poi una casella illuminata. Per ogni pianta vedi quali animali attira. Se non pianti un seme entro un giorno, lo pianta il vento al posto tuo.")),
                (L("Come sblocco nuove piante?"),
                 L("Andando avanti nel Sentiero. Le prime sono pronte subito, le altre arrivano col passare dei giorni (7, 21, 60, 100) e alcune con piccole sfide, come far crescere tre alberi uguali.")),
                (L("Cos'è una variante rara?"),
                 L("Ogni seme ha circa una possibilità su dieci di nascere raro, un po' di più se hai tanti giorni di fila. Il decimo seme della stessa pianta è sempre raro. Le varianti rare attirano gli animali rari.")),
                (L("Le piante crescono da sole?"),
                 L("Sì: intorno a ogni pianta spuntano erba e fiori, e gli alberi lasciano cadere semi che a volte germogliano. La prima pianta di ogni tipo, dopo 5–14 giorni, si evolve e attira un animale Speciale.")),
            ]),
            Topic(icon: "pawprint.fill", tint: Theme.peach, title: L("Animali"), items: [
                (L("Come arrivano gli animali?"),
                 L("Ogni animale cerca certe piante: quando le trova, arriva entro qualche ora. Alcuni vogliono qualcosa in più, come un'altra pianta o un altro animale. Serve anche spazio: più l'isola cresce, più animali ospita.")),
                (L("Comuni, rari, Speciali e Leggendari?"),
                 L("I comuni e i non comuni arrivano con le piante normali. I rari vogliono le varianti rare. Gli Speciali arrivano dalle piante evolute. I Leggendari sono cinque per mondo, si sbloccano molto avanti nel Sentiero e alcuni nascondono un indovinello.")),
                (L("Cosa succede se tocco un animale?"),
                 L("Fa il suo verso e si apre la sua scheda: carattere, cosa sta facendo, da quanto vive sull'isola e chi l'ha attirato. Con la matita puoi dargli un nome.")),
                (L("Perché non lo trovo o dorme?"),
                 L("Gli animali seguono l'ora vera: alcuni dormono di notte, altri escono solo col buio o al tramonto. Col pulsante dell'ora in alto puoi sbirciare l'isola di giorno, al crepuscolo o di notte.")),
                (L("Gli animali fanno cuccioli?"),
                 L("Sì: due animali della stessa specie che vivono insieme da qualche giorno possono avere uno o due cuccioli, se c'è spazio.")),
            ]),
            Topic(icon: "map.fill", tint: Theme.gold, title: L("Sentiero e Diario"), items: [
                (L("Cos'è il Sentiero?"),
                 L("È il tuo viaggio: va avanti di un giorno a ogni mezzanotte e attraversa cinque zone. Mostra cosa si sblocca e quando, e contiene l'album degli animali trovati. Si ferma solo durante una tempesta forte.")),
                (L("A cosa servono Diario e Calendario?"),
                 L("Il Diario elenca abitanti, piante e la storia dell'isola: tocca una notizia per vederla sull'isola. Il Calendario mostra le tue risposte, mese per mese.")),
                (L("Posso spostare le cose?"),
                 L("Sì, con la chiave inglese: sposti piante e acqua, oppure svuoti l'isola e la risistemi da capo.")),
            ]),
            Topic(icon: "cloud.bolt.rain.fill", tint: Color(hex: 0x6B7A99), title: L("Giorni difficili"), items: [
                (L("Cosa succede se salto un giorno?"),
                 L("Se passa un giorno intero senza risposta arriva una tempesta, che peggiora ogni giorno: nuvole, pioggia, vento, temporale, isola spazzata. Con la pioggia gli animali si riparano, col vento alcuni se ne vanno, poi soffrono fiori e alberi. Basta rispondere, anche con una ricaduta, per farla finire. Con le abitudini settimanali hai una settimana di margine.")),
                (L("E dopo la tempesta?"),
                 L("Esce l'arcobaleno, erba e fiori ricrescono e gli alberi seccati tornano verdi dopo tre giorni buoni. Gli animali partiti possono tornare.")),
                (L("Cosa succede se ci ricado?"),
                 L("Lo dici con «Sì» alla domanda della sera o con «Ho sgarrato». In modalità Normale perdi solo il seme di oggi e i giorni di fila. In modalità dura cade un meteorite: al massimo due piante e due animali, e in 12 giorni il cratere diventa uno stagno. Il primo giorno non ci sono mai conseguenze.")),
                (L("Come cambio modalità?"),
                 L("Nella schermata delle isole, tieni premuta l'isola e accendi o spegni Modalità dura.")),
                (L("A cosa serve «Ho voglia»?"),
                 L("Toccalo quando senti la voglia: respiriamo insieme per circa mezzo minuto. Se la voglia passa, sull'isola sboccia un raro Fiore della tenacia.")),
                (L("Cosa non perdo mai?"),
                 L("I semi guadagnati, le risposte, il Sentiero con tutto ciò che hai sbloccato, la grandezza dell'isola e la sorgente al centro.")),
            ]),
            Topic(icon: "sparkles", tint: Theme.violet, title: L("Cielo e mondi"), items: [
                (L("Il meteo cambia?"),
                 L("Sì, ogni poche ore e senza conseguenze: sole, pioggia, nebbia, petali, tramonti di fuoco. Di notte a volte arrivano lucciole, stelle cadenti, l'aurora o una rarissima notte magica.")),
                (L("Chi sono i visitatori del cielo?"),
                 L("Animali che compaiono solo durante un fenomeno raro, come la Balena del cielo con l'aurora o il Colibrì arcobaleno con l'arcobaleno. Restano finché dura: se li vedi, toccali.")),
                (L("Posso avere più isole?"),
                 L("Sì, una per abitudine, ognuna nel mondo che scegli: Foresta, Isola preistorica, Savana, Terre dei ghiacci, Giardino zen o Fattoria. Cambiano piante, animali e musica, le regole sono le stesse.")),
            ]),
            Topic(icon: "icloud.fill", tint: Theme.muted, title: L("Abbonamento e dati"), items: [
                (L("Serve un abbonamento?"),
                 L("La prima isola, i primi semi e il primo animale sono gratis. Per continuare serve l'abbonamento: lo gestisci o lo disdici dalle impostazioni del tuo account Apple, e «Ripristina acquisti» è nelle Impostazioni.")),
                (L("Dove sono le mie isole?"),
                 L("Su questo iPhone e nel tuo iCloud privato, senza account: tornano se reinstalli l'app o cambi iPhone.")),
                (L("Che notifiche ricevo?"),
                 L("Il promemoria all'ora che scegli (salta se hai già risposto), gli arrivi, i cuccioli, le evoluzioni, l'avviso di tempesta e i fenomeni più rari. Puoi rispondere direttamente dalla notifica.")),
            ]),
        ]
    }
}
