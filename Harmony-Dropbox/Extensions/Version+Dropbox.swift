//
//  Version+Dropbox.swift
//  Harmony-Dropbox
//
//  Created by Riley Testut on 3/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Harmony

import SwiftyDropbox

extension Version
{
    init?(metadata: Files.FileMetadata)
    {        
        self.init(identifier: metadata.rev, date: metadata.clientModified)
    }
}
