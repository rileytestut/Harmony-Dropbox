//
//  DropboxService+Files.swift
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
    func upload(_ file: File, for record: AnyRecord, metadata: [HarmonyMetadataKey : Any], context: NSManagedObjectContext, completionHandler: @escaping (Result<RemoteFile, FileError>) -> Void) -> Progress
    {
        let progress = Progress.discreteProgress(totalUnitCount: 1)
        
        var didAddChildProgress = false
        
        self.validateMetadata(metadata) { (result) in
            do
            {
                let templateID = try result.get()
                                
                guard let dropboxClient = self.dropboxClient else { throw AuthenticationError.notAuthenticated }
                
                let filename = String(describing: record.recordID) + "-" + file.identifier
                
                let path = try self.remotePath(filename: filename)
                let propertyGroup = FileProperties.PropertyGroup(templateID: templateID, metadata: metadata)
                let request = dropboxClient.files.upload(path: path, mode: .overwrite, autorename: false, mute: false, propertyGroups: [propertyGroup], strictConflict: false, input: file.fileURL)
                    .progress { (fileProgress) in
                        guard !didAddChildProgress else { return }
                        
                        progress.addChild(fileProgress, withPendingUnitCount: 1)
                        didAddChildProgress = true
                    }
                    .response(queue: self.responseQueue) { (dropboxFile, error) in
                        context.perform {
                            do
                            {
                                let file = try self.process(Result(dropboxFile, error))
                                
                                guard let remoteFile = RemoteFile(file: file, metadata: metadata, context: context) else { throw ServiceError.invalidResponse }
                                
                                completionHandler(.success(remoteFile))
                            }
                            catch
                            {
                                completionHandler(.failure(FileError(file.identifier, error)))
                            }
                        }
                }
                
                progress.cancellationHandler = {
                    request.cancel()
                    completionHandler(.failure(FileError(file.identifier, GeneralError.cancelled)))
                }
            }
            catch
            {
                completionHandler(.failure(FileError(file.identifier, error)))
            }
        }
        
        return progress
    }
    
    func download(_ remoteFile: RemoteFile, completionHandler: @escaping (Result<File, FileError>) -> Void) -> Progress
    {
        let progress = Progress.discreteProgress(totalUnitCount: 1)
        
        let fileIdentifier = remoteFile.identifier
        
        var didAddChildProgress = false
        
        do
        {
            guard let dropboxClient = self.dropboxClient else { throw AuthenticationError.notAuthenticated }
            
            let temporaryURL = FileManager.default.uniqueTemporaryURL()
            let request = dropboxClient.files.download(path: remoteFile.remoteIdentifier, rev: remoteFile.versionIdentifier, destination: { (_, _) in temporaryURL })
                .progress { (fileProgress) in
                    guard !didAddChildProgress else { return }
                    
                    progress.addChild(fileProgress, withPendingUnitCount: 1)
                    didAddChildProgress = true
                }
                .response(queue: self.responseQueue) { (result, error) in
                do
                {
                    let (_, fileURL) = try self.process(Result(result, error))
                    
                    let file = File(identifier: fileIdentifier, fileURL: fileURL)
                    completionHandler(.success(file))
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
    
    func delete(_ remoteFile: RemoteFile, completionHandler: @escaping (Result<Void, FileError>) -> Void) -> Progress
    {
        let progress = Progress.discreteProgress(totalUnitCount: 1)
        
        let fileIdentifier = remoteFile.identifier
        
        do
        {
            guard let dropboxClient = self.dropboxClient else { throw AuthenticationError.notAuthenticated }
            
            let request = dropboxClient.files.deleteV2(path: remoteFile.remoteIdentifier).response(queue: self.responseQueue) { (result, error) in
                do
                {
                    try self.process(Result(error))
                    
                    completionHandler(.success)
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
