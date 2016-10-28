/*
 * Cordova WebSocket Server Plugin
 *
 * WebSocket Server plugin for Cordova/Phonegap 
 * by Sylvain Brejeon
 */
 
import Foundation

@objc(WebSocketServer) public class WebSocketServer : CDVPlugin, PSWebSocketServerDelegate {
    
    fileprivate var wsserver: PSWebSocketServer?
    fileprivate var port: Int?
    fileprivate var origins: [String]?
    fileprivate var protocols: [String]?
    fileprivate var UUIDSockets: [String: PSWebSocket]!
    fileprivate var socketsUUID: [PSWebSocket: String]!
    fileprivate var remoteAddresses: [PSWebSocket: String]!
    fileprivate var listenerCallbackId: String?
    
    override public func pluginInitialize() {
        UUIDSockets  = [:]
        socketsUUID = [:]
        remoteAddresses = [:]
    }
    
    override public func onAppTerminate() {
        if let server = wsserver {
            server.stop()
            wsserver = nil
            UUIDSockets.removeAll()
            socketsUUID.removeAll()
            remoteAddresses.removeAll()
        }
    }
    
    public func getInterfaces(_ command: CDVInvokedUrlCommand) {
        
        commandDelegate?.run(inBackground: {
        
            var ipv4Addresses: [String] = []
            var ipv6Addresses: [String] = []
        
            for intf in Interface.allInterfaces() {
                if !intf.isLoopback {
                    if intf.family == .ipv6 {
                        ipv6Addresses.append(intf.address!)
                    } else if intf.family == .ipv4 {
                        ipv4Addresses.append(intf.address!)
                    }
                }
            }
            
            if ipv6Addresses.count > 1 {
                ipv6Addresses = Array(Set(ipv6Addresses))
            }
        
            let addresses: NSDictionary = NSDictionary(objects: [ipv4Addresses, ipv6Addresses], forKeys: ["ipv4Addresses" as NSCopying, "ipv6Addresses" as NSCopying])
            
            #if DEBUG
                print("WebSocketServer: getInterfaces: \(addresses)")
            #endif
            
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: addresses as! [AnyHashable: Any])
            pluginResult?.setKeepCallbackAs(false)
            self.commandDelegate?.send(pluginResult, callbackId: command.callbackId)
            
        })
        
    }
    
    public func start(_ command: CDVInvokedUrlCommand) {
        
        #if DEBUG
            print("WebSocketServer: start")
        #endif
        
        if wsserver != nil {
            return
        }
        
        port = command.argument(at: 0) as? Int
        origins = command.argument(at: 1) as? [String]
        protocols = command.argument(at: 2) as? [String]
        
        if let server = PSWebSocketServer(host: nil, port: UInt(port!)) {
            listenerCallbackId = command.callbackId
            wsserver = server
            server.delegate = self
            
            commandDelegate?.run(inBackground: {
                server.start()
            })
            
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_NO_RESULT)
            pluginResult?.setKeepCallbackAs(true)
        }
        
    }
    
    public func stop(_ command: CDVInvokedUrlCommand) {
        
        #if DEBUG
            print("WebSocketServer: stop")
        #endif
        
        if let server = wsserver {
            
            commandDelegate?.run(inBackground: {
                server.stop()
            })
        
        }
    }
    
    public func send(_ command: CDVInvokedUrlCommand) {
        
        #if DEBUG
            print("WebSocketServer: send")
        #endif
        
        let uuid = command.argument(at: 0) as? String
        let msg = command.argument(at: 1) as? String
        
        if uuid != nil && msg != nil {
            if let webSocket = UUIDSockets[uuid!] {
                
                commandDelegate?.run(inBackground: {
                    webSocket.send(msg)
                })
                
            } else {
                #if DEBUG
                    print("WebSocketServer: Send: unknown socket.")
                #endif
            }
        } else {
            #if DEBUG
                print("WebSocketServer: Send: UUID or msg not specified.")
            #endif
        }
    }
    
    public func close(_ command: CDVInvokedUrlCommand) {
        
        #if DEBUG
            print("WebSocketServer: close")
        #endif
        
        let uuid = command.argument(at: 0) as? String
        let code = command.argument(at: 1, withDefault: -1) as! Int
        let reason = command.argument(at: 2) as? String
        
        if uuid != nil {
            if let webSocket = UUIDSockets[uuid!] {
                
                commandDelegate?.run(inBackground: {
                    if (code == -1) {
                        webSocket.close()
                    } else {
                        webSocket.close(withCode: code, reason: reason)
                    }
                })
                
            } else {
                #if DEBUG
                    print("WebSocketServer: Close: unknown socket.")
                #endif
            }
        } else {
            #if DEBUG
                print("WebSocketServer: Close: UUID not specified.")
            #endif
        }
    }
    
    public func serverDidStart(_ server: PSWebSocketServer!) {
        
        #if DEBUG
            print("WebSocketServer: Server did start…")
        #endif
        
        let status: NSDictionary = NSDictionary(objects: ["onStart", "0.0.0.0", Int(server.realPort)], forKeys: ["action" as NSCopying, "addr" as NSCopying, "port" as NSCopying])
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: status as! [AnyHashable: Any])
        pluginResult?.setKeepCallbackAs(true)
        commandDelegate?.send(pluginResult, callbackId: listenerCallbackId)
    }
    
    public func serverDidStop(_ server: PSWebSocketServer!) {
        
        #if DEBUG
            print("WebSocketServer: Server did stop…")
        #endif
        
        wsserver = nil
        UUIDSockets.removeAll()
        socketsUUID.removeAll()
        remoteAddresses.removeAll()
        
        let status: NSDictionary = NSDictionary(objects: ["onStop", "0.0.0.0", Int(server.realPort)], forKeys: ["action" as NSCopying, "addr" as NSCopying, "port" as NSCopying])
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: status as! [AnyHashable: Any])
        pluginResult?.setKeepCallbackAs(false)
        commandDelegate?.send(pluginResult, callbackId: listenerCallbackId)
    }
    
    public func server(_ server: PSWebSocketServer!, didFailWithError error: Error!) {
        
        #if DEBUG
            print("WebSocketServer: Server did fail with error: \(error)")
        #endif
        
        wsserver = nil
        UUIDSockets.removeAll()
        socketsUUID.removeAll()
        remoteAddresses.removeAll()
        
        let status: NSDictionary = NSDictionary(objects: ["onDidNotStart", "0.0.0.0", port!], forKeys: ["action" as NSCopying, "addr" as NSCopying, "port" as NSCopying])
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: status as! [AnyHashable: Any])
        pluginResult?.setKeepCallbackAs(false)
        commandDelegate?.send(pluginResult, callbackId: listenerCallbackId)
    }
    
    public func server(_ server: PSWebSocketServer!, acceptWebSocketFrom address: Data, with request: URLRequest, trust: SecTrust, response: AutoreleasingUnsafeMutablePointer<HTTPURLResponse?>) -> Bool {
        
        #if DEBUG
            print("WebSocketServer: Server should accept request: \(request)")
        #endif
        
        if let o = origins {
            let origin = request.value(forHTTPHeaderField: "Origin")
            if o.index(of: origin!) == nil {
                #if DEBUG
                    print("WebSocketServer: Origin denied: \(origin)")
                #endif
                return false
            }
        }
        
        if let _ = protocols {
            if let acceptedProtocol = getAcceptedProtocol(request) {
                let headerFields = [ "Sec-WebSocket-Protocol" : acceptedProtocol ]
                let r = HTTPURLResponse.init(url: request.url!, statusCode: 200, httpVersion: "1.1", headerFields: headerFields )!
                response.pointee = r
            } else {
                #if DEBUG
                    let secWebSocketProtocol = request.value(forHTTPHeaderField: "Sec-WebSocket-Protocol")
                    print("WebSocketServer: Sec-WebSocket-Protocol denied: \(secWebSocketProtocol)")
                #endif
                return false
            }
        }
        
        return true;
    }
    
    public func server(_ server: PSWebSocketServer!, webSocketDidOpen webSocket: PSWebSocket!) {
        
        #if DEBUG
            print("WebSocketServer: WebSocket did open")
        #endif
        
        var uuid: String!
        while uuid == nil || UUIDSockets[uuid] != nil {
            // prevent collision
            uuid = UUID().uuidString
        }
        UUIDSockets[uuid] = webSocket
        socketsUUID[webSocket] = uuid
        
        var remoteAddr = ""
        if let addr = extractAddress(webSocket.remoteAddress) {
            remoteAddr = addr
            remoteAddresses[webSocket] = addr
        }
        
        var acceptedProtocol = ""
        if (protocols != nil) {
            acceptedProtocol = getAcceptedProtocol(webSocket.urlRequest)!
        }
        
        let httpFields = webSocket.urlRequest.allHTTPHeaderFields!
        let resource = String(cString: (webSocket.urlRequest.url!.query?.cString(using: String.Encoding.utf8))! )
		
        let conn: NSDictionary = NSDictionary(objects: [uuid, remoteAddr, acceptedProtocol, httpFields, resource], forKeys: ["uuid" as NSCopying, "remoteAddr" as NSCopying, "acceptedProtocol" as NSCopying, "httpFields" as NSCopying, "resource" as NSCopying])
        let status: NSDictionary = NSDictionary(objects: ["onOpen", conn], forKeys: ["action" as NSCopying, "conn" as NSCopying])
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: status as! [AnyHashable: Any])
        pluginResult?.setKeepCallbackAs(true)
        commandDelegate?.send(pluginResult, callbackId: listenerCallbackId)
    }
    
    public func server(_ server: PSWebSocketServer!, webSocket: PSWebSocket!, didReceiveMessage message: Any) {
        
        #if DEBUG
            print("WebSocketServer: Websocket did receive message: \(message)")
        #endif
        
        if let uuid = socketsUUID[webSocket] {

            var remoteAddr = ""
            if let addr = extractAddress(webSocket.remoteAddress) {
                remoteAddr = addr
                remoteAddresses[webSocket] = addr
            }

            let conn: NSDictionary = NSDictionary(objects: [uuid, remoteAddr], forKeys: ["uuid" as NSCopying, "remoteAddr" as NSCopying])
            let status: NSDictionary = NSDictionary(objects: ["onMessage", conn, message], forKeys: ["action" as NSCopying, "conn" as NSCopying, "msg" as NSCopying])
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: status as! [AnyHashable: Any])
            pluginResult?.setKeepCallbackAs(true)
            commandDelegate?.send(pluginResult, callbackId: listenerCallbackId)
        } else {
            #if DEBUG
                print("WebSocketServer: unknown socket")
            #endif
        }
    }
    
    public func server(_ server: PSWebSocketServer!, webSocket: PSWebSocket!, didCloseWithCode code: Int, reason: String, wasClean: Bool) {
        
        #if DEBUG
            print("WebSocketServer: WebSocket did close with code: \(code), reason: \(reason), wasClean: \(wasClean)")
        #endif
        
        if let uuid = socketsUUID[webSocket] {
            
            let remoteAddr = remoteAddresses[webSocket] // extractAddress(webSocket.remoteAddress)! bad access error
            
            let conn: NSDictionary = NSDictionary(objects: [uuid, remoteAddr!], forKeys: ["uuid" as NSCopying, "remoteAddr" as NSCopying])
            let status: NSDictionary = NSDictionary(objects: ["onClose", conn, code, reason, wasClean], forKeys: ["action" as NSCopying, "conn" as NSCopying, "code" as NSCopying, "reason" as NSCopying, "wasClean" as NSCopying])
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: status as! [AnyHashable: Any])
            pluginResult?.setKeepCallbackAs(true)
            commandDelegate?.send(pluginResult, callbackId: listenerCallbackId)
            
            socketsUUID.removeValue(forKey: webSocket)
            UUIDSockets.removeValue(forKey: uuid)
            remoteAddresses.removeValue(forKey: webSocket)
        } else {
            #if DEBUG
                print("WebSocketServer: unknown socket")
            #endif
        }
    }
    
    public func server(_ server: PSWebSocketServer!, webSocket: PSWebSocket!, didFailWithError error: Error!) {
        
        #if DEBUG
            print("WebSocketServer: WebSocket did fail with error: \(error)")
        #endif
    }
    
    fileprivate func getAcceptedProtocol(_ request: URLRequest) -> String? {
        var acceptedProtocol: String?
        if let secWebSocketProtocol = request.value(forHTTPHeaderField: "Sec-WebSocket-Protocol") {
            let requestedProtocols = secWebSocketProtocol.components(separatedBy: ", ")
            for requestedProtocol in requestedProtocols {
                if protocols!.index(of: requestedProtocol) != nil {
                    // returns first matching protocol.
                    // assumes in order of preference.
                    acceptedProtocol = requestedProtocol
                    break
                }
            }
            #if DEBUG
                print("WebSocketServer: Sec-WebSocket-Protocol: \(secWebSocketProtocol)")
                print("WebSocketServer: Accepted Protocol: \(acceptedProtocol)")
            #endif
        }
        return acceptedProtocol
    }
    
    fileprivate func extractAddress(_ addressBytes:Data) -> String? {
        var addr = (addressBytes as NSData).bytes.load(as: sockaddr.self)
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if (getnameinfo(&addr, socklen_t(addr.sa_len), &hostname,
                        socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0) {
            return String(cString: hostname)
        }
        return nil
    }
}
