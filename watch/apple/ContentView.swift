import SwiftUI
import WatchKit

// =====================================================================
//  Ultimate Observer — Apple Watch companion
//  Standalone watchOS app: score, between-points clock (80s pull / 60s
//  readiness, end-aware), and ABBA gender ratio. Mirrors the timing
//  logic of the web app. watchOS 10+.
// =====================================================================

// MARK: - Models

enum Ratio: String, Codable, Hashable {
    case women = "W"
    case men   = "M"
    var short: String { self == .women ? "4W" : "4M" }
    var long:  String { self == .women ? "4W / 3M" : "4M / 3W" }
    var opposite: Ratio { self == .women ? .men : .women }
}

struct Point: Codable, Identifiable {
    var id = UUID()
    var by: Int            // 0 or 1
    var scoreA: Int
    var scoreB: Int
    var ratio: Ratio?
    var pullAt: Int?
}

final class GameState: ObservableObject {
    static let key = "observerwatch.v1"

    // --- Config (role-affecting setters recompute the running clock) ---
    @Published var teamNames: [String] = ["Team 1", "Team 2"] { didSet { saveIfLoaded() } }
    @Published var endLabels: [String] = ["End A", "End B"]   { didSet { saveIfLoaded() } }
    @Published var obsEnd: Int     = 0     { didSet { roleChanged() } }   // end the observer stands at
    @Published var startDTeam: Int = 0     { didSet { roleChanged() } }   // team pulling the 1st point
    @Published var startDEnd: Int  = 0     { didSet { roleChanged() } }   // end that 1st pull comes from
    @Published var ratioA: Ratio   = .women { didSet { saveIfLoaded() } } // point-1 ratio (the "A" in ABBA)
    @Published var roleFlip: Bool  = false  { didSet { roleChanged() } }  // manual parity correction
    @Published var pullLimit: Int  = 80     { didSet { roleChanged() } }
    @Published var readyLimit: Int = 60     { didSet { roleChanged() } }

    // --- Game ---
    @Published var score: [Int] = [0, 0]
    @Published var points: [Point] = []

    // --- Clock ---
    @Published var clockStart: Date? = nil
    @Published var pulled: Bool = false
    @Published var pulledAt: Double = 0
    @Published var deadline: Double = 80
    @Published var role: String = ""      // "PULL" or "READY"
    @Published var clockTeam: Int = 0

    private var loaded = true
    private var ticker: Timer?
    private var firedHaptics = Set<String>()

    // MARK: Derived

    var pointNo: Int { score[0] + score[1] + 1 }

    func ratio(for n: Int) -> Ratio { ((n / 2) % 2 == 0) ? ratioA : ratioA.opposite }
    var currentRatio: Ratio { ratio(for: pointNo) }

    /// (pulling team, end the pull comes from) for the point about to be played.
    /// Pull stays at the same end on an offence hold, flips on a defensive break.
    var pullStateNow: (team: Int, end: Int) {
        var team = startDTeam
        var end  = startDEnd
        for p in points {
            if p.by == team { end = 1 - end }   // pulling/defending team scored -> break -> flip
            team = p.by
        }
        if roleFlip { end = 1 - end }
        return (team, end)
    }
    var amPull: Bool { pullStateNow.end == obsEnd }

    func elapsed(at date: Date = Date()) -> Double {
        guard let s = clockStart else { return 0 }
        if pulled { return pulledAt }
        return max(0, date.timeIntervalSince(s))
    }

    // MARK: Actions

    func addGoal(_ by: Int) {
        let n = pointNo
        let r = ratio(for: n)
        let pa: Int? = (clockStart != nil && pulled) ? Int(pulledAt.rounded()) : nil
        score[by] += 1
        points.append(Point(by: by, scoreA: score[0], scoreB: score[1], ratio: r, pullAt: pa))
        WKInterfaceDevice.current().play(.click)
        startBetweenPoint()
    }

    func undoGoal() {
        guard let last = points.last else { return }
        points.removeLast()
        score[last.by] = max(0, score[last.by] - 1)
        stopClock()
        save()
    }

    func startBetweenPoint() {
        let st = pullStateNow
        let pull = st.end == obsEnd
        role = pull ? "PULL" : "READY"
        clockTeam = pull ? st.team : (1 - st.team)
        deadline = Double(pull ? pullLimit : readyLimit)
        clockStart = Date()
        pulled = false
        pulledAt = 0
        firedHaptics.removeAll()
        startTicking()
        save()
    }

