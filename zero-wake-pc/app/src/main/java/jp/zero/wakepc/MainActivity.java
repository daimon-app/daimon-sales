package jp.zero.wakepc;

import android.app.Activity;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.util.Locale;

public class MainActivity extends Activity {
    private static final String DEFAULT_MAC = "68:84:7E:5E:34:D1";
    private static final String DEFAULT_BROADCAST = "192.168.0.255";
    private static final int DEFAULT_PORT = 9;
    private static final String PREFS = "zero_wake_pc";
    private EditText macInput, broadcastInput, portInput;
    private TextView status;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(24), dp(42), dp(24), dp(24));
        root.setBackgroundColor(Color.rgb(7, 17, 31));

        TextView title = text("ZERO WAKE PC", 28, Color.WHITE);
        title.setGravity(Gravity.CENTER_HORIZONTAL);
        root.addView(title, matchWrap());
        TextView subtitle = text("LAN内 Wake-on-LAN", 15, Color.rgb(151, 170, 190));
        subtitle.setGravity(Gravity.CENTER_HORIZONTAL);
        LinearLayout.LayoutParams subtitleParams = matchWrap();
        subtitleParams.setMargins(0, dp(6), 0, dp(28));
        root.addView(subtitle, subtitleParams);

        macInput = field("MACアドレス", prefs.getString("mac", DEFAULT_MAC));
        broadcastInput = field("ブロードキャストIP", prefs.getString("broadcast", DEFAULT_BROADCAST));
        portInput = field("UDPポート", String.valueOf(prefs.getInt("port", DEFAULT_PORT)));
        portInput.setInputType(InputType.TYPE_CLASS_NUMBER);
        root.addView(macInput, fieldParams());
        root.addView(broadcastInput, fieldParams());
        root.addView(portInput, fieldParams());

        Button wake = new Button(this);
        wake.setText("PC 電源ON");
        wake.setTextSize(20);
        wake.setAllCaps(false);
        LinearLayout.LayoutParams buttonParams = matchWrap();
        buttonParams.height = dp(64);
        buttonParams.setMargins(0, dp(18), 0, dp(14));
        root.addView(wake, buttonParams);
        status = text("送信準備完了", 14, Color.rgb(151, 170, 190));
        status.setGravity(Gravity.CENTER_HORIZONTAL);
        root.addView(status, matchWrap());
        wake.setOnClickListener(v -> saveAndWake());
        setContentView(root);
    }

    private void saveAndWake() {
        final String mac;
        final String broadcast = broadcastInput.getText().toString().trim();
        final int port;
        try {
            mac = normalizeMac(macInput.getText().toString());
            InetAddress.getByName(broadcast);
            port = Integer.parseInt(portInput.getText().toString().trim());
            if (port < 1 || port > 65535) throw new IllegalArgumentException("UDPポートが不正です");
        } catch (Exception e) {
            status.setText("設定エラー");
            Toast.makeText(this, "設定値を確認してください: " + e.getMessage(), Toast.LENGTH_LONG).show();
            return;
        }
        macInput.setText(mac);
        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                .putString("mac", mac).putString("broadcast", broadcast).putInt("port", port).apply();
        status.setText("Magic Packet送信中…");
        new Thread(() -> sendMagicPacket(mac, broadcast, port)).start();
    }

    private void sendMagicPacket(String mac, String broadcast, int port) {
        try {
            byte[] data = buildMagicPacket(mac);
            InetAddress target = InetAddress.getByName(broadcast);
            try (DatagramSocket socket = new DatagramSocket()) {
                socket.setBroadcast(true);
                for (int i = 0; i < 3; i++) {
                    socket.send(new DatagramPacket(data, data.length, target, port));
                    if (i < 2) Thread.sleep(150);
                }
            }
            runOnUiThread(() -> status.setText("送信完了：3回"));
        } catch (Exception e) {
            runOnUiThread(() -> {
                status.setText("送信失敗");
                Toast.makeText(this, "送信できませんでした: " + e.getMessage(), Toast.LENGTH_LONG).show();
            });
        }
    }

    static String normalizeMac(String raw) {
        String hex = raw.replaceAll("[^0-9A-Fa-f]", "").toUpperCase(Locale.ROOT);
        if (hex.length() != 12) throw new IllegalArgumentException("MACは12桁の16進数で入力してください");
        StringBuilder result = new StringBuilder(17);
        for (int i = 0; i < 12; i += 2) {
            if (i > 0) result.append(':');
            result.append(hex, i, i + 2);
        }
        return result.toString();
    }

    static byte[] buildMagicPacket(String normalizedMac) {
        String[] parts = normalizedMac.split(":");
        byte[] mac = new byte[6];
        for (int i = 0; i < 6; i++) mac[i] = (byte) Integer.parseInt(parts[i], 16);
        byte[] packet = new byte[102];
        for (int i = 0; i < 6; i++) packet[i] = (byte) 0xFF;
        for (int i = 6; i < packet.length; i++) packet[i] = mac[(i - 6) % 6];
        return packet;
    }

    private EditText field(String hint, String value) {
        EditText field = new EditText(this);
        field.setHint(hint);
        field.setText(value);
        field.setTextColor(Color.WHITE);
        field.setHintTextColor(Color.rgb(121, 143, 165));
        field.setSingleLine(true);
        field.setTextSize(16);
        return field;
    }

    private TextView text(String value, int size, int color) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(color);
        return view;
    }

    private LinearLayout.LayoutParams fieldParams() {
        LinearLayout.LayoutParams params = matchWrap();
        params.setMargins(0, 0, 0, dp(10));
        return params;
    }

    private LinearLayout.LayoutParams matchWrap() {
        return new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
