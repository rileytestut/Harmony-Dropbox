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
    
    private struct CallError<T>: LocalizedError
    {
        var callError: SwiftyDropbox.CallError<T>
        
        var errorDescription: String? {
            return self.callError.description
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
    
    private var authorizationCompletionHandlers = [(Result<Account, AuthenticationError>) -> Void]()
    
    private var accountID: String? {
        get {
            return UserDefaults.standard.string(forKey: "harmony-dropbox_accountID")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "harmony-dropbox_accountID")
        }
    }
    
    private var dropboxClient: DropboxClient?
    
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
    
    private func finishAuthentication()
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
                self.dropboxClient = dropboxClient
                self.accountID = account.accountId
                
                let account = Account(name: account.email)
                finish(.success(account))
            }
            
            if let error = error
            {
                let error = CallError(callError: error)
                finish(.failure(.other(error)))
            }
        }
    }
}

extension DropboxService
{
    public func fetchAllRemoteRecords(context: NSManagedObjectContext, completionHandler: @escaping (Result<(Set<RemoteRecord>, Data), FetchError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    public func fetchChangedRemoteRecords(changeToken: Data, context: NSManagedObjectContext, completionHandler: @escaping (Result<(Set<RemoteRecord>, Set<String>, Data), FetchError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    public func upload(_ record: AnyRecord, metadata: [HarmonyMetadataKey : Any], context: NSManagedObjectContext, completionHandler: @escaping (Result<RemoteRecord, RecordError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    public func download(_ record: AnyRecord, version: Version, context: NSManagedObjectContext, completionHandler: @escaping (Result<LocalRecord, RecordError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    public func delete(_ record: AnyRecord, completionHandler: @escaping (Result<Void, RecordError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    public func upload(_ file: File, for record: AnyRecord, metadata: [HarmonyMetadataKey : Any], context: NSManagedObjectContext, completionHandler: @escaping (Result<RemoteFile, FileError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    public func download(_ remoteFile: RemoteFile, completionHandler: @escaping (Result<File, FileError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    public func delete(_ remoteFile: RemoteFile, completionHandler: @escaping (Result<Void, FileError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    public func updateMetadata(_ metadata: [HarmonyMetadataKey : Any], for record: AnyRecord, completionHandler: @escaping (Result<Void, RecordError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    public func fetchVersions(for record: AnyRecord, completionHandler: @escaping (Result<[Version], RecordError>) -> Void) -> Progress
    {
        fatalError()
    }
}
