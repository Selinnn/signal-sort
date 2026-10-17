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
