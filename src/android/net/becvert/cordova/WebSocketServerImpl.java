/*
 * Cordova WebSocket Server Plugin
 *
 * WebSocket Server plugin for Cordova/Phonegap 
 * by Sylvain Brejeon
 */

package net.becvert.cordova;

import java.net.InetSocketAddress;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.PluginResult;
import org.java_websocket.WebSocket;
import org.java_websocket.drafts.Draft;
import org.java_websocket.exceptions.InvalidDataException;
import org.java_websocket.framing.CloseFrame;
import org.java_websocket.handshake.ClientHandshake;
import org.java_websocket.handshake.ServerHandshakeBuilder;
import org.java_websocket.server.WebSocketServer;
import org.json.JSONException;
import org.json.JSONObject;

import android.util.Log;

public class WebSocketServerImpl extends WebSocketServer {

    protected boolean active = true;

    private CallbackContext callbackContext;

    private List<String> origins;

    private List<String> protocols;

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

    public void setOrigins(List<String> origins) {
        this.origins = origins;
    }

    public void setProtocols(List<String> protocols) {
        this.protocols = protocols;
    }

    private String getAcceptedProtocol(ClientHandshake clientHandshake) {
        String acceptedProtocol = null;
        String secWebSocketProtocol = clientHandshake.getFieldValue("Sec-WebSocket-Protocol");
        if (secWebSocketProtocol != null && !secWebSocketProtocol.equals("")) {
            String[] requestedProtocols = secWebSocketProtocol.split(", ");
            for (int i = 0, l = requestedProtocols.length; i < l; i++) {
                if (protocols.indexOf(requestedProtocols[i]) > -1) {
                    // returns first matching protocol.
                    // assumes in order of preference.
                    acceptedProtocol = requestedProtocols[i];
                    break;
                }
            }
        }
        return acceptedProtocol;
    }

    @Override
    public ServerHandshakeBuilder onWebsocketHandshakeReceivedAsServer(WebSocket conn, Draft draft,
            ClientHandshake request) throws InvalidDataException {

        ServerHandshakeBuilder serverHandshakeBuilder = super.onWebsocketHandshakeReceivedAsServer(conn, draft,
                request);

        if (origins != null) {
            String origin = request.getFieldValue("Origin");
            if (origins.indexOf(origin) == -1) {
                Log.w("WebSocketServer", "handshake: origin denied: " + origin);
                throw new InvalidDataException(CloseFrame.REFUSE);
            }
        }

        if (protocols != null) {
            String acceptedProtocol = getAcceptedProtocol(request);
            if (acceptedProtocol == null) {
                String secWebSocketProtocol = request.getFieldValue("Sec-WebSocket-Protocol");
                Log.w("WebSocketServer", "handshake: protocol denied: " + secWebSocketProtocol);
                throw new InvalidDataException(CloseFrame.PROTOCOL_ERROR);
            } else {
                serverHandshakeBuilder.put("Sec-WebSocket-Protocol", acceptedProtocol);
            }
        }

        return serverHandshakeBuilder;
    }

    @Override
    public void onOpen(WebSocket webSocket, ClientHandshake clientHandshake) {
        Log.v("WebSocketServer", "onopen");

        String uuid = null;
        while (uuid == null || UUIDSockets.containsKey(uuid)) {
            // prevent collision
            uuid = UUID.randomUUID().toString();
        }
        UUIDSockets.put(uuid, webSocket);
        socketsUUID.put(webSocket, uuid);

        try {
            JSONObject httpFields = new JSONObject();
            Iterator<String> iterator = clientHandshake.iterateHttpFields();
            while (iterator.hasNext()) {
                String httpField = iterator.next();
                httpFields.put(httpField, clientHandshake.getFieldValue(httpField));
            }

            JSONObject conn = new JSONObject();
            conn.put("uuid", uuid);
            conn.put("remoteAddr", webSocket.getRemoteSocketAddress().getAddress().getHostAddress());

            String acceptedProtocol = "";
            if (protocols != null) {
                acceptedProtocol = getAcceptedProtocol(clientHandshake);
            }
            conn.put("acceptedProtocol", acceptedProtocol);

            conn.put("httpFields", httpFields);
            conn.put("resource", clientHandshake.getResourceDescriptor());

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
                conn.put("remoteAddr", webSocket.getRemoteSocketAddress().getAddress().getHostAddress());

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
                    conn.put("remoteAddr", webSocket.getRemoteSocketAddress().getAddress().getHostAddress());

                    JSONObject status = new JSONObject();
                    status.put("action", "onClose");
                    status.put("conn", conn);
                    status.put("code", code);
                    status.put("reason", reason);
                    status.put("wasClean", remote);

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

    public void close(String uuid, int code, String reason) {
        Log.v("WebSocketServer", "close");

        WebSocket webSocket = UUIDSockets.get(uuid);

        if (webSocket != null) {
            if (code == -1) {
                webSocket.close(CloseFrame.NORMAL);
            } else {
                webSocket.close(code, reason);
            }
            UUIDSockets.remove(uuid);
            socketsUUID.remove(webSocket);
        } else {
            Log.d("WebSocketServer", "close: unknown websocket");
        }

    }

}