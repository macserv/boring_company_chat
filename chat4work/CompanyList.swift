//
//  CompanyList.swift
//  chat4work
//
//  Created by A Arrow on 6/7/17.
//  Copyright © 2017 755R3VBZ84. All rights reserved.
//

import Cocoa
import Alamofire
import AlamofireImage
import Starscream
import Moya
import RxSwift
import RealmSwift

class ButtonWithTeam: NSButton, WebSocketDelegate {
  var team = Team(JSONString: "{}")
  var reconnect_url: String?
  var ws: WebSocket?
  var lastReconnect: Double?
  
  func websocketDidConnect(socket: WebSocket) {
    
    Swift.print("websocket is connected")
    //socket.write(string: "hello there!")
  }
  
  func reconnect() {
    ws = WebSocket(url: URL(string: reconnect_url!)!)
    ws?.delegate = self
    ws?.connect()
  }
  
  func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
    Swift.print("websocket disconnected")
    
    DispatchQueue.global().async {
      let now = Date().timeIntervalSince1970
      if now-self.lastReconnect! < 5 {
        sleep(5)
      }
      self.reconnect()
      self.lastReconnect = now
    }
    
  }
  
  func websocketDidReceiveMessage(socket: WebSocket, text: String) {
    Swift.print("RT: \(text)")
    
    //RT: {"reply_to":53,"type":"message",
    //"channel":"D1KD59XH9",
    //"user":"U035LF6C1","text":"1","ts":"1497722672.03237"}
    
    do {
      let data = text.data(using: String.Encoding.utf8, allowLossyConversion: false)!
      var json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
      json?["team"] = self.team?.id
      let etype = json?["type"] as? String
      if etype == "message" {
        
        NotificationCenter.default.post(
          name:NSNotification.Name(rawValue: "rtmMessage"),
          object: json)
      } else if etype == "reconnect_url" {
        reconnect_url = json?["url"] as? String
      }
    } catch {
      Swift.print("Error deserializing JSON: \(error)")
    }
    
    
    //{"type":"message",
    //"channel":"D18T96VJM",
    //"user":"U025M33EJ",
    //"text":"wefwefwe",
    //"ts":"1497128451.247014",
    //"source_team":"T025K4ALN",
    //"team":"T025K4ALN"}
    
    /*RT: {"type":"im_marked","channel":"D18T96VJM","ts":"1497128451.247014","dm_count":0,"unread_count_display":0,"num_mentions_display":0,"mention_count_display":0,"event_ts":"1497128452.824439"} */
  }
  
  func websocketDidReceiveData(socket: WebSocket, data: Data) {
    Swift.print("RD: \(data.count)")
  }
  
  override init(frame frameRect: NSRect) {
    super.init(frame:frameRect);
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
}

class CompanyWithRed: NSView, NSUserNotificationCenterDelegate {
  let reddot = NSImage(named: "reddot.png")
  let button = ButtonWithTeam(frame: NSMakeRect(0,0,50,50))
  let red = NSImageView(frame: NSMakeRect(42,38,12,12))
  
  func toggleOff() {
    self.red.isHidden = true
    self.needsDisplay = true
  }
  
  func toggleOn() {
    self.red.isHidden = false
    self.needsDisplay = true
  }
  
  func checkRedDotStatus(notification: NSNotification) {
    
    let json = notification.object as! [String: Any]
    //NSLog("\(json)")
    //2017-06-11 03:53:46.014074+0000 boring-company-chat[7958:82613] ["team": T035N23CL, "source_team": T035N23CL, "user": U035LF6C1, "text": wefwef, "channel": D1KD59XH9, "type": message, "ts": 1497153225.487018]
    
    let text = json["text"]
    
    if text == nil {
      return
    }
    
    if let team = json["team"] {
      
      let text = json["text"] as! String
      
      let notification = NSUserNotification()
      let d = NSUserNotificationCenter.default
      d.delegate = self
      
      
      notification.title = "BCC"
      //notification.subtitle = "sub"
      notification.identifier = "bcc"
      notification.informativeText = text
      //notification.soundName = NSUserNotificationDefaultSoundName
      
      d.removeDeliveredNotification(notification)
      NSUserNotificationCenter.default.deliver(notification)
      
      if (team as! String) == self.button.team?.id {
        let channel = json["channel"] as! String
        if channel == "off" {
          self.toggleOff()
        } else {
          self.toggleOn()
        }
      }
    }
  }
  
