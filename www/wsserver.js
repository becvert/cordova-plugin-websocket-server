/*
 * Cordova WebSocket Server Plugin
 *
 * WebSocket Server plugin for Cordova/Phonegap 
 * by Sylvain Brejeon
 */

'use strict';
var exec = require('cordova/exec');

var fail = function(o) {
    console.error("Error " + JSON.stringify(o));
};

var connections = null;

var WebSocketServer = {

    getInterfaces : function(success, failure) {
        return exec(success, failure, "WebSocketServer", "getInterfaces", []);
    },

    start : function(port, options) {
        return exec(function(result) {
            switch (result.action) {
            case 'onStart':
            case 'onDidNotStart':
            case 'onStop':
                var callback = options[result.action];
                if (callback) {
                    callback(result.addr, result.port);
                }
                connections = [];
                break;
            case 'onOpen':
                var conn = result.conn;
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
                    delete connections[conn.uuid];
                    var callback = options[result.action];
                    if (callback) {
                        callback(conn, result.code, result.reason, result.wasClean);
                    }
                }
                break;
            default:
                console.log('unknown action: ' + result.action);
            }
        }, fail, "WebSocketServer", "start", [ port, options.origins, options.protocols ]);
    },

    stop : function() {
        return exec(null, fail, "WebSocketServer", "stop", []);
    },

    send : function(conn, msg) {
        return exec(null, fail, "WebSocketServer", "send", [ conn.uuid, msg ]);
    },

    close : function(conn, code, reason) {
        return exec(null, fail, "WebSocketServer", "close", [ conn.uuid, code, reason ]);
    }

};

module.exports = WebSocketServer;
