/*
 * Cordova WebSocket Server Plugin
 *
 * WebSocket Server plugin for Cordova/Phonegap 
 * by Sylvain Brejeon
 */

package net.becvert.cordova;

import java.net.InetSocketAddress;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.PluginResult;
import org.java_websocket.WebSocket;
import org.java_websocket.framing.CloseFrame;
import org.java_websocket.handshake.ClientHandshake;
import org.java_websocket.server.WebSocketServer;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.util.Log;

public class WebSocketServerImpl extends WebSocketServer {

    protected boolean active = true;

    private CallbackContext callbackContext;

    private JSONArray origins;

    private Map<String, WebSocket> UUIDSockets = new HashMap<String, WebSocket>();

    private Map<WebSocket, String> socketsUUID = new HashMap<WebSocket, String>();

    public WebSocketServerImpl(int port) {
        super(new InetSocketAddress(port));
    }

    public CallbackContext getCallbackContext() {
        return this.callbackContext;
    }

    public void setCallbackContext(CallbackContext callbackContext) {
        this.callbackContext = callbackContext;
    }

    public void setOrigins(JSONArray origins) {
        this.origins = origins;
    }

    @Override
    public void onOpen(WebSocket webSocket, ClientHandshake clientHandshake) {
        Log.v("WebSocketServer", "onopen");

        if (origins != null) {
            boolean accept = false;
            String origin = clientHandshake.getFieldValue("Origin");
            for (int i = 0, l = origins.length(); i < l; i++) {
                try {
                    if (origins.getString(i).equals(origin)) {
                        accept = true;
                        break;
                    }
                } catch (JSONException e) {
                    e.printStackTrace();
                }
            }
            if (!accept) {
                Log.w("WebSocketServer", "onopen: origin denied: " + origin);
                webSocket.close(CloseFrame.REFUSE);
                return;
            }
        }

        String uuid = UUID.randomUUID().toString();
        UUIDSockets.put(uuid, webSocket);
        socketsUUID.put(webSocket, uuid);

        try {
            JSONObject conn = new JSONObject();
            conn.put("uuid", uuid);
            conn.put("addr", webSocket.getRemoteSocketAddress().getAddress().getHostAddress());

            JSONObject status = new JSONObject();
            status.put("action", "onOpen");
            status.put("conn", conn);

            Log.d("WebSocketServer", "onopen result: " + status.toString());
            PluginResult result = new PluginResult(PluginResult.Status.OK, status);
            result.setKeepCallback(true);
            callbackContext.sendPluginResult(result);

        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onMessage(WebSocket webSocket, String msg) {
        Log.v("WebSocketServer", "onmessage");

        String uuid = socketsUUID.get(webSocket);

        if (uuid != null) {
            try {
                JSONObject conn = new JSONObject();
                conn.put("uuid", uuid);
                conn.put("addr", webSocket.getRemoteSocketAddress().getAddress().getHostAddress());

                JSONObject status = new JSONObject();
                status.put("action", "onMessage");
                status.put("conn", conn);
                status.put("msg", msg);

                Log.d("WebSocketServer", "onmessage result: " + status.toString());
                PluginResult result = new PluginResult(PluginResult.Status.OK, status);
                result.setKeepCallback(true);
                callbackContext.sendPluginResult(result);

            } catch (JSONException e) {
                e.printStackTrace();
            }
        } else {
            Log.d("WebSocketServer", "onmessage: unknown websocket");
        }

    }

    @Override
    public void onClose(WebSocket webSocket, int code, String reason, boolean remote) {
        Log.v("WebSocketServer", "onclose");

        if (webSocket != null) {

            String uuid = socketsUUID.get(webSocket);

            if (uuid != null) {
                try {
                    JSONObject conn = new JSONObject();
                    conn.put("uuid", uuid);
                    conn.put("addr", webSocket.getRemoteSocketAddress().getAddress().getHostAddress());

                    JSONObject status = new JSONObject();
                    status.put("action", "onClose");
                    status.put("conn", conn);

                    Log.d("WebSocketServer", "onclose result: " + status.toString());
                    PluginResult result = new PluginResult(PluginResult.Status.OK, status);
                    result.setKeepCallback(true);
                    callbackContext.sendPluginResult(result);

                } catch (JSONException e) {
                    e.printStackTrace();
                } finally {
                    socketsUUID.remove(webSocket);
                    UUIDSockets.remove(uuid);
                }
            } else {
                Log.d("WebSocketServer", "onclose: unknown websocket");
            }

        }

    }

    @Override
    public void onError(WebSocket webSocket, Exception exception) {
        Log.v("WebSocketServer", "onerror");

        if (webSocket == null) {
            try {
                JSONObject status = new JSONObject();
                status.put("action", "onStop");
                status.put("addr", this.getAddress().getAddress().getHostAddress());
                status.put("port", this.getPort());

                Log.d("WebSocketServer", "onerror result: " + status.toString());
                PluginResult result = new PluginResult(PluginResult.Status.OK, status);
                result.setKeepCallback(false);
                this.callbackContext.sendPluginResult(result);

            } catch (JSONException e) {
                e.printStackTrace();
            }

            this.active = false;
            this.callbackContext = null;
            this.UUIDSockets = null;
            this.socketsUUID = null;

        }

    }

    public void send(String uuid, String msg) {
        Log.v("WebSocketServer", "send");

        WebSocket webSocket = UUIDSockets.get(uuid);

        if (webSocket != null) {
            webSocket.send(msg);
        } else {
            Log.d("WebSocketServer", "send: unknown websocket");
        }

    }

    public void close(String uuid) {
        Log.v("WebSocketServer", "close");

        WebSocket webSocket = UUIDSockets.get(uuid);

        if (webSocket != null) {
            webSocket.close(CloseFrame.NORMAL);
            UUIDSockets.remove(uuid);
            socketsUUID.remove(webSocket);
        } else {
            Log.d("WebSocketServer", "close: unknown websocket");
        }

    }

}