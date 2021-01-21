//
//  TUSFileManager.swift
//  TUSKit
//
//  Created by Mark Robert Masterson on 4/16/20.
//

import Foundation

class TUSFileManager: NSObject {
    private weak var client: TUSClient?
    
    init(with client: TUSClient) {
        self.client = client
        super.init()
        self.createFileDirectory()
    }
    
    // MARK: Private file storage methods
    
    func fileStorePath() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let documentsDirectory: String = paths[0]
        return documentsDirectory.appending(TUSConstants.TUSFileDirectoryName)
    }
    
    private func createFileDirectory() {
        do {
            try FileManager.default.createDirectory(atPath: fileStorePath(), withIntermediateDirectories: false, attributes: nil)
        } catch let error as NSError {
            if (error.code != 516) { //516 is failed creating due to already existing
                let response: TUSResponse = TUSResponse(message: "Failed creating TUS directory in documents")
                client?.delegate?.TUSFailure(forUpload: nil, withResponse: response, andError: error)

            }
        }
    }
    
    internal func fileExists(withName name: String) -> Bool {
        return FileManager.default.fileExists(atPath: fileStorePath().appending(name))
    }
    
    internal func moveFile(atLocation location: URL, withFileName name: String) throws {
        try FileManager.default.moveItem(at: location, to: URL(fileURLWithPath: fileStorePath().appending(name)))
    }
    
    internal func writeData(withData data: Data, andFileName name: String) throws {
        try data.write(to: URL(fileURLWithPath: fileStorePath().appending(name)))
    }
    
    @discardableResult
    internal func deleteFile(withName name: String) -> Bool {
        do {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: fileStorePath().appending(name)))
                return true
        } catch let error as NSError {
            let response: TUSResponse = TUSResponse(message: "Failed deleting file \(name) from TUS folder storage")
            client?.delegate?.TUSFailure(forUpload: nil, withResponse: response, andError: error)
            return false
        }
    }
    
    internal func sizeForLocalFilePath(filePath:String) -> UInt64 {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: filePath)
            if let fileSize = fileAttributes[FileAttributeKey.size]  {
                return (fileSize as! NSNumber).uint64Value
            } else {
                let response: TUSResponse = TUSResponse(message: "Failed to get a size attribute from path: \(filePath)")
                client?.delegate?.TUSFailure(forUpload: nil, withResponse: response, andError: nil)
            }
        } catch {
            let response: TUSResponse = TUSResponse(message: "Failed to get a size attribute from path: \(filePath)")
            client?.delegate?.TUSFailure(forUpload: nil, withResponse: response, andError: error)
        }
        return 0
    }
}
