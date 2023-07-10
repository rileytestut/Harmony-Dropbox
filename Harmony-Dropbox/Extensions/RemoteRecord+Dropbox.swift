//
//  RemoteRecord+Dropbox.swift
//  Harmony-Dropbox
//
//  Created by Riley Testut on 3/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Harmony

import SwiftyDropbox

extension RemoteRecord
{
    convenience init?(file: Files.FileMetadata, metadata: [HarmonyMetadataKey: Any]?, status: RecordStatus, context: NSManagedObjectContext)
    {
        guard let identifier = file.pathLower, let metadata = file.propertyGroups?.first?.metadata ?? metadata?.compactMapValues({ $0 as? String }) else { return nil }
        
        try? self.init(identifier: identifier, versionIdentifier: file.rev, versionDate: file.clientModified, metadata: metadata, status: status, context: context)
    }
}
