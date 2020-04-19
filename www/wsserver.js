'use strict';
var exec = require('cordova/exec');
var utils = require('cordova/utils');

var fail = function(o) {
    console.error("Error " + JSON.stringify(o));
};

var connections = [];
var callbacks = {};

function generateUniqueIdFor(obj) {
    let id = null;
    while (id == null || obj[id] != null) {
        id = utils.createUUID();
    }
    return id;
}

function addCallback(success, failure, type) {
    const id = generateUniqueIdFor(callbacks);
    callbacks[id] = {success, failure, type};
    return id;
}

function successCallback(type, result) {
    Object.keys(callbacks)
        .map(id => callbacks[id])
        .filter(c => c.type === type && c.success)
        .forEach(c => c.success(result));
}

var WebSocketServer = {

    getInterfaces : function(success, failure) {
        return exec(success, failure, "WebSocketServer", "getInterfaces", []);
    },

    start : function(port, options, success, failure) {
        return exec(function(result) {
            switch (result.action) {
            case 'onFailure':
                connections = [];
                var callback = options[result.action];
                if (callback) {
                    callback(result.addr, result.port, result.reason);
                }

                successCallback('failure', {
                    addr: result.addr,
                    port: result.port,
                    reason: result.reason,
                });
                break;
            case 'onOpen':
                var conn = result.conn;
                conn.state = 'open';
                connections[conn.uuid] = conn;
                var callback = options[result.action];
                if (callback) {
                    callback(conn);
                }

                successCallback('open', conn);
                break;
            case 'onMessage':
                var conn = connections[result.uuid];
                if (conn) {
                    var callback = options[result.action];
                    if (callback) {
                        if(result.is_binary) {
                            // convert Base64 string to ArrayBuffer
                            var binary_string = window.atob(result.msg);
                            var len = binary_string.length;
                            var bytes = new Uint8Array(len);
                            for (var i = 0; i < len; i++) {
                                bytes[i] = binary_string.charCodeAt(i);
                            }
                            callback(conn, bytes.buffer);
                        }
                        else {
                            callback(conn, result.msg);
                        }
                    }
                }

                successCallback('message', {
                    conn: conn,
                    msg: result.msg,
                });
                break;
            case 'onClose':
                var conn = connections[result.uuid];
                if (conn) {
                    conn.state = 'closed';
                    delete connections[conn.uuid];
                    var callback = options[result.action];
                    if (callback) {
                        callback(conn, result.code, result.reason, result.wasClean);
                    }

                    successCallback('close', {
                        conn: conn,
                        code: result.code,
                        reason: result.reason,
                        wasClean: result.wasClean,
                    });
                }
                break;
            default:
                connections = [];
                if (success) {
                    success({
                        addr: result.addr,
                        port: result.port,
                    });
                }
            }
        }, failure, "WebSocketServer", "start", [ port, options.origins, options.protocols, options.tcpNoDelay ]);
    },

    onMessage: function(success, failure) {
        return addCallback(success, failure, 'message');
    },

    onOpen: function(success, failure) {
        return addCallback(success, failure, 'open');
    },

    onClose: function(success, failure) {
        return addCallback(success, failure, 'close');
    },

    onFailure: function(success, failure) {
        return addCallback(success, failure, 'failure');
    },

    removeCallback: function(uuid) {
        if (uuid && callbacks[uuid]) {
            delete callbacks[uuid];
        }
    },

    stop : function(success, failure) {
        return exec(function(result) {
            connections = [];
            callbacks = [];
            if (success) {
                success({
                    addr: result.addr,
                    port: result.port,
                });
            }
        }, failure, "WebSocketServer", "stop", []);
    },

    send : function(conn, msg) {
        if (typeof msg == "string") {
            
            // send text frame (websocket opcode 1)
            return exec(null, fail, "WebSocketServer", "send", [ conn.uuid, msg ]);

        } else {
            // convert any iterable object to Base64 string
            var binary_string = '';
            var bytes = new Uint8Array(msg);
            var len = bytes.byteLength;
            for (var i = 0; i < len; i++) {
                binary_string += String.fromCharCode(bytes[i]);
            }
            var msg_base64 = window.btoa(binary_string);

            // send binary frame (websocket opcode 2)
            return exec(null, fail, "WebSocketServer", "send_binary", [ conn.uuid, msg_base64 ]);
        }
    },

    close : function(conn, code, reason) {
        return exec(null, fail, "WebSocketServer", "close", [ conn.uuid, code, reason ]);
    }

};

module.exports = WebSocketServer;
