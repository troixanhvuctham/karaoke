package com.hatkaraoke.app;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.Iterator;

/**
 * Tìm video trên YouTube không cần API key: tải trang kết quả tìm kiếm rồi đọc
 * dữ liệu ytInitialData trong trang. Nếu YouTube đổi cấu trúc trang thì trả về null
 * để trang karaoke chuyển sang mở trang tìm kiếm YouTube.
 */
final class YouTubeSearch {
    private static final int MAX_RESULTS = 24;
    private static final String DATA_START = "var ytInitialData = ";
    private static final String DATA_END = ";</script>";

    private YouTubeSearch() {}

    /** Trả về chuỗi JSON [{id, title, channel, thumb}, ...], hoặc "null" nếu không đọc được. */
    static String searchJson(String query) {
        try {
            String html = download("https://www.youtube.com/results?hl=vi&gl=VN&search_query="
                    + URLEncoder.encode(query, "UTF-8"));
            int start = html.indexOf(DATA_START);
            if (start < 0) return "null";
            start += DATA_START.length();
            int end = html.indexOf(DATA_END, start);
            if (end < 0) return "null";
            JSONArray results = new JSONArray();
            collectVideos(new JSONObject(html.substring(start, end)), results);
            return results.toString();
        } catch (Exception e) {
            return "null";
        }
    }

    private static String download(String url) throws Exception {
        HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
        conn.setConnectTimeout(10000);
        conn.setReadTimeout(15000);
        conn.setRequestProperty("User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36");
        conn.setRequestProperty("Accept-Language", "vi-VN,vi;q=0.9");
        conn.setRequestProperty("Cookie", "CONSENT=YES+");
        try (InputStream in = conn.getInputStream()) {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buf = new byte[16384];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            return out.toString("UTF-8");
        } finally {
            conn.disconnect();
        }
    }

    /** Duyệt toàn bộ dữ liệu, lấy mọi "videoRenderer" (bỏ qua Shorts và quảng cáo). */
    private static void collectVideos(Object node, JSONArray results) throws Exception {
        if (results.length() >= MAX_RESULTS) return;
        if (node instanceof JSONArray) {
            JSONArray arr = (JSONArray) node;
            for (int i = 0; i < arr.length(); i++) collectVideos(arr.get(i), results);
        } else if (node instanceof JSONObject) {
            JSONObject obj = (JSONObject) node;
            Iterator<String> keys = obj.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                Object value = obj.get(key);
                if (key.equals("videoRenderer") && value instanceof JSONObject) {
                    JSONObject video = toResult((JSONObject) value);
                    if (video != null && results.length() < MAX_RESULTS) results.put(video);
                } else {
                    collectVideos(value, results);
                }
            }
        }
    }

    private static JSONObject toResult(JSONObject v) throws Exception {
        String id = v.optString("videoId", "");
        String title = firstRun(v.optJSONObject("title"));
        if (id.isEmpty() || title.isEmpty()) return null;
        String channel = firstRun(v.optJSONObject("ownerText"));
        if (channel.isEmpty()) channel = firstRun(v.optJSONObject("longBylineText"));
        JSONObject result = new JSONObject();
        result.put("id", id);
        result.put("title", title);
        result.put("channel", channel);
        result.put("thumb", "https://i.ytimg.com/vi/" + id + "/hqdefault.jpg");
        return result;
    }

    private static String firstRun(JSONObject text) {
        if (text == null) return "";
        JSONArray runs = text.optJSONArray("runs");
        if (runs != null && runs.length() > 0) return runs.optJSONObject(0).optString("text", "");
        return text.optString("simpleText", "");
    }
}
