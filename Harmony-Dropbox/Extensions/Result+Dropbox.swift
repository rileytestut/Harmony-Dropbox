//
//  Result+Dropbox.swift
//  Harmony-Dropbox
//
//  Created by Riley Testut on 3/12/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Harmony
import SwiftyDropbox

extension Result
{
    init<E>(_ value: Success?, _ error: SwiftyDropbox.CallError<E>?) where Failure == DropboxService.CallError<E>
    {
        switch (value, error)
        {
        case (let value?, _): self = .success(value)
        case (_, let error?): self = .failure(DropboxService.CallError(error))
        case (nil, nil): self = .failure(DropboxService.CallError(SwiftyDropbox.CallError<E>.clientError(ServiceError.invalidResponse)))
        }
    }
}

extension Result where Success == Void
{
    init<E>(_ error: SwiftyDropbox.CallError<E>?) where Failure == DropboxService.CallError<E>
    {
        if let error = error
        {
            self = .failure(DropboxService.CallError(error))
        }
        else
        {
            self = .success
        }
    }
}
