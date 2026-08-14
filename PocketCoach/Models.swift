import Foundation

enum PlayerRole: String, Codable, CaseIterable, Identifiable {
    case handler, cutter, flex
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .handler: "Handler"
        case .cutter: "Cutter"
        case .flex: "Flex"
        }
    }
    var shortLabel: String {
        switch self {
        case .handler: "H"
        case .cutter: "C"
        case .flex: "F"
        }
    }
}

enum PlayerStatus: String, Codable, CaseIterable, Identifiable {
    case active, injured, out
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .active: "Active"
        case .injured: "Injured"
        case .out: "Out"
        }
    }
    var isSideline: Bool { self == .injured || self == .out }
}

enum PodId: String, Codable, CaseIterable, Identifiable, Hashable {
    case h1, h2, c1, c2, c3
    var id: String { rawValue }
    var displayName: String { rawValue.uppercased() }
    var isHandler: Bool { self == .h1 || self == .h2 }
    var capacity: Int { isHandler ? 3 : 4 }
    var sortOrder: Int {
        switch self {
        case .h1: 0
        case .h2: 1
        case .c1: 2
        case .c2: 3
        case .c3: 4
        }
    }
}

struct Player: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var number: String?
    var role: PlayerRole
    var status: PlayerStatus

    init(
        id: UUID = UUID(),
        name: String,
        number: String? = nil,
        role: PlayerRole,
        status: PlayerStatus = .active
    ) {
        self.id = id
        self.name = name
        self.number = number
        self.role = role
        self.status = status
    }
}

struct Lineup: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var pods: [PodId: [UUID]]
    /// Ordered fill list per short pod — rotate these people in so time stays even.
    var fillRotation: [PodId: [UUID]]
    var fillPointers: [PodId: Int]

    init(
        id: UUID = UUID(),
        name: String,
        pods: [PodId: [UUID]] = [:],
        fillRotation: [PodId: [UUID]] = [:],
        fillPointers: [PodId: Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.pods = pods
        self.fillRotation = fillRotation
        self.fillPointers = fillPointers
    }

    func playerIds(in pod: PodId) -> [UUID] {
        pods[pod] ?? []
    }

    func fillers(for pod: PodId) -> [UUID] {
        fillRotation[pod] ?? []
    }
}

struct LineupSnapshot: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var savedAt: Date
    var lineup: Lineup

    init(id: UUID = UUID(), name: String, savedAt: Date = Date(), lineup: Lineup) {
        self.id = id
        self.name = name
        self.savedAt = savedAt
        self.lineup = lineup
    }
}

enum DefenseKind: String, Codable, CaseIterable, Identifiable {
    case person, clam, cup, junk, kill
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .person: "Person"
        case .clam: "Trap / Clam"
        case .cup: "Cup"
        case .junk: "Junk"
        case .kill: "Kill"
        }
    }
}

enum Force: String, Codable, CaseIterable, Identifiable {
    case flick, backhand, straight
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .flick: "Flick"
        case .backhand: "Backhand"
        case .straight: "Straight up"
        }
    }
    var shortLabel: String {
        switch self {
        case .flick: "Flick"
        case .backhand: "BH"
        case .straight: "SU"
        }
    }
}

struct SavedLine: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var defenseKind: DefenseKind
    var force: Force
    var playerIds: [UUID]

    init(
        id: UUID = UUID(),
        name: String,
        defenseKind: DefenseKind,
        force: Force = .backhand,
        playerIds: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.defenseKind = defenseKind
        self.force = force
        self.playerIds = playerIds
    }
}

struct CustomLine: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var playerIds: [UUID]

    init(id: UUID = UUID(), name: String, playerIds: [UUID] = []) {
        self.id = id
        self.name = name
        self.playerIds = playerIds
    }
}

enum WindGameType: String, Codable, CaseIterable, Identifiable {
    case none, crosswind, upwindDownwind
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none: "No wind"
        case .crosswind: "Crosswind"
        case .upwindDownwind: "Upwind / downwind"
        }
    }
}

enum WindDirection: String, Codable, CaseIterable, Identifiable {
    case leftToRight, rightToLeft
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .leftToRight: "Left → right"
        case .rightToLeft: "Right → left"
        }
    }
}

enum WindSpeed: String, Codable, CaseIterable, Identifiable {
    case calm, moderate, strong
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .calm: "Calm"
        case .moderate: "Moderate"
        case .strong: "Strong"
        }
    }
}

struct WindState: Codable, Hashable {
    var gameType: WindGameType
    var direction: WindDirection
    var speed: WindSpeed
    var pointIsUpwind: Bool

    static let `default` = WindState(
        gameType: .none,
        direction: .leftToRight,
        speed: .calm,
        pointIsUpwind: false
    )
}

