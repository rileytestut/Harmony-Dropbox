//
//  PropertyGroup+Harmony.swift
//  Harmony-Dropbox
//
//  Created by Riley Testut on 3/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import SwiftyDropbox

import Harmony

extension FileProperties.PropertyGroup
{
    var metadata: [HarmonyMetadataKey: String] {
        let metadata = self.fields.reduce(into: [:]) { $0[HarmonyMetadataKey($1.name)] = $1.value }
        return metadata
    }
    
    convenience init<T>(templateID: String, metadata: [HarmonyMetadataKey: T])
    {
        let propertyFields = metadata.compactMap { (key, value) -> FileProperties.PropertyField? in
            guard let value = value as? String else { return nil }
            
            let propertyField = FileProperties.PropertyField(name: key.rawValue, value: value)
            return propertyField
        }
        
        self.init(templateId: templateID, fields: propertyFields)
    }
}
