//
//  DropboxService+Versions.swift
//  Harmony-Dropbox
//
//  Created by Riley Testut on 3/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Harmony

import SwiftyDropbox

public extension DropboxService
{
    func fetchVersions(for record: AnyRecord, completionHandler: @escaping (Result<[Version], RecordError>) -> Void) -> Progress
    {
        let progress = Progress.discreteProgress(totalUnitCount: 1)
        
        do
        {
            guard let dropboxClient = self.dropboxClient else { throw AuthenticationError.notAuthenticated }
            
            try record.perform() { (managedRecord) -> Void in
                guard let remoteRecord = managedRecord.remoteRecord else { throw ValidationError.nilRemoteRecord }
                
                let request = dropboxClient.files.listRevisions(path: remoteRecord.identifier, limit: 100).response(queue: self.responseQueue) { (result, error) in
                    do
                    {
                        let result = try self.process(Result(result, error))
     
                        let versions = result.entries.compactMap(Version.init(metadata:))
                        completionHandler(.success(versions))
                        
                        progress.completedUnitCount = 1
                    }
                    catch
                    {
                        completionHandler(.failure(RecordError(record, error)))
                    }
                }
                
                progress.cancellationHandler = {
                    request.cancel()
                    completionHandler(.failure(RecordError(record, GeneralError.cancelled)))
                }
            }
        }
        catch
        {
            completionHandler(.failure(RecordError(record, error)))
        }
        
        return progress
    }
    
    func fetchVersions(for remoteFile: RemoteFile, completionHandler: @escaping (Result<[Version], FileError>) -> Void) -> Progress
    {
        let progress = Progress.discreteProgress(totalUnitCount: 1)
        let fileIdentifier = remoteFile.identifier
        
        do
        {
            guard let dropboxClient = self.dropboxClient else { throw AuthenticationError.notAuthenticated }
            
            let request = dropboxClient.files.listRevisions(path: remoteFile.remoteIdentifier, limit: 100).response(queue: self.responseQueue) { (result, error) in
                do
                {
                    let result = try self.process(Result(result, error))
 
                    let versions = result.entries.compactMap(Version.init(metadata:))
                    completionHandler(.success(versions))
                    
                    progress.completedUnitCount = 1
                }
                catch
                {
                    completionHandler(.failure(FileError(fileIdentifier, error)))
                }
            }
            
            progress.cancellationHandler = {
                request.cancel()
                completionHandler(.failure(FileError(fileIdentifier, GeneralError.cancelled)))
            }
        }
        catch
        {
            completionHandler(.failure(FileError(fileIdentifier, error)))
        }
        
        return progress
    }
}
