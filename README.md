# Cordova WebSocket Server Plugin

This plugin allows you to run a single, lightweight, barebone WebSocket Server from applications developed using PhoneGap/Cordova 3.0 or newer.

This is not a background service. When the cordova view is destroyed/terminated, the server is stopped.

## Changelog ##

#### 1.4.3

- [Android] switching back to [org:java-websocket:1.3.2](https://github.com/TooTallNate/Java-WebSocket)

#### 1.4.2

- fixed error when a connection is open before the start success callback occurs

#### 1.4.1

- new tcpNoDelay option

#### 1.4.0

- onStart, onDidNotStart and onStop handlers replaced with success and failure callbacks
- added generic onFailure handler (assume the server is unexpectedly stopped in this handler)
- [iOS] fixed crash on stop and close (dealloc)

#### 1.3.1

- adding state 'open' or 'closed' to the `conn` object

#### 1.3.0

- getInterfaces returns the ipv4 and ipv6 addresses organized by network interface
- onOpen, onMessage and onClose handlers share the same `conn` instances
- [Android] switching to [com.pusher:java-websocket:1.4.1](https://github.com/pusher/java-websocket)
- [iOS] IPv6 support [30a98b0](https://github.com/couchbasedeps/PocketSocket/commit/30a98b0c62763e11ee5b3e7097a8c8b4b66674f9)


#### 1.2.1

- [iOS] fixed crash (error retrieving URL query string)

#### 1.2.0

- new onDidNotStart handler in the start method
- getInterfaces returns ipv4 and ipv6 addresses

## Installation ##

In your application project directory:

```bash
cordova plugin add cordova-plugin-websocket-server
```

## Usage ##

```javascript
var wsserver = cordova.plugins.wsserver;
```

#### `start(port, options, success, failure)`
Starts the server on the given port (0 means any free port).
Binds to all available network interfaces ('0.0.0.0').

```javascript
 wsserver.start(port, {
    // WebSocket Server handlers
    'onFailure' :  function(addr, port, reason) {
        console.log('Stopped listening on %s:%d. Reason: %s', addr, port, reason);
    },
    // WebSocket Connection handlers
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
    // Other options
    'origins' : [ 'file://' ], // validates the 'Origin' HTTP Header.
    'protocols' : [ 'my-protocol-v1', 'my-protocol-v2' ], // validates the 'Sec-WebSocket-Protocol' HTTP Header.
    'tcpNoDelay' : true // enable/disable Nagle's algorithm. false by default.
}, function onStart(addr, port) {
    console.log('Listening on %s:%d', addr, port);
}, function onDidNotStart(reason) {
    console.log('Did not start. Reason: %s', reason);
});
```

#### `stop(success,failure)`
Stops the server.

```javascript
wsserver.stop(function onStop(addr, port) {
    console.log('Stopped listening on %s:%d', addr, port);
});
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
Returns the non-loopback IPv4 and IPv6 network interfaces.

```javascript
wsserver.getInterfaces(function(result) {
    for (var interface in result) {
        if (result.hasOwnProperty(interface)) {
            console.log('interface', interface);
            console.log('ipv4', result[interface].ipv4Addresses);
            console.log('ipv6', result[interface].ipv6Addresses);
        }
    }
});
```

## Credits

#### Android
It depends on [the TooTallNate WebSocket Server](https://github.com/TooTallNate/Java-WebSocket).

#### iOS
It depends on [the couchbasedeps PocketSocket Server](https://github.com/couchbasedeps/PocketSocket) forked from [the zwopple PocketSocket Server](https://github.com/zwopple/PocketSocket). 

## Licence ##

The MIT License
