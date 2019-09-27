# Cordova WebSocket Server Plugin

This plugin allows you to run a single, lightweight, barebone WebSocket Server from applications developed using PhoneGap/Cordova 3.0 or newer.

This is not a background service. When the cordova view is destroyed/terminated, the server is stopped.

[CHANGELOG](https://github.com/becvert/cordova-plugin-websocket-server/blob/master/CHANGELOG.md)

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
         'httpFields' : {...},
         'resource' : '/?param1=value1&param2=value2'
         } */
        console.log('A user connected from %s', conn.remoteAddr);
    },
    'onMessage' : function(conn, msg) {
        console.log(conn, msg);
    },
    'onClose' : function(conn, code, reason, wasClean) {
        console.log('A user disconnected from %s', conn.remoteAddr);
    },
    // Other options
    'origins' : [ 'file://' ], // validates the 'Origin' HTTP Header.
    'protocols' : [ 'my-protocol-v1', 'my-protocol-v2' ], // validates the 'Sec-WebSocket-Protocol' HTTP Header.
    'tcpNoDelay' : true // disables Nagle's algorithm.
}, function onStart(server) {
    console.log('Listening on %s:%d', server.addr, server.port);
}, function onDidNotStart(reason) {
    console.log('Did not start. Reason: %s', reason);
});
```

#### `stop(success,failure)`
Stops the server.

```javascript
wsserver.stop(function onStop(server) {
    console.log('Stopped listening on %s:%d', server.addr, server.port);
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

#### `onMessage(success, failure)`
Add additional callback for receiving messages

```javascript
wsserver.onMessage(function(result) {
    console.log('Connection', result.conn);
    console.log('Message', result.msg);
}, null); // Currently failure is not handled
```

#### `onOpen(success, failure)`
Add additional callback for new connections 

```javascript
wsserver.onOpen(function(conn) {
    console.log('Connection', conn);
}, null); // Currently failure is not handled
```

#### `onClose(success, failure)`
Add additional callback for closed connections

```javascript
wsserver.onClose(function(result) {
    console.log('Connection', result.conn);
    console.log(`Code: ${result.code}, Reason: ${result.reason}, Clean: ${result.wasClean}`);
}, null); // Currently failure is not handled
```

#### `onFailure(success, failure)`
Add additional callback for failures

```javascript
wsserver.onFailure(function(result) {
    console.log(`Server at ${result.addr}:${result.port} has failed`);
    console.log(result.reason);
}, null); // Currently failure is not handled
```

## Credits

#### Android
It depends on [the TooTallNate WebSocket Server](https://github.com/TooTallNate/Java-WebSocket).

#### iOS
It depends on [the couchbasedeps PocketSocket Server](https://github.com/couchbasedeps/PocketSocket) forked from [the zwopple PocketSocket Server](https://github.com/zwopple/PocketSocket). 

## Licence ##

The MIT License