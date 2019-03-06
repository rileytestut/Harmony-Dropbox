//
//  DropboxService.swift
//  Harmony-Dropbox
//
//  Created by Riley Testut on 3/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Harmony

import SwiftyDropbox

extension DropboxService
{
    enum DropboxError: LocalizedError
    {
        case nilDirectoryName
        
        var errorDescription: String? {
            switch self
            {
            case .nilDirectoryName: return NSLocalizedString("There is no provided Dropbox directory name.", comment: "")
            }
        }
    }
    
    private struct OAuthError: LocalizedError
    {
        var oAuthError: OAuth2Error
        var errorDescription: String?
        
        init(error: OAuth2Error, description: String)
        {
            self.oAuthError = error
            self.errorDescription = description
        }
    }
    
    internal struct CallError<T>: LocalizedError
    {
        var callError: SwiftyDropbox.CallError<T>
        
        var errorDescription: String? {
            return self.callError.description
        }
        
        init(_ callError: SwiftyDropbox.CallError<T>)
        {
            self.callError = callError
        }
    }
}

public class DropboxService: NSObject, Service
{
    public static let shared = DropboxService()
    
    public let localizedName = NSLocalizedString("Dropbox", comment: "")
    public let identifier = "com.rileytestut.Harmony.Dropbox"
    
    public var clientID: String? {
        didSet {
            guard let clientID = self.clientID else { return }
            DropboxClientsManager.setupWithAppKey(clientID)
        }
    }
    
    public var preferredDirectoryName: String?
    
    internal private(set) var dropboxClient: DropboxClient?
    internal let responseQueue = DispatchQueue(label: "com.rileytestut.Harmony.Dropbox.responseQueue")
    
    private var authorizationCompletionHandlers = [(Result<Account, AuthenticationError>) -> Void]()
    
    private var accountID: String? {
        get {
            return UserDefaults.standard.string(forKey: "harmony-dropbox_accountID")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "harmony-dropbox_accountID")
        }
    }
    
    private(set) var propertyGroupTemplate: (String, FileProperties.PropertyGroupTemplate)?
    
    private override init()
    {
        super.init()
    }
}

