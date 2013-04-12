package wami;

import org.json.JSONArray;

public class WamiInvocation {

    private final String mCallId;
    private final String mMethod;
    private final JSONArray mParameters;
    private final WamiBridge mBridge;

    WamiInvocation(String method, String callId, JSONArray parameters, WamiBridge bridge) {
        mMethod = method;
        mParameters = parameters;
        mCallId = callId;
        mBridge = bridge;
    }

    public JSONArray getParameters() {
        return mParameters;
    }

    public void finish(Object response) {
        mBridge.finishInvocation(mCallId, response);
    }

    public void fail(Object error) {
        mBridge.failInvocation(mCallId, error);
    }

    public void revert() {
        mBridge.revertInvocation(mMethod, mCallId, getParameters());
    }
}
