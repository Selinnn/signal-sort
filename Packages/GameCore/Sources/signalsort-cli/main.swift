import Foundation
import GameCore

let usage = """
    signalsort-cli — Signal Sort seviye araçları (şema v\(GameCore.schemaVersion), üretici v\(LevelGenerator.version))

    Kullanım:
      signalsort-cli render <level.json> [--solved]
      signalsort-cli validate [--deep] <level.json>...
      signalsort-cli solve <level.json> [--write]
      signalsort-cli generate --profile <ad> [--seed <n>] [--count <n>] [--out <klasör>] [--quiet]
      signalsort-cli profiles
      signalsort-cli build-campaign --spec <spec.json> --handmade <klasör> --out <campaign.json>
      signalsort-cli check-campaign <campaign.json> [--deep]
      signalsort-cli build-dailies --from <yyyy-MM-dd> --days <n> --out <dailies.json>
      signalsort-cli check-dailies <dailies.json> [--deep]
    """

struct CLIError: Error, CustomStringConvertible {
    var description: String
}

func loadLevel(_ path: String) throws -> LevelDefinition {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(LevelDefinition.self, from: data)
}

func writeLevel(_ level: LevelDefinition, to path: String) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(level).write(to: URL(fileURLWithPath: path))
}

func option(_ name: String, in args: [String]) -> String? {
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    return args[index + 1]
}

func positional(_ args: [String], skippingValuesOf valued: Set<String> = []) -> [String] {
    var result: [String] = []
    var skip = false
    for arg in args {
        if skip { skip = false; continue }
        if valued.contains(arg) { skip = true; continue }
        if !arg.hasPrefix("--") { result.append(arg) }
    }
    return result
}

func describe(_ level: LevelDefinition, _ report: SolveReport) -> String {
    let par = report.par.map(String.init) ?? "—"
    let exact = report.isExhaustive ? "" : " (eksik arama)"
    return "par \(par), çözüm \(report.solutionCount)\(exact), arama düğümü \(report.searchNodes)"
}

/// Bölüm başına zorluk eğrisi: par ve arama düğümü (PLAN §6 tablosu için).
func printCurve(_ campaign: Campaign) {
    for chapter in campaign.chapters {
        let pars = chapter.levels.map { $0.par.map(String.init) ?? "?" }.joined(separator: " ")
        print("  \(chapter.id) par: \(pars)")
    }
}

