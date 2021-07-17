//
//  CloudCodeExecutionManager.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

class CloudCodeExecutionManager: ObservableObject{
    
    private static let judge0Server = "SERVER_URL"
    private static let judge0ExtraServer = "EXTRA_SERVER_URL"
    private static let judge0Key = "YOUR_OWN_KEY"
    
    @Published var isRunningCode = false
    @Published var consoleContent = ""
    @Published var stdin: String = ""
    
    private var mainSession: URLSession? = nil
    
    struct codeResult: Decodable {
        let status: codeStatus
        let stdout: String?
        let stderr: String?
        let compile_output: String?
        let message: String?
        let exit_code: Int?
        let exit_signal: Int?
        let time: String?
        let memory: Float?
    }
    
    struct codeStatus: Decodable {
        let description: String
        let id: Int
    }
    
    func stopRunning(){
        mainSession?.getTasksWithCompletionHandler { (dataTasks: Array, uploadTasks: Array, downloadTasks: Array) in
            for task in downloadTasks {
                task.cancel()
            }
            self.mainSession?.invalidateAndCancel()
        }
        
        DispatchQueue.main.async {
            self.isRunningCode = false
            self.consoleContent = "Execution cancelled."
        }
        
    }
    
    func runCode(directoryURL: URL, source: String, language: Int){
        self.isRunningCode = true
        
        self.consoleContent = "Running \(directoryURL.lastPathComponent) remotely..\n"
        
        var language = language
        if language == 71 {
            language = 10
        }
        
        var request = URLRequest(url: URL(string: "\(CloudCodeExecutionManager.judge0Server)/submissions/?base64_encoded=true&wait=true")!)
        if language == 10 {
            request = URLRequest(url: URL(string: "\(CloudCodeExecutionManager.judge0ExtraServer)/submissions/?base64_encoded=true&wait=true")!)
        }
        request.httpMethod = "POST"
        
        let parameters: [String: Any] = [
            "source_code": source.base64Encoded()!,
            "language_id": language,
            "stdin": stdin.base64Encoded()!,
            "cpu_time_limit": 6,
            "additional_files": returnDirectoryAsBase64(url: directoryURL.deletingLastPathComponent(), fileURL: directoryURL)
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
        } catch let error {
            print(error.localizedDescription)
        }
        
        request.addValue("application/json", forHTTPHeaderField: "content-Type")
        request.addValue("application/json", forHTTPHeaderField: "accept")
        request.addValue(CloudCodeExecutionManager.judge0Key, forHTTPHeaderField: "X-Auth-Token")
        
        mainSession = URLSession.shared
        
        mainSession?.dataTask(with: request) {data, response, err in
            guard self.isRunningCode else {
                return
            }
            if data != nil{
                DispatchQueue.main.async {
                    do{
                        let result = try JSONDecoder().decode(codeResult.self, from: data!)
                        
                        
                        if result.stderr != nil{
                            self.consoleContent += "\n" + result.stderr!.base64Decoded()! + "\n"
                        }
                        if result.compile_output != nil{
                            if let mes = (result.compile_output!).base64Decoded() {
                                self.consoleContent += "\n" + mes + "\n"
                            }
                        }
                        if result.stdout != nil{
                            self.consoleContent += "\n" + result.stdout!.base64Decoded()! + "\n"
                        }
                        if result.time != nil && result.memory != nil{
                            self.consoleContent += "\nProgram finished in \(result.time!)s with \(result.memory!)KB of memory."
                        }
                        self.isRunningCode = false
                        
                    }catch{
                        self.consoleContent.append("\nConnection failed.")
                        self.isRunningCode = false
                        print("Error info: \(error)")
                    }
                }
            }else{
                DispatchQueue.main.async {
                    self.consoleContent.append("\nConnection failed.")
                    self.isRunningCode = false
                }
                
            }

        }.resume()
        
    }
}