package com.hatkaraoke.app;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.os.Bundle;
import android.speech.RecognizerIntent;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.webkit.WebViewAssetLoader;

import org.json.JSONObject;

import java.util.ArrayList;

/** Màn hình tìm bài: hiển thị trang index.html (dùng chung với bản máy tính). */
public class MainActivity extends Activity {
    /** Trang trong app được phục vụ qua địa chỉ https giả để YouTube chấp nhận. */
    static final String APP_ORIGIN = "https://appassets.androidplatform.net";
    private static final int VOICE_REQUEST = 1;

    private WebView web;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        web = new WebView(this);
        setContentView(web);

        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);

        final WebViewAssetLoader assets = new WebViewAssetLoader.Builder()
                .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
                .build();
        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return assets.shouldInterceptRequest(request.getUrl());
            }

            // Mọi link ra ngoài (video, trang tìm kiếm YouTube) mở ở màn hình phát.
            @Override
            @SuppressWarnings("deprecation")
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                if (url.startsWith(APP_ORIGIN)) return false;
                if (url.startsWith("http://") || url.startsWith("https://")) {
                    PlayerActivity.open(MainActivity.this, url);
                }
                return true;
            }
        });
        web.addJavascriptInterface(new Bridge(), "KaraokeApp");
        web.requestFocus();
        web.loadUrl(APP_ORIGIN + "/assets/index.html");
    }

    /** Các hàm trang index.html gọi được qua window.KaraokeApp. */
    private class Bridge {
        @JavascriptInterface
        public void search(final String query, final int seq) {
            new Thread(new Runnable() {
                @Override
                public void run() {
                    final String json = YouTubeSearch.searchJson(query);
                    runJs("onAppSearch(" + seq + "," + json + ")");
                }
            }).start();
        }

        @JavascriptInterface
        public boolean hasVoice() {
            return !getPackageManager()
                    .queryIntentActivities(new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH), 0)
                    .isEmpty();
        }

        @JavascriptInterface
        public void startVoice() {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
                    intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
                    intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "vi-VN");
                    intent.putExtra(RecognizerIntent.EXTRA_PROMPT, "Nói tên bài hát");
                    try {
                        startActivityForResult(intent, VOICE_REQUEST);
                    } catch (ActivityNotFoundException ignored) {
                    }
                }
            });
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != VOICE_REQUEST || resultCode != RESULT_OK || data == null) return;
        ArrayList<String> results = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS);
        if (results != null && !results.isEmpty()) runJs("onAppVoice(" + JSONObject.quote(results.get(0)) + ")");
    }

    private void runJs(final String script) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                web.evaluateJavascript(script, null);
            }
        });
    }

    @Override
    protected void onDestroy() {
        web.destroy();
        super.onDestroy();
    }
}
