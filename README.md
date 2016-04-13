# Cordova WebSocket Server Plugin

This plugin allows you to run a single, lightweight, barebone WebSocket Server from applications developed using PhoneGap/Cordova 3.0 or newer.

This is not a background service. When the cordova view is destroyed/terminated, the server is stopped.

## Installation ##

In your application project directory:

```bash
cordova plugin add cordova-plugin-websocket-server
```

#### iOS
It's written in Swift, not objective-c.

In the build settings of your project:

```Embedded Content Contains Swift Code: YES```

```Objective-C Bridging Header: YOUR_PROJECT/Bridging-Header.h```
Insert the content of the WebSocketServer-Bridging-Header.h file in it.

```Runpath Search Paths: @executable_path/Frameworks```

```Other swift flags: -D DEBUG``` optional. for debugging purpose.

## Usage ##

```javascript
var wsserver = cordova.plugins.wsserver;
```

#### `start(port, options)`
Starts the server on the given port (0 means any free port).
Binds to all available IPv4 network interfaces ('0.0.0.0').

```javascript
 wsserver.start(port, {
    // WebSocket Server
    'onStart' : function(addr, port) {
        console.log('Listening on %s:%d', addr, port);
    },
    'onStop' : function(addr, port) {
        console.log('Stopped listening on %s:%d', addr, port);
    },
    // WebSocket Connection
    'onOpen' : function(conn) {
        /* conn: {
         'uuid' : '8e176b14-a1af-70a7-3e3d-8b341977a16e',
         'remoteAddr' : '192.168.1.10',
         'acceptedProtocol' : 'my-protocol-v1',
         'httpFields' : {...},
		 'resource' : '/?param1=value1&param2=value2'
         } */
        console.log('A user connected from %s', conn.remoteAddr);
    },
    'onMessage' : function(conn, msg) {
        console.log(conn, msg);
    },
    'onClose' : function(conn, code, reason) {
        console.log('A user disconnected from %s', conn.remoteAddr);
    },
    'origins' : [ 'file://' ] // optional. validates the 'Origin' HTTP Header.
    'protocols' : [ 'my-protocol-v1', 'my-protocol-v2' ] // optional. validates the 'Sec-WebSocket-Protocol' HTTP Header.
});
```

#### `stop()`
Stops the server.

```javascript
wsserver.stop();
```

#### `send(conn, msg)`
Sends a message to the given connection.

```javascript
wsserver.send({'uuid':'8e176b14-a1af-70a7-3e3d-8b341977a16e'}, msg);
```

#### `close(conn, code, reason)`
Closes a websocket connection. Close event code and reason are optional.

```javascript
wsserver.close({'uuid':'8e176b14-a1af-70a7-3e3d-8b341977a16e'}, 4000, 'my reason');
```

#### `getInterfaces(callback)`
Returns the available IPv4 network interfaces

```javascript
wsserver.getInterfaces(function(ips) {
    console.log(ips);
});
```

## Credits

#### Android
It depends on [the TooTallNate WebSocket Server](https://github.com/TooTallNate/Java-WebSocket).

#### iOS
It depends on [the couchbasedeps PocketSocket Server](https://github.com/couchbasedeps/PocketSocket) forked from [the zwopple PocketSocket Server](https://github.com/zwopple/PocketSocket). 

## Licence ##

The MIT License
