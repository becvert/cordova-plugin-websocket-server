/*
 * Cordova WebSocket Server Plugin
 *
 * WebSocket Server plugin for Cordova/Phonegap 
 * by Sylvain Brejeon
 */
 
import Foundation

@objc(WebSocketServer) public class WebSocketServer : CDVPlugin, PSWebSocketServerDelegate {
    
    fileprivate var wsserver: PSWebSocketServer?
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
            
            let intfs = self.getWiFiAddresses()
            
            let pluginResult = CDVPluginResult( status: CDVCommandStatus_OK, messageAs: intfs)
            self.commandDelegate?.send(pluginResult, callbackId: command.callbackId)
        })
        
    }
    
    public func start(_ command: CDVInvokedUrlCommand) {
        
        #if DEBUG
            print("start")
        #endif
        
        if wsserver != nil {
            return
        }
        
        let port = command.argument(at: 0) as? Int
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
            print("stop")
        #endif
        
        if let server = wsserver {
            
            commandDelegate?.run(inBackground: {
                server.stop()
            })
        
        }
    }
    
    public func send(_ command: CDVInvokedUrlCommand) {
        
        #if DEBUG
            print("send")
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
                    print("Send: unknown socket.")
                #endif
            }
        } else {
            #if DEBUG
                print("Send: UUID or msg not specified.")
            #endif
        }
    }
    
    public func close(_ command: CDVInvokedUrlCommand) {
        
        #if DEBUG
            print("close")
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
                    print("Close: unknown socket.")
                #endif
            }
        } else {
            #if DEBUG
                print("Close: UUID not specified.")
            #endif
        }
    }
    
    public func serverDidStart(_ server: PSWebSocketServer!) {
        
        #if DEBUG
            print("Server did start…")
        #endif
        
        let status: NSDictionary = NSDictionary(objects: ["onStart", "0.0.0.0", Int(server.realPort)], forKeys: ["action" as NSCopying, "addr" as NSCopying, "port" as NSCopying])
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: status as! [AnyHashable: Any])
        pluginResult?.setKeepCallbackAs(true)
        commandDelegate?.send(pluginResult, callbackId: listenerCallbackId)
    }
    
    public func serverDidStop(_ server: PSWebSocketServer!) {
        
        #if DEBUG
            print("Server did stop…")
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
            print("Server did fail with error: \(error)")
        #endif
    }
    
    public func server(_ server: PSWebSocketServer!, acceptWebSocketFrom address: Data, with request: URLRequest, trust: SecTrust, response: AutoreleasingUnsafeMutablePointer<HTTPURLResponse?>) -> Bool {
        
        #if DEBUG
            print("Server should accept request: \(request)")
        #endif
        
        if let o = origins {
            let origin = request.value(forHTTPHeaderField: "Origin")
            if o.index(of: origin!) == nil {
                #if DEBUG
                    print("Origin denied: \(origin)")
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
                    print("Sec-WebSocket-Protocol denied: \(secWebSocketProtocol)")
                #endif
                return false
            }
        }
        
        return true;
    }
    
    public func server(_ server: PSWebSocketServer!, webSocketDidOpen webSocket: PSWebSocket!) {
        
        #if DEBUG
            print("WebSocket did open")
        #endif
        
        var uuid: String!
        while uuid == nil || UUIDSockets[uuid] != nil {
            // prevent collision
            uuid = UUID().uuidString
        }
        UUIDSockets[uuid] = webSocket
        socketsUUID[webSocket] = uuid
        
        let remoteAddr = IP(webSocket.remoteAddress)
        remoteAddresses[webSocket] = remoteAddr
        
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
            print("Server websocket did receive message: \(message)")
        #endif
        
        if let uuid = socketsUUID[webSocket] {

            let remoteAddr = IP(webSocket.remoteAddress)

            let conn: NSDictionary = NSDictionary(objects: [uuid, remoteAddr], forKeys: ["uuid" as NSCopying, "remoteAddr" as NSCopying])
            let status: NSDictionary = NSDictionary(objects: ["onMessage", conn, message], forKeys: ["action" as NSCopying, "conn" as NSCopying, "msg" as NSCopying])
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: status as! [AnyHashable: Any])
            pluginResult?.setKeepCallbackAs(true)
            commandDelegate?.send(pluginResult, callbackId: listenerCallbackId)
        } else {
            #if DEBUG
                print("unknown socket")
            #endif
        }
    }
    
    public func server(_ server: PSWebSocketServer!, webSocket: PSWebSocket!, didCloseWithCode code: Int, reason: String, wasClean: Bool) {
        
        #if DEBUG
            print("WebSocket did close with code: \(code), reason: \(reason), wasClean: \(wasClean)")
        #endif
        
        if let uuid = socketsUUID[webSocket] {
            
            let remoteAddr = remoteAddresses[webSocket] // IP(ws.remoteAddress) bad access error
            
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
                print("unknown socket")
            #endif
        }
    }
    
    public func server(_ server: PSWebSocketServer!, webSocket: PSWebSocket!, didFailWithError error: Error!) {
        
        #if DEBUG
            print("WebSocket did fail with error: \(error)")
        #endif
    }
    
    // http://dev.eltima.com/post/99996366184/using-bonjour-in-swift
    fileprivate func IP(_ addressBytes: Data) -> String {
        var inetAddress : sockaddr_in!
        var inetAddress6 : sockaddr_in6!
        //NSData’s bytes returns a read-only pointer to the receiver’s contents.
        let inetAddressPointer = (addressBytes as NSData).bytes.bindMemory(to: sockaddr_in.self, capacity: addressBytes.count)
        //Access the underlying raw memory
        inetAddress = inetAddressPointer.pointee
        if inetAddress.sin_family == __uint8_t(AF_INET) {
        }
        else {
            if inetAddress.sin_family == __uint8_t(AF_INET6) {
                let inetAddressPointer6 = (addressBytes as NSData).bytes.bindMemory(to: sockaddr_in6.self, capacity: addressBytes.count)
                inetAddress6 = inetAddressPointer6.pointee
                inetAddress = nil
            }
            else {
                inetAddress = nil
            }
        }
        var ipString : UnsafePointer<CChar>?
        //static func alloc(num: Int) -> UnsafeMutablePointer
        let ipStringBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(INET6_ADDRSTRLEN))
        if inetAddress != nil {
            var addr = inetAddress.sin_addr
            ipString = inet_ntop(Int32(inetAddress.sin_family),
                &addr,
                ipStringBuffer,
                __uint32_t (INET6_ADDRSTRLEN))
        } else {
            if inetAddress6 != nil {
                var addr = inetAddress6.sin6_addr
                ipString = inet_ntop(Int32(inetAddress6.sin6_family),
                    &addr,
                    ipStringBuffer,
                    __uint32_t(INET6_ADDRSTRLEN))
            }
        }
        if ipString != nil {
            let ip = String(cString: ipString!)
            return ip
        }
        return "0.0.0.0"
    }
    
    // http://stackoverflow.com/questions/30748480/swift-get-devices-ip-address
    fileprivate func getWiFiAddresses() -> [String] {
        var addresses : [String] = []
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            // For each interface ...
            var ptr = ifaddr;
            while (ptr != nil) {
                let interface = ptr?.pointee
                
                // Check for IPv4 interface:
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    
                    // Check interface name:
                    if let name = String(validatingUTF8: (interface?.ifa_name)!) , name == "en0" {
                        
                        // Convert interface address to a human readable string:
                        var addr = interface?.ifa_addr.pointee
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(&addr!, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                            &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST)
                        addresses.append(String(cString: hostname))
                    }
                }
                ptr = ptr?.pointee.ifa_next;
            }
            freeifaddrs(ifaddr)
        }
        return addresses
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
                print("Sec-WebSocket-Protocol: \(secWebSocketProtocol)")
                print("Accepted Protocol: \(acceptedProtocol)")
            #endif
        }
        return acceptedProtocol
    }
    
}
