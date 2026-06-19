import AppIntents
import Foundation
import UIKit

@available(iOS 16.0, *)
enum CsACShortcutDestination: String, AppEnum {
  case home
  case chats
  case space
  case search
  case notices
  case profile

  static var typeDisplayRepresentation = TypeDisplayRepresentation(
    name: "CsAC Destination"
  )

  static var caseDisplayRepresentations: [CsACShortcutDestination: DisplayRepresentation] = [
    .home: "Home",
    .chats: "Chats",
    .space: "Space",
    .search: "Search",
    .notices: "Notices",
    .profile: "Me",
  ]
}

@available(iOS 16.0, *)
enum CsACShortcutChatType: String, AppEnum {
  case group
  case user

  static var typeDisplayRepresentation = TypeDisplayRepresentation(
    name: "CsAC Chat Type"
  )

  static var caseDisplayRepresentations: [CsACShortcutChatType: DisplayRepresentation] = [
    .group: "Group",
    .user: "User",
  ]
}

@available(iOS 16.0, *)
struct OpenCsACIntent: AppIntent {
  static var title: LocalizedStringResource = "Open CsAC"
  static var description = IntentDescription("Open CsAC to a selected area.")
  static var openAppWhenRun = true

  @Parameter(title: "Destination", default: .home)
  var destination: CsACShortcutDestination

  func perform() async throws -> some IntentResult {
    openCsACURL("csacflutterleon://\(destination.rawValue)")
    return .result()
  }
}

@available(iOS 16.0, *)
struct OpenCsACSearchIntent: AppIntent {
  static var title: LocalizedStringResource = "Search CsAC"
  static var description = IntentDescription("Open CsAC search with optional keywords.")
  static var openAppWhenRun = true

  @Parameter(title: "Query")
  var query: String?

  func perform() async throws -> some IntentResult {
    let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmed.isEmpty {
      openCsACURL("csacflutterleon://search")
    } else {
      let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
      openCsACURL("csacflutterleon://search?q=\(encoded)")
    }
    return .result()
  }
}

@available(iOS 16.0, *)
struct OpenCsACUserIntent: AppIntent {
  static var title: LocalizedStringResource = "Open CsAC User"
  static var description = IntentDescription("Open a CsAC user profile by UID.")
  static var openAppWhenRun = true

  @Parameter(title: "UID")
  var uid: Int

  func perform() async throws -> some IntentResult {
    openCsACURL("csacflutterleon://profile/user/\(uid)")
    return .result()
  }
}

@available(iOS 16.0, *)
struct OpenCsACGroupIntent: AppIntent {
  static var title: LocalizedStringResource = "Open CsAC Group"
  static var description = IntentDescription("Open a CsAC group chat by room ID.")
  static var openAppWhenRun = true

  @Parameter(title: "Room ID")
  var roomId: Int

  func perform() async throws -> some IntentResult {
    openCsACURL("csacflutterleon://chat/group/\(roomId)")
    return .result()
  }
}

@available(iOS 16.0, *)
struct ComposeCsACMessageIntent: AppIntent {
  static var title: LocalizedStringResource = "Compose CsAC Message"
  static var description = IntentDescription("Open a CsAC chat and fill a message draft. Direct sending always asks for confirmation inside CsAC.")
  static var openAppWhenRun = true

  @Parameter(title: "Chat Type", default: .group)
  var chatType: CsACShortcutChatType

  @Parameter(title: "ID")
  var id: Int

  @Parameter(title: "Message")
  var message: String

  @Parameter(title: "Ask CsAC To Send", default: false)
  var askToSend: Bool

  func perform() async throws -> some IntentResult {
    let type = chatType == .group ? "group" : "private"
    var components = URLComponents(string: "csacflutterleon://chat/\(type)/\(id)")
    var items = [URLQueryItem(name: "draft", value: message)]
    if askToSend {
      items.append(URLQueryItem(name: "send", value: "confirm"))
    }
    components?.queryItems = items
    if let value = components?.url?.absoluteString {
      openCsACURL(value)
    }
    return .result()
  }
}

@available(iOS 16.0, *)
struct GetCsACUnreadStatusIntent: AppIntent {
  static var title: LocalizedStringResource = "Get CsAC Unread Status"
  static var description = IntentDescription("Return the latest unread status cached by CsAC.")
  static var openAppWhenRun = false

  @Parameter(title: "Group Room ID")
  var roomId: Int?

  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    return .result(value: csacUnreadStatusText(roomId: roomId))
  }
}

@available(iOS 16.0, *)
struct CsACShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: OpenCsACIntent(),
      phrases: [
        "Open \(.applicationName)",
        "Open \(.applicationName) chats",
      ],
      shortTitle: "Open CsAC",
      systemImageName: "bubble.left.and.bubble.right"
    )
    AppShortcut(
      intent: OpenCsACSearchIntent(),
      phrases: [
        "Search \(.applicationName)",
      ],
      shortTitle: "Search CsAC",
      systemImageName: "magnifyingglass"
    )
    AppShortcut(
      intent: OpenCsACUserIntent(),
      phrases: [
        "Open \(.applicationName) user",
      ],
      shortTitle: "Open User",
      systemImageName: "person.crop.circle"
    )
    AppShortcut(
      intent: OpenCsACGroupIntent(),
      phrases: [
        "Open \(.applicationName) group",
      ],
      shortTitle: "Open Group",
      systemImageName: "person.3"
    )
    AppShortcut(
      intent: ComposeCsACMessageIntent(),
      phrases: [
        "Compose \(.applicationName) message",
        "Send \(.applicationName) message",
      ],
      shortTitle: "Compose Message",
      systemImageName: "square.and.pencil"
    )
    AppShortcut(
      intent: GetCsACUnreadStatusIntent(),
      phrases: [
        "Get \(.applicationName) unread status",
      ],
      shortTitle: "Unread Status",
      systemImageName: "bell.badge"
    )
  }
}

@available(iOS 16.0, *)
private func openCsACURL(_ value: String) {
  guard let url = URL(string: value) else {
    return
  }
  Task { @MainActor in
    UIApplication.shared.open(url)
  }
}

@available(iOS 16.0, *)
private func csacUnreadStatusText(roomId: Int?) -> String {
  let status = UserDefaults.standard.dictionary(forKey: "CsACShortcutUnreadStatus") ?? [:]
  let totalUnread = intFromAny(status["total_unread"])
  let notificationTotal = intFromAny(status["notification_total"])
  let mentionCount = intFromAny(status["mention_count"])
  let updatedAt = status["updated_at"] as? String ?? "unknown"
  var lines = [
    "Unread: \(totalUnread)",
    "Notifications: \(notificationTotal)",
    "Mentions: \(mentionCount)",
  ]
  if let roomId, roomId > 0 {
    let conversations = status["conversations"] as? [[String: Any]] ?? []
    let groupUnread = conversations.first { item in
      (item["type"] as? String) == "group" && intFromAny(item["id"]) == roomId
    }.map { intFromAny($0["unread_count"]) } ?? 0
    lines.append("Group \(roomId): \(groupUnread)")
  }
  lines.append("Updated: \(updatedAt)")
  return lines.joined(separator: "\n")
}

private func intFromAny(_ value: Any?) -> Int {
  if let intValue = value as? Int {
    return intValue
  }
  if let number = value as? NSNumber {
    return number.intValue
  }
  if let string = value as? String {
    return Int(string) ?? 0
  }
  return 0
}
