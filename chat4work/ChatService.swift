//
//  ChatService.swift
//  boring-company-chat
//
//  Created by A Arrow on 6/8/17.
//  Copyright © 2017 755R3VBZ84. All rights reserved.
//

import Foundation
import Moya

enum ChatService {
  case zen
  case showUser(id: Int)
  case postMessage(token: String, id: String, text: String)
  case updateUser(id:Int, firstName: String, lastName: String)
  case showChannels(token: String)
  case showGroups(token: String)
  case showIMs(token: String)
  case showUsers(token: String)
  case showTeam(token: String)
  case historyIM(token: String, id: String, count: Int, unreads: Int)
  case historyGroup(token: String, id: String, count: Int, unreads: Int)
  case historyChannel(token: String, id: String, count: Int, unreads: Int)

  case markIM(token: String, id: String, ts: String)
  case markGroup(token: String, id: String, ts: String)
  case markChannel(token: String, id: String, ts: String)

  case rtmConnect(token: String)
}

extension ChatService: TargetType {
  var baseURL: URL { return URL(string: "https://slack.com")! }
  
  var path: String {
    switch self {
    case .zen:
      return "/zen"
    case .showUser(let id), .updateUser(let id, _, _):
      return "/users/\(id)"
    case .postMessage(_, _, _):
      return "/api/chat.postMessage"
    case .showChannels:
      return "/api/channels.list"
    case .showGroups:
      return "/api/groups.list"
    case .showIMs:
      return "/api/im.list"
    case .historyIM:
      return "/api/im.history"
    case .historyGroup:
      return "/api/groups.history"
    case .historyChannel:
      return "/api/channels.history"
      
    case .markIM:
      return "/api/im.mark"
    case .markGroup:
      return "/api/groups.mark"
    case .markChannel:
      return "/api/channels.mark"

    case .showUsers:
      return "/api/users.list"
    case .showTeam:
      return "/api/team.info"
    case .rtmConnect:
      return "/api/rtm.connect"
    }
  }
  var method: Moya.Method {
    switch self {
    case .zen, .showUser, .showChannels, .showGroups, .showIMs, .showUsers,
         .showTeam, .historyIM, .historyGroup, .historyChannel,
         .markIM, .markGroup, .markChannel:
      return .get
    case .postMessage, .updateUser, .rtmConnect:
      return .post
    }
  }
  var parameters: [String: Any]? {
    switch self {
    case .zen, .showUser:
      return nil
    case .showChannels(let token), .showGroups(let token), .showIMs(let token), .showUsers(let token), .showTeam(let token), .rtmConnect(let token):
      return ["token": token]
    case .historyIM(let token, let id, let count, let unreads), .historyGroup(let token, let id, let count, let unreads),
         .historyChannel(let token, let id, let count, let unreads):
      return ["token": token, "channel": id, "count": count, "unreads": unreads]
    case .markIM(let token, let id, let ts), .markGroup(let token, let id, let ts), .markChannel(let token, let id, let ts):
      return ["token": token, "channel": id, "ts": ts]
    case .postMessage(let token, let id, let text):
      return ["channel": id, "text": text, "token": token, "as_user": "true"]
    case .updateUser(_, let firstName, let lastName):
      return ["first_name": firstName, "last_name": lastName]
    }
  }
  
  var parameterEncoding: ParameterEncoding {
    return URLEncoding.default
  }
  var sampleData: Data {
    return "If you aren't in over your head, how do you know how tall you are?".utf8Encoded
  }
  var task: Task {
    return .request
  }
}

// MARK: - Helpers
private extension String {
  var urlEscaped: String {
    return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
  }
  
  var utf8Encoded: Data {
    return self.data(using: .utf8)!
  }
}
