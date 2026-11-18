package com.brumclassics.mobile.murb;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Bundle;
import android.view.HapticFeedbackConstants;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public final class MurbRemoteGamepadActivity extends Activity implements MurbRemoteClient.Listener {
    private String host;
    private int port;
    private String token;
    private String system = "ds";

    private MurbRemoteClient client;
    private RemoteCanvasView canvasView;
    private TextView statusPill;
    private TextView modeToggle;
    private TextView scaleToggle;

    private int physicalButtons;
    private int physicalStickX;
    private int physicalStickY;
    private int virtualButtons;
    private boolean virtualTouching;
    private int virtualTouchX;
    private int virtualTouchY;
    private int virtualStickX;
    private int virtualStickY;

    private int fps;
    private int frameCounter;
    private long lastFpsTick;
    private int lastRtt;

    public static Intent intent(Context context, String host, int port, String token, String system) {
        Intent intent = new Intent(context, MurbRemoteGamepadActivity.class);
        intent.putExtra("host", host);
        intent.putExtra("port", port);
        intent.putExtra("token", token);
        intent.putExtra("sys", system);
        return intent;
    }

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        hideSystemUI();

        host = getIntent().getStringExtra("host");
        port = getIntent().getIntExtra("port", 8089);
        token = getIntent().getStringExtra("token");
        system = MurbRemoteClient.normalizeSystem(getIntent().getStringExtra("sys"));

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.rgb(6, 7, 10));

        canvasView = new RemoteCanvasView(this);
        canvasView.setSystem(system);
        canvasView.setListener((buttons, touching, tx, ty, sx, sy) -> {
            virtualButtons = buttons;
            virtualTouching = touching;
            virtualTouchX = tx;
            virtualTouchY = ty;
            virtualStickX = sx;
            virtualStickY = sy;
            dispatchCombinedInput();
        });
        root.addView(canvasView, new FrameLayout.LayoutParams(-1, -1));

        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setPadding(dp(12), dp(8), dp(12), dp(8));

        TextView exit = pillButton("‹ Sair", false, v -> finish());
        statusPill = pillButton("", false, null);
        statusPill.setTextColor(Color.rgb(220, 226, 232));

        modeToggle = pillButton("Touch puro", false, v -> {
            canvasView.setShowControls(!canvasView.isShowControls());
            updateControlsToggle();
        });
        scaleToggle = pillButton("Tela cheia", false, v -> {
            canvasView.setFillScreen(!canvasView.isFillScreen());
            scaleToggle.setText(canvasView.isFillScreen() ? "4:3" : "Tela cheia");
        });
        TextView reconnect = pillButton("Reconectar", false, v -> startClient());

        bar.addView(exit);
        bar.addView(statusPill, marginStart(dp(8)));
        View spacer = new View(this);
        bar.addView(spacer, new LinearLayout.LayoutParams(0, 1, 1));
        bar.addView(scaleToggle, marginStart(dp(6)));
        bar.addView(modeToggle, marginStart(dp(6)));
        bar.addView(reconnect, marginStart(dp(6)));
        root.addView(bar, new FrameLayout.LayoutParams(-1, -2));

        setContentView(root);
        updateDualScreenControls();
        updateStatusPill();
        startClient();
    }

    private LinearLayout.LayoutParams marginStart(int px) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-2, dp(36));
        lp.leftMargin = px;
        return lp;
    }

    private TextView pillButton(String title, boolean accent, View.OnClickListener click) {
        TextView view = new TextView(this);
        view.setText(title);
        view.setTextSize(12);
        view.setTypeface(Typeface.DEFAULT_BOLD);
        view.setTextColor(accent ? Color.BLACK : Color.WHITE);
        view.setBackgroundColor(accent ? Color.rgb(157, 255, 59) : Color.argb(215, 22, 26, 33));
        view.setPadding(dp(12), dp(8), dp(12), dp(8));
        if (click != null) view.setOnClickListener(click);
        return view;
    }

    private void startClient() {
        if (client != null) client.disconnect();
        client = new MurbRemoteClient(host, port, token, this);
        client.connect();
        updateStatusPill();
    }

    private void updateDualScreenControls() {
        boolean dual = MurbRemoteClient.supportsDualScreen(system);
        modeToggle.setVisibility(dual ? View.VISIBLE : View.GONE);
        scaleToggle.setVisibility(dual ? View.VISIBLE : View.GONE);
        if (!dual) canvasView.setShowControls(true);
        updateControlsToggle();
    }

    private void updateControlsToggle() {
        boolean show = canvasView.isShowControls();
        modeToggle.setText(show ? "Touch puro" : "Controles");
        modeToggle.setTextColor(show ? Color.WHITE : Color.BLACK);
        modeToggle.setBackgroundColor(show ? Color.argb(215, 22, 26, 33) : Color.rgb(157, 255, 59));
    }

    private void dispatchCombinedInput() {
        if (client == null || !client.isConnected()) return;
        int combined = virtualButtons | physicalButtons;
        int sx = Math.abs(physicalStickX) > Math.abs(virtualStickX) ? physicalStickX : virtualStickX;
        int sy = Math.abs(physicalStickY) > Math.abs(virtualStickY) ? physicalStickY : virtualStickY;
        client.sendInput(combined, virtualTouching, virtualTouchX, virtualTouchY, sx, sy);
    }

    @Override public boolean dispatchKeyEvent(KeyEvent event) {
        int bit = mapKeyBit(event.getKeyCode());
        if (bit != 0) {
            if (event.getAction() == KeyEvent.ACTION_DOWN) physicalButtons |= bit;
            else if (event.getAction() == KeyEvent.ACTION_UP) physicalButtons &= ~bit;
            dispatchCombinedInput();
            return true;
        }
        return super.dispatchKeyEvent(event);
    }

    @Override public boolean dispatchGenericMotionEvent(MotionEvent event) {
        if ((event.getSource() & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
                && event.getAction() == MotionEvent.ACTION_MOVE) {
            float hatX = event.getAxisValue(MotionEvent.AXIS_HAT_X);
            float hatY = event.getAxisValue(MotionEvent.AXIS_HAT_Y);
            physicalButtons &= ~(MurbRemoteClient.BTN_LEFT | MurbRemoteClient.BTN_RIGHT
                | MurbRemoteClient.BTN_UP | MurbRemoteClient.BTN_DOWN);
            if (hatX < -0.45f) physicalButtons |= MurbRemoteClient.BTN_LEFT;
            if (hatX > 0.45f) physicalButtons |= MurbRemoteClient.BTN_RIGHT;
            if (hatY < -0.45f) physicalButtons |= MurbRemoteClient.BTN_UP;
            if (hatY > 0.45f) physicalButtons |= MurbRemoteClient.BTN_DOWN;

            physicalStickX = Math.round(clamp(event.getAxisValue(MotionEvent.AXIS_X)) * 32767f);
            physicalStickY = Math.round(clamp(event.getAxisValue(MotionEvent.AXIS_Y)) * 32767f);
            float l2 = event.getAxisValue(MotionEvent.AXIS_LTRIGGER);
            float r2 = event.getAxisValue(MotionEvent.AXIS_RTRIGGER);
            if (l2 > 0.25f) physicalButtons |= MurbRemoteClient.BTN_L2; else physicalButtons &= ~MurbRemoteClient.BTN_L2;
            if (r2 > 0.25f) physicalButtons |= MurbRemoteClient.BTN_R2; else physicalButtons &= ~MurbRemoteClient.BTN_R2;
            dispatchCombinedInput();
            return true;
        }
        return super.dispatchGenericMotionEvent(event);
    }

    private static float clamp(float value) { return Math.max(-1f, Math.min(1f, value)); }

    private static int mapKeyBit(int keyCode) {
        switch (keyCode) {
            case KeyEvent.KEYCODE_BUTTON_B: return MurbRemoteClient.BTN_A;
            case KeyEvent.KEYCODE_BUTTON_A: return MurbRemoteClient.BTN_B;
            case KeyEvent.KEYCODE_BUTTON_Y: return MurbRemoteClient.BTN_X;
            case KeyEvent.KEYCODE_BUTTON_X: return MurbRemoteClient.BTN_Y;
            case KeyEvent.KEYCODE_BUTTON_SELECT: return MurbRemoteClient.BTN_SELECT;
            case KeyEvent.KEYCODE_BUTTON_START: return MurbRemoteClient.BTN_START;
            case KeyEvent.KEYCODE_DPAD_UP: return MurbRemoteClient.BTN_UP;
            case KeyEvent.KEYCODE_DPAD_DOWN: return MurbRemoteClient.BTN_DOWN;
            case KeyEvent.KEYCODE_DPAD_LEFT: return MurbRemoteClient.BTN_LEFT;
            case KeyEvent.KEYCODE_DPAD_RIGHT: return MurbRemoteClient.BTN_RIGHT;
            case KeyEvent.KEYCODE_BUTTON_L1: return MurbRemoteClient.BTN_L;
            case KeyEvent.KEYCODE_BUTTON_R1: return MurbRemoteClient.BTN_R;
            case KeyEvent.KEYCODE_BUTTON_L2: return MurbRemoteClient.BTN_L2;
            case KeyEvent.KEYCODE_BUTTON_R2: return MurbRemoteClient.BTN_R2;
            case KeyEvent.KEYCODE_BUTTON_THUMBL: return MurbRemoteClient.BTN_L3;
            case KeyEvent.KEYCODE_BUTTON_THUMBR: return MurbRemoteClient.BTN_R3;
            default: return 0;
        }
    }

    @Override public void onConnected() { updateStatusPill(); }

    @Override public void onDisconnected() {
        updateStatusPill();
        if (!isFinishing() && !isDestroyed()) {
            canvasView.postDelayed(() -> {
                if (!isFinishing() && !isDestroyed() && (client == null || !client.isConnected())) {
                    startClient();
                }
            }, 2000);
        }
    }

    @Override public void onVideoFrame(byte[] rgb565Pixels, int width, int height, int sequence) {
        canvasView.updateFrame(rgb565Pixels, width, height);
        frameCounter++;
        long now = System.currentTimeMillis();
        if (now - lastFpsTick >= 1000) {
            fps = frameCounter;
            frameCounter = 0;
            lastFpsTick = now;
            updateStatusPill();
        }
    }

    @Override public void onPingRtt(int rttMs) {
        lastRtt = rttMs;
        updateStatusPill();
    }

    @Override public void onSystemIdentified(String identified) {
        system = identified;
        canvasView.setSystem(system);
        updateDualScreenControls();
        updateStatusPill();
    }

    @Override public void onError(String message) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }

    private void updateStatusPill() {
        boolean online = client != null && client.isConnected();
        String dot = online ? "●" : "○";
        String base = dot + " M.U.R.B " + system.toUpperCase(Locale.ROOT) + " · PC";
        if (online && MurbRemoteClient.supportsDualScreen(system)) {
            statusPill.setText(String.format(Locale.US, "%s · %d FPS · %d ms", base, fps, lastRtt));
        } else if (online) {
            statusPill.setText(String.format(Locale.US, "%s · %d ms", base, lastRtt));
        } else {
            statusPill.setText(base + " · reconectando…");
        }
    }

    @Override protected void onPause() {
        physicalButtons = 0;
        virtualButtons = 0;
        virtualTouching = false;
        dispatchCombinedInput();
        super.onPause();
    }

    @Override protected void onDestroy() {
        if (client != null) {
            client.disconnect();
            client = null;
        }
        super.onDestroy();
    }

    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }

    @SuppressWarnings("deprecation")
    private void hideSystemUI() {
        if (Build.VERSION.SDK_INT >= 30) {
            WindowInsetsController c = getWindow().getInsetsController();
            if (c != null) {
                c.hide(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
                c.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        } else {
            getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            );
        }
    }

    private static final class RemoteCanvasView extends View {
        interface Listener {
            void onInput(int buttons, boolean touching, int touchX, int touchY, int stickX, int stickY);
        }

        private static final class Zone {
            final int bit;
            final String label;
            final RectF rect;
            final boolean circle;
            Zone(int bit, String label, RectF rect, boolean circle) {
                this.bit = bit; this.label = label; this.rect = rect; this.circle = circle;
            }
        }

        private Listener listener;
        private String system = "ds";
        private boolean showControls = true;
        private boolean fillScreen = false;
        private boolean useStick = true;
        private Bitmap frameBitmap;
        private final RectF screenRect = new RectF();
        private final RectF dpadRect = new RectF();
        private final RectF stickRect = new RectF();
        private final RectF modeSwitchRect = new RectF();
        private final List<Zone> zones = new ArrayList<>();
        private final Map<Integer, Integer> buttonPointers = new HashMap<>();
        private int dpadPointer = -1;
        private int dpadMask;
        private int stickPointer = -1;
        private float stickX, stickY;
        private int screenPointer = -1;
        private float normTouchX, normTouchY, rawTouchX, rawTouchY;

        private final Paint fillPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint strokePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint bitmapPaint = new Paint();

        RemoteCanvasView(Context context) {
            super(context);
            strokePaint.setStyle(Paint.Style.STROKE);
            textPaint.setTypeface(Typeface.DEFAULT_BOLD);
            textPaint.setTextAlign(Paint.Align.CENTER);
        }

        void setListener(Listener listener) { this.listener = listener; }
        boolean isShowControls() { return showControls; }
        boolean isFillScreen() { return fillScreen; }
        void setShowControls(boolean show) { showControls = show; rebuildZones(); invalidate(); emit(); }
        void setFillScreen(boolean fill) { fillScreen = fill; rebuildZones(); invalidate(); }
        void setSystem(String sys) { system = sys; rebuildZones(); invalidate(); }

        void updateFrame(byte[] rgb565Pixels, int width, int height) {
            if (frameBitmap == null || frameBitmap.getWidth() != width || frameBitmap.getHeight() != height) {
                frameBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565);
            }
            frameBitmap.copyPixelsFromBuffer(ByteBuffer.wrap(rgb565Pixels));
            postInvalidateOnAnimation();
        }

        @Override protected void onSizeChanged(int w, int h, int oldw, int oldh) {
            super.onSizeChanged(w, h, oldw, oldh);
            rebuildZones();
        }

        private void rebuildZones() {
            zones.clear();
            dpadRect.setEmpty();
            stickRect.setEmpty();
            modeSwitchRect.setEmpty();
            screenRect.setEmpty();

            float w = getWidth(), h = getHeight();
            if (w <= 0 || h <= 0) return;
            float d = getResources().getDisplayMetrics().density;
            float topPad = 52f * d;

            if (MurbRemoteClient.supportsDualScreen(system)) {
                if (fillScreen) {
                    screenRect.set(10f * d, topPad, w - 10f * d, h - 10f * d);
                } else {
                    float availW = w - 20f * d;
                    float availH = Math.max(40f * d, h - topPad - 10f * d);
                    float aspect = 4f / 3f;
                    float sw = Math.min(availW, availH * aspect);
                    float sh = sw / aspect;
                    screenRect.set((w - sw) / 2f, topPad + (availH - sh) / 2f, (w + sw) / 2f, topPad + (availH + sh) / 2f);
                }
            }

            if (!showControls) return;

            boolean analog = MurbRemoteClient.hasAnalogStick(system);
            float cx = 96f * d, cy = h - 98f * d;
            if (analog && useStick) stickRect.set(cx - 64f * d, cy - 64f * d, cx + 64f * d, cy + 64f * d);
            else dpadRect.set(cx - 68f * d, cy - 68f * d, cx + 68f * d, cy + 68f * d);
            if (analog) modeSwitchRect.set(cx - 34f * d, cy - 106f * d, cx + 34f * d, cy - 78f * d);

            zones.add(new Zone(MurbRemoteClient.BTN_L, "L", new RectF(16f * d, 56f * d, 84f * d, 96f * d), false));
            zones.add(new Zone(MurbRemoteClient.BTN_R, "R", new RectF(w - 84f * d, 56f * d, w - 16f * d, 96f * d), false));
            if (analog) {
                zones.add(new Zone(MurbRemoteClient.BTN_L2, "L2", new RectF(92f * d, 56f * d, 152f * d, 96f * d), false));
                zones.add(new Zone(MurbRemoteClient.BTN_R2, "R2", new RectF(w - 152f * d, 56f * d, w - 92f * d, 96f * d), false));
            }
            zones.add(new Zone(MurbRemoteClient.BTN_SELECT, "SELECT", new RectF(w / 2f - 84f * d, h - 46f * d, w / 2f - 6f * d, h - 12f * d), false));
            zones.add(new Zone(MurbRemoteClient.BTN_START, "START", new RectF(w / 2f + 6f * d, h - 46f * d, w / 2f + 84f * d, h - 12f * d), false));

            float rx = w - 104f * d, ry = h - 98f * d;
            float r = 27f * d, dist = 50f * d;
            boolean ps = "ps1".equals(system) || "ps2".equals(system) || "psp".equals(system);
            zones.add(new Zone(MurbRemoteClient.BTN_X, ps ? "△" : "X", new RectF(rx - r, ry - dist - r, rx + r, ry - dist + r), true));
            zones.add(new Zone(MurbRemoteClient.BTN_B, ps ? "×" : "B", new RectF(rx - r, ry + dist - r, rx + r, ry + dist + r), true));
            zones.add(new Zone(MurbRemoteClient.BTN_Y, ps ? "□" : "Y", new RectF(rx - dist - r, ry - r, rx - dist + r, ry + r), true));
            zones.add(new Zone(MurbRemoteClient.BTN_A, ps ? "○" : "A", new RectF(rx + dist - r, ry - r, rx + dist + r, ry + r), true));
        }

        @Override protected void onDraw(Canvas canvas) {
            float d = getResources().getDisplayMetrics().density;
            if (!screenRect.isEmpty()) {
                fillPaint.setColor(Color.rgb(16, 19, 24));
                canvas.drawRect(screenRect, fillPaint);
                if (frameBitmap != null) {
                    canvas.drawBitmap(frameBitmap, null, screenRect, bitmapPaint);
                } else {
                    textPaint.setTextSize(12f * d);
                    textPaint.setColor(Color.rgb(140, 148, 160));
                    canvas.drawText("AGUARDANDO 2ª TELA DO PC", screenRect.centerX(), screenRect.centerY(), textPaint);
                }
                strokePaint.setColor(Color.argb(55, 255, 255, 255));
                strokePaint.setStrokeWidth(1.5f * d);
                canvas.drawRect(screenRect, strokePaint);
                if (screenPointer >= 0) {
                    strokePaint.setColor(Color.rgb(157, 255, 59));
                    strokePaint.setStrokeWidth(2.5f * d);
                    canvas.drawCircle(rawTouchX, rawTouchY, 16f * d, strokePaint);
                }
            }

            if (!showControls) return;

            if (!dpadRect.isEmpty()) {
                fillPaint.setColor(Color.argb(205, 20, 23, 29));
                canvas.drawOval(dpadRect, fillPaint);
                strokePaint.setColor(Color.argb(75, 255, 255, 255));
                strokePaint.setStrokeWidth(1.5f * d);
                canvas.drawOval(dpadRect, strokePaint);
                textPaint.setTextSize(17f * d);
                drawArrow(canvas, MurbRemoteClient.BTN_UP, "▲", dpadRect.centerX(), dpadRect.top + 26f * d);
                drawArrow(canvas, MurbRemoteClient.BTN_DOWN, "▼", dpadRect.centerX(), dpadRect.bottom - 18f * d);
                drawArrow(canvas, MurbRemoteClient.BTN_LEFT, "◀", dpadRect.left + 22f * d, dpadRect.centerY() + 6f * d);
                drawArrow(canvas, MurbRemoteClient.BTN_RIGHT, "▶", dpadRect.right - 22f * d, dpadRect.centerY() + 6f * d);
            }

            if (!stickRect.isEmpty()) {
                fillPaint.setColor(Color.argb(205, 20, 23, 29));
                canvas.drawOval(stickRect, fillPaint);
                strokePaint.setColor(Color.argb(75, 255, 255, 255));
                strokePaint.setStrokeWidth(1.5f * d);
                canvas.drawOval(stickRect, strokePaint);
                float radius = stickRect.width() / 2f - 22f * d;
                fillPaint.setColor(Color.argb(235, 157, 255, 59));
                canvas.drawCircle(stickRect.centerX() + stickX * radius, stickRect.centerY() + stickY * radius, 21f * d, fillPaint);
            }

            if (!modeSwitchRect.isEmpty()) {
                drawButton(canvas, modeSwitchRect, useStick ? "D-PAD" : "STICK", false, false, 9f * d, d);
            }

            int held = 0;
            for (Integer bit : buttonPointers.values()) held |= bit;
            for (Zone z : zones) {
                drawButton(canvas, z.rect, z.label, (held & z.bit) != 0, z.circle, 12f * d, d);
            }
        }

        private void drawArrow(Canvas canvas, int bit, String symbol, float x, float y) {
            textPaint.setColor((dpadMask & bit) != 0 ? Color.rgb(157, 255, 59) : Color.WHITE);
            canvas.drawText(symbol, x, y, textPaint);
        }

        private void drawButton(Canvas canvas, RectF rect, String label, boolean on, boolean circle, float radius, float d) {
            fillPaint.setColor(on ? Color.rgb(157, 255, 59) : Color.argb(205, 22, 26, 33));
            strokePaint.setColor(on ? Color.WHITE : Color.argb(55, 255, 255, 255));
            strokePaint.setStrokeWidth(1f * d);
            if (circle) {
                canvas.drawOval(rect, fillPaint);
                canvas.drawOval(rect, strokePaint);
            } else {
                canvas.drawRoundRect(rect, radius, radius, fillPaint);
                canvas.drawRoundRect(rect, radius, radius, strokePaint);
            }
            textPaint.setTextSize((label.length() > 2 ? 10f : 15f) * d);
            textPaint.setColor(on ? Color.BLACK : Color.WHITE);
            canvas.drawText(label, rect.centerX(), rect.centerY() + (textPaint.getTextSize() * 0.34f), textPaint);
        }

        @Override public boolean onTouchEvent(MotionEvent event) {
            int action = event.getActionMasked();
            int idx = event.getActionIndex();
            int pid = event.getPointerId(idx);

            if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_POINTER_DOWN) {
                float x = event.getX(idx), y = event.getY(idx);
                if (showControls && !modeSwitchRect.isEmpty() && modeSwitchRect.contains(x, y)) {
                    useStick = !useStick;
                    dpadPointer = -1; dpadMask = 0;
                    stickPointer = -1; stickX = 0; stickY = 0;
                    rebuildZones(); invalidate(); emit();
                    return true;
                }
                if (showControls) {
                    for (Zone z : zones) {
                        if (hit(z.rect, x, y)) {
                            buttonPointers.put(pid, z.bit);
                            performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
                            invalidate(); emit();
                            return true;
                        }
                    }
                    if (!dpadRect.isEmpty() && hit(dpadRect, x, y)) {
                        dpadPointer = pid;
                        updateDPad(x, y);
                        performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
                        invalidate(); emit();
                        return true;
                    }
                    if (!stickRect.isEmpty() && hit(stickRect, x, y)) {
                        stickPointer = pid;
                        updateStick(x, y);
                        invalidate(); emit();
                        return true;
                    }
                }
                if (!screenRect.isEmpty() && screenRect.contains(x, y)) {
                    screenPointer = pid;
                    updateScreen(x, y);
                    invalidate(); emit();
                }
            } else if (action == MotionEvent.ACTION_MOVE) {
                for (int i = 0; i < event.getPointerCount(); i++) {
                    int id = event.getPointerId(i);
                    float x = event.getX(i), y = event.getY(i);
                    if (id == dpadPointer) updateDPad(x, y);
                    else if (id == stickPointer) updateStick(x, y);
                    else if (id == screenPointer) updateScreen(x, y);
                    else if (buttonPointers.containsKey(id)) {
                        boolean found = false;
                        for (Zone z : zones) {
                            if (hit(z.rect, x, y)) { buttonPointers.put(id, z.bit); found = true; break; }
                        }
                        if (!found) buttonPointers.remove(id);
                    }
                }
                invalidate(); emit();
            } else if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_POINTER_UP || action == MotionEvent.ACTION_CANCEL) {
                if (action == MotionEvent.ACTION_CANCEL) {
                    buttonPointers.clear();
                    dpadPointer = -1; dpadMask = 0;
                    stickPointer = -1; stickX = 0; stickY = 0;
                    screenPointer = -1;
                } else {
                    buttonPointers.remove(pid);
                    if (pid == dpadPointer) { dpadPointer = -1; dpadMask = 0; }
                    if (pid == stickPointer) { stickPointer = -1; stickX = 0; stickY = 0; }
                    if (pid == screenPointer) screenPointer = -1;
                }
                invalidate(); emit();
            }
            return true;
        }

        private boolean hit(RectF r, float x, float y) {
            float pad = 8f * getResources().getDisplayMetrics().density;
            return x >= r.left - pad && x <= r.right + pad && y >= r.top - pad && y <= r.bottom + pad;
        }

        private void updateDPad(float x, float y) {
            float dx = x - dpadRect.centerX(), dy = y - dpadRect.centerY();
            float t = (dpadRect.width() / 2f) * 0.22f;
            int mask = 0;
            if (dx < -t) mask |= MurbRemoteClient.BTN_LEFT;
            if (dx > t) mask |= MurbRemoteClient.BTN_RIGHT;
            if (dy < -t) mask |= MurbRemoteClient.BTN_UP;
            if (dy > t) mask |= MurbRemoteClient.BTN_DOWN;
            dpadMask = mask;
        }

        private void updateStick(float x, float y) {
            float radius = Math.max(1f, stickRect.width() / 2f - 20f * getResources().getDisplayMetrics().density);
            float dx = (x - stickRect.centerX()) / radius, dy = (y - stickRect.centerY()) / radius;
            float mag = (float) Math.hypot(dx, dy);
            stickX = mag > 1f ? dx / mag : dx;
            stickY = mag > 1f ? dy / mag : dy;
        }

        private void updateScreen(float x, float y) {
            normTouchX = Math.max(0f, Math.min(1f, (x - screenRect.left) / Math.max(1f, screenRect.width())));
            normTouchY = Math.max(0f, Math.min(1f, (y - screenRect.top) / Math.max(1f, screenRect.height())));
            rawTouchX = x; rawTouchY = y;
        }

        private void emit() {
            if (listener == null) return;
            int mask = dpadMask;
            for (Integer bit : buttonPointers.values()) mask |= bit;
            boolean threeDS = "3ds".equals(MurbRemoteClient.normalizeSystem(system));
            int tx = screenPointer < 0 ? 0 : Math.round(normTouchX * (threeDS ? 319f : 255f));
            int ty = screenPointer < 0 ? 0 : Math.round(normTouchY * (threeDS ? 239f : 191f));
            listener.onInput(mask, screenPointer >= 0, tx, ty,
                Math.round(stickX * 32767f), Math.round(stickY * 32767f));
        }
    }
}
