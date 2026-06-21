import SwiftUI
import WatchKit

// =====================================================================
//  Ultimate Observer — Apple Watch companion (standalone, watchOS 10+)
//  Score · count-up STOPWATCH between points · COUNTDOWN for the 5-min
//  half · gender ratio with 1st/2nd-of-pair · timeout. End-aware role
//  with the 2nd-half reversal, matching the web app.
// =====================================================================

enum Ratio: String, Codable, Hashable {
    case women = "W", men = "M"
    var short: String { self == .women ? "4W" : "4M" }
    var opposite: Ratio { self == .women ? .men : .women }
}
enum ClockMode: String, Codable { case none, point, half, timeout }

struct Point: Codable, Identifiable {
    var id = UUID()
    var by: Int
    var half: Int
    var ratio: Ratio?
}

final class GameState: ObservableObject {
    static let key = "observerwatch.v2"

    // --- Config ---
    @Published var teamNames = ["Team 1", "Team 2"] { didSet { saveIfLoaded() } }
    @Published var endLabels = ["Rocks", "Forest"]  { didSet { saveIfLoaded() } }
    @Published var obsEnd = 0      { didSet { roleChanged() } }
    @Published var startDTeam = 0  { didSet { roleChanged() } }   // team pulling 1st point
    @Published var startDEnd = 0   { didSet { roleChanged() } }   // end the 1st pull comes from
    @Published var ratioA: Ratio = .women { didSet { saveIfLoaded() } }
    @Published var roleFlip = false { didSet { roleChanged() } }
    @Published var halfTarget = 8  { didSet { saveIfLoaded() } }
    @Published var halfLen = 5     { didSet { saveIfLoaded() } }  // minutes
    @Published var pullLimit = 80  { didSet { roleChanged() } }
    @Published var readyLimit = 60 { didSet { roleChanged() } }
    @Published var toLen = 70      { didSet { saveIfLoaded() } }

    // --- Game ---
    @Published var score = [0, 0]
    @Published var points: [Point] = []
    @Published var half = 1

    // --- Clock ---
    @Published var mode: ClockMode = .none
    @Published var clockStart: Date? = nil
    @Published var deadline = 80.0       // point mode: my 80/60 deadline
    @Published var role = ""             // "PULL" / "READY"
    @Published var clockTeam = 0
    @Published var auxBase = 0.0         // half / timeout countdown length
    @Published var auxLabel = ""

    private var loaded = true
    private var ticker: Timer?
    private var fired = Set<String>()

    // --- Derived ---
    func other(_ i: Int) -> Int { i == 0 ? 1 : 0 }
    var pointNo: Int { score[0] + score[1] + 1 }
    func ratio(for n: Int) -> Ratio { ((n / 2) % 2 == 0) ? ratioA : ratioA.opposite }
    func ratioSeq(_ n: Int) -> String { (n == 1) ? "1st" : (n % 2 == 0 ? "1st" : "2nd") }
    var currentRatio: Ratio { ratio(for: pointNo) }
    var currentSeq: String { ratioSeq(pointNo) }

    var secondHalfPullTeam: Int { startDTeam == 0 ? 1 : 0 }   // team that received opening now pulls
    var pullStateNow: (team: Int, end: Int) {
        var team: Int, end: Int, replay: [Point]
        if half == 2 {                                       // 2nd-half reversal reset
            team = secondHalfPullTeam; end = startDEnd
            if let h2 = points.firstIndex(where: { $0.half == 2 }) { replay = Array(points[h2...]) } else { replay = [] }
        } else {
            team = startDTeam; end = startDEnd; replay = points
        }
        for p in replay { if p.by == team { end = other(end) }; team = p.by }
        if roleFlip { end = other(end) }
        return (team, end)
    }
    var amPull: Bool { pullStateNow.end == obsEnd }

    func elapsed(at d: Date = Date()) -> Double {
        guard let s = clockStart else { return 0 }
        return max(0, d.timeIntervalSince(s))
    }

