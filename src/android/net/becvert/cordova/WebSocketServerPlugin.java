/*
 * Cordova WebSocket Server Plugin
 *
 * WebSocket Server plugin for Cordova/Phonegap 
 * by Sylvain Brejeon
 */

package net.becvert.cordova;

import android.util.Log;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.apache.cordova.PluginResult.Status;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class WebSocketServerPlugin extends CordovaPlugin {

    private WebSocketServerImpl wsserver = null;

    public static final String ACTION_GET_INTERFACES = "getInterfaces";
    public static final String ACTION_START = "start";
    public static final String ACTION_STOP = "stop";
    public static final String ACTION_SEND = "send";
    public static final String ACTION_CLOSE = "close";

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        Log.v("WebSocketServer", "Initialized");
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (wsserver != null) {
            try {
                wsserver.stop();
            } catch (IOException e) {
                e.printStackTrace();
            } catch (InterruptedException e) {
                e.printStackTrace();
            } finally {
                wsserver = null;
            }
        }
    }

    @Override
    public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) {

        if (wsserver != null && !wsserver.active) {
            wsserver = null;
        }

        if (ACTION_GET_INTERFACES.equals(action)) {

            cordova.getThreadPool().execute(new Runnable() {
                @Override
                public void run() {

                    JSONArray ips = new JSONArray();
                    List<String> interfaces = WebSocketServerPlugin.getInterfaces();
                    for (String intf : interfaces) {
                        ips.put(intf);
                    }

                    PluginResult result = new PluginResult(Status.OK, ips);
                    callbackContext.sendPluginResult(result);
                }
            });

        } else if (ACTION_START.equals(action)) {

            final int port = args.optInt(0);
            final JSONArray origins = args.optJSONArray(1);
            final JSONArray protocols = args.optJSONArray(2);
            if (wsserver == null) {
                cordova.getThreadPool().execute(new Runnable() {
                    @Override
                    public void run() {
                        wsserver = new WebSocketServerImpl(port);
                        wsserver.setCallbackContext(callbackContext);
                        try {
                            wsserver.setOrigins(jsonArrayToArrayList(origins));
                        } catch (JSONException e) {
                            wsserver = null;
                            callbackContext.error("Origins option error");
                            return;
                        }
                        try {
                            wsserver.setProtocols(jsonArrayToArrayList(protocols));
                        } catch (JSONException e) {
                            wsserver = null;
                            callbackContext.error("Protocols option error");
                            return;
                        }
                        wsserver.start();

                        try {
                            // wait for port binding!
                            Thread.sleep(2000);
                        } catch (InterruptedException e) {
                            e.printStackTrace();
                        }

                        try {
                            JSONObject status = new JSONObject();
                            status.put("action", "onStart");
                            status.put("addr", wsserver.getAddress().getAddress().getHostAddress());
                            status.put("port", wsserver.getPort());

                            Log.d("WebSocketServer", "start result: " + status.toString());
                            PluginResult result = new PluginResult(PluginResult.Status.OK, status);
                            result.setKeepCallback(true);
                            callbackContext.sendPluginResult(result);

                        } catch (JSONException e) {
                            e.printStackTrace();
                        }
                    }
                });
            } else {
                callbackContext.error("Server already running.");
                return false;
            }

        } else if (ACTION_STOP.equals(action)) {

            if (wsserver != null) {
                this.cordova.getThreadPool().execute(new Runnable() {
                    @Override
                    public void run() {

                        try {
                            wsserver.stop();
                        } catch (IOException e) {
                            e.printStackTrace();
                        } catch (InterruptedException e) {
                            e.printStackTrace();
                        } finally {

                            try {
                                JSONObject status = new JSONObject();
                                status.put("action", "onStop");
                                status.put("addr", wsserver.getAddress().getAddress().getHostAddress());
                                status.put("port", wsserver.getPort());

                                Log.d("WebSocketServer", "stop result: " + status.toString());
                                PluginResult result = new PluginResult(PluginResult.Status.OK, status);
                                result.setKeepCallback(false);
                                wsserver.getCallbackContext().sendPluginResult(result);

                            } catch (JSONException e) {
                                e.printStackTrace();
                            }

                            wsserver = null;
                        }
                    }
                });
            }

        } else if (ACTION_SEND.equals(action)) {

            final String uuid = args.optString(0);
            final String msg = args.optString(1);
            if (uuid != null && msg != null) {
                this.cordova.getThreadPool().execute(new Runnable() {
                    @Override
                    public void run() {
                        if (wsserver != null) {
                            wsserver.send(uuid, msg);
                        }
                    }
                });
            } else {
                callbackContext.error("UUID or msg not specified.");
                return false;
            }

        } else if (ACTION_CLOSE.equals(action)) {

            final String uuid = args.optString(0);
            final int code = args.optInt(1, -1);
            final String reason = args.optString(2);

            if (uuid != null) {
                this.cordova.getThreadPool().execute(new Runnable() {
                    @Override
                    public void run() {
                        if (wsserver != null) {
                            wsserver.close(uuid, code, reason);
                        }
                    }
                });
            } else {
                callbackContext.error("UUID not specified.");
                return false;
            }

        } else {
            Log.e("WebSocketServer", "Invalid action: " + action);
            callbackContext.error("Invalid action: " + action);
            return false;
        }

        return true;
    }

    /**
     * Returns IP4 addresses.
     * 
     * @return IP4 addresses
     */
    public static List<String> getInterfaces() {
        ArrayList<String> interfaces = new ArrayList<String>();
        try {
            List<NetworkInterface> intfs = Collections.list(NetworkInterface.getNetworkInterfaces());
            for (NetworkInterface intf : intfs) {
                List<InetAddress> addrs = Collections.list(intf.getInetAddresses());
                for (InetAddress addr : addrs) {
                    if (!addr.isLoopbackAddress()) {
                        if (addr instanceof Inet4Address) {
                            interfaces.add(addr.getHostAddress().toUpperCase());
                        }
                    }
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return interfaces;
    }

    public static List<String> jsonArrayToArrayList(JSONArray jsonArray) throws JSONException {
        ArrayList<String> list = null;
        if (jsonArray != null && jsonArray.length() > 0) {
            list = new ArrayList<String>();
            for (int i = 0; i < jsonArray.length(); i++) {
                list.add(jsonArray.get(i).toString());
            }
        }
        return list;
    }

}