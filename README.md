# Cordova WebSocket Server Plugin

This plugin allows you to run a single, lightweight, barebone WebSocket Server from applications developed using PhoneGap/Cordova 3.0 or newer.

This is not a background service. When the cordova view is destroyed/terminated, the server is stopped.

## Changelog ##

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

#### `start(port, options)`
Starts the server on the given port (0 means any free port).
Binds to all available network interfaces ('0.0.0.0').

```javascript
 wsserver.start(port, {
    // WebSocket Server
    'onStart' : function(addr, port) {
        console.log('Listening on %s:%d', addr, port);
    },
    'onDidNotStart' :  function(addr, port) {
        console.log('Failed to listen on %s:%d', addr, port);
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
    'origins' : [ 'file://' ], // optional. validates the 'Origin' HTTP Header.
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
