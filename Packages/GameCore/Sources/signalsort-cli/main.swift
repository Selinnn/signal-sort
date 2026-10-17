import Foundation
import GameCore

let usage = """
    signalsort-cli — Signal Sort seviye araçları (şema v\(GameCore.schemaVersion))

    Kullanım:
      signalsort-cli render <level.json>
      signalsort-cli validate <level.json>...
      signalsort-cli solve <level.json>
      signalsort-cli generate --seed <n> --profile <name>
      signalsort-cli build-campaign
      signalsort-cli build-dailies --from <yyyy-MM-dd> --days <n>

    Komutlar sonraki adımlarda eklenecek.
    """

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case nil, "help", "-h", "--help":
    print(usage)
default:
    print("Bilinmeyen veya henüz uygulanmamış komut: \(arguments[0])\n")
    print(usage)
    exit(2)
}
