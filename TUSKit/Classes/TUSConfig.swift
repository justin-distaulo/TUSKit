//
//  TUSConfig.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/6/20.
//

import Foundation

public struct TUSConfig {
    var uploadURL: URL
    var URLSessionConfig: URLSessionConfiguration = URLSessionConfiguration.default
    public var logLevel: TUSLogLevel = .Off
    
    public init(withUploadURL uploadURL: URL, andSessionConfig sessionConfig: URLSessionConfiguration = URLSessionConfiguration.default) {
        self.uploadURL = uploadURL
        self.URLSessionConfig = sessionConfig
    }
}
