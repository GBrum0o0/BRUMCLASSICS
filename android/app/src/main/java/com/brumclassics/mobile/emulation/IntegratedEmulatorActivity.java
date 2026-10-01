package com.brumclassics.mobile.emulation;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.Gravity;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.File;

public final class IntegratedEmulatorActivity extends Activity {
    public static final String RESULT_GAME_ID = "gameId";
    public static final String RESULT_ELAPSED_SECONDS = "elapsedSeconds";
    private static final int ACCENT = Color.rgb(157, 255, 59);
    private static final int[] CONTROLLER_KEYS = {
        KeyEvent.KEYCODE_BUTTON_B, KeyEvent.KEYCODE_BUTTON_Y, KeyEvent.KEYCODE_BUTTON_SELECT,
        KeyEvent.KEYCODE_BUTTON_START, KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN,
        KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT, KeyEvent.KEYCODE_BUTTON_A,
        KeyEvent.KEYCODE_BUTTON_X
    };

    private IntegratedEmulatorLaunch launch;
    private BrumCoreView emulatorView;
    private boolean closing;

    public static Intent intent(Context context, IntegratedEmulatorLaunch launch) {
        Intent intent = new Intent(context, IntegratedEmulatorActivity.class);
        intent.putExtra("gameId", launch.gameId); intent.putExtra("title", launch.title);
        intent.putExtra("canonicalGameId", launch.canonicalGameId); intent.putExtra("systemId", launch.systemId);
        intent.putExtra("contentSha256", launch.contentSha256); intent.putExtra("coreId", launch.coreId);
        intent.putExtra("romFile", launch.romFile.getAbsolutePath()); intent.putExtra("saveFile", launch.saveFile.getAbsolutePath());
        intent.putExtra("manifestFile", launch.manifestFile.getAbsolutePath()); intent.putExtra("systemDirectory", launch.systemDirectory.getAbsolutePath());
        return intent;
    }

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
        hideSystemUI();
        launch = readLaunch(getIntent());
        try {
            String corePath = getApplicationInfo().nativeLibraryDir + "/libmgba_libretro.so";
            if (!new File(corePath).isFile()) throw new IllegalStateException("O núcleo mGBA não está presente nesta instalação.");
            BrumCoreBridge bridge = new BrumCoreBridge(corePath, launch);
            emulatorView = new BrumCoreView(this, bridge);
            setContentView(buildInterface());
        } catch (Throwable error) {
            showFailure(error.getMessage() == null ? "O BRUM Core não conseguiu abrir este jogo." : error.getMessage());
        }
    }

    @Override protected void onResume() {
        super.onResume(); hideSystemUI();
        if (emulatorView != null) emulatorView.resumeEmulation();
    }

    @Override protected void onPause() {
        if (emulatorView != null) {
            emulatorView.pauseEmulation();
            try { SaveManifestStore.update(this, launch); } catch (Exception ignored) {}
        }
        super.onPause();
    }

    @Override protected void onDestroy() {
        if (emulatorView != null) emulatorView.destroy();
        super.onDestroy();
    }

    @Override public void onBackPressed() { closeEmulator(); }

    @Override public boolean dispatchKeyEvent(KeyEvent event) {
        if (emulatorView != null) {
            for (int id = 0; id < CONTROLLER_KEYS.length; id++) if (event.getKeyCode() == CONTROLLER_KEYS[id]) {
                emulatorView.setButton(id, event.getAction() == KeyEvent.ACTION_DOWN);
                return true;
            }
        }
        return super.dispatchKeyEvent(event);
    }

    @Override public boolean dispatchGenericMotionEvent(MotionEvent event) {
        if (emulatorView != null && (event.getSource() & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK && event.getAction() == MotionEvent.ACTION_MOVE) {
            float x = axis(event, MotionEvent.AXIS_HAT_X, MotionEvent.AXIS_X);
            float y = axis(event, MotionEvent.AXIS_HAT_Y, MotionEvent.AXIS_Y);
            emulatorView.setButton(6, x < -0.45f); emulatorView.setButton(7, x > 0.45f);
            emulatorView.setButton(4, y < -0.45f); emulatorView.setButton(5, y > 0.45f);
            return true;
        }
        return super.dispatchGenericMotionEvent(event);
    }

    private FrameLayout buildInterface() {
        FrameLayout root = new FrameLayout(this); root.setBackgroundColor(Color.BLACK);
        root.addView(emulatorView, new FrameLayout.LayoutParams(-1, -1));

        Button exit = control("←  SAIR");
        exit.setOnClickListener(v -> closeEmulator());
        FrameLayout.LayoutParams exitParams = frame(104, 44, Gravity.TOP | Gravity.START); exitParams.setMargins(dp(14), dp(12), 0, 0); root.addView(exit, exitParams);

        TextView title = label(launch.title, 13, Color.WHITE, true); title.setSingleLine(true); title.setGravity(Gravity.CENTER);
        FrameLayout.LayoutParams titleParams = frame(300, 42, Gravity.TOP | Gravity.CENTER_HORIZONTAL); titleParams.topMargin = dp(13); root.addView(title, titleParams);

        LinearLayout tools = new LinearLayout(this); tools.setOrientation(LinearLayout.HORIZONTAL); tools.setGravity(Gravity.CENTER); tools.setPadding(0, 0, 0, 0);
        Button display = control("PREENCHER"); Button fast = control("≫  5×");
        display.setOnClickListener(v -> { emulatorView.toggleFillDisplay(); display.setText(emulatorView.fillsDisplay() ? "PREENCHER" : "INTEIRA"); });
        fast.setOnClickListener(v -> { emulatorView.setFastForward(!emulatorView.isFastForward()); fast.setTextColor(emulatorView.isFastForward() ? Color.BLACK : Color.WHITE); fast.setBackground(controlBackground(emulatorView.isFastForward())); });
        tools.addView(display, new LinearLayout.LayoutParams(dp(100), dp(44))); LinearLayout.LayoutParams fastParams = new LinearLayout.LayoutParams(dp(82), dp(44)); fastParams.leftMargin = dp(8); tools.addView(fast, fastParams);
        FrameLayout.LayoutParams toolsParams = frame(190, 44, Gravity.TOP | Gravity.END); toolsParams.setMargins(0, dp(12), dp(14), 0); root.addView(tools, toolsParams);

        addPadButton(root, "↑", 4, Gravity.BOTTOM | Gravity.START, 78, 126);
        addPadButton(root, "↓", 5, Gravity.BOTTOM | Gravity.START, 78, 18);
        addPadButton(root, "←", 6, Gravity.BOTTOM | Gravity.START, 20, 72);
        addPadButton(root, "→", 7, Gravity.BOTTOM | Gravity.START, 136, 72);
        addPadButton(root, "B", 0, Gravity.BOTTOM | Gravity.END, 136, 42);
        addPadButton(root, "A", 8, Gravity.BOTTOM | Gravity.END, 34, 88);

        Button select = gameButton("SELECT", 2); Button start = gameButton("START", 3);
        FrameLayout.LayoutParams selectParams = frame(82, 40, Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL); selectParams.setMargins(0, 0, dp(47), dp(18)); root.addView(select, selectParams);
        FrameLayout.LayoutParams startParams = frame(82, 40, Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL); startParams.setMargins(dp(47), 0, 0, dp(18)); root.addView(start, startParams);

        TextView status = label("BRUM CORE · mGBA · " + launch.systemId.toUpperCase(), 9, ACCENT, true);
        FrameLayout.LayoutParams statusParams = frame(260, 28, Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL); statusParams.bottomMargin = dp(65); root.addView(status, statusParams);
        return root;
    }

    private void addPadButton(FrameLayout root, String text, int id, int gravity, int horizontal, int bottom) {
        Button button = gameButton(text, id);
        FrameLayout.LayoutParams params = frame(58, 58, gravity); params.setMargins(dp(horizontal), 0, dp(horizontal), dp(bottom)); root.addView(button, params);
    }

    private Button gameButton(String text, int id) {
        Button button = control(text); button.setTextSize(text.length() > 2 ? 9 : 20); button.setAlpha(.76f);
        button.setOnTouchListener((view, event) -> {
            if (event.getActionMasked() == MotionEvent.ACTION_DOWN) { emulatorView.setButton(id, true); view.setPressed(true); return true; }
            if (event.getActionMasked() == MotionEvent.ACTION_UP || event.getActionMasked() == MotionEvent.ACTION_CANCEL) { emulatorView.setButton(id, false); view.setPressed(false); return true; }
            return true;
        });
        return button;
    }

    private Button control(String value) {
        Button button = new Button(this); button.setText(value); button.setTextColor(Color.WHITE); button.setTextSize(10); button.setTypeface(Typeface.DEFAULT_BOLD);
        button.setAllCaps(false); button.setPadding(dp(8), 0, dp(8), 0); button.setBackground(controlBackground(false)); return button;
    }

    private GradientDrawable controlBackground(boolean active) {
        GradientDrawable drawable = new GradientDrawable(); drawable.setCornerRadius(dp(22));
        drawable.setColor(active ? ACCENT : Color.argb(188, 19, 21, 25)); drawable.setStroke(dp(1), active ? ACCENT : Color.argb(80, 255, 255, 255)); return drawable;
    }

    private void closeEmulator() {
        if (closing) return; closing = true;
        if (emulatorView != null) {
            emulatorView.pauseEmulation();
            try { SaveManifestStore.update(this, launch); } catch (Exception ignored) {}
        }
        Intent result = new Intent(); result.putExtra(RESULT_GAME_ID, launch.gameId);
        result.putExtra(RESULT_ELAPSED_SECONDS, emulatorView == null ? 0L : emulatorView.playedSeconds());
        setResult(RESULT_OK, result); finish();
    }

    private void showFailure(String message) {
        LinearLayout page = new LinearLayout(this); page.setOrientation(LinearLayout.VERTICAL); page.setGravity(Gravity.CENTER); page.setPadding(dp(30), dp(30), dp(30), dp(30)); page.setBackgroundColor(Color.BLACK);
        page.addView(label("NÃO FOI POSSÍVEL INICIAR", 20, Color.WHITE, true)); TextView detail = label(message, 13, Color.LTGRAY, false); detail.setGravity(Gravity.CENTER); page.addView(detail, new LinearLayout.LayoutParams(-1, dp(90)));
        Button back = control("VOLTAR"); back.setTextColor(Color.BLACK); back.setBackground(controlBackground(true)); back.setOnClickListener(v -> closeEmulator()); page.addView(back, new LinearLayout.LayoutParams(dp(280), dp(54)));
        setContentView(page);
    }

    private IntegratedEmulatorLaunch readLaunch(Intent intent) {
        return new IntegratedEmulatorLaunch(intent.getStringExtra("gameId"), intent.getStringExtra("title"), intent.getStringExtra("canonicalGameId"),
            intent.getStringExtra("systemId"), intent.getStringExtra("contentSha256"), intent.getStringExtra("coreId"),
            new File(intent.getStringExtra("romFile")), new File(intent.getStringExtra("saveFile")),
            new File(intent.getStringExtra("manifestFile")), new File(intent.getStringExtra("systemDirectory")));
    }

    private float axis(MotionEvent event, int preferred, int fallback) {
        float value = event.getAxisValue(preferred); return Math.abs(value) > .05f ? value : event.getAxisValue(fallback);
    }

    private TextView label(String value, int size, int color, boolean bold) {
        TextView view = new TextView(this); view.setText(value); view.setTextSize(size); view.setTextColor(color); if (bold) view.setTypeface(Typeface.DEFAULT_BOLD); return view;
    }

    private FrameLayout.LayoutParams frame(int width, int height, int gravity) { FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(dp(width), dp(height)); params.gravity = gravity; return params; }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }

    private void hideSystemUI() {
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            WindowInsetsController controller = getWindow().getInsetsController();
            if (controller != null) { controller.hide(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars()); controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE); }
        } else {
            getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        }
    }
}
