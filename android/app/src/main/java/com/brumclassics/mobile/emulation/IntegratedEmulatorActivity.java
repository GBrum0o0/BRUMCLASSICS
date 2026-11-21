package com.brumclassics.mobile.emulation;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ActivityInfo;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.hardware.input.InputManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public final class IntegratedEmulatorActivity extends Activity {
    public static final String RESULT_GAME_ID = "gameId";
    public static final String RESULT_ELAPSED_SECONDS = "elapsedSeconds";
    private static final int ACCENT = Color.rgb(157, 255, 59);
    private static final int[] CONTROLLER_KEYS = {
        KeyEvent.KEYCODE_BUTTON_B, KeyEvent.KEYCODE_BUTTON_Y, KeyEvent.KEYCODE_BUTTON_SELECT,
        KeyEvent.KEYCODE_BUTTON_START, KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN,
        KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT, KeyEvent.KEYCODE_BUTTON_A,
        KeyEvent.KEYCODE_BUTTON_X, KeyEvent.KEYCODE_BUTTON_L1, KeyEvent.KEYCODE_BUTTON_R1,
        KeyEvent.KEYCODE_BUTTON_L2, KeyEvent.KEYCODE_BUTTON_R2,
        KeyEvent.KEYCODE_BUTTON_THUMBL, KeyEvent.KEYCODE_BUTTON_THUMBR
    };

    private IntegratedEmulatorLaunch launch;
    private BrumCoreView emulatorView;
    private ParcelFileDescriptor romDescriptor;
    private boolean closing;
    private final List<View> padOverlayViews = new ArrayList<>();
    private VirtualDPadView dpadView;
    private VirtualAnalogView analogView;
    private Button controlsToggleButton;
    private Button padModeButton;
    private boolean manualControlsHidden;
    private boolean autoHideWithController;
    private boolean virtualHapticsEnabled = true;
    private boolean useAnalogStick;
    private int virtualPadPort;
    private final List<Integer> physicalDeviceIds = new ArrayList<>();
    private final InputManager.InputDeviceListener inputListener = new InputManager.InputDeviceListener() {
        @Override public void onInputDeviceAdded(int deviceId) { syncControllerOverlay(true); }
        @Override public void onInputDeviceChanged(int deviceId) { syncControllerOverlay(false); }
        @Override public void onInputDeviceRemoved(int deviceId) { syncControllerOverlay(true); }
    };

    public static Intent intent(Context context, IntegratedEmulatorLaunch launch) {
        return intent(context, launch, 0);
    }

    public static Intent intent(Context context, IntegratedEmulatorLaunch launch, int virtualPadPort) {
        Intent intent = new Intent(context, IntegratedEmulatorActivity.class);
        intent.putExtra("gameId", launch.gameId); intent.putExtra("title", launch.title);
        intent.putExtra("canonicalGameId", launch.canonicalGameId); intent.putExtra("systemId", launch.systemId);
        intent.putExtra("contentSha256", launch.contentSha256); intent.putExtra("coreId", launch.coreId);
        intent.putExtra("coreDisplayName", launch.coreDisplayName); intent.putExtra("coreVersion", launch.coreVersion);
        intent.putExtra("coreLibraryName", launch.coreLibraryName);
        intent.putExtra("raGameId", launch.retroAchievementsGameId);
        intent.putExtra("virtualPadPort", Math.max(0, Math.min(3, virtualPadPort)));
        intent.putExtra("romFile", launch.romFile == null ? "" : launch.romFile.getAbsolutePath()); intent.putExtra("romUri", launch.romUri); intent.putExtra("saveFile", launch.saveFile.getAbsolutePath());
        intent.putExtra("manifestFile", launch.manifestFile.getAbsolutePath()); intent.putExtra("systemDirectory", launch.systemDirectory.getAbsolutePath());
        return intent;
    }

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
        if (Build.VERSION.SDK_INT >= 28) {
            WindowManager.LayoutParams lp = getWindow().getAttributes();
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            getWindow().setAttributes(lp);
        }
        hideSystemUI();
        launch = readLaunch(getIntent());
        try {
            String corePath = getApplicationInfo().nativeLibraryDir + "/" + launch.coreLibraryName;
            if (!new File(corePath).isFile()) throw new IllegalStateException("O núcleo " + launch.coreDisplayName + " não está presente nesta instalação.");
            String romPath;
            if (launch.romFile != null) {
                romPath = launch.romFile.getAbsolutePath();
            } else {
                romDescriptor = getContentResolver().openFileDescriptor(android.net.Uri.parse(launch.romUri), "r");
                if (romDescriptor == null) throw new IllegalStateException("O Android não liberou o arquivo do jogo.");
                romPath = "/proc/self/fd/" + romDescriptor.getFd();
            }
            BrumCoreBridge bridge = new BrumCoreBridge(corePath, romPath, launch);
            emulatorView = new BrumCoreView(this, bridge, this::showRuntimeFailure);
            virtualPadPort = Math.max(0, Math.min(3, getIntent().getIntExtra("virtualPadPort", 0)));
            emulatorView.setVirtualPadPort(virtualPadPort);
            SharedPreferences prefs = getSharedPreferences("brum_mobile_prefs", MODE_PRIVATE);
            virtualHapticsEnabled = prefs.getBoolean("virtual_haptics", true);
            autoHideWithController = prefs.getBoolean("auto_hide_pad_with_controller", false);
            if (prefs.getBoolean("default_fill_display", false)) emulatorView.toggleFillDisplay();
            setContentView(buildInterface());
            syncControllerOverlay(false);
        } catch (Throwable error) {
            showFailure(error.getMessage() == null ? "O BRUM Core não conseguiu abrir este jogo." : error.getMessage());
        }
    }

    @Override protected void onResume() {
        super.onResume(); hideSystemUI();
        getSystemService(InputManager.class).registerInputDeviceListener(inputListener, new Handler(Looper.getMainLooper()));
        syncControllerOverlay(false);
        if (emulatorView != null) emulatorView.resumeEmulation();
    }

    @Override protected void onPause() {
        getSystemService(InputManager.class).unregisterInputDeviceListener(inputListener);
        if (emulatorView != null) {
            emulatorView.pauseEmulation();
            try { SaveManifestStore.update(this, launch); } catch (Exception ignored) {}
        }
        super.onPause();
    }

    @Override protected void onDestroy() {
        if (emulatorView != null) emulatorView.destroy();
        if (romDescriptor != null) { try { romDescriptor.close(); } catch (Exception ignored) {} romDescriptor = null; }
        super.onDestroy();
    }

    @Override public void onBackPressed() { closeEmulator(); }

    private int resolvePhysicalPort(int deviceId) {
        if (deviceId <= 0) return 0;
        int idx = physicalDeviceIds.indexOf(deviceId);
        if (idx < 0) {
            physicalDeviceIds.add(deviceId);
            idx = physicalDeviceIds.size() - 1;
        }
        return Math.max(0, Math.min(3, idx));
    }

    @Override public boolean dispatchKeyEvent(KeyEvent event) {
        if (emulatorView != null) {
            int port = resolvePhysicalPort(event.getDeviceId());
            for (int id = 0; id < CONTROLLER_KEYS.length; id++) if (event.getKeyCode() == CONTROLLER_KEYS[id]) {
                emulatorView.setPortButton(port, id, event.getAction() == KeyEvent.ACTION_DOWN);
                return true;
            }
        }
        return super.dispatchKeyEvent(event);
    }

    @Override public boolean dispatchGenericMotionEvent(MotionEvent event) {
        if (emulatorView != null && (event.getSource() & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK && event.getAction() == MotionEvent.ACTION_MOVE) {
            int port = resolvePhysicalPort(event.getDeviceId());
            float x = axis(event, MotionEvent.AXIS_HAT_X, MotionEvent.AXIS_X);
            float y = axis(event, MotionEvent.AXIS_HAT_Y, MotionEvent.AXIS_Y);
            emulatorView.setPortButton(port, 6, x < -0.45f); emulatorView.setPortButton(port, 7, x > 0.45f);
            emulatorView.setPortButton(port, 4, y < -0.45f); emulatorView.setPortButton(port, 5, y > 0.45f);
            emulatorView.setPortAnalog(port, 0, 0, clampAxis(event.getAxisValue(MotionEvent.AXIS_X)));
            emulatorView.setPortAnalog(port, 0, 1, clampAxis(event.getAxisValue(MotionEvent.AXIS_Y)));
            emulatorView.setPortAnalog(port, 1, 0, clampAxis(event.getAxisValue(MotionEvent.AXIS_Z)));
            emulatorView.setPortAnalog(port, 1, 1, clampAxis(event.getAxisValue(MotionEvent.AXIS_RZ)));
            emulatorView.setPortButton(port, 12, event.getAxisValue(MotionEvent.AXIS_LTRIGGER) > 0.25f);
            emulatorView.setPortButton(port, 13, event.getAxisValue(MotionEvent.AXIS_RTRIGGER) > 0.25f);
            return true;
        }
        return super.dispatchGenericMotionEvent(event);
    }

    private static float clampAxis(float value) {
        return Math.abs(value) < 0.08f ? 0f : Math.max(-1f, Math.min(1f, value));
    }

    private FrameLayout buildInterface() {
        padOverlayViews.clear();
        FrameLayout root = new FrameLayout(this); root.setBackgroundColor(Color.BLACK);
        root.addView(emulatorView, new FrameLayout.LayoutParams(-1, -1));

        Button exit = control("←  SAIR");
        exit.setOnClickListener(v -> closeEmulator());
        FrameLayout.LayoutParams exitParams = frame(104, 44, Gravity.TOP | Gravity.START); exitParams.setMargins(dp(14), dp(12), 0, 0); root.addView(exit, exitParams);

        TextView title = label(launch.title, 13, Color.WHITE, true); title.setSingleLine(true); title.setGravity(Gravity.CENTER);
        FrameLayout.LayoutParams titleParams = frame(240, 42, Gravity.TOP | Gravity.CENTER_HORIZONTAL); titleParams.topMargin = dp(13); root.addView(title, titleParams);

        LinearLayout tools = new LinearLayout(this); tools.setOrientation(LinearLayout.HORIZONTAL); tools.setGravity(Gravity.CENTER); tools.setPadding(0, 0, 0, 0);
        controlsToggleButton = control("PAD");
        Button states = control("SLOTS");
        Button display = control(emulatorView.fillsDisplay() ? "CORTAR" : "INTEIRA");
        Button fast = control("≫  5×");
        controlsToggleButton.setOnClickListener(v -> {
            manualControlsHidden = !manualControlsHidden;
            syncControllerOverlay(false);
        });
        states.setOnClickListener(v -> showStateMenu());
        display.setOnClickListener(v -> { emulatorView.toggleFillDisplay(); display.setText(emulatorView.fillsDisplay() ? "CORTAR" : "INTEIRA"); });
        fast.setOnClickListener(v -> { emulatorView.setFastForward(!emulatorView.isFastForward()); fast.setTextColor(emulatorView.isFastForward() ? Color.BLACK : Color.WHITE); fast.setBackground(controlBackground(emulatorView.isFastForward())); });
        tools.addView(controlsToggleButton, new LinearLayout.LayoutParams(dp(56), dp(44)));
        LinearLayout.LayoutParams stateParams = new LinearLayout.LayoutParams(dp(64), dp(44)); stateParams.leftMargin = dp(6); tools.addView(states, stateParams);
        LinearLayout.LayoutParams displayParams = new LinearLayout.LayoutParams(dp(86), dp(44)); displayParams.leftMargin = dp(6); tools.addView(display, displayParams);
        LinearLayout.LayoutParams fastParams = new LinearLayout.LayoutParams(dp(74), dp(44)); fastParams.leftMargin = dp(6); tools.addView(fast, fastParams);
        FrameLayout.LayoutParams toolsParams = frame(304, 44, Gravity.TOP | Gravity.END); toolsParams.setMargins(0, dp(12), dp(14), 0); root.addView(tools, toolsParams);

        String sys = launch.systemId == null ? "" : launch.systemId.toLowerCase(Locale.ROOT);
        boolean isAnalog = "ps2".equals(sys) || "psp".equals(sys);
        useAnalogStick = isAnalog;

        dpadView = new VirtualDPadView(this);
        FrameLayout.LayoutParams dpadParams = frame(152, 152, Gravity.BOTTOM | Gravity.START);
        dpadParams.setMargins(dp(20), 0, 0, dp(20));
        root.addView(dpadView, dpadParams);
        padOverlayViews.add(dpadView);

        if (isAnalog) {
            analogView = new VirtualAnalogView(this);
            FrameLayout.LayoutParams stickParams = frame(152, 152, Gravity.BOTTOM | Gravity.START);
            stickParams.setMargins(dp(20), 0, 0, dp(20));
            root.addView(analogView, stickParams);
            padOverlayViews.add(analogView);

            padModeButton = control("D-PAD");
            padModeButton.setOnClickListener(v -> toggleAnalogPadMode());
            FrameLayout.LayoutParams modeParams = frame(72, 34, Gravity.BOTTOM | Gravity.START);
            modeParams.setMargins(dp(20), 0, 0, dp(180));
            root.addView(padModeButton, modeParams);
            padOverlayViews.add(padModeButton);
            updateAnalogPadVisibility(false);
        }

        buildActionButtonsForSystem(root, sys);

        String raStatus = launch.retroAchievementsGameId > 0 ? " · RA ID " + launch.retroAchievementsGameId + " (PREPARAÇÃO)" : "";
        TextView status = label("BRUM CORE · " + launch.coreDisplayName + " · " + launch.systemId.toUpperCase(Locale.ROOT) + raStatus, 9, ACCENT, true);
        FrameLayout.LayoutParams statusParams = frame(260, 28, Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL); statusParams.bottomMargin = dp(65); root.addView(status, statusParams);
        return root;
    }

    private void buildActionButtonsForSystem(FrameLayout root, String sys) {
        boolean isTwoBtn = "gb".equals(sys) || "gbc".equals(sys) || "nes".equals(sys) || "pce".equals(sys)
            || "sms".equals(sys) || "gg".equals(sys) || "gba".equals(sys);
        boolean hasShoulders = !("gb".equals(sys) || "gbc".equals(sys) || "nes".equals(sys)
            || "pce".equals(sys) || "sms".equals(sys) || "gg".equals(sys) || "ws".equals(sys) || "wsc".equals(sys));
        if ("neogeo".equals(sys)) {
            addPadButton(root, "A", 0, Gravity.BOTTOM | Gravity.END, 198, 42);
            addPadButton(root, "B", 8, Gravity.BOTTOM | Gravity.END, 138, 42);
            addPadButton(root, "C", 1, Gravity.BOTTOM | Gravity.END, 78, 42);
            addPadButton(root, "D", 9, Gravity.BOTTOM | Gravity.END, 18, 42);
        } else if ("ws".equals(sys) || "wsc".equals(sys)) {
            addPadButton(root, "Y▲", 13, Gravity.BOTTOM | Gravity.END, 96, 152);
            addPadButton(root, "Y◀", 10, Gravity.BOTTOM | Gravity.END, 152, 98);
            addPadButton(root, "Y▶", 11, Gravity.BOTTOM | Gravity.END, 40, 98);
            addPadButton(root, "Y▼", 12, Gravity.BOTTOM | Gravity.END, 96, 44);
            addPadButton(root, "B", 0, Gravity.BOTTOM | Gravity.END, 152, 24);
            addPadButton(root, "A", 8, Gravity.BOTTOM | Gravity.END, 40, 24);
        } else if (isTwoBtn) {
            boolean sms = "sms".equals(sys) || "gg".equals(sys);
            boolean pce = "pce".equals(sys);
            addPadButton(root, pce ? "II" : sms ? "1" : "B", 0, Gravity.BOTTOM | Gravity.END, 118, 56);
            addPadButton(root, pce ? "I" : sms ? "2" : "A", 8, Gravity.BOTTOM | Gravity.END, 34, 88);
        } else {
            boolean ps = "ps2".equals(sys) || "psp".equals(sys);
            addPadButton(root, ps ? "×" : "B", 0, Gravity.BOTTOM | Gravity.END, 126, 36);
            addPadButton(root, ps ? "○" : "A", 8, Gravity.BOTTOM | Gravity.END, 34, 86);
            addPadButton(root, ps ? "□" : "Y", 1, Gravity.BOTTOM | Gravity.END, 184, 86);
            addPadButton(root, ps ? "△" : "X", 9, Gravity.BOTTOM | Gravity.END, 126, 138);
        }

        if (hasShoulders) {
            boolean ps = "ps2".equals(sys);
            addShoulderButton(root, ps ? "L1" : "L", 10, Gravity.TOP | Gravity.START, 16);
            addShoulderButton(root, ps ? "R1" : "R", 11, Gravity.TOP | Gravity.END, 16);
            if (ps) {
                addShoulderButton(root, "L2", 12, Gravity.TOP | Gravity.START, 92);
                addShoulderButton(root, "R2", 13, Gravity.TOP | Gravity.END, 92);
            }
        }

        if (!"sms".equals(sys) && !"gg".equals(sys)) {
            Button select = gameButton("ws".equals(sys) || "wsc".equals(sys) ? "GIRAR" : "SELECT", 2);
            FrameLayout.LayoutParams selectParams = frame(82, 40, Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
            selectParams.setMargins(0, 0, dp(47), dp(18));
            root.addView(select, selectParams);
            padOverlayViews.add(select);
        }
        Button start = gameButton("START", 3);
        FrameLayout.LayoutParams startParams = frame(82, 40, Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        startParams.setMargins("sms".equals(sys) || "gg".equals(sys) ? 0 : dp(47), 0, 0, dp(18));
        root.addView(start, startParams);
        padOverlayViews.add(start);
    }

    private void toggleAnalogPadMode() {
        useAnalogStick = !useAnalogStick;
        if (emulatorView != null) {
            emulatorView.setAnalog(0, 0, 0f);
            emulatorView.setAnalog(0, 1, 0f);
            for (int bit = 4; bit <= 7; bit++) emulatorView.setButton(bit, false);
        }
        if (padModeButton != null) padModeButton.setText(useAnalogStick ? "D-PAD" : "STICK");
        syncControllerOverlay(false);
    }

    private boolean hasPhysicalController() {
        InputManager manager = getSystemService(InputManager.class);
        if (manager == null) return false;
        physicalDeviceIds.clear();
        for (int id : manager.getInputDeviceIds()) {
            InputDevice device = manager.getInputDevice(id);
            if (device == null || device.isVirtual()) continue;
            if (Build.VERSION.SDK_INT >= 27 && !device.isEnabled()) continue;
            if (device.supportsSource(InputDevice.SOURCE_GAMEPAD) || device.supportsSource(InputDevice.SOURCE_JOYSTICK)) {
                physicalDeviceIds.add(id);
            }
        }
        return !physicalDeviceIds.isEmpty();
    }

    private void updateAnalogPadVisibility(boolean hidden) {
        if (analogView == null) {
            if (dpadView != null) dpadView.setVisibility(hidden ? View.GONE : View.VISIBLE);
            return;
        }
        analogView.setVisibility(!hidden && useAnalogStick ? View.VISIBLE : View.GONE);
        if (dpadView != null) dpadView.setVisibility(!hidden && !useAnalogStick ? View.VISIBLE : View.GONE);
        if (padModeButton != null) padModeButton.setVisibility(hidden ? View.GONE : View.VISIBLE);
    }

    private void syncControllerOverlay(boolean notify) {
        boolean hasPhysical = hasPhysicalController();
        boolean hidden = manualControlsHidden || (autoHideWithController && hasPhysical);
        for (View view : padOverlayViews) {
            view.setVisibility(hidden ? View.GONE : View.VISIBLE);
        }
        updateAnalogPadVisibility(hidden);
        if (hidden && emulatorView != null) {
            for (int id = 0; id < 16; id++) emulatorView.setButton(id, false);
            emulatorView.setAnalog(0, 0, 0f);
            emulatorView.setAnalog(0, 1, 0f);
        }
        if (controlsToggleButton != null) {
            controlsToggleButton.setTextColor(hidden ? Color.BLACK : (hasPhysical ? ACCENT : Color.WHITE));
            controlsToggleButton.setBackground(controlBackground(hidden));
        }
        if (notify) {
            Toast.makeText(this, hasPhysical ? "Controle físico conectado." : "Controle desconectado · modo tátil ativo.", Toast.LENGTH_SHORT).show();
        }
    }

    private void showStateMenu() {
        String[] choices = new String[6];
        for (int slot = 1; slot <= 3; slot++) {
            File state = launch.quickStateFile(slot);
            choices[(slot - 1) * 2] = "Salvar no slot " + slot;
            choices[(slot - 1) * 2 + 1] = "Carregar slot " + slot + (QuickStateStore.isCompatible(launch, slot, state) ? "" : " (vazio ou incompatível)");
        }
        new AlertDialog.Builder(this)
            .setTitle("ESTADOS RÁPIDOS")
            .setMessage("O save normal continua separado. Escolha um dos três slots locais.")
            .setItems(choices, (dialog, which) -> {
                int slot = which / 2 + 1;
                if ((which & 1) == 0) saveQuickState(slot); else loadQuickState(slot);
            })
            .setNegativeButton("Cancelar", null)
            .show();
    }

    private void saveQuickState(int slot) {
        File state = launch.quickStateFile(slot);
        if (!emulatorView.saveState(state.getAbsolutePath())) {
            Toast.makeText(this, "Não foi possível salvar o slot.", Toast.LENGTH_SHORT).show();
            return;
        }
        try { QuickStateStore.update(launch, slot, state); }
        catch (Exception error) {
            state.delete(); new File(state.getAbsolutePath() + ".json").delete();
            Toast.makeText(this, "Não foi possível concluir o slot.", Toast.LENGTH_SHORT).show(); return;
        }
        Toast.makeText(this, "Slot " + slot + " salvo.", Toast.LENGTH_SHORT).show();
    }

    private void loadQuickState(int slot) {
        File state = launch.quickStateFile(slot);
        if (!QuickStateStore.isCompatible(launch, slot, state)) { Toast.makeText(this, "O slot está vazio ou é incompatível.", Toast.LENGTH_SHORT).show(); return; }
        if (!emulatorView.loadState(state.getAbsolutePath())) { Toast.makeText(this, "Estado incompatível ou corrompido.", Toast.LENGTH_SHORT).show(); return; }
        Toast.makeText(this, "Slot " + slot + " carregado.", Toast.LENGTH_SHORT).show();
    }

    private void addPadButton(FrameLayout root, String text, int id, int gravity, int horizontal, int bottom) {
        Button button = gameButton(text, id);
        FrameLayout.LayoutParams params = frame(58, 58, gravity); params.setMargins(dp(horizontal), 0, dp(horizontal), dp(bottom)); root.addView(button, params);
        padOverlayViews.add(button);
    }

    private void addShoulderButton(FrameLayout root, String text, int id, int gravity, int horizontal) {
        Button button = gameButton(text, id);
        FrameLayout.LayoutParams params = frame(68, 42, gravity); params.setMargins(dp(horizontal), dp(66), dp(horizontal), 0); root.addView(button, params);
        padOverlayViews.add(button);
    }

    private Button gameButton(String text, int id) {
        Button button = control(text); button.setTextSize(text.length() > 2 ? 9 : 20); button.setAlpha(.76f);
        button.setOnTouchListener((view, event) -> {
            if (event.getActionMasked() == MotionEvent.ACTION_DOWN) {
                emulatorView.setButton(id, true);
                view.setPressed(true);
                if (virtualHapticsEnabled) view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
                return true;
            }
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

    private void showRuntimeFailure(String message) {
        if (isFinishing() || isDestroyed()) return;
        new AlertDialog.Builder(this)
            .setTitle("O JOGO FOI INTERROMPIDO")
            .setMessage(message + "\n\nO BRUM Core manteve esta tela aberta para mostrar a causa, em vez de fechar silenciosamente.")
            .setCancelable(false)
            .setPositiveButton("Voltar", (dialog, which) -> closeEmulator())
            .show();
    }

    private IntegratedEmulatorLaunch readLaunch(Intent intent) {
        return new IntegratedEmulatorLaunch(intent.getStringExtra("gameId"), intent.getStringExtra("title"), intent.getStringExtra("canonicalGameId"),
            intent.getStringExtra("systemId"), intent.getStringExtra("contentSha256"), intent.getStringExtra("coreId"),
            intent.getStringExtra("coreDisplayName"), intent.getStringExtra("coreVersion"), intent.getStringExtra("coreLibraryName"), intent.getIntExtra("raGameId", 0),
            intent.getStringExtra("romFile").isEmpty() ? null : new File(intent.getStringExtra("romFile")), intent.getStringExtra("romUri"), new File(intent.getStringExtra("saveFile")),
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
            getWindow().setDecorFitsSystemWindows(false);
            WindowInsetsController controller = getWindow().getInsetsController();
            if (controller != null) { controller.hide(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars()); controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE); }
        } else {
            getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        }
    }

    private final class VirtualDPadView extends View {
        private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint cross = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint arrow = new Paint(Paint.ANTI_ALIAS_FLAG);
        private int mask;

        VirtualDPadView(Context context) {
            super(context);
            cross.setColor(Color.argb(30, 255, 255, 255));
            arrow.setTextAlign(Paint.Align.CENTER);
            arrow.setTypeface(Typeface.DEFAULT_BOLD);
        }

        @Override protected void onDraw(Canvas canvas) {
            float cx = getWidth() / 2f, cy = getHeight() / 2f;
            float r = Math.min(cx, cy) - dp(2);
            fill.setStyle(Paint.Style.FILL);
            fill.setColor(Color.argb(210, 20, 23, 29));
            canvas.drawCircle(cx, cy, r, fill);
            fill.setStyle(Paint.Style.STROKE);
            fill.setStrokeWidth(dp(2));
            fill.setColor(Color.argb(80, 255, 255, 255));
            canvas.drawCircle(cx, cy, r, fill);
            float armLong = r * 0.72f, armHalf = dp(16);
            canvas.drawRoundRect(cx - armLong, cy - armHalf, cx + armLong, cy + armHalf, dp(6), dp(6), cross);
            canvas.drawRoundRect(cx - armHalf, cy - armLong, cx + armHalf, cy + armLong, dp(6), dp(6), cross);
            arrow.setTextSize(dp(18));
            drawDir(canvas, 1, "▲", cx, cy - r * 0.54f + dp(6));
            drawDir(canvas, 2, "▼", cx, cy + r * 0.54f + dp(6));
            drawDir(canvas, 4, "◀", cx - r * 0.54f, cy + dp(6));
            drawDir(canvas, 8, "▶", cx + r * 0.54f, cy + dp(6));
        }

        private void drawDir(Canvas canvas, int bit, String symbol, float x, float y) {
            arrow.setColor((mask & bit) != 0 ? ACCENT : Color.WHITE);
            canvas.drawText(symbol, x, y, arrow);
        }

        @Override public boolean onTouchEvent(MotionEvent event) {
            int action = event.getActionMasked();
            if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) {
                applyMask(0);
                return true;
            }
            float dx = event.getX() - getWidth() / 2f;
            float dy = event.getY() - getHeight() / 2f;
            float threshold = (Math.min(getWidth(), getHeight()) / 2f) * 0.18f;
            int next = 0;
            if (dy < -threshold) next |= 1;
            if (dy > threshold) next |= 2;
            if (dx < -threshold) next |= 4;
            if (dx > threshold) next |= 8;
            if (action == MotionEvent.ACTION_DOWN && next != 0 && virtualHapticsEnabled) {
                performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
            }
            applyMask(next);
            return true;
        }

        private void applyMask(int next) {
            if (mask == next) return;
            mask = next;
            if (emulatorView != null) {
                emulatorView.setButton(4, (mask & 1) != 0);
                emulatorView.setButton(5, (mask & 2) != 0);
                emulatorView.setButton(6, (mask & 4) != 0);
                emulatorView.setButton(7, (mask & 8) != 0);
            }
            invalidate();
        }
    }

    private final class VirtualAnalogView extends View {
        private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint ring = new Paint(Paint.ANTI_ALIAS_FLAG);
        private float nx, ny;

        VirtualAnalogView(Context context) {
            super(context);
            ring.setStyle(Paint.Style.STROKE);
            ring.setStrokeWidth(dp(2));
            ring.setColor(Color.argb(80, 255, 255, 255));
        }

        @Override protected void onDraw(Canvas canvas) {
            float cx = getWidth() / 2f, cy = getHeight() / 2f;
            float r = Math.min(cx, cy) - dp(2);
            fill.setColor(Color.argb(210, 20, 23, 29));
            canvas.drawCircle(cx, cy, r, fill);
            canvas.drawCircle(cx, cy, r, ring);
            float knobR = dp(22);
            float travel = Math.max(1f, r - knobR - dp(4));
            fill.setColor(Color.argb(235, 157, 255, 59));
            canvas.drawCircle(cx + nx * travel, cy + ny * travel, knobR, fill);
        }

        @Override public boolean onTouchEvent(MotionEvent event) {
            int action = event.getActionMasked();
            if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) {
                nx = 0f; ny = 0f;
                if (emulatorView != null) { emulatorView.setAnalog(0, 0, 0f); emulatorView.setAnalog(0, 1, 0f); }
                invalidate();
                return true;
            }
            float cx = getWidth() / 2f, cy = getHeight() / 2f;
            float travel = Math.max(1f, Math.min(cx, cy) - dp(26));
            float dx = (event.getX() - cx) / travel;
            float dy = (event.getY() - cy) / travel;
            float mag = (float) Math.hypot(dx, dy);
            nx = mag > 1f ? dx / mag : dx;
            ny = mag > 1f ? dy / mag : dy;
            if (emulatorView != null) {
                emulatorView.setAnalog(0, 0, nx);
                emulatorView.setAnalog(0, 1, ny);
            }
            invalidate();
            return true;
        }
    }
}