public extension DropboxService
{
    func authenticate(withPresentingViewController viewController: UIViewController, completionHandler: @escaping (Result<Account, AuthenticationError>) -> Void)
    {
        self.authorizationCompletionHandlers.append(completionHandler)
        
        DropboxClientsManager.authorizeFromController(UIApplication.shared, controller: viewController) { (url) in
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    func authenticateInBackground(completionHandler: @escaping (Result<Account, AuthenticationError>) -> Void)
    {
        guard let accountID = self.accountID else { return completionHandler(.failure(.noSavedCredentials)) }
        
        self.authorizationCompletionHandlers.append(completionHandler)
        
        DropboxClientsManager.reauthorizeClient(accountID)
        
        self.finishAuthentication()
    }
    
    func deauthenticate(completionHandler: @escaping (Result<Void, AuthenticationError>) -> Void)
    {
        DropboxClientsManager.unlinkClients()
        
        self.accountID = nil
        completionHandler(.success)
    }
    
    func handleDropboxURL(_ url: URL) -> Bool
    {
        guard let result = DropboxClientsManager.handleRedirectURL(url) else { return false }
        
        switch result
        {
        case .cancel:
            self.authorizationCompletionHandlers.forEach { $0(.failure(.other(GeneralError.cancelled))) }
            self.authorizationCompletionHandlers.removeAll()
            
        case .success:
            self.finishAuthentication()
            
        case .error(let error, let description):
            print("Error authorizing with Dropbox.", error, description)
            
            let oAuthError = OAuthError(error: error, description: description)
            self.authorizationCompletionHandlers.forEach { $0(.failure(.other(oAuthError))) }
            
            self.authorizationCompletionHandlers.removeAll()
        }
        
        return true
    }
}

extension DropboxService
{
    public func fetchVersions(for record: AnyRecord, completionHandler: @escaping (Result<[Version], RecordError>) -> Void) -> Progress
    {
        fatalError()
    }
}

private extension DropboxService
{
    func finishAuthentication()
    {
        func finish(_ result: Result<Account, AuthenticationError>)
        {
            self.authorizationCompletionHandlers.forEach { $0(result) }
            self.authorizationCompletionHandlers.removeAll()
        }
        
        guard let dropboxClient = DropboxClientsManager.authorizedClient else { return finish(.failure(.noSavedCredentials)) }
        
        dropboxClient.users.getCurrentAccount().response { (account, error) in
            if let account = account
            {
                self.createSyncDirectoryIfNeeded() { (result) in
                    switch result
                    {
                    case .success:
                        // Validate metadata first so we can also retrieve property group template ID.
                        let dummyMetadata = HarmonyMetadataKey.allHarmonyKeys.reduce(into: [:], { $0[$1] = $1.rawValue as Any })
                        self.validateMetadata(dummyMetadata) { (result) in
                            switch result
                            {
                            case .success:
                                // We could just always use DropboxClientsManager.authorizedClient,
                                // but this way dropboxClient is nil until _all_ authentication steps are finished.
                                self.dropboxClient = dropboxClient
                                self.accountID = account.accountId
                                
                                let account = Account(name: account.email)
                                finish(.success(account))
                                
                            case .failure(let error):
                                finish(.failure(.other(error)))
                            }
                        }
                        
                    case .failure(let error):
                        finish(.failure(.other(error)))
                    }
                }
            }
            
            if let error = error
            {
                let error = CallError(error)
                finish(.failure(.other(error)))
            }
        }
    }
    
    func createSyncDirectoryIfNeeded(completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        do
        {
            guard let dropboxClient = DropboxClientsManager.authorizedClient else { throw AuthenticationError.noSavedCredentials }
            
            let path = try self.remotePath(filename: nil)
            dropboxClient.files.getMetadata(path: path).response(queue: self.responseQueue) { (metadata, error) in
                // Retrieved metadata successfully, which means folder exists, so no need to do anything else.
                guard let error = error else { return completionHandler(.success) }
                
                if case .routeError(let error, _, _, _) = error, case .path(.notFound) = error.unboxed
                {
                    dropboxClient.files.createFolderV2(path: path).response(queue: self.responseQueue) { (result, error) in
                        do
                        {
                            if let error = error
                            {
                                throw NetworkError.connectionFailed(CallError(error))
                            }
                            
                            completionHandler(.success)
                        }
                        catch
                        {
                            completionHandler(.failure(error))
                        }
                    }
                }
                else
                {
                    completionHandler(.failure(CallError(error)))
                }
            }
        }
        catch
        {
            completionHandler(.failure(error))
        }
    }
}

extension DropboxService
{
    func validateMetadata<T>(_ metadata: [HarmonyMetadataKey: T], completionHandler: @escaping (Result<String, Error>) -> Void)
    {
        let fields = metadata.keys.map { FileProperties.PropertyFieldTemplate(name: $0.rawValue, description_: $0.rawValue, type: .string_) }
        
        do
        {
            guard let dropboxClient = DropboxClientsManager.authorizedClient else { throw AuthenticationError.noSavedCredentials }
            
            if let (templateID, propertyGroupTemplate) = self.propertyGroupTemplate
            {
                let existingFields = Set(propertyGroupTemplate.fields.map { $0.name })
                
                let addedFields = fields.filter { !existingFields.contains($0.name) }
                guard !addedFields.isEmpty else { return completionHandler(.success(templateID)) }
                
                dropboxClient.file_properties.templatesUpdateForUser(templateId: templateID, name: nil, description_: nil, addFields: addedFields).response(queue: self.responseQueue) { (result, error) in
                    do
                    {
                        guard let result = result else { throw NetworkError.connectionFailed(CallError(error!)) }
                        
                        let templateID = result.templateId
                        self.fetchPropertyGroupTemplate(forTemplateID: templateID) { (result) in
                            switch result
                            {
                            case .success: completionHandler(.success(templateID))
                            case .failure(let error): completionHandler(.failure(error))
                            }
                        }
                    }
                    catch
                    {
                        completionHandler(.failure(error))
                    }
                }
            }
            else
            {
                dropboxClient.file_properties.templatesListForUser().response(queue: self.responseQueue) { (result, error) in
                    do
                    {
                        guard let result = result else { throw NetworkError.connectionFailed(CallError(error!)) }
                        
                        if let templateID = result.templateIds.first
                        {
                            self.fetchPropertyGroupTemplate(forTemplateID: templateID) { (result) in
                                switch result
                                {
                                case .success: self.validateMetadata(metadata, completionHandler: completionHandler)
                                case .failure(let error): completionHandler(.failure(error))
                                }
                            }
                        }
                        else
                        {
                            dropboxClient.file_properties.templatesAddForUser(name: "Harmony", description_: "Harmony syncing metadata.", fields: fields).response(queue: self.responseQueue) { (result, error) in
                                do
                                {
                                    guard let result = result else { throw NetworkError.connectionFailed(CallError(error!)) }
                                    
                                    let templateID = result.templateId
                                    self.fetchPropertyGroupTemplate(forTemplateID: templateID) { (result) in
                                        switch result
                                        {
                                        case .success: completionHandler(.success(templateID))
                                        case .failure(let error): completionHandler(.failure(error))
                                        }
                                    }
                                }
                                catch
                                {
                                    completionHandler(.failure(error))
                                }
                            }
                        }
                    }
                    catch
                    {
                        completionHandler(.failure(error))
                    }
                }
            }
        }
        catch
        {
            completionHandler(.failure(error))
        }
    }
    
    func fetchPropertyGroupTemplate(forTemplateID templateID: String, completionHandler: @escaping (Result<FileProperties.PropertyGroupTemplate, Error>) -> Void)
    {
        do
        {
            guard let dropboxClient = DropboxClientsManager.authorizedClient else { throw AuthenticationError.noSavedCredentials }
            
            dropboxClient.file_properties.templatesGetForUser(templateId: templateID).response(queue: self.responseQueue) { (result, error) in
                do
                {
                    guard let result = result else { throw NetworkError.connectionFailed(CallError(error!)) }
                    self.propertyGroupTemplate = (templateID, result)
                    
                    completionHandler(.success(result))
                }
                catch
                {
                    completionHandler(.failure(error))
                }
            }
        }
        catch
        {
            completionHandler(.failure(error))
        }
    }
    
    func remotePath(filename: String?) throws -> String
    {
        guard let directoryName = self.preferredDirectoryName else { throw DropboxError.nilDirectoryName }
        
        var remotePath = "/" + directoryName
        
        if let filename = filename
        {
           remotePath += "/" + filename
        }
        
        return remotePath
    }
}