func run(_ args: [String]) throws -> Int32 {
    guard let command = args.first else {
        print(usage)
        return 0
    }
    let rest = Array(args.dropFirst())

    switch command {
    case "help", "-h", "--help":
        print(usage)

    case "render":
        guard let path = positional(rest).first else { throw CLIError(description: "render: dosya yolu gerekli") }
        let level = try loadLevel(path)
        var state = LevelState.initial
        if rest.contains("--solved") {
            guard let solution = level.solutions?.first ?? Solver().solve(level).solutions.first else {
                throw CLIError(description: "Seviyenin çözümü yok")
            }
            state = solution.state(in: level)
        }
        print("\(level.id)  \(level.width)×\(level.height)  hamle \(state.moves)")
        print(BoardRenderer.render(level, state))

    case "validate":
        let paths = positional(rest)
        guard !paths.isEmpty else { throw CLIError(description: "validate: en az bir dosya gerekli") }
        let deep = rest.contains("--deep")
        var failed = 0
        for path in paths {
            let issues = LevelValidator().validate(try loadLevel(path), deep: deep)
            if issues.isEmpty {
                print("✓ \(path)")
            } else {
                failed += 1
                print("✗ \(path)")
                for issue in issues { print("    \(issue)") }
            }
        }
        print("\(paths.count - failed)/\(paths.count) geçerli")
        return failed == 0 ? 0 : 1

    case "solve":
        guard let path = positional(rest).first else { throw CLIError(description: "solve: dosya yolu gerekli") }
        var level = try loadLevel(path)
        let report = Solver().solve(level)
        print(describe(level, report))
        for (index, solution) in report.solutions.prefix(5).enumerated() {
            let dirs = solution.directions.keys.sorted().map { "\($0)=\(solution.directions[$0]!.rawValue)" }.joined(separator: " ")
            print("  #\(index + 1) hamle \(solution.moves): \(dirs)")
        }
        if let metrics = LevelMetrics.measure(level, report: report) {
            print("  karar \(metrics.decisions), karışık \(metrics.scrambled), paylaşılan hücre \(metrics.sharedCells), tuzak \(metrics.decoys)")
        }
        if rest.contains("--write") {
            guard report.isExhaustive else { throw CLIError(description: "Arama eksik; yazılmadı") }
            level.par = report.par
            level.solutionCount = report.solutionCount
            level.solutions = report.solutions
            try writeLevel(level, to: path)
            print("yazıldı: \(path)")
        }

    case "generate":
        guard let name = option("--profile", in: rest), let profile = DifficultyProfile.named(name) else {
            throw CLIError(description: "generate: --profile gerekli (\(DifficultyProfile.all.map(\.name).joined(separator: ", ")))")
        }
        let firstSeed = UInt64(option("--seed", in: rest) ?? "1") ?? 1
        let count = Int(option("--count", in: rest) ?? "1") ?? 1
        let outDir = option("--out", in: rest)
        let quiet = rest.contains("--quiet")
        let generator = LevelGenerator()
        var produced: [GeneratedLevel] = []
        var failures: [GenerationError] = []
        let started = Date()
        for seed in firstSeed..<(firstSeed + UInt64(count)) {
            do {
                let generated = try generator.generate(seed: seed, profile: profile)
                produced.append(generated)
                if let outDir {
                    try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
                    try writeLevel(generated.level, to: "\(outDir)/\(generated.level.id).json")
                }
                if !quiet {
                    let m = generated.metrics
                    print("\(generated.level.id): par \(m.par), çözüm \(m.solutionCount), düğüm \(m.searchNodes), karar \(m.decisions), paylaşılan \(m.sharedCells), deneme \(generated.attempts)")
                    if count == 1 { print(BoardRenderer.render(generated.level)) }
                }
            } catch let error as GenerationError {
                failures.append(error)
                if !quiet { print("✗ \(error)") }
            }
        }
        let elapsed = Date().timeIntervalSince(started)
        if count > 1 {
            let attempts = produced.map(\.attempts).reduce(0, +) + failures.map(\.attempts).reduce(0, +)
            print("\n\(profile.name): \(produced.count)/\(count) üretildi, \(failures.count) başarısız, toplam deneme \(attempts), \(String(format: "%.1f", elapsed)) sn")
            if !produced.isEmpty {
                let pars = produced.map(\.metrics.par).sorted()
                let nodes = produced.map(\.metrics.searchNodes).sorted()
                print("  par min/medyan/max: \(pars.first!)/\(pars[pars.count / 2])/\(pars.last!)")
                print("  düğüm min/medyan/max: \(nodes.first!)/\(nodes[nodes.count / 2])/\(nodes.last!)")
                print("  ortalama deneme: \(produced.map(\.attempts).reduce(0, +) / produced.count)")
            }
            var reasons: [QualityRejection: Int] = [:]
            for failure in failures { reasons.merge(failure.rejections, uniquingKeysWith: +) }
            if !reasons.isEmpty { print("  başarısız tohumların red nedenleri: \(reasons.sorted { $0.value > $1.value }.map { "\($0.key.rawValue)=\($0.value)" }.joined(separator: " "))") }
        }
        return failures.isEmpty ? 0 : 1

    case "build-campaign":
        guard let specPath = option("--spec", in: rest), let handmadeDir = option("--handmade", in: rest),
              let outPath = option("--out", in: rest) else {
            throw CLIError(description: "build-campaign: --spec, --handmade ve --out gerekli")
        }
        let spec = try JSONDecoder().decode(CampaignSpec.self, from: Data(contentsOf: URL(fileURLWithPath: specPath)))
        var handmade: [String: LevelDefinition] = [:]
        for file in try FileManager.default.contentsOfDirectory(atPath: handmadeDir).sorted() where file.hasSuffix(".json") {
            handmade[String(file.dropLast(5))] = try loadLevel("\(handmadeDir)/\(file)")
        }
        let started = Date()
        let campaign = try CampaignBuilder().build(spec: spec, handmade: handmade) { print($0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(campaign).write(to: URL(fileURLWithPath: outPath))
        print("\(campaign.levels.count) seviye yazıldı: \(outPath) (\(String(format: "%.0f", Date().timeIntervalSince(started))) sn)")
        printCurve(campaign)

    case "check-campaign":
        guard let path = positional(rest).first else { throw CLIError(description: "check-campaign: dosya yolu gerekli") }
        let campaign = try JSONDecoder().decode(Campaign.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let deep = rest.contains("--deep")
        var failed = 0
        for level in campaign.levels {
            let issues = LevelValidator().validate(level, deep: deep)
            if !issues.isEmpty {
                failed += 1
                print("✗ \(level.id): \(issues.map(\.description).joined(separator: "; "))")
            }
        }
        print("\(campaign.levels.count - failed)/\(campaign.levels.count) geçerli\(deep ? " (derin)" : "")")
        return failed == 0 ? 0 : 1

    case "build-dailies":
        guard let fromText = option("--from", in: rest), let start = DayKey(fromText),
              let days = option("--days", in: rest).flatMap(Int.init), let outPath = option("--out", in: rest) else {
            throw CLIError(description: "build-dailies: --from <yyyy-MM-dd>, --days ve --out gerekli")
        }
        let started = Date()
        let pack = try DailySchedule.build(from: start, days: days)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(pack).write(to: URL(fileURLWithPath: outPath))
        print("\(pack.levels.count) günlük yazıldı: \(pack.startDate) … \(pack.endDate) (\(String(format: "%.0f", Date().timeIntervalSince(started))) sn)")

    case "check-dailies":
        guard let path = positional(rest).first else { throw CLIError(description: "check-dailies: dosya yolu gerekli") }
        let pack = try JSONDecoder().decode(DailyPack.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let deep = rest.contains("--deep")
        var failed = 0
        for level in pack.levels {
            let issues = LevelValidator().validate(level, deep: deep)
            if !issues.isEmpty {
                failed += 1
                print("✗ \(level.id): \(issues.map(\.description).joined(separator: "; "))")
            }
        }
        print("\(pack.levels.count - failed)/\(pack.levels.count) geçerli\(deep ? " (derin)" : "")")
        return failed == 0 ? 0 : 1

    case "profiles":
        for profile in DifficultyProfile.all {
            let sizes = profile.sizes.map { "\($0.width)×\($0.height)" }.joined(separator: ",")
            print("\(profile.name): \(sizes), sinyal \(profile.signals), par \(profile.par), düğüm \(profile.searchNodes), gereken \(profile.requirements.map(\.rawValue))")
        }

    default:
        throw CLIError(description: "Bilinmeyen komut: \(command)\n\n\(usage)")
    }
    return 0
}

do {
    exit(try run(Array(CommandLine.arguments.dropFirst())))
} catch {
    FileHandle.standardError.write(Data("hata: \(error)\n".utf8))
    exit(2)
}
