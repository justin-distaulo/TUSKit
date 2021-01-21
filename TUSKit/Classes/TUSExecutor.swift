//
//  TUSExecutor.swift
//  TUSKit
//
//  Created by Mark Robert Masterson on 4/16/20.
//

import Foundation

class TUSExecutor: NSObject, URLSessionDelegate {
    
    var customHeaders: [String: String] = [:]
    
    // MARK: Private Networking / Upload methods
    
    private func urlRequest(withFullURL url: URL, andMethod method: String, andContentLength contentLength: String?, andUploadLength uploadLength: String?, andHeaders headers: [String: String]) -> URLRequest {
        
        var request: URLRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.httpMethod = method
        request.addValue(TUSConstants.TUSProtocolVersion, forHTTPHeaderField: "TUS-Resumable")
        
        if let contentLength = contentLength {
            request.addValue(contentLength, forHTTPHeaderField: "Content-Length")
        }
        
        if let uploadLength = uploadLength {
            request.addValue(uploadLength, forHTTPHeaderField: "Upload-Length")
        }

        for header in headers.merging(customHeaders, uniquingKeysWith: { (current, _) in current }) {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }

        return request
    }
    
    func create(forUpload upload: TUSUpload, with client: TUSClient) {
        let request = urlRequest(withFullURL: client.uploadURL,
                                 andMethod: "POST",
                                 andContentLength: upload.contentLength,
                                 andUploadLength: upload.uploadLength,
                                 andHeaders: ["Upload-Extension": "creation", "Upload-Metadata": upload.encodedMetadata])
        
        let task =  client.tusSession.session.dataTask(with: request) { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    client.logger.log(forLevel: .Info, withMessage:String(format: "File %@ created", upload.id))
                    // Set the new status and other props for the upload
                    upload.status = .created
//                    upload.contentLength = httpResponse.allHeaderFields["Content-Length"] as? String
                    upload.uploadLocationURL = URL(string: httpResponse.allHeaderFieldsUpper()["LOCATION"]!, relativeTo: client.uploadURL)
                    //Begin the upload
                    client.updateUpload(upload)
                    self.upload(forUpload: upload, with: client)
                }
            }
        }
        task.resume()
    }
    
    func upload(forUpload upload: TUSUpload, with client: TUSClient) {
        /*
         If the Upload is from a file, turn into data.
         Loop through until file is fully uploaded and data range has been completed. On each successful chunk, save file to defaults
         */
        //First we create chunks
        
        client.logger.log(forLevel: .Info, withMessage: String(format: "Preparing upload data for file %@", upload.id))
        
        var fileUrl = URL(fileURLWithPath: client.fileManager.fileStorePath())
        fileUrl.appendPathComponent(upload.fileName)
        
        guard let uploadData = try? Data(contentsOf: fileUrl) else {
            return
        }
        
        let chunks = dataIntoChunks(data: uploadData,
                                    chunkSize: client.chunkSize * 1024 * 1024)
        //Then we start the upload from the first chunk
        self.upload(forChunks: chunks, withUpload: upload, with: client, atPosition: 0)
    }
    
    private func upload(forChunks chunks: [Data], withUpload upload: TUSUpload, with client: TUSClient, atPosition position: Int) {
        client.logger.log(forLevel: .Info, withMessage:String(format: "Upload starting for file %@ - Chunk %u / %u", upload.id, position + 1, chunks.count))
        let request: URLRequest = urlRequest(withFullURL: upload.uploadLocationURL!, andMethod: "PATCH", andContentLength: upload.contentLength!, andUploadLength: nil, andHeaders: ["Content-Type":"application/offset+octet-stream", "Upload-Offset": upload.uploadOffset!, "Content-Length": String(chunks[position].count), "Upload-Metadata": upload.encodedMetadata])
         let task = client.tusSession.session.uploadTask(with: request, from: chunks[position], completionHandler: { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200..<300:
                    //success
                    if (chunks.count > position+1 ){
                        upload.uploadOffset = httpResponse.allHeaderFieldsUpper()["UPLOAD-OFFSET"]
                        client.updateUpload(upload)
                        self.upload(forChunks: chunks, withUpload: upload, with: client, atPosition: position+1)
                    } else
                    if (httpResponse.statusCode == 204) {
                        client.logger.log(forLevel: .Info, withMessage:String(format: "Chunk %u / %u complete", position + 1, chunks.count))
                        if (position + 1 == chunks.count) {
                            client.logger.log(forLevel: .Info, withMessage:String(format: "File %@ uploaded at %@", upload.id, upload.uploadLocationURL!.absoluteString))
                            client.updateUpload(upload)
                            client.delegate?.TUSSuccess(forUpload: upload)
                            client.cleanUp(forUpload: upload)
                            client.status = .ready
                            if (client.currentUploads!.count > 0) {
                                client.createOrResume(forUpload: client.currentUploads![0])
                            }
                        }
                    }
                case 400..<500:
                    //reuqest error
                    client.delegate?.TUSFailure(forUpload: upload,
                                                          withResponse: nil,
                                                          andError: error)
                case 500..<600:
                    //server
                    client.delegate?.TUSFailure(forUpload: upload,
                                                          withResponse: nil,
                                                          andError: error)
                default: break
                }
            }
        })
        task.resume()
    }
    
    
    
    func cancel(forUpload upload: TUSUpload) {
        // TODO: Finish implementing this method?
    }
    
    private func dataIntoChunks(data: Data, chunkSize: Int) -> [Data] {
        var chunks = [Data]()
        var chunkStart = 0
        while(chunkStart < data.count) {
            let remaining = data.count - chunkStart
            let nextChunkSize = min(chunkSize, remaining)
            let chunkEnd = chunkStart + nextChunkSize
            
            chunks.append(data.subdata(in: chunkStart..<chunkEnd))
            
            chunkStart = chunkEnd
        }
        return chunks
    }
    
    // MARK: Private Networking / Other methods

    func get(forUpload upload: TUSUpload) {
        var request: URLRequest = URLRequest(url: upload.uploadLocationURL!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
//        let task = shared?.tusSession.session.downloadTask(with: request) { (url, response, error) in
//            shared?.logger.log(forLevel: .Info, withMessage:response!.description)
//        }
        // TODO: Finish implementing this method?
    }
}