struct WindRule: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var gameType: WindGameType
    var direction: WindDirection?
    var minSpeed: WindSpeed?
    var pointIsUpwind: Bool?
    var savedLineId: UUID
    var forceOverride: Force?

    init(
        id: UUID = UUID(),
        name: String,
        gameType: WindGameType,
        direction: WindDirection? = nil,
        minSpeed: WindSpeed? = nil,
        pointIsUpwind: Bool? = nil,
        savedLineId: UUID,
        forceOverride: Force? = nil
    ) {
        self.id = id
        self.name = name
        self.gameType = gameType
        self.direction = direction
        self.minSpeed = minSpeed
        self.pointIsUpwind = pointIsUpwind
        self.savedLineId = savedLineId
        self.forceOverride = forceOverride
    }
}

enum LineSource: Codable, Equatable, Hashable {
    case rotation
    case savedLine(UUID)
    case custom(UUID)
    case manual
}

enum NextLineCardKind: String, Codable, Hashable {
    case even, zone, custom
}

struct NextLineCard: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: NextLineCardKind
    /// For even: offset index. For zone/custom: related id as string.
    var evenOffset: Int
    var relatedId: UUID?

    init(id: UUID = UUID(), kind: NextLineCardKind, evenOffset: Int = 0, relatedId: UUID? = nil) {
        self.id = id
        self.kind = kind
        self.evenOffset = evenOffset
        self.relatedId = relatedId
    }
}

struct TournamentSettings: Codable, Hashable {
    var gameTo: Int
    var halfCapMinutes: Int
    var softCapMinutes: Int
    var hardCapMinutes: Int

    static let `default` = TournamentSettings(
        gameTo: 15,
        halfCapMinutes: 45,
        softCapMinutes: 70,
        hardCapMinutes: 80
    )
}

enum FlipPreference: String, Codable, CaseIterable, Identifiable {
    case defense, offense, startUpwind, startDownwind, receive, pull
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .defense: "Start on defense"
        case .offense: "Start on offense"
        case .startUpwind: "Start upwind"
        case .startDownwind: "Start downwind"
        case .receive: "Receive"
        case .pull: "Pull"
        }
    }
    var detail: String {
        switch self {
        case .defense: "If we win the flip, take D."
        case .offense: "If we win the flip, take O."
        case .startUpwind: "If we win, choose the upwind end first."
        case .startDownwind: "If we win, choose the downwind end first."
        case .receive: "If we win, receive the pull."
        case .pull: "If we win, pull."
        }
    }
}

enum TimeScope: String, Codable, CaseIterable, Identifiable {
    case game, day, weekend
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .game: "This game"
        case .day: "Today"
        case .weekend: "All games"
        }
    }
}

struct GameSession: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var lineupId: UUID
    var usScore: Int
    var themScore: Int
    var hPointer: Int
    var cPointer: Int
    var currentLineSource: LineSource
    var wind: WindState
    var specialPoints: Int
    var evenPoints: Int
    var lastConfirmedAt: Date?
    var podOutings: [String: Int]
    var playerPoints: [String: Int]
    var onNowOverride: [UUID]?
    var nextLineCards: [NextLineCard]
    var customLines: [CustomLine]
    var fillPointers: [String: Int]

    static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    var dayKey: String { Self.dayKey(for: createdAt) }

    var totalPoints: Int { evenPoints + specialPoints }

    var specialRatio: Double {
        guard totalPoints > 0 else { return 0 }
        return Double(specialPoints) / Double(totalPoints)
    }

    func outings(for pod: PodId) -> Int {
        podOutings[pod.rawValue] ?? 0
    }

    func points(for playerId: UUID) -> Int {
        playerPoints[playerId.uuidString] ?? 0
    }

    static func fresh(name: String, lineupId: UUID, wind: WindState = .default) -> GameSession {
        GameSession(
            id: UUID(),
            name: name,
            createdAt: Date(),
            lineupId: lineupId,
            usScore: 0,
            themScore: 0,
            hPointer: 0,
            cPointer: 0,
            currentLineSource: .rotation,
            wind: wind,
            specialPoints: 0,
            evenPoints: 0,
            lastConfirmedAt: nil,
            podOutings: [:],
            playerPoints: [:],
            onNowOverride: nil,
            nextLineCards: Self.defaultNextCards(),
            customLines: [],
            fillPointers: [:]
        )
    }

    static func defaultNextCards() -> [NextLineCard] {
        [
            NextLineCard(kind: .even, evenOffset: 0),
            NextLineCard(kind: .even, evenOffset: 1),
            NextLineCard(kind: .even, evenOffset: 2)
        ]
    }
}

