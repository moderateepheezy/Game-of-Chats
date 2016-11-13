//
//  Message.swift
//  Game-Of-Chat
//
//  Created by SimpuMind on 11/11/16.
//  Copyright © 2016 SimpuMind. All rights reserved.
//

import UIKit
import Firebase

class Message: NSObject {
    
    var fromId: String?
    var text: String?
    var timestamp: NSNumber?
    var toId: String?
    
    func checkPartnerId() -> String?{
        
        return (fromId == FIRAuth.auth()?.currentUser?.uid ? toId : fromId)!
    }
}
