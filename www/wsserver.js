'use strict';
var exec = require('cordova/exec');

var fail = function(o) {
    console.error("Error " + JSON.stringify(o));
};

var connections = [];

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
                break;
            case 'onOpen':
                var conn = result.conn;
                conn.state = 'open';
                connections[conn.uuid] = conn;
                var callback = options[result.action];
                if (callback) {
                    callback(conn);
                }
                break;
            case 'onMessage':
                var conn = connections[result.uuid];
                if (conn) {
                    var callback = options[result.action];
                    if (callback) {
                        callback(conn, result.msg);
                    }
                }
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
                }
                break;
            default:
                connections = [];
                if (success) {
                    success(result.addr, result.port);
                }
            }
        }, failure, "WebSocketServer", "start", [ port, options.origins, options.protocols, options.tcpNoDelay ]);
    },

    stop : function(success, failure) {
        return exec(function(result) {
            connections = [];
            if (success) {
                success(result.addr, result.port);
            }
        }, failure, "WebSocketServer", "stop", []);
    },

    send : function(conn, msg) {
        return exec(null, fail, "WebSocketServer", "send", [ conn.uuid, msg ]);
    },

    close : function(conn, code, reason) {
        return exec(null, fail, "WebSocketServer", "close", [ conn.uuid, code, reason ]);
    }

};

module.exports = WebSocketServer;
