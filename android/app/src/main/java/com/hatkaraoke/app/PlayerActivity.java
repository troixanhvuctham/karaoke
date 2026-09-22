package com.hatkaraoke.app;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import androidx.webkit.WebViewAssetLoader;

/**
 * Màn hình phát: video YouTube phát toàn màn hình qua player.html. Video không cho nhúng
 * thì player.html tự chuyển sang m.youtube. Nút Back trên remote quay về màn hình tìm bài.
 */
public class PlayerActivity extends Activity {
    private static final String EXTRA_URL = "url";

    private FrameLayout root;
    private WebView web;
    private View fullscreenView;
    private WebChromeClient.CustomViewCallback fullscreenCallback;

    static void open(Context context, String url) {
        context.startActivity(new Intent(context, PlayerActivity.class).putExtra(EXTRA_URL, url));
    }

    /** Link video (youtube.com/watch?v=..., youtu.be/...) phát bằng player.html; link khác mở nguyên trang. */
    private static String pageFor(String url) {
        Uri uri = Uri.parse(url);
        String host = uri.getHost() == null ? "" : uri.getHost();
        String id = null;
        if (host.endsWith("youtube.com") && "/watch".equals(uri.getPath())) id = uri.getQueryParameter("v");
        else if (host.equals("youtu.be") && uri.getPath() != null) id = uri.getPath().substring(1);
        if (id == null || id.isEmpty()) return url;
        return MainActivity.APP_ORIGIN + "/assets/player.html?v=" + Uri.encode(id);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        root = new FrameLayout(this);
        web = new WebView(this);
        root.addView(web, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(root);

        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setMediaPlaybackRequiresUserGesture(false);

        final WebViewAssetLoader assets = new WebViewAssetLoader.Builder()
                .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
                .build();
        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return assets.shouldInterceptRequest(request.getUrl());
            }

            // Chặn link kiểu intent:// (mời mở app YouTube, vốn không chạy trên máy này).
            @Override
            @SuppressWarnings("deprecation")
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                return !(url.startsWith("http://") || url.startsWith("https://"));
            }
        });
        // Cho phép video m.youtube phóng toàn màn hình.
        web.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onShowCustomView(View view, CustomViewCallback callback) {
                exitFullscreen();
                fullscreenView = view;
                fullscreenCallback = callback;
                root.addView(view, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
                web.setVisibility(View.GONE);
            }

            @Override
            public void onHideCustomView() {
                exitFullscreen();
            }
        });
        web.addJavascriptInterface(new Object() {
            // player.html gọi khi hát xong bài để tự quay về màn hình tìm bài.
            @JavascriptInterface
            public void close() {
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        finish();
                    }
                });
            }
        }, "KaraokePlayer");
        web.requestFocus();
        web.loadUrl(pageFor(getIntent().getStringExtra(EXTRA_URL)));
    }

    private void exitFullscreen() {
        if (fullscreenView == null) return;
        root.removeView(fullscreenView);
        fullscreenView = null;
        if (fullscreenCallback != null) fullscreenCallback.onCustomViewHidden();
        fullscreenCallback = null;
        web.setVisibility(View.VISIBLE);
    }

    /** Trên player.html: OK = dừng/phát, trái/phải = tua lùi/tới 10 giây. */
    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        String url = web.getUrl();
        if (url != null && url.startsWith(MainActivity.APP_ORIGIN + "/assets/player.html")) {
            String action = null;
            switch (event.getKeyCode()) {
                case KeyEvent.KEYCODE_DPAD_CENTER:
                case KeyEvent.KEYCODE_ENTER:
                case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
                    action = "toggle";
                    break;
                case KeyEvent.KEYCODE_DPAD_LEFT:
                case KeyEvent.KEYCODE_MEDIA_REWIND:
                    action = "back";
                    break;
                case KeyEvent.KEYCODE_DPAD_RIGHT:
                case KeyEvent.KEYCODE_MEDIA_FAST_FORWARD:
                    action = "forward";
                    break;
            }
            if (action != null) {
                if (event.getAction() == KeyEvent.ACTION_UP) web.evaluateJavascript("remote('" + action + "')", null);
                return true;
            }
        }
        return super.dispatchKeyEvent(event);
    }

    @Override
    @SuppressWarnings("deprecation")
    public void onBackPressed() {
        if (fullscreenView != null) exitFullscreen();
        else finish();
    }

    @Override
    protected void onDestroy() {
        web.destroy();
        super.onDestroy();
    }
}
