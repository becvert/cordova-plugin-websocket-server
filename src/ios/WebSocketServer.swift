/*
 * Cordova WebSocket Server Plugin
 *
 * WebSocket Server plugin for Cordova/Phonegap 
 * by Sylvain Brejeon
 */
 
import Foundation

@objc(WebSocketServer) class WebSocketServer : CDVPlugin, PSWebSocketServerDelegate {
    
    var wsserver: PSWebSocketServer?
    var origins: [String]?
    var protocols: [String]?
    var UUIDSockets: [String: PSWebSocket] = [:]
    var socketsUUID: [PSWebSocket: String] = [:]
    var remoteAddresses: [PSWebSocket: String] = [:]
    var listenerCallbackId: String?
    
    override func onAppTerminate() {
        if let server = wsserver {
            server.stop()
            wsserver = nil
            UUIDSockets.removeAll()
            socketsUUID.removeAll()
            remoteAddresses.removeAll()
        }
    }
    
    func getInterfaces(command: CDVInvokedUrlCommand) {
        
        commandDelegate?.runInBackground({
            
            let intfs = self.getWiFiAddresses()
            
            let pluginResult = CDVPluginResult( status: CDVCommandStatus_OK, messageAsArray: intfs)
            self.commandDelegate?.sendPluginResult(pluginResult, callbackId: command.callbackId)
        })
        
    }
    
