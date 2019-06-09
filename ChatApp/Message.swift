//
//  Message.swift
//  ChatApp
//
//  Created by 西谷恭紀 on 2019/06/09.
//  Copyright © 2019 西谷恭紀. All rights reserved.
//

import Foundation
import MessageKit

struct Message: MessageType {
    var sender: SenderType
    
    var messageId: String
    
    var sentDate: Date
    
    var kind: MessageKind
    
    
}
