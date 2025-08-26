package com.smartlab.zippy;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String DEEP_LINK_CHANNEL = "deep_link_channel";
    private MethodChannel methodChannel;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        methodChannel = new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), DEEP_LINK_CHANNEL);
        methodChannel.setMethodCallHandler(
            (call, result) -> {
                if (call.method.equals("getInitialLink")) {
                    String initialLink = getInitialLink();
                    result.success(initialLink);
                } else {
                    result.notImplemented();
                }
            }
        );

        // Handle deep link from intent
        handleIntent(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        handleIntent(intent);
    }

    private void handleIntent(Intent intent) {
        String action = intent.getAction();
        Uri data = intent.getData();

        if (Intent.ACTION_VIEW.equals(action) && data != null) {
            String link = data.toString();
            if (methodChannel != null) {
                methodChannel.invokeMethod("onDeepLink", link);
            }
        }
    }

    private String getInitialLink() {
        Intent intent = getIntent();
        String action = intent.getAction();
        Uri data = intent.getData();

        if (Intent.ACTION_VIEW.equals(action) && data != null) {
            return data.toString();
        }
        return null;
    }
}