  override init(frame frameRect: NSRect) {
    super.init(frame:frameRect);
    red.image = reddot
    red.isHidden = true
    
    addSubview(button)
    addSubview(red)
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(checkRedDotStatus),
                                           name: NSNotification.Name(rawValue: "rtmMessage"),
                                           object: nil)
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class CompanyList: NSScrollView {
  
  let left = NSView(frame: NSMakeRect(0,0,70,1560+900))
  let image5 = NSImage(named: "mena.png")
  var disposeBag = DisposeBag()
  
  func addIcon(i: Int, image: NSImage, team: Team) -> ButtonWithTeam {
    let cwr = CompanyWithRed(frame: NSMakeRect(10,(CGFloat(i*60)),60,50))
    cwr.button.image = image
    cwr.button.target = self
    cwr.button.action = #selector(changeCompany)
    cwr.button.team = team
    left.addSubview(cwr)
    return cwr.button
  }
  
  func channelDidChange(notification: NSNotification) {
    _ = notification.object as! ButtonWithStringTag
    
  }
  
  func newTeamAdded(notification: NSNotification) {
    let team = notification.object as! Team
    
    let token = team.token
    
    let provider = RxMoyaProvider<ChatService>()
    let channelApi = ChannelApiImpl(provider: provider)
    
    Alamofire.request(team.icon!).responseImage { response in
      let uf = UnreadFinder()
      uf.cacheUsers(team: team)
      
      if let image = response.result.value {
        let bwt = self.addIcon(i: team.index!+1, image: image, team: team)
        
        channelApi.rtmConnect(token: token!).subscribe(
          onNext: { team in
            bwt.ws = WebSocket(url: URL(string: team.url!)!)
            bwt.ws?.delegate = bwt
            bwt.lastReconnect = Date().timeIntervalSince1970
            bwt.ws?.connect()
        },
          onError: { error in
            
        }).addDisposableTo(self.disposeBag)
        
      }
    }
    
  }
  
  func changeCompany(sender:ButtonWithTeam) {
    
    // let existing = UserDefaults.standard.value(forKey: "bcc_teams") as! Array<String>
    // let token = existing[sender.tag-1]
    // let cwr = left.subviews[sender.tag] as! CompanyWithRed
    // cwr.toggleOff()
    
    
    if sender.team?.id == "BCC" {
      return
    }
    
    let team = sender.team
    
    NotificationCenter.default.post(
      name:NSNotification.Name(rawValue: "companyDidChange"),
      object: team)
  }
  
  func listenRTM(notification: NSNotification) {
    
    let json = notification.object as! [String: Any]
    //NSLog("\(json)")
    let team = json["team"] as? String
    let channel = json["channel"] as! String
    
    let realm = try! Realm()
    
    let cos = realm.objects(ChannelObject.self).filter("team = %@", team!)
    if cos.count == 0 {
      return
    }
    for c in cos {
      if c.id == channel {
        try! realm.write {
          c.possibly_new = 1
        }
      }
    }
    
    let jtype = json["type"]
    let jtext = json["text"]
    
    if jtype != nil && jtext != nil {
      let theType = jtype as! String
      if theType == "message"  {
        let mo = MessageObject()
        mo.ts = json["ts"] as! String
        mo.tsd = Double(mo.ts)!
        mo.channel = json["channel"] as! String
        mo.text = json["text"] as! String
        mo.user = ""
        
        if json["user"] != nil {
          mo.user = json["user"] as! String
          mo.username = "system"
          
          let pkey = "\(team ?? "").\(mo.user)"
          if let existing = realm.object(ofType: UserObject.self,
                                         forPrimaryKey: pkey as AnyObject) {
            mo.username = existing.name
            
          }
          
        }
        
        mo.team = team!
        mo.id = "\(team ?? "").\(mo.channel).\(mo.ts)"
        
        let existing = realm.object(ofType: MessageObject.self, forPrimaryKey: mo.id as AnyObject)
        
        if (existing == nil) {
          try! realm.write {
            realm.add(mo)
          }
          
          NotificationCenter.default.post(
            name:NSNotification.Name(rawValue: "contentIsReady"),
            object: ["team": team!, "channel": mo.channel])
          
        }
        
      }
    }
    
    //2017-06-11 03:53:46.014074+0000 boring-company-chat[7958:82613] ["team": T035N23CL, "source_team": T035N23CL, "user": U035LF6C1, "text": wefwef, "channel": D1KD59XH9, "type": message, "ts": 1497153225.487018]
    
  }
  
  override init(frame frameRect: NSRect) {
    super.init(frame:frameRect);
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(newTeamAdded),
                                           name: NSNotification.Name(rawValue: "newTeamAdded"),
                                           object: nil)
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(listenRTM),
                                           name: NSNotification.Name(rawValue: "rtmMessage"),
                                           object: nil)
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(channelDidChange),
                                           name: NSNotification.Name(rawValue: "channelDidChange"),
                                           object: nil)
    
    wantsLayer = true
    
    left.wantsLayer = true
    left.layer?.backgroundColor = NSColor.lightGray.cgColor
    for i in 0...0 {
      let team = Team(withToken: "", id: "BCC")!
      _ = addIcon(i: i, image: image5!, team: team)
    }
    
    translatesAutoresizingMaskIntoConstraints = true
    autoresizingMask.insert(NSAutoresizingMaskOptions.viewHeightSizable)
    
    left.translatesAutoresizingMaskIntoConstraints = true
    left.autoresizingMask.insert(NSAutoresizingMaskOptions.viewHeightSizable)
    
    documentView = left
    hasVerticalScroller = false
    //documentView?.scroll(NSPoint(x: 0, y:200))
  }
  
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
}

