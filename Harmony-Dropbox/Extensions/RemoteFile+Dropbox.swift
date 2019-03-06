//
//  RemoteFile+Dropbox.swift
//  Harmony-Dropbox
//
//  Created by Riley Testut on 3/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Harmony

import SwiftyDropbox

extension RemoteFile
{
    convenience init?(file: Files.FileMetadata, metadata: [HarmonyMetadataKey: Any]?, context: NSManagedObjectContext)
    {
        guard let identifier = file.pathLower, let metadata = file.propertyGroups?.first?.metadata ?? metadata?.compactMapValues({ $0 as? String }) else { return nil }
        
        try? self.init(remoteIdentifier: identifier, versionIdentifier: file.rev, size: Int(file.size), metadata: metadata, context: context)
    }
}