struct Team: Codable, Hashable {
    var name: String
    var joinCode: String
    var activeLineupId: UUID
    var activeGameId: UUID
    var players: [Player]
    var lineups: [Lineup]
    var lineupHistory: [LineupSnapshot]
    var savedLines: [SavedLine]
    var windRules: [WindRule]
    var games: [GameSession]
    var tournament: TournamentSettings
    var flipPreference: FlipPreference
    var flipNotes: String
}

enum SeedIDs {
    static let alex = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-000000000001")!
    static let blair = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-000000000002")!
    static let casey = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-000000000003")!
    static let drew = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-000000000004")!
    static let eden = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-000000000005")!
    static let fin = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-000000000006")!
    static let gia = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-000000000007")!
    static let harper = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-000000000008")!
    static let indy = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-000000000009")!
    static let jules = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-00000000000a")!
    static let kai = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-00000000000b")!
    static let lane = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-00000000000c")!
    static let morgan = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-00000000000d")!
    static let nico = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-00000000000e")!
    static let oak = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-00000000000f")!
    static let parker = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-000000000010")!
    static let quinn = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-000000000011")!
    static let remy = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-000000000012")!

    static let lineupWeekend = UUID(uuidString: "bbbbbbbb-bbbb-4ccc-8ddd-000000000001")!
    static let game1 = UUID(uuidString: "dddddddd-bbbb-4ccc-8ddd-000000000001")!
    static let clam1 = UUID(uuidString: "cccccccc-bbbb-4ccc-8ddd-000000000001")!
    static let clam2 = UUID(uuidString: "cccccccc-bbbb-4ccc-8ddd-000000000002")!
    static let clam3 = UUID(uuidString: "cccccccc-bbbb-4ccc-8ddd-000000000003")!
    static let cup = UUID(uuidString: "cccccccc-bbbb-4ccc-8ddd-000000000004")!
    static let person = UUID(uuidString: "cccccccc-bbbb-4ccc-8ddd-000000000005")!
    static let junk = UUID(uuidString: "cccccccc-bbbb-4ccc-8ddd-000000000006")!
    static let kill = UUID(uuidString: "cccccccc-bbbb-4ccc-8ddd-000000000007")!
}

