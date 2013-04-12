package wami;

import java.util.HashMap;
import java.util.Map;

import org.json.JSONArray;
import org.json.JSONException;

import android.util.Log;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;

public class WamiBridge {

    private final WebView mWebView;
    private final Map<String, WamiMethod> mRegisteredMethods;
    private OnWamiBridgeactivatedListener mActivatedListener;

    public WamiBridge(WebView webView) {
        mWebView = webView;
        mRegisteredMethods = new HashMap<String, WamiMethod>();
        mWebView.addJavascriptInterface(new WamiJavascriptInterface(this), "WAMIAndroidBridge");
        mRegisteredMethods.put("console", new WamiMethod() {
            @Override
            public void invoke(WamiInvocation invocation) {
                Log.i("WAMIConsole", invocation.getParameters().toString());
            }
        });
    }

    public void setOnWamiBridgeactivatedListener(OnWamiBridgeactivatedListener activateListener) {
        mActivatedListener = activateListener;
    }

    void finishInvocation(String callId, Object response) {
        callJavascriptFunction("WAMI.finishAppMethod", new JSONArray().put(callId).put(response));
    }

    void failInvocation(String callId, Object error) {
        callJavascriptFunction("WAMI.failAppMethod", new JSONArray().put(callId).put(error));
    }

    void revertInvocation(String method, String callId, JSONArray parameters) {
        callJavascriptFunction("WAMI.revertAppMethod", new JSONArray().put(method).put(callId).put(parameters));
    }

    public void setMethod(String name, WamiMethod method) {
        mRegisteredMethods.put(name, method);
    }

    public void callJavascriptFunction(String name, JSONArray args) {
        executeJavascript(String.format("%s(%s)", name, WamiBridge.argsString(args)));
    }

    public void executeJavascript(final String script) {
        mWebView.post(new Runnable() {
            @Override
            public void run() {
                mWebView.loadUrl(String.format("javascript:%s;", script));
            }
        });
    }

    /**
     * Serialize a supported object to its JSON value, can safely be inserted as
     * arguments to a JavaScript function.
     * 
     * @param o
     *            The object to convert (must be supported type)
     * @return A JavaScript arguments string representation of the object.
     */
    private static String argsString(JSONArray args) {
        if (args == null)
            return "";
        String jsonValue = args.toString();
        return jsonValue.substring(1, jsonValue.length() - 1);
    }

    private void registerBridge() {
        callJavascriptFunction("WAMI.setCurrentPlatform", new JSONArray().put("Android").put(true));
        if (mActivatedListener != null) {
            mActivatedListener.onWamiBridgeActivated(this);
        }
    }

    private class WamiJavascriptInterface {
        private final WamiBridge mBridge;

        WamiJavascriptInterface(WamiBridge bridge) {
            mBridge = bridge;
        }

        @SuppressWarnings("unused")
        @JavascriptInterface
        public void invoke(String method, String callId, String args, boolean expectsResponse) throws JSONException {
            if (!mBridge.mRegisteredMethods.containsKey(method)) {
                if (expectsResponse) {
                    mBridge.revertInvocation(method, callId, new JSONArray(args));
                }
                return;
            }
            mBridge.mRegisteredMethods.get(method).invoke(
                    new WamiInvocation(method, callId, new JSONArray(args), mBridge));
        }

        @SuppressWarnings("unused")
        @JavascriptInterface
        public void register() {
            mBridge.registerBridge();
        }
    }

    public interface OnWamiBridgeactivatedListener {
        public void onWamiBridgeActivated(WamiBridge bridge);
    }
}