    func markPull() {
        guard let s = clockStart else { return }
        if pulled {                                   // undo
            pulled = false
            clockStart = Date().addingTimeInterval(-pulledAt)
            startTicking()
        } else {
            pulledAt = max(0, Date().timeIntervalSince(s))
            pulled = true
            ticker?.invalidate()
            WKInterfaceDevice.current().play(pulledAt <= deadline ? .success : .failure)
        }
        save()
    }

    func stopClock() {
        ticker?.invalidate(); ticker = nil
        clockStart = nil; pulled = false
    }

    func resetGame() {
        score = [0, 0]; points = []
        stopClock()
        save()
    }

    func flipRole() { roleFlip.toggle() }   // didSet recomputes + saves

    // MARK: Ticking / haptics (foreground)

    func startTicking() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard let s = clockStart, !pulled else { return }
        let e = Date().timeIntervalSince(s)
        for lead in [20.0, 10.0] {
            let mark = deadline - lead
            let k = "lead\(Int(lead))"
            if mark > 0, e >= mark, !firedHaptics.contains(k) {
                firedHaptics.insert(k)
                WKInterfaceDevice.current().play(lead == 10 ? .notification : .start)
            }
        }
        if e >= deadline, !firedHaptics.contains("over") {
            firedHaptics.insert("over")
            WKInterfaceDevice.current().play(.failure)
        }
    }

    private func roleChanged() {
        guard loaded else { return }
        if clockStart != nil, !pulled {
            let st = pullStateNow
            let pull = st.end == obsEnd
            role = pull ? "PULL" : "READY"
            clockTeam = pull ? st.team : (1 - st.team)
            deadline = Double(pull ? pullLimit : readyLimit)
        }
        save()
    }
    private func saveIfLoaded() { if loaded { save() } }

    // MARK: Persistence (UserDefaults)

    struct Snapshot: Codable {
        var teamNames: [String]; var endLabels: [String]; var obsEnd: Int
        var startDTeam: Int; var startDEnd: Int; var ratioA: Ratio; var roleFlip: Bool
        var pullLimit: Int; var readyLimit: Int
        var score: [Int]; var points: [Point]
        var clockStart: Date?; var pulled: Bool; var pulledAt: Double
        var deadline: Double; var role: String; var clockTeam: Int
    }

    func save() {
        let s = Snapshot(teamNames: teamNames, endLabels: endLabels, obsEnd: obsEnd,
                         startDTeam: startDTeam, startDEnd: startDEnd, ratioA: ratioA, roleFlip: roleFlip,
                         pullLimit: pullLimit, readyLimit: readyLimit,
                         score: score, points: points,
                         clockStart: clockStart, pulled: pulled, pulledAt: pulledAt,
                         deadline: deadline, role: role, clockTeam: clockTeam)
        if let d = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(d, forKey: Self.key)
        }
    }

    static func load() -> GameState {
        let g = GameState()
        if let d = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode(Snapshot.self, from: d) {
            g.loaded = false
            g.teamNames = s.teamNames; g.endLabels = s.endLabels; g.obsEnd = s.obsEnd
            g.startDTeam = s.startDTeam; g.startDEnd = s.startDEnd; g.ratioA = s.ratioA; g.roleFlip = s.roleFlip
            g.pullLimit = s.pullLimit; g.readyLimit = s.readyLimit
            g.score = s.score; g.points = s.points
            g.clockStart = s.clockStart; g.pulled = s.pulled; g.pulledAt = s.pulledAt
            g.deadline = s.deadline; g.role = s.role; g.clockTeam = s.clockTeam
            g.loaded = true
        }
        if g.clockStart != nil && !g.pulled { g.startTicking() }
        return g
    }

    func name(_ i: Int) -> String { teamNames[i].isEmpty ? "Team \(i+1)" : teamNames[i] }
    func endName(_ i: Int) -> String { endLabels[i].isEmpty ? "End \(i == 0 ? "A" : "B")" : endLabels[i] }
}

func clockString(_ sec: Double) -> String {
    let neg = sec < 0
    let s = Int(abs(sec).rounded())
    return (neg ? "+" : "") + "\(s/60):" + String(format: "%02d", s % 60)
}

// MARK: - Main view