extension Team {
    static func makeJoinCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in chars.randomElement() })
    }

    static func sample() -> Team {
        let players: [Player] = [
            Player(id: SeedIDs.alex, name: "Alex", number: "4", role: .handler),
            Player(id: SeedIDs.blair, name: "Blair", number: "11", role: .handler),
            Player(id: SeedIDs.casey, name: "Casey", number: "7", role: .handler),
            Player(id: SeedIDs.drew, name: "Drew", number: "2", role: .handler),
            Player(id: SeedIDs.eden, name: "Eden", number: "19", role: .handler),
            Player(id: SeedIDs.fin, name: "Fin", number: "8", role: .handler),
            Player(id: SeedIDs.gia, name: "Gia", number: "14", role: .cutter),
            Player(id: SeedIDs.harper, name: "Harper", number: "21", role: .cutter),
            Player(id: SeedIDs.indy, name: "Indy", number: "5", role: .cutter),
            Player(id: SeedIDs.jules, name: "Jules", number: "33", role: .cutter),
            Player(id: SeedIDs.kai, name: "Kai", number: "9", role: .cutter),
            Player(id: SeedIDs.lane, name: "Lane", number: "16", role: .cutter),
            Player(id: SeedIDs.morgan, name: "Morgan", number: "27", role: .cutter),
            Player(id: SeedIDs.nico, name: "Nico", number: "3", role: .cutter),
            Player(id: SeedIDs.oak, name: "Oak", number: "18", role: .cutter),
            Player(id: SeedIDs.parker, name: "Parker", number: "22", role: .cutter),
            Player(id: SeedIDs.quinn, name: "Quinn", number: "6", role: .flex),
            Player(id: SeedIDs.remy, name: "Remy", number: "12", role: .cutter)
        ]

        let weekend = Lineup(
            id: SeedIDs.lineupWeekend,
            name: "Weekend",
            pods: [
                .h1: [SeedIDs.alex, SeedIDs.blair, SeedIDs.casey],
                .h2: [SeedIDs.drew, SeedIDs.eden, SeedIDs.fin],
                .c1: [SeedIDs.gia, SeedIDs.harper, SeedIDs.indy, SeedIDs.jules],
                .c2: [SeedIDs.kai, SeedIDs.lane, SeedIDs.morgan, SeedIDs.nico],
                .c3: [SeedIDs.oak, SeedIDs.parker, SeedIDs.quinn, SeedIDs.remy]
            ],
            fillRotation: [
                .c1: [SeedIDs.kai, SeedIDs.oak],
                .c2: [SeedIDs.gia, SeedIDs.oak],
                .c3: [SeedIDs.harper, SeedIDs.lane],
                .h1: [SeedIDs.drew],
                .h2: [SeedIDs.alex]
            ]
        )

        var game = GameSession.fresh(name: "Game 1", lineupId: SeedIDs.lineupWeekend)
        game.id = SeedIDs.game1
        game.nextLineCards = [
            NextLineCard(kind: .even, evenOffset: 0),
            NextLineCard(kind: .even, evenOffset: 1),
            NextLineCard(kind: .zone, relatedId: SeedIDs.clam1),
            NextLineCard(kind: .zone, relatedId: SeedIDs.clam2),
            NextLineCard(kind: .zone, relatedId: SeedIDs.clam3),
            NextLineCard(kind: .zone, relatedId: SeedIDs.cup),
            NextLineCard(kind: .zone, relatedId: SeedIDs.kill)
        ]

        let saved: [SavedLine] = [
            SavedLine(id: SeedIDs.clam1, name: "Clam 1", defenseKind: .clam, force: .backhand,
                      playerIds: [SeedIDs.alex, SeedIDs.drew, SeedIDs.gia, SeedIDs.harper, SeedIDs.kai, SeedIDs.oak, SeedIDs.quinn]),
            SavedLine(id: SeedIDs.clam2, name: "Clam 2", defenseKind: .clam, force: .backhand,
                      playerIds: [SeedIDs.blair, SeedIDs.eden, SeedIDs.indy, SeedIDs.jules, SeedIDs.lane, SeedIDs.parker, SeedIDs.nico]),
            SavedLine(id: SeedIDs.clam3, name: "Clam 3", defenseKind: .clam, force: .flick,
                      playerIds: [SeedIDs.casey, SeedIDs.fin, SeedIDs.morgan, SeedIDs.remy, SeedIDs.harper, SeedIDs.oak, SeedIDs.quinn]),
            SavedLine(id: SeedIDs.cup, name: "Cup", defenseKind: .cup, force: .backhand,
                      playerIds: [SeedIDs.casey, SeedIDs.fin, SeedIDs.gia, SeedIDs.morgan, SeedIDs.oak, SeedIDs.remy, SeedIDs.quinn]),
            SavedLine(id: SeedIDs.person, name: "Person", defenseKind: .person, force: .backhand,
                      playerIds: [SeedIDs.alex, SeedIDs.blair, SeedIDs.gia, SeedIDs.harper, SeedIDs.kai, SeedIDs.lane, SeedIDs.oak]),
            SavedLine(id: SeedIDs.junk, name: "Junk", defenseKind: .junk, force: .flick,
                      playerIds: [SeedIDs.drew, SeedIDs.eden, SeedIDs.indy, SeedIDs.jules, SeedIDs.morgan, SeedIDs.parker, SeedIDs.remy]),
            SavedLine(id: SeedIDs.kill, name: "Kill", defenseKind: .kill, force: .flick,
                      playerIds: [SeedIDs.alex, SeedIDs.casey, SeedIDs.gia, SeedIDs.kai, SeedIDs.oak, SeedIDs.quinn, SeedIDs.harper])
        ]

        let rules: [WindRule] = [
            WindRule(name: "Crosswind L→R → Clam · BH", gameType: .crosswind, direction: .leftToRight,
                     savedLineId: SeedIDs.clam1, forceOverride: .backhand),
            WindRule(name: "Crosswind R→L → Clam · Flick", gameType: .crosswind, direction: .rightToLeft,
                     savedLineId: SeedIDs.clam2, forceOverride: .flick),
            WindRule(name: "No / light wind → Person", gameType: .none,
                     savedLineId: SeedIDs.person, forceOverride: .backhand),
            WindRule(name: "They attack downwind → Junk", gameType: .upwindDownwind, minSpeed: .strong,
                     pointIsUpwind: false, savedLineId: SeedIDs.junk),
            WindRule(name: "They attack upwind → Cup", gameType: .upwindDownwind, minSpeed: .strong,
                     pointIsUpwind: true, savedLineId: SeedIDs.cup)
        ]

        return Team(
            name: "Pocket Coach",
            joinCode: makeJoinCode(),
            activeLineupId: SeedIDs.lineupWeekend,
            activeGameId: SeedIDs.game1,
            players: players,
            lineups: [weekend],
            lineupHistory: [],
            savedLines: saved,
            windRules: rules,
            games: [game],
            tournament: .default,
            flipPreference: .defense,
            flipNotes: "Prefer D if wind is calm. Take upwind if it's blowing."
        )
    }
}