    func start(command: CDVInvokedUrlCommand) {
        
        #if DEBUG
            print("start")
        #endif
        
        if wsserver != nil {
            return
        }
        
        let port = command.argumentAtIndex(0) as? Int
        origins = command.argumentAtIndex(1) as? [String]
        protocols = command.argumentAtIndex(2) as? [String]
        
        if let server = PSWebSocketServer(host: nil, port: UInt(port!)) {
            listenerCallbackId = command.callbackId
            wsserver = server
            server.delegate = self
            
            commandDelegate?.runInBackground({
                server.start()
            })
            
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_NO_RESULT)
            pluginResult.setKeepCallbackAsBool(true)
        }
        
    }
    
    func stop(command: CDVInvokedUrlCommand) {
        
        #if DEBUG
            print("stop")
        #endif
        
        if let server = wsserver {
            
            commandDelegate?.runInBackground({
                server.stop()
            })
        
        }
    }
    
    func send(command: CDVInvokedUrlCommand) {
        
        #if DEBUG
            print("send")
        #endif
        
        let uuid = command.argumentAtIndex(0) as? String
        let msg = command.argumentAtIndex(1) as? String
        
        if uuid != nil && msg != nil {
            if let webSocket = UUIDSockets[uuid!] {
                
                commandDelegate?.runInBackground({
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
    
    func close(command: CDVInvokedUrlCommand) {
        
        #if DEBUG
            print("close")
        #endif
        
        let uuid = command.argumentAtIndex(0) as? String
        
        if uuid != nil {
            if let webSocket = UUIDSockets[uuid!] {
                
                commandDelegate?.runInBackground({
                    webSocket.close()
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
    
    func serverDidStart(server: PSWebSocketServer) {
        
        #if DEBUG
            print("Server did start…")
        #endif
        
        let status: NSDictionary = NSDictionary(objects: ["onStart", "0.0.0.0", Int(server.realPort)], forKeys: ["action", "addr", "port"])
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: status as [NSObject : AnyObject])
        pluginResult.setKeepCallbackAsBool(true)
        commandDelegate?.sendPluginResult(pluginResult, callbackId: listenerCallbackId)
    }
    
    func serverDidStop(server: PSWebSocketServer) {
        
        #if DEBUG
            print("Server did stop…")
        #endif
        
        wsserver = nil
        UUIDSockets.removeAll()
        socketsUUID.removeAll()
        remoteAddresses.removeAll()
        
        let status: NSDictionary = NSDictionary(objects: ["onStop", "0.0.0.0", Int(server.realPort)], forKeys: ["action", "addr", "port"])
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: status as [NSObject : AnyObject])
        pluginResult.setKeepCallbackAsBool(false)
        commandDelegate?.sendPluginResult(pluginResult, callbackId: listenerCallbackId)
    }
    
    func server(server: PSWebSocketServer, didFailWithError error: NSError) {
        
        #if DEBUG
            print("Server did fail with error: \(error)")
        #endif
    }
    
    func server(server: PSWebSocketServer, acceptWebSocketFrom address: NSData, withRequest request: NSURLRequest, trust: SecTrustRef, response: AutoreleasingUnsafeMutablePointer<NSHTTPURLResponse?>) -> Bool {
        
        #if DEBUG
            print("Server should accept request: \(request)")
        #endif
        
        if let o = origins {
            let origin = request.valueForHTTPHeaderField("Origin")
            if o.indexOf(origin!) == nil {
                #if DEBUG
                    print("Origin denied: \(origin)")
                #endif
                return false
            }
        }
        
        if let _ = protocols {
            if let acceptedProtocol = getAcceptedProtocol(request) {
                let headerFields = [ "Sec-WebSocket-Protocol" : acceptedProtocol ]
                let r = NSHTTPURLResponse.init(URL: request.URL!, statusCode: 200, HTTPVersion: "1.1", headerFields: headerFields )!
                response.memory = r
            } else {
                #if DEBUG
                    let secWebSocketProtocol = request.valueForHTTPHeaderField("Sec-WebSocket-Protocol")
                    print("Sec-WebSocket-Protocol denied: \(secWebSocketProtocol)")
                #endif
                return false
            }
        }
        
        return true;
    }
    
    func server(server: PSWebSocketServer, webSocketDidOpen webSocket: PSWebSocket) {
        
        #if DEBUG
            print("WebSocket did open")
        #endif
        
        var uuid: String!
        while uuid == nil || UUIDSockets[uuid] != nil {
            // prevent collision
            uuid = NSUUID().UUIDString
        }
        UUIDSockets[uuid] = webSocket
        socketsUUID[webSocket] = uuid
        
        let remoteAddr = IP(webSocket.remoteAddress)
        remoteAddresses[webSocket] = remoteAddr
        
        let acceptedProtocol = getAcceptedProtocol(webSocket.URLRequest)
        
        let httpFields = webSocket.URLRequest.allHTTPHeaderFields
        
        let conn: NSDictionary = NSDictionary(objects: [uuid, remoteAddr, acceptedProtocol!, httpFields!], forKeys: ["uuid", "remoteAddr", "acceptedProtocol", "httpFields"])
        let status: NSDictionary = NSDictionary(objects: ["onOpen", conn], forKeys: ["action", "conn"])
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: status as [NSObject : AnyObject])
        pluginResult.setKeepCallbackAsBool(true)
        commandDelegate?.sendPluginResult(pluginResult, callbackId: listenerCallbackId)
    }
    
    func server(server: PSWebSocketServer, webSocket: PSWebSocket, didReceiveMessage message: AnyObject) {
        
        #if DEBUG
            print("Server websocket did receive message: \(message)")
        #endif
        
        if let uuid = socketsUUID[webSocket] {

            let remoteAddr = IP(webSocket.remoteAddress)

            let conn: NSDictionary = NSDictionary(objects: [uuid, remoteAddr], forKeys: ["uuid", "remoteAddr"])
            let status: NSDictionary = NSDictionary(objects: ["onMessage", conn, message], forKeys: ["action", "conn", "msg"])
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: status as [NSObject : AnyObject])
            pluginResult.setKeepCallbackAsBool(true)
            commandDelegate?.sendPluginResult(pluginResult, callbackId: listenerCallbackId)
        } else {
            #if DEBUG
                print("unknown socket")
            #endif
        }
    }
    
    func server(server: PSWebSocketServer, webSocket: PSWebSocket, didCloseWithCode code: Int, reason: String, wasClean: Bool) {
        
        #if DEBUG
            print("WebSocket did close with code: \(code), reason: \(reason), wasClean: \(wasClean)")
        #endif
        
        if let uuid = socketsUUID[webSocket] {
            
            let remoteAddr = remoteAddresses[webSocket] // IP(ws.remoteAddress) bad access error
            
            let conn: NSDictionary = NSDictionary(objects: [uuid, remoteAddr!], forKeys: ["uuid", "remoteAddr"])
            let status: NSDictionary = NSDictionary(objects: ["onClose", conn], forKeys: ["action", "conn"])
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: status as [NSObject : AnyObject])
            pluginResult.setKeepCallbackAsBool(true)
            commandDelegate?.sendPluginResult(pluginResult, callbackId: listenerCallbackId)
            
            socketsUUID.removeValueForKey(webSocket)
            UUIDSockets.removeValueForKey(uuid)
            remoteAddresses.removeValueForKey(webSocket)
        } else {
            #if DEBUG
                print("unknown socket")
            #endif
        }
    }
    
    func server(server: PSWebSocketServer, webSocket: PSWebSocket, didFailWithError error: NSError) {
        
        #if DEBUG
            print("WebSocket did fail with error: \(error)")
        #endif
    }
    
    // http://dev.eltima.com/post/99996366184/using-bonjour-in-swift
    private func IP(addressBytes: NSData) -> String {
        var inetAddress : sockaddr_in!
        var inetAddress6 : sockaddr_in6!
        //NSData’s bytes returns a read-only pointer to the receiver’s contents.
        let inetAddressPointer = UnsafePointer<sockaddr_in>(addressBytes.bytes)
        //Access the underlying raw memory
        inetAddress = inetAddressPointer.memory
        if inetAddress.sin_family == __uint8_t(AF_INET) {
        }
        else {
            if inetAddress.sin_family == __uint8_t(AF_INET6) {
                let inetAddressPointer6 = UnsafePointer<sockaddr_in6>(addressBytes.bytes)
                inetAddress6 = inetAddressPointer6.memory
                inetAddress = nil
            }
            else {
                inetAddress = nil
            }
        }
        var ipString : UnsafePointer<CChar>?
        //static func alloc(num: Int) -> UnsafeMutablePointer
        let ipStringBuffer = UnsafeMutablePointer<CChar>.alloc(Int(INET6_ADDRSTRLEN))
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
            let ip = String.fromCString(ipString!)
            return ip!
        }
        return "0.0.0.0"
    }
    
    // http://stackoverflow.com/questions/30748480/swift-get-devices-ip-address
    private func getWiFiAddresses() -> [String] {
        var addresses : [String] = []
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs> = nil
        if getifaddrs(&ifaddr) == 0 {
            // For each interface ...
            for (var ptr = ifaddr; ptr != nil; ptr = ptr.memory.ifa_next) {
                let interface = ptr.memory
                
                // Check for IPv4 interface:
                let addrFamily = interface.ifa_addr.memory.sa_family
                if addrFamily == UInt8(AF_INET) {
                    
                    // Check interface name:
                    if let name = String.fromCString(interface.ifa_name) where name == "en0" {
                        
                        // Convert interface address to a human readable string:
                        var addr = interface.ifa_addr.memory
                        var hostname = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
                        getnameinfo(&addr, socklen_t(interface.ifa_addr.memory.sa_len),
                            &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST)
                        addresses.append(String.fromCString(hostname)!)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return addresses
    }
    
    private func getAcceptedProtocol(request: NSURLRequest) -> String? {
        var acceptedProtocol: String?
        if let secWebSocketProtocol = request.valueForHTTPHeaderField("Sec-WebSocket-Protocol") {
            let requestedProtocols = secWebSocketProtocol.componentsSeparatedByString(", ")
            for requestedProtocol in requestedProtocols {
                if protocols!.indexOf(requestedProtocol) != nil {
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
