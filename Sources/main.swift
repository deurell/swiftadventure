import Foundation

var commandAliases: [String: String] = [
  "pick up": "get",
  "inv": "inventory",
  "i": "inventory",
  "move": "go",
  "north": "go north",
  "south": "go south",
  "east": "go east",
  "west": "go west",
  "up": "go up",
  "down": "go down",
  "n": "go north",
  "s": "go south",
  "e": "go east",
  "w": "go west",
  "talk": "talk to",
]

struct Path: Codable {
  var roomID: Int
  var isLocked: Bool
}

struct UseEffect: Codable {
  var originatingRoomID: Int?
  var target: String
  var action: String
  var message: String
}

struct Item: Codable {
  var name: String
  var description: String
  var useEffects: [String: UseEffect]?
}

struct Character: Codable {
  var name: String
  var dialogue: String
}

struct Room: Codable {
  var id: Int
  var description: String
  var paths: [String: Path]
  var items: [Item]
  var characters: [Character]?
}

struct GameData: Codable {
  var startingRoom: Int
  var rooms: [Room]
}

var gameRooms: [Int: Room] = [:]
var currentRoomID = 0
var playerInventory: [Item] = []

func resolveAlias(_ command: String) -> String {
  if let actualCommand = commandAliases[command] {
    return actualCommand
  }
  for (alias, actualCommand) in commandAliases {
    if command.starts(with: alias) {
      // Check if the command after resolving is the same as the original
      if actualCommand == command {
        return actualCommand
      }

      let remainder = command.dropFirst(alias.count)
      if remainder.isEmpty {
        return actualCommand
      }
      return actualCommand + " " + remainder
    }
  }
  return command
}

func loadGameData(from filename: String) {
  do {
    let data = try Data(contentsOf: URL(fileURLWithPath: filename))
    let gameData = try JSONDecoder().decode(GameData.self, from: data)
    gameRooms = Dictionary(uniqueKeysWithValues: gameData.rooms.map { ($0.id, $0) })
    currentRoomID = gameData.startingRoom
  } catch {
    print("Error loading game data: \(error)")
  }
}

func lookAround(in room: Room) {
  print(room.description)
  room.characters?.forEach { print("\($0.name) is here.") }
  room.items.forEach { print("There's a \($0.name) here.") }
  room.paths.keys.forEach { print("You can go \($0).") }
}

func go(_ direction: String) {
  if let path = gameRooms[currentRoomID]?.paths[direction] {
    if !path.isLocked {
      currentRoomID = path.roomID
      print("You move \(direction).")
      if let currentRoom = gameRooms[currentRoomID] {
        lookAround(in: currentRoom)
      }
    } else {
      print("The path to the \(direction) is locked.")
    }
  } else {
    print("You can't go in that direction.")
  }
}

func getItem(named itemName: String) {
  if let index = gameRooms[currentRoomID]?.items.firstIndex(where: { $0.name == itemName }) {
    if let item = gameRooms[currentRoomID]?.items.remove(at: index) {
      playerInventory.append(item)
      print("You picked up the \(itemName).")
    }
  } else {
    print("There's no \(itemName) here to pick up.")
  }
}

func dropItem(named itemName: String) {
  if let index = playerInventory.firstIndex(where: { $0.name == itemName }) {
    let item = playerInventory.remove(at: index)
    gameRooms[currentRoomID]?.items.append(item)
    print("You dropped the \(itemName).")
  } else {
    print("You don't have a \(itemName) in your inventory.")
  }
}

func useItem(named itemName: String) {
  guard let item = playerInventory.first(where: { $0.name == itemName }) else {
    print("You don't have a \(itemName) in your inventory.")
    return
  }

  print("You used the \(itemName).")

  if let useEffects = item.useEffects {
    for useEffect in useEffects.values {
      if useEffect.originatingRoomID == currentRoomID {
        switch useEffect.action {
        case "open":
          // Assuming target refers to an item name
          if let index = gameRooms[currentRoomID]?.items.firstIndex(where: {
            $0.name == useEffect.target
          }) {
            gameRooms[currentRoomID]?.items.remove(at: index)
            print(useEffect.message)
          }
        case "unlock":
          // Assuming target refers to a direction
          gameRooms[currentRoomID]?.paths[useEffect.target]?.isLocked = false
          print(useEffect.message)
        default:
          print("Nothing happens.")
        }
      } else {
        print("Nothing happens.")
      }
    }
  } else {
    print("Nothing happens.")
  }
}

func showInventory() {
  if playerInventory.isEmpty {
    print("Your inventory is empty.")
  } else {
    print("You have:")
    playerInventory.forEach { print("- \($0.name): \($0.description)") }
  }
}

func talkToCharacter(named characterName: String) {
  if let character = gameRooms[currentRoomID]?.characters?.first(where: { $0.name == characterName }
  ) {
    print("\(characterName): \"\(character.dialogue)\"")
  } else {
    print("\(characterName) is not here.")
  }
}

func handleCommand(_ rawCommand: String) {
  let command = resolveAlias(rawCommand)
  let commandParts = command.split(separator: " ")

  // Check if commandParts is empty
  guard !commandParts.isEmpty else {
    print("Please enter a command.")
    return
  }

  switch commandParts[0] {
  case "look":
    if let currentRoom = gameRooms[currentRoomID] {
      lookAround(in: currentRoom)
    }
  case "use":
    if commandParts.count > 1 {
      let itemName = commandParts.dropFirst().joined(separator: " ")
      useItem(named: itemName)
    } else {
      print("What would you like to use?")
    }
  case "go":
    if commandParts.count > 1 {
      go(String(commandParts[1]))
    } else {
      print("Where would you like to go?")
    }
  case "inventory":
    showInventory()
  case "get":
    if commandParts.count > 1 {
      let itemName = commandParts.dropFirst().joined(separator: " ")
      getItem(named: itemName)
    } else {
      print("What would you like to get?")
    }
  case "quit":
    print("Goodbye!")
    exit(0)
  case "talk":
    if commandParts.count >= 3 && commandParts[1] == "to" {
      let characterName = commandParts.dropFirst(2).joined(separator: " ")
      talkToCharacter(named: characterName)
    } else {
      print("Who would you like to talk to?")
    }
  case "drop":
    if commandParts.count > 1 {
      let itemName = commandParts.dropFirst().joined(separator: " ")
      dropItem(named: itemName)
    } else {
      print("What would you like to drop?")
    }
  default:
    print("I don't understand that command.")
  }
}

func printCurrentRoomDescription() {
  print(gameRooms[currentRoomID]?.description ?? "")
}

func main() {
  guard let jsonMap = Bundle.module.path(forResource: "map", ofType: "json") else {
    print("Could not find map.json")
    return
  }
  loadGameData(from: jsonMap)
  printCurrentRoomDescription()

  while true {
    print("What would you like to do?")
    if let input = readLine() {
      handleCommand(input)
    }
  }
}

main()
