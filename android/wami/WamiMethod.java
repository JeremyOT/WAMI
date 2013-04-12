package wami;

import org.json.JSONException;

public abstract class WamiMethod {
    public abstract void invoke(WamiInvocation invocation) throws JSONException;

    private static class RevertingWamiMethod extends WamiMethod {

        @Override
        public void invoke(WamiInvocation invocation) throws JSONException {
            invocation.revert();
        }

    }

    public static WamiMethod getReverter() {
        return new RevertingWamiMethod();
    }
}
