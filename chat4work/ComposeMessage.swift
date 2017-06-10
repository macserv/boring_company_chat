//
//  CurrentCompany.swift
//  chat4work
//
//  Created by A Arrow on 6/7/17.
//  Copyright © 2017 755R3VBZ84. All rights reserved.
//

import Cocoa
import Moya
import RxSwift

class ComposeMessage: NSView, NSTextFieldDelegate {
  
  let text = NSTextField(frame: NSMakeRect(5, 5, 600, 50))
  var disposeBag = DisposeBag()
  
  func addNewTeam(token: String) {
    
    let provider = RxMoyaProvider<ChatService>()
    let channelApi = ChannelApiImpl(provider: provider)
    
    channelApi.getTeamInfo(token: token).subscribe(
      onNext: { team in
        Swift.print("\(team)")
        
        let defaults = UserDefaults.standard
        defaults.set("\(team.icon ?? "none")", forKey: "bcc_\(token)")
        
        NotificationCenter.default.post(
          name:NSNotification.Name(rawValue: "newTeamAdded"),
          object: team.icon)
    },
      onError: { error in
        
    }).addDisposableTo(disposeBag)
  }
  
  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    
    if commandSelector == #selector(NSResponder.insertNewline(_:)) {
      
      if text.stringValue.hasPrefix("/token ") {
        let tokens = text.stringValue.components(separatedBy: " ")
        
        
        let existing = UserDefaults.standard.value(forKey: "bcc_tokens")
        
        if (existing != nil) {
          let defaults = UserDefaults.standard
          var to_save = defaults.value(forKey: "bcc_tokens") as! Array<String>
          to_save.append(tokens[1])
          defaults.set(to_save, forKey: "bcc_tokens")
        } else {
          let to_save = [tokens[1]]
          let defaults = UserDefaults.standard
          defaults.set(to_save, forKey: "bcc_tokens")          
        }
        
        addNewTeam(token: tokens[1])
      } else if text.stringValue.hasPrefix("/tokens") {
        let existing = UserDefaults.standard.value(forKey: "bcc_tokens")
        Swift.print("www \(String(describing: existing))")
      } else if text.stringValue.hasPrefix("/logout") {
        let existing = UserDefaults.standard.value(forKey: "bcc_tokens") as! Array<String>
        for token in existing {
          UserDefaults.standard.removeObject(forKey: "bcc_\(token)")
        }
        UserDefaults.standard.removeObject(forKey: "bcc_tokens")
      }

      
      NotificationCenter.default.post(
        name:NSNotification.Name(rawValue: "sendMessage"),
        object: text.stringValue)
      text.stringValue = ""
      
      return true
    }
    return false
  }
  
  override init(frame frameRect: NSRect) {
    super.init(frame:frameRect);
    
    //autoresizingMask.insert(NSAutoresizingMaskOptions.viewMinYMargin)
    autoresizingMask.insert(NSAutoresizingMaskOptions.viewMaxYMargin)
    translatesAutoresizingMaskIntoConstraints = true
    
    wantsLayer = true
    layer?.backgroundColor = NSColor.darkGray.cgColor
    
    text.stringValue = ""
    text.isEditable = true
    text.backgroundColor = NSColor.white
    text.isBordered = true
    text.font = NSFont.systemFont(ofSize: 14.0)
    text.delegate = self;
    addSubview(text)
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
}