struct ContentView: View {
    @StateObject private var game = GameState.load()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    scoreRow
                    clockCard
                    goalButtons
                    if game.clockStart != nil {
                        Button { game.markPull() } label: {
                            Label(game.pulled ? "Pulled \(clockString(game.pulledAt)) — undo" : "Pull released",
                                  systemImage: game.pulled ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(game.pulled ? .green : .blue)
                        .controlSize(.small)
                    } else {
                        Button { game.startBetweenPoint() } label: {
                            Label("Start clock", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    bottomRow
                }
                .padding(.horizontal, 2)
            }
            .navigationTitle("Observer")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, game.clockStart != nil, !game.pulled { game.startTicking() }
        }
    }

    private var scoreRow: some View {
        HStack(spacing: 4) {
            Text("\(game.score[0])–\(game.score[1])").font(.title3.bold()).monospacedDigit()
            Spacer(minLength: 2)
            Text(game.currentRatio.short)
                .font(.caption2.bold())
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(game.currentRatio == .women ? Color.pink.opacity(0.30) : Color.blue.opacity(0.30))
                .clipShape(Capsule())
            Text("Pt \(game.pointNo)").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var clockCard: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let e = game.elapsed(at: context.date)
            let rem = game.deadline - e
            VStack(spacing: 2) {
                if game.clockStart == nil {
                    Text("no point running").font(.caption2).foregroundStyle(.secondary)
                    Text("–:–").font(.system(size: 38, weight: .bold, design: .rounded))
                } else if game.pulled {
                    Text("✓ PULLED · \(game.name(game.clockTeam))").font(.caption2).foregroundStyle(.green)
                    Text(clockString(game.pulledAt)).font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit().foregroundStyle(.green)
                    Text(game.pulledAt <= game.deadline ? "pull on time" : "pull late")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("\(game.role) · \(game.name(game.clockTeam))").font(.caption2).foregroundStyle(.secondary)
                    Text(clockString(e)).font(.system(size: 38, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(rem > 0 ? "\(Int(ceil(rem)))s \(game.role == "PULL" ? "to pull" : "for hand")"
                                 : "OVER +\(clockString(-rem))")
                        .font(.caption.bold())
                        .foregroundStyle(rem <= 0 ? .red : (rem <= 12 ? .orange : .primary))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(clockBG(rem: rem))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func clockBG(rem: Double) -> Color {
        if game.clockStart == nil { return Color.gray.opacity(0.15) }
        if game.pulled { return Color.green.opacity(0.18) }
        if rem <= 0 { return Color.red.opacity(0.22) }
        if rem <= 12 { return Color.orange.opacity(0.20) }
        return Color.blue.opacity(0.18)
    }

    private var goalButtons: some View {
        HStack(spacing: 6) {
            goalBtn(0); goalBtn(1)
        }
    }
    private func goalBtn(_ i: Int) -> some View {
        Button { game.addGoal(i) } label: {
            VStack(spacing: 0) {
                Text("＋").font(.headline)
                Text(game.name(i)).font(.caption2).lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(i == 0 ? .blue : .indigo)
    }

    private var bottomRow: some View {
        HStack {
            Button { game.undoGoal() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .controlSize(.small)
            Spacer()
            NavigationLink { SettingsView(game: game) } label: { Image(systemName: "gearshape.fill") }
                .controlSize(.small)
        }
        .font(.caption2)
        .buttonStyle(.bordered)
        .padding(.top, 2)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject var game: GameState

    var body: some View {
        Form {
            Section("Teams") {
                TextField("Team 1", text: $game.teamNames[0])
                TextField("Team 2", text: $game.teamNames[1])
            }
            Section("Ends") {
                TextField("End A", text: $game.endLabels[0])
                TextField("End B", text: $game.endLabels[1])
                Picker("You're at", selection: $game.obsEnd) {
                    Text(game.endName(0)).tag(0)
                    Text(game.endName(1)).tag(1)
                }
            }
            Section("Game start") {
                Picker("Pulls first", selection: $game.startDTeam) {
                    Text(game.name(0)).tag(0)
                    Text(game.name(1)).tag(1)
                }
                Picker("Pull from", selection: $game.startDEnd) {
                    Text(game.endName(0)).tag(0)
                    Text(game.endName(1)).tag(1)
                }
                Picker("Point 1 ratio", selection: $game.ratioA) {
                    Text("4W / 3M").tag(Ratio.women)
                    Text("4M / 3W").tag(Ratio.men)
                }
            }
            Section("Role") {
                LabeledContent("Now timing", value: game.amPull ? "PULL \(game.pullLimit)s" : "READY \(game.readyLimit)s")
                Button("Role looks wrong — flip") { game.flipRole() }
            }
            Section {
                Button("Reset game", role: .destructive) { game.resetGame() }
            }
        }
        .navigationTitle("Setup")
    }
}
