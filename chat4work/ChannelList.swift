//
//  CompanyList.swift
//  chat4work
//
//  Created by A Arrow on 6/7/17.
//  Copyright © 2017 755R3VBZ84. All rights reserved.
//

import Cocoa
import Moya
import RxSwift

class ButtonWithStringTag: NSButton {
  var stringTag: String = ""
  var flavor: String = ""
  var team: Team?
}

class ChannelWithRed: NSView {
  let reddot = NSImage(named: "reddot.png")
  let button = ButtonWithStringTag(frame: NSMakeRect(0,0,200,25))
  let red = NSImageView(frame: NSMakeRect(180,8,12,12))
  var team_id = ""
  var channel_id = ""
  
  func checkRedDotStatus(notification: NSNotification) {
    
    let json = notification.object as! [String: Any]
    if let c = json["channel"] {
      //NSLog("\(c) | \(self.channel_id)")
      if (c as! String) == self.channel_id {
        red.isHidden = false
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

class ChannelList: NSScrollView {
    
  let list = NSView(frame: NSMakeRect(0,0,220,1560+900))
  var disposeBag = DisposeBag()
  var oms = Array<Any>()
  
  func sortByLastMsgDate(notification: NSNotification) {
    
    for sv in list.subviews {
      let cwr = sv as! ChannelWithRed

      
      let team = cwr.button.team
      let provider = RxMoyaProvider<ChatService>()
      let channelApi = ChannelApiImpl(provider: provider)
      
      // Observable<Messages>
      
      let om = channelApi.getHistoryByFlavor(token: (team?.token!)!, id:cwr.button.stringTag, flavor: cwr.button.flavor)
      oms.append(om.subscribe(
        onNext: { messages in
          
          NSLog("\(cwr.button.stringTag)")
          NSLog("\(cwr.button.flavor)")
          
          if (messages.results != nil && (messages.results?.count)! > 0) {
            
            NSLog("\(messages.results?.count)")
            for (_,m) in (messages.results?.enumerated())! {
            }
          }
      },
        onError: { error in
          NSLog("\(error)")
      }))
      
      /*
      channelApi.getHistoryByFlavor(token: (team?.token!)!, id:cwr.button.stringTag, flavor: cwr.button.flavor).subscribe(
        onNext: { messages in

          NSLog("\(cwr.button.stringTag)")
          NSLog("\(cwr.button.flavor)")
          
          if (messages.results != nil && (messages.results?.count)! > 0) {
            
            NSLog("\(messages.results?.count)")
            for (_,m) in (messages.results?.enumerated())! {
            }
          }
      },
        onError: { error in
          NSLog("\(error)")
      }).addDisposableTo(disposeBag)*/
    }
    
    //let alert = notification.object as! NSAlert
    //alert.buttons[0].performClick(self)
    
  }
    
  func companyDidChange(notification: NSNotification) {
    let team = notification.object as! Team

    
    let provider = RxMoyaProvider<ChatService>()
    let channelApi = ChannelApiImpl(provider: provider)
    
    self.list.subviews = []
    
    Observable.zip(
      channelApi.getUsers(token: team.token!),
      channelApi.getChannels(token: team.token!),
      channelApi.getGroups(token: team.token!),
      channelApi.getIMs(token: team.token!)) { (users, channels, groups, ims) in
        var UserHash = ["1":"2"]
        
        if let u = users.results {
          
          u.forEach({
            (user) in
            UserHash[user.id!] = user.name
          })
        }
        
        
        if let c = channels.results {
          
          c.forEach({
            (channel) in
            var red = 0
            if ((team.listOfNew?[channel.id!]) != nil) {
              red = 1
            }
            
            self.addChannel(i: self.list.subviews.count, title: channel.name!,
                            id: channel.id!, flavor: "channel",
                            red: red,
                            team: team)
          })
        }
        
        if let g = groups.results {
          g.forEach({
            (group) in
            var red = 0
            if ((team.listOfNew?[group.id!]) != nil) {
              red = 1
            }

            self.addChannel(i: self.list.subviews.count, title: group.name!, id: group.id!,
                            flavor: "group",
                            red: red,
                            team: team)
          })
        }
        
        if let i = ims.results {
          i.forEach({
            (im) in
            var red = 0
            if ((team.listOfNew?[im.id!]) != nil) {
              red = 1
            }

            self.addChannel(i: self.list.subviews.count, title: UserHash[im.user!]!, id: im.id!,
                            flavor: "im",
                            red: red,
                            team: team)
          })
        }
      }
      .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
      .observeOn(MainScheduler.instance)
      .subscribe()
      .addDisposableTo(disposeBag)
  }
  
  func addChannel(i: Int, title: String, id: String, flavor: String,
                  red: Int, team: Team) {
    let cwr = ChannelWithRed(frame: NSMakeRect(10,(CGFloat(i*30)),200,25))
    cwr.button.title = title
    cwr.button.tag = i
    cwr.button.stringTag = id
    cwr.channel_id = id
    cwr.button.flavor = flavor
    cwr.button.team = team
    cwr.button.target = self
    cwr.button.action = #selector(changeChannel)
    
    if red == 1 {
      cwr.red.isHidden = false
    }
    
    list.addSubview(cwr)
  }
  
  func changeChannel(sender:ButtonWithStringTag) {
    NotificationCenter.default.post(
      name:NSNotification.Name(rawValue: "channelDidChange"),
      object: sender)
    
    let cwr = list.subviews[sender.tag] as! ChannelWithRed
    cwr.red.isHidden = true
  }
  
  override init(frame frameRect: NSRect) {
    super.init(frame:frameRect);
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(companyDidChange),
                                           name: NSNotification.Name(rawValue: "companyDidChange"),
                                           object: nil)
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(sortByLastMsgDate),
                                           name: NSNotification.Name(rawValue: "sortByLastMsgDate"),
                                           object: nil)
    
    wantsLayer = true
    
    list.wantsLayer = true
    list.layer?.backgroundColor = NSColor.lightGray.cgColor

    translatesAutoresizingMaskIntoConstraints = true
    //autoresizingMask.insert(NSAutoresizingMaskOptions.viewHeightSizable)
    //autoresizingMask.insert(NSAutoresizingMaskOptions.viewMinYMargin)
    autoresizingMask.insert(NSAutoresizingMaskOptions.viewMaxYMargin)

    documentView = list
    hasVerticalScroller = false
    //documentView?.scroll(NSPoint(x: 0, y:2000))
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

}
 