    // --- Actions ---
    func addGoal(_ by: Int) {
        let n = pointNo, r = ratio(for: n)
        score[by] += 1
        points.append(Point(by: by, half: half, ratio: r))
        WKInterfaceDevice.current().play(.click)
        if half == 1 && (score[0] >= halfTarget || score[1] >= halfTarget) { half = 2 }
        startBetweenPoint()
    }
    func undo() {
        guard let l = points.last else { return }
        points.removeLast(); score[l.by] = max(0, score[l.by] - 1)
        half = points.last?.half ?? 1
        stop(); save()
    }
    func startBetweenPoint() {
        let st = pullStateNow, pull = (st.end == obsEnd)
        role = pull ? "PULL" : "READY"; clockTeam = pull ? st.team : other(st.team)
        deadline = Double(pull ? pullLimit : readyLimit)
        mode = .point; clockStart = Date(); fired.removeAll(); startTicking(); save()
    }
    func startHalftime() {
        if half == 1 { half = 2 }
        mode = .half; auxBase = Double(halfLen * 60); clockStart = Date(); fired.removeAll(); startTicking(); save()
    }
    func startTimeout() {
        // Between-points TO: count down (toLen − elapsed-at-call); when 0, the regular
        // 60/80 window begins. So the regular window restarts toLen sec after the goal.
        let E = (mode == .point) ? elapsed() : 0
        mode = .timeout; auxBase = max(0, Double(toLen) - E); clockStart = Date(); fired.removeAll(); startTicking(); save()
    }
    func stop() { ticker?.invalidate(); ticker = nil; mode = .none; clockStart = nil; save() }
    func resetGame() { score = [0, 0]; points = []; half = 1; stop() }
    func flipRole() { roleFlip.toggle() }

    // --- Ticking / haptics ---
    func startTicking() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
    }
    private func tick() {
        guard let s = clockStart else { return }
        let e = Date().timeIntervalSince(s)
        if mode == .point {
            for lead in [20.0, 10.0] {
                let m = deadline - lead, k = "d\(Int(lead))"
                if m > 0, e >= m, !fired.contains(k) { fired.insert(k); WKInterfaceDevice.current().play(lead == 10 ? .notification : .start) }
            }
            if e >= deadline, !fired.contains("over") { fired.insert("over"); WKInterfaceDevice.current().play(.failure) }
        } else if mode == .half || mode == .timeout {
            for lead in [60.0, 10.0] {
                let m = auxBase - lead, k = "a\(Int(lead))"
                if m > 0, e >= m, !fired.contains(k) { fired.insert(k); WKInterfaceDevice.current().play(.notification) }
            }
            if e >= auxBase, !fired.contains("end") {
                fired.insert("end"); WKInterfaceDevice.current().play(.failure)
                if mode == .timeout { startBetweenPoint() }   // regular 60/80 window begins
            }
        }
    }
    private func roleChanged() {
        guard loaded else { return }
        if mode == .point, clockStart != nil {
            let st = pullStateNow, pull = (st.end == obsEnd)
            role = pull ? "PULL" : "READY"; clockTeam = pull ? st.team : other(st.team)
            deadline = Double(pull ? pullLimit : readyLimit)
        }
        save()
    }
    private func saveIfLoaded() { if loaded { save() } }

    // --- Persistence ---
    struct Snap: Codable {
        var teamNames: [String]; var endLabels: [String]; var obsEnd: Int; var startDTeam: Int; var startDEnd: Int
        var ratioA: Ratio; var roleFlip: Bool; var halfTarget: Int; var halfLen: Int; var pullLimit: Int; var readyLimit: Int; var toLen: Int
        var score: [Int]; var points: [Point]; var half: Int
        var mode: ClockMode; var clockStart: Date?; var deadline: Double; var role: String; var clockTeam: Int; var auxBase: Double
    }
    func save() {
        let s = Snap(teamNames: teamNames, endLabels: endLabels, obsEnd: obsEnd, startDTeam: startDTeam, startDEnd: startDEnd,
                     ratioA: ratioA, roleFlip: roleFlip, halfTarget: halfTarget, halfLen: halfLen, pullLimit: pullLimit, readyLimit: readyLimit, toLen: toLen,
                     score: score, points: points, half: half,
                     mode: mode, clockStart: clockStart, deadline: deadline, role: role, clockTeam: clockTeam, auxBase: auxBase)
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: Self.key) }
    }
    static func load() -> GameState {
        let g = GameState()
        if let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(Snap.self, from: d) {
            g.loaded = false
            g.teamNames = s.teamNames; g.endLabels = s.endLabels; g.obsEnd = s.obsEnd; g.startDTeam = s.startDTeam; g.startDEnd = s.startDEnd
            g.ratioA = s.ratioA; g.roleFlip = s.roleFlip; g.halfTarget = s.halfTarget; g.halfLen = s.halfLen
            g.pullLimit = s.pullLimit; g.readyLimit = s.readyLimit; g.toLen = s.toLen
            g.score = s.score; g.points = s.points; g.half = s.half
            g.mode = s.mode; g.clockStart = s.clockStart; g.deadline = s.deadline; g.role = s.role; g.clockTeam = s.clockTeam; g.auxBase = s.auxBase
            g.loaded = true
        }
        if g.clockStart != nil && g.mode != .none { g.startTicking() }
        return g
    }

    func name(_ i: Int) -> String { teamNames[i].isEmpty ? "Team \(i+1)" : teamNames[i] }
    func endName(_ i: Int) -> String { endLabels[i].isEmpty ? "End \(i == 0 ? "A" : "B")" : endLabels[i] }
}

