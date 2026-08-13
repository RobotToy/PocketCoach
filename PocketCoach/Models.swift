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
    var weekendPoints: Int
    var gamePoints: Int
    /// When these pods are short, this player can fill them.
    var floaterPodIds: [PodId]

    init(
        id: UUID = UUID(),
        name: String,
        number: String? = nil,
        role: PlayerRole,
        status: PlayerStatus = .active,
        weekendPoints: Int = 0,
        gamePoints: Int = 0,
        floaterPodIds: [PodId] = []
    ) {
        self.id = id
        self.name = name
        self.number = number
        self.role = role
        self.status = status
        self.weekendPoints = weekendPoints
        self.gamePoints = gamePoints
        self.floaterPodIds = floaterPodIds
    }
}

struct Lineup: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var pods: [PodId: [UUID]]
    var collapsedCutterPods: Bool

    init(
        id: UUID = UUID(),
        name: String,
        pods: [PodId: [UUID]] = [:],
        collapsedCutterPods: Bool = false
    ) {
        self.id = id
        self.name = name
        self.pods = pods
        self.collapsedCutterPods = collapsedCutterPods
    }

    func playerIds(in pod: PodId) -> [UUID] {
        pods[pod] ?? []
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
        force: Force,
        playerIds: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.defenseKind = defenseKind
        self.force = force
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
    /// True when we are defending the upwind end (they attack into the wind).
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
}

struct GameState: Codable, Hashable {
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

    static let `default` = GameState(
        usScore: 0,
        themScore: 0,
        hPointer: 0,
        cPointer: 0,
        currentLineSource: .rotation,
        wind: .default,
        specialPoints: 0,
        evenPoints: 0,
        lastConfirmedAt: nil,
        podOutings: [:]
    )

    var totalPoints: Int { evenPoints + specialPoints }

    var specialRatio: Double {
        guard totalPoints > 0 else { return 0 }
        return Double(specialPoints) / Double(totalPoints)
    }

    func outings(for pod: PodId) -> Int {
        podOutings[pod.rawValue] ?? 0
    }
}

struct Team: Codable, Hashable {
    var name: String
    var joinCode: String
    var activeLineupId: UUID
    var players: [Player]
    var lineups: [Lineup]
    var savedLines: [SavedLine]
    var windRules: [WindRule]
    var game: GameState
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
    static let clamBH = UUID(uuidString: "cccccccc-bbbb-4ccc-8ddd-000000000001")!
    static let clamFlick = UUID(uuidString: "cccccccc-bbbb-4ccc-8ddd-000000000002")!
    static let cup = UUID(uuidString: "cccccccc-bbbb-4ccc-8ddd-000000000003")!
    static let person = UUID(uuidString: "cccccccc-bbbb-4ccc-8ddd-000000000004")!
    static let junk = UUID(uuidString: "cccccccc-bbbb-4ccc-8ddd-000000000005")!
    static let kill = UUID(uuidString: "cccccccc-bbbb-4ccc-8ddd-000000000006")!
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
            ]
        )

        let saved: [SavedLine] = [
            SavedLine(
                id: SeedIDs.clamBH,
                name: "Clam BH",
                defenseKind: .clam,
                force: .backhand,
                playerIds: [SeedIDs.alex, SeedIDs.drew, SeedIDs.gia, SeedIDs.harper, SeedIDs.kai, SeedIDs.oak, SeedIDs.quinn]
            ),
            SavedLine(
                id: SeedIDs.clamFlick,
                name: "Clam Flick",
                defenseKind: .clam,
                force: .flick,
                playerIds: [SeedIDs.blair, SeedIDs.eden, SeedIDs.indy, SeedIDs.jules, SeedIDs.lane, SeedIDs.parker, SeedIDs.nico]
            ),
            SavedLine(
                id: SeedIDs.cup,
                name: "Cup",
                defenseKind: .cup,
                force: .backhand,
                playerIds: [SeedIDs.casey, SeedIDs.fin, SeedIDs.gia, SeedIDs.morgan, SeedIDs.oak, SeedIDs.remy, SeedIDs.quinn]
            ),
            SavedLine(
                id: SeedIDs.person,
                name: "Person",
                defenseKind: .person,
                force: .backhand,
                playerIds: [SeedIDs.alex, SeedIDs.blair, SeedIDs.gia, SeedIDs.harper, SeedIDs.kai, SeedIDs.lane, SeedIDs.oak]
            ),
            SavedLine(
                id: SeedIDs.junk,
                name: "Junk",
                defenseKind: .junk,
                force: .flick,
                playerIds: [SeedIDs.drew, SeedIDs.eden, SeedIDs.indy, SeedIDs.jules, SeedIDs.morgan, SeedIDs.parker, SeedIDs.remy]
            ),
            SavedLine(
                id: SeedIDs.kill,
                name: "Kill",
                defenseKind: .kill,
                force: .flick,
                playerIds: [SeedIDs.alex, SeedIDs.casey, SeedIDs.gia, SeedIDs.kai, SeedIDs.oak, SeedIDs.quinn, SeedIDs.harper]
            )
        ]

        let rules: [WindRule] = [
            WindRule(
                name: "Crosswind L→R",
                gameType: .crosswind,
                direction: .leftToRight,
                savedLineId: SeedIDs.clamBH,
                forceOverride: .backhand
            ),
            WindRule(
                name: "Crosswind R→L",
                gameType: .crosswind,
                direction: .rightToLeft,
                savedLineId: SeedIDs.clamFlick,
                forceOverride: .flick
            ),
            WindRule(
                name: "No / light wind",
                gameType: .none,
                minSpeed: nil,
                savedLineId: SeedIDs.person,
                forceOverride: .backhand
            ),
            WindRule(
                name: "They attack downwind",
                gameType: .upwindDownwind,
                minSpeed: .strong,
                pointIsUpwind: false,
                savedLineId: SeedIDs.junk
            ),
            WindRule(
                name: "They attack upwind",
                gameType: .upwindDownwind,
                minSpeed: .strong,
                pointIsUpwind: true,
                savedLineId: SeedIDs.cup
            )
        ]

        return Team(
            name: "Pocket Coach",
            joinCode: makeJoinCode(),
            activeLineupId: SeedIDs.lineupWeekend,
            players: players,
            lineups: [weekend],
            savedLines: saved,
            windRules: rules,
            game: .default
        )
    }
}
