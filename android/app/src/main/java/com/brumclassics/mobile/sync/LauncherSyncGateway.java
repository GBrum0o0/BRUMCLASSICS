package com.brumclassics.mobile.sync;

import com.brumclassics.mobile.model.Game;
import java.util.List;

/** Contract for a future authenticated bridge. The demo build deliberately has no account access. */
public interface LauncherSyncGateway {
    interface Callback {
        void onSuccess(List<Game> games);
        void onError(String safeMessage);
    }

    void synchronize(Callback callback);
    boolean isConnected();
}