func clockString(_ sec: Double) -> String {
    let neg = sec < 0, s = Int(abs(sec).rounded())
    return (neg ? "+" : "") + "\(s/60):" + String(format: "%02d", s % 60)
}

// MARK: - Main view

struct ContentView: View {
    @StateObject private var game = GameState.load()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 7) {
                    scoreRow
                    clockCard
                    HStack(spacing: 6) { goalBtn(0); goalBtn(1) }
                    HStack(spacing: 6) {
                        smallBtn("Timeout", "pause.circle") { game.startTimeout() }
                        smallBtn("Half \(game.halfLen)m", "clock") { game.startHalftime() }
                    }
                    HStack(spacing: 6) {
                        smallBtn("Start pt", "play") { game.startBetweenPoint() }
                        smallBtn("Undo", "arrow.uturn.backward") { game.undo() }
                    }
                    NavigationLink { SettingsView(game: game) } label: {
                        Label("Setup", systemImage: "gearshape.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }
                .padding(.horizontal, 2)
            }
            .navigationTitle("Observer")
        }
        .onChange(of: scenePhase) { _, p in
            if p == .active, game.clockStart != nil, game.mode != .none { game.startTicking() }
        }
    }

    private var scoreRow: some View {
        HStack(spacing: 4) {
            Text("\(game.score[0])–\(game.score[1])").font(.title3.bold()).monospacedDigit()
            Spacer(minLength: 2)
            Text("\(game.currentRatio.short) \(game.currentSeq)")
                .font(.caption2.bold())
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(game.currentRatio == .women ? Color.pink.opacity(0.30) : Color.blue.opacity(0.30))
                .clipShape(Capsule())
            Text("H\(game.half)·\(game.pointNo)").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var clockCard: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let e = game.elapsed(at: context.date)
            VStack(spacing: 2) {
                switch game.mode {
                case .point:
                    let rem = game.deadline - e
                    Text("\(game.role) · \(game.name(game.clockTeam))").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    Text(clockString(e)).font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(rem > 0 ? "\(Int(ceil(rem)))s \(game.role == "PULL" ? "to pull" : "for hand")" : "OVER +\(clockString(-rem))")
                        .font(.caption.bold())
                        .foregroundStyle(rem <= 0 ? .red : (rem <= 12 ? .orange : .secondary))
                case .half, .timeout:
                    let rem = game.auxBase - e
                    Text(game.mode == .half ? "HALFTIME" : "TIMEOUT").font(.caption2).foregroundStyle(.secondary)
                    Text(clockString(max(0, rem))).font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(rem <= 0 ? .red : .primary)
                    Text(game.mode == .timeout ? "until regular window" : (rem > 0 ? "remaining" : "time up"))
                        .font(.caption2).foregroundStyle(.secondary)
                case .none:
                    Text("no point running").font(.caption2).foregroundStyle(.secondary)
                    Text("–:–").font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("tap Start pt or + a goal").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 6)
            .background(clockBG(e)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    private func clockBG(_ e: Double) -> Color {
        switch game.mode {
        case .none: return Color.gray.opacity(0.15)
        case .point:
            let rem = game.deadline - e
            if rem <= 0 { return Color.red.opacity(0.22) }
            if rem <= 12 { return Color.orange.opacity(0.20) }
            return Color.blue.opacity(0.18)
        case .half, .timeout:
            return (game.auxBase - e) <= 0 ? Color.red.opacity(0.22) : Color.green.opacity(0.16)
        }
    }

    private func goalBtn(_ i: Int) -> some View {
        Button { game.addGoal(i) } label: {
            VStack(spacing: 0) {
                Text("＋").font(.headline)
                Text(game.name(i)).font(.caption2).lineLimit(1).minimumScaleFactor(0.6)
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.borderedProminent).tint(i == 0 ? .blue : .indigo)
    }
    private func smallBtn(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.caption2).frame(maxWidth: .infinity) }
            .buttonStyle(.bordered).controlSize(.small)
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
                    Text(game.endName(0)).tag(0); Text(game.endName(1)).tag(1)
                }
            }
            Section("Game start") {
                Picker("Pulls first", selection: $game.startDTeam) {
                    Text(game.name(0)).tag(0); Text(game.name(1)).tag(1)
                }
                Picker("Pull from", selection: $game.startDEnd) {
                    Text(game.endName(0)).tag(0); Text(game.endName(1)).tag(1)
                }
                Picker("Point 1 ratio", selection: $game.ratioA) {
                    Text("4W / 3M").tag(Ratio.women); Text("4M / 3W").tag(Ratio.men)
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
