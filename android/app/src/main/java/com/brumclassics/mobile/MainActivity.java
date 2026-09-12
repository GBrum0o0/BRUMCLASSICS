package com.brumclassics.mobile;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ClipData;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.text.Editable;
import android.text.InputType;
import android.text.InputFilter;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.window.OnBackInvokedDispatcher;
import android.view.animation.DecelerateInterpolator;
import android.widget.Button;
import android.widget.BaseAdapter;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.GridLayout;
import android.widget.GridView;
import android.widget.HorizontalScrollView;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.Space;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import com.brumclassics.mobile.data.GameRepository;
import com.brumclassics.mobile.data.HomeLibrary;
import com.brumclassics.mobile.data.BCardLibrary;
import com.brumclassics.mobile.data.MomentRepository;
import com.brumclassics.mobile.model.Game;
import com.brumclassics.mobile.model.Moment;
import com.brumclassics.mobile.model.PerformanceLiveState;
import com.brumclassics.mobile.classics.ClassicsRepository;
import com.brumclassics.mobile.classics.ClassicsRules;
import com.brumclassics.mobile.classics.LocalClassic;
import com.brumclassics.mobile.classics.LocalArtworkClient;
import com.brumclassics.mobile.classics.RetroAchievementsClient;
import com.brumclassics.mobile.sync.BridgeClient;
import com.brumclassics.mobile.update.MobileUpdateManager;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.HashMap;
import java.util.Map;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private static final int REQUEST_ROM_TREE = 7301;
    private static final int REQUEST_RUNTIME_TREE = 7302;
    private static final int BG = Color.rgb(9, 10, 12);
    private static final int SURFACE = Color.rgb(17, 19, 23);
    private static final int RAISED = Color.rgb(23, 26, 31);
    private static final int TEXT = Color.rgb(245, 246, 248);
    private static final int MUTED = Color.rgb(117, 123, 134);
    private static final int LINE = Color.argb(24, 255, 255, 255);
    private static final int ACCENT = Color.rgb(157, 255, 59);

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final ExecutorService modelExecutor = Executors.newSingleThreadExecutor();
    private final List<Button> navButtons = new ArrayList<>();
    private FrameLayout content;
    private GameRepository repository;
    private MomentRepository momentRepository;
    private ClassicsRepository classicsRepository;
    private RetroAchievementsClient retroAchievements;
    private LocalArtworkClient localArtwork;
    private List<Game> games = new ArrayList<>();
    private String currentScreen = "home";
    private String detailsReturnScreen = "library";
    private String currentGameId = "";
    private String bCardGameId = "";
    private String bCardCategory = "modern";
    private String currentClassicId = "";
    private boolean launchingClassic;
    private String syncState = "offline";
    private String syncDetail = "Dados locais";
    private BridgeClient bridgeClient;
    private MobileUpdateManager updateManager;
    private MobileUpdateManager.UpdateInfo mobileUpdate;
    private String mobileUpdateState = "idle";
    private String mobileUpdateDetail = "Verifique se existe uma versão móvel mais recente.";
    private int mobileUpdatePercent = 0;
    private String query = "";
    private String platformFilter = "TODAS";
    private String genreFilter = "TODOS";
    private String statusFilter = "TODOS";
    private String progressFilter = "TODOS";
    private boolean favoriteOnly = false;
    private org.json.JSONObject lifeHub = new org.json.JSONObject();
    private org.json.JSONObject sessionStatus = new org.json.JSONObject();
    private org.json.JSONObject companion = new org.json.JSONObject();
    private org.json.JSONObject performance = new org.json.JSONObject();
    private org.json.JSONObject notificationSnapshot = new org.json.JSONObject();
    private final Map<String, TextView> performanceValues = new HashMap<>();
    private final PerformanceLiveState performanceLive = new PerformanceLiveState();
    private LinearLayout performancePanel;
    private final Runnable performanceExpiry = new Runnable() {
        @Override public void run() {
            if ("companion".equals(currentScreen)) refreshPerformanceValues();
            handler.postDelayed(this, 1000);
        }
    };
    private org.json.JSONObject experience = new org.json.JSONObject();
    private long lastRootBackAt = 0L;

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Window window = getWindow();
        window.setStatusBarColor(BG);
        window.setNavigationBarColor(BG);
        window.getDecorView().setSystemUiVisibility(0);
        repository = new GameRepository(this);
        momentRepository = new MomentRepository(this);
        classicsRepository = new ClassicsRepository(this);
        retroAchievements = new RetroAchievementsClient();
        localArtwork = new LocalArtworkClient(this);
        bridgeClient = new BridgeClient(this, new BridgeClient.Listener() {
            @Override public void onStatus(String state, String detail) {
                syncState = state; syncDetail = detail;
                if ("offline".equals(state) || "connecting".equals(state)) performanceLive.disconnect();
                if ("companion".equals(currentScreen)) refreshPerformanceValues();
                if ("profile".equals(currentScreen)) showProfile();
            }
            @Override public void onSnapshot(String rawJson) {
                modelExecutor.execute(() -> {
                    try {
                        org.json.JSONObject snapshot = new org.json.JSONObject(rawJson);
                        org.json.JSONObject nextLifeHub = snapshot.optJSONObject("lifeHub") == null ? new org.json.JSONObject() : snapshot.optJSONObject("lifeHub");
                        org.json.JSONObject nextSessionStatus = snapshot.optJSONObject("sessionStatus") == null ? new org.json.JSONObject() : snapshot.optJSONObject("sessionStatus");
                        org.json.JSONObject nextCompanion = snapshot.optJSONObject("companion") == null ? new org.json.JSONObject() : snapshot.optJSONObject("companion");
                        org.json.JSONObject nextPerformance = snapshot.optJSONObject("performance") == null ? new org.json.JSONObject() : snapshot.optJSONObject("performance");
                        org.json.JSONObject nextNotifications = snapshot.optJSONObject("notifications") == null ? new org.json.JSONObject() : snapshot.optJSONObject("notifications");
                        org.json.JSONObject nextExperience = snapshot.optJSONObject("experience") == null ? new org.json.JSONObject() : snapshot.optJSONObject("experience");
                        repository.replaceFromSnapshot(rawJson);
                        List<Game> nextGames = repository.all();
                        handler.post(() -> {
                            lifeHub = nextLifeHub;
                            sessionStatus = nextSessionStatus;
                            companion = nextCompanion;
                            performance = nextPerformance;
                            notificationSnapshot = nextNotifications;
                            performanceLive.accept(performance.optBoolean("active"), performance.optString("gameId", ""), SystemClock.elapsedRealtime());
                            experience = nextExperience;
                            games = nextGames;
                            refreshCurrentScreen();
                            bridgeClient.prefetchArtwork(games);
                            updateManager.check(false);
                        });
                    } catch (Exception error) {
                        handler.post(() -> onError("A biblioteca recebida não pôde ser processada; o cache anterior foi preservado."));
                    }
                });
            }
            @Override public void onEvent(String type, org.json.JSONObject payload) {
                if ("achievement_unlocked".equals(type)) {
                    org.json.JSONObject achievement = payload.optJSONObject("achievement");
                    Toast.makeText(MainActivity.this, achievement == null ? "Nova conquista sincronizada" : "Conquista: " + achievement.optString("title", "Desbloqueada"), Toast.LENGTH_LONG).show();
                } else if ("install_changed".equals(type)) {
                    org.json.JSONObject update = payload.optJSONObject("update");
                    syncDetail = update == null ? "Download atualizado" : "Download · " + Math.round(update.optDouble("percent", 0)) + "% · " + update.optString("state", "em andamento");
                    if ("companion".equals(currentScreen)) showCompanion();
                } else if ("session_completed".equals(type)) {
                    org.json.JSONObject session = payload.optJSONObject("session");
                    syncDetail = session == null ? "Sessão concluída" : "Sessão concluída · " + session.optString("gameTitle", "jogo");
                    if ("companion".equals(currentScreen)) showCompanion();
                } else if ("companion_changed".equals(type)) {
                    syncDetail = "Identificando jogo ativo...";
                    if ("companion".equals(currentScreen)) showCompanion();
                } else if ("performance_changed".equals(type)) {
                    org.json.JSONObject next = payload.optJSONObject("performance");
                    if (next != null) performance = next;
                    performanceLive.accept(performance.optBoolean("active"), performance.optString("gameId", ""), SystemClock.elapsedRealtime());
                    if ("companion".equals(currentScreen)) refreshPerformanceValues();
                } else if ("performance_alert".equals(type)) {
                    org.json.JSONObject alert = payload.optJSONObject("alert");
                    if (alert != null && "GPU_TEMPERATURE_HIGH".equals(alert.optString("code")))
                        Toast.makeText(MainActivity.this, "GPU em " + Math.round(alert.optDouble("temperatureC")) + " °C", Toast.LENGTH_LONG).show();
                }
            }
            @Override public void onError(String safeMessage) {
                Toast.makeText(MainActivity.this, safeMessage, Toast.LENGTH_LONG).show();
            }
        });
        updateManager = new MobileUpdateManager(this, new MobileUpdateManager.Listener() {
            @Override public void onStatus(String state, String detail, int percent) {
                handler.post(() -> {
                    mobileUpdateState = state; mobileUpdateDetail = detail; mobileUpdatePercent = percent;
                    if ("profile".equals(currentScreen)) showProfile();
                });
            }
            @Override public void onAvailable(MobileUpdateManager.UpdateInfo update) {
                handler.post(() -> {
                    mobileUpdate = update; mobileUpdateState = "available";
                    mobileUpdateDetail = "Versão " + update.version + " disponível pelo " + ("github".equals(update.source) ? "GitHub" : "launcher local") + ".";
                    String announced = getSharedPreferences("brum_mobile_updates", MODE_PRIVATE).getString("announced_version", "");
                    if (!update.version.equals(announced)) {
                        getSharedPreferences("brum_mobile_updates", MODE_PRIVATE).edit().putString("announced_version", update.version).apply();
                        Toast.makeText(MainActivity.this, "BRUMCLASSICS MOVEL " + update.version + " disponível em Perfil.", Toast.LENGTH_LONG).show();
                    }
                    if ("profile".equals(currentScreen)) showProfile();
                });
            }
            @Override public void onCurrent() {
                handler.post(() -> {
                    mobileUpdate = null; mobileUpdateState = "current"; mobileUpdateDetail = "Você já possui a versão móvel mais recente."; mobileUpdatePercent = 0;
                    if ("profile".equals(currentScreen)) showProfile();
                });
            }
            @Override public void onError(String safeMessage) {
                handler.post(() -> {
                    mobileUpdateState = "error"; mobileUpdateDetail = safeMessage; mobileUpdatePercent = 0;
                    if ("profile".equals(currentScreen)) showProfile();
                    Toast.makeText(MainActivity.this, safeMessage, Toast.LENGTH_LONG).show();
                });
            }
        });
        if (Build.VERSION.SDK_INT >= 33) {
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                this::handleBackNavigation
            );
        }
        setContentView(buildShell());
        showLoading();
        modelExecutor.execute(() -> {
            try {
                String cached = bridgeClient.cachedSnapshot();
                if (!cached.isEmpty()) repository.replaceFromSnapshot(cached);
                List<Game> loadedGames = repository.all();
                handler.post(() -> {
                    games = loadedGames;
                    List<Game> startupArtwork = startupArtworkGames();
                    bridgeClient.warmArtwork(startupArtwork, 4, () -> {
                        showHome();
                        if (bridgeClient.isConfigured()) { bridgeClient.fetchSnapshot(); bridgeClient.startRealtime(); }
                        handlePairingIntent(getIntent());
                        handler.postDelayed(() -> updateManager.check(false), 1200);
                    });
                });
            } catch (Exception error) {
                handler.post(() -> showError("Não foi possível abrir a biblioteca local."));
            }
        });
    }

    @Override protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handlePairingIntent(intent);
    }

    @Override protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if ((requestCode != REQUEST_ROM_TREE && requestCode != REQUEST_RUNTIME_TREE) || resultCode != RESULT_OK || data == null || data.getData() == null) return;
        Uri tree = data.getData();
        modelExecutor.execute(() -> {
            try {
                if (requestCode == REQUEST_ROM_TREE) classicsRepository.configureRomTree(tree);
                else classicsRepository.configureRuntimeTree(tree);
                handler.post(() -> {
                    Toast.makeText(this, requestCode == REQUEST_ROM_TREE ? "Pasta de ROMs autorizada." : "Pasta de logs autorizada.", Toast.LENGTH_LONG).show();
                    if (requestCode == REQUEST_ROM_TREE) showClassics(); else showClassicSettings();
                });
            } catch (Exception error) { handler.post(() -> Toast.makeText(this, error.getMessage(), Toast.LENGTH_LONG).show()); }
        });
    }

    @Override protected void onDestroy() {
        handler.removeCallbacks(performanceExpiry);
        bridgeClient.close();
        updateManager.close();
        retroAchievements.close();
        localArtwork.close();
        modelExecutor.shutdownNow();
        super.onDestroy();
    }

    @Override protected void onResume() {
        super.onResume();
        handler.removeCallbacks(performanceExpiry);
        handler.post(performanceExpiry);
        if (updateManager != null) updateManager.resumeInstallIfReady();
        handler.postDelayed(this::syncAllClassicsIfDue, 700);
        if (classicsRepository != null) modelExecutor.execute(() -> {
            try {
                ClassicsRepository.SessionResult result = classicsRepository.finishReturnedSession();
                if (result != null) handler.post(() -> {
                    launchingClassic = false;
                    LocalClassic game = classicsRepository.find(result.gameId);
                    if (game != null) {
                        Toast.makeText(this, "Sessão concluída · " + Math.max(0, result.addedSeconds / 60) + " min · " + result.source, Toast.LENGTH_LONG).show();
                        getSharedPreferences("brum_classics_android", MODE_PRIVATE).edit().putLong("last_auto_sync", System.currentTimeMillis()).apply();
                        syncClassic(game, false);
                    }
                    refreshCurrentScreen();
                });
            } catch (Exception error) { handler.post(() -> Toast.makeText(this, error.getMessage(), Toast.LENGTH_LONG).show()); }
        });
    }

    @Override protected void onPause() {
        handler.removeCallbacks(performanceExpiry);
        if (launchingClassic && classicsRepository != null) classicsRepository.markSessionBackgrounded();
        super.onPause();
    }

    private void refreshCurrentScreen() {
        if ("library".equals(currentScreen)) showLibrary();
        else if ("stats".equals(currentScreen)) showStats();
        else if ("companion".equals(currentScreen)) showCompanion();
        else if ("moments".equals(currentScreen)) showMoments();
        else if ("bcard-list".equals(currentScreen)) showBCardLibrary();
        else if ("classics".equals(currentScreen)) showClassics();
        else if ("classic-details".equals(currentScreen)) {
            LocalClassic classic = classicsRepository.find(currentClassicId);
            if (classic != null) showClassicDetails(classic); else showClassics();
        }
        else if ("classic-settings".equals(currentScreen)) showClassicSettings();
        else if ("notifications".equals(currentScreen)) showNotifications();
        else if ("bcard".equals(currentScreen)) {
            for (Game game : games) if (game.id.equals(bCardGameId)) { showBCard(game); return; }
            showBCardLibrary();
        }
        else if ("profile".equals(currentScreen)) showProfile();
        else if ("details".equals(currentScreen)) {
            for (Game game : games) if (game.id.equals(currentGameId)) { showDetails(game); return; }
            showLibrary();
        } else showHome();
    }

    private View buildShell() {
        LinearLayout shell = column();
        shell.setBackgroundColor(BG);
        shell.setFitsSystemWindows(true);

        content = new FrameLayout(this);
        content.setLayoutParams(new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        shell.addView(content);

        LinearLayout nav = row();
        nav.setGravity(Gravity.CENTER);
        nav.setPadding(dp(8), dp(7), dp(8), dp(9));
        nav.setBackground(background(SURFACE, 0, LINE, 1));
        nav.addView(navButton("INÍCIO", "home"));
        nav.addView(navButton("BIBLIOTECA", "library"));
        nav.addView(navButton("ESTATÍSTICAS", "stats"));
        nav.addView(navButton("COMPANION", "companion"));
        nav.addView(navButton("PERFIL", "profile"));
        shell.addView(nav, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(64)));
        return shell;
    }

    private Button navButton(String label, String screen) {
        Button button = button(label);
        button.setTextSize(8);
        button.setLetterSpacing(.11f);
        button.setTextColor(MUTED);
        button.setBackgroundColor(Color.TRANSPARENT);
        button.setPadding(dp(4), 0, dp(4), 0);
        button.setOnClickListener(v -> navigate(screen));
        navButtons.add(button);
        button.setTag(screen);
        button.setLayoutParams(new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1));
        return button;
    }

    private void navigate(String screen) {
        if ("home".equals(screen)) showHome();
        else if ("library".equals(screen)) showLibrary();
        else if ("stats".equals(screen)) showStats();
        else if ("companion".equals(screen)) showCompanion();
        else if ("moments".equals(screen)) showMoments();
        else if ("classics".equals(screen)) showClassics();
        else showProfile();
    }

    private org.json.JSONObject json(String key, Object value) {
        org.json.JSONObject object = new org.json.JSONObject();
        try { object.put(key, value); } catch (Exception ignored) { }
        return object;
    }

    private void showCompanion() {
        performanceValues.clear();
        performancePanel = null;
        ScrollView scroll = scroll(); LinearLayout page = page(); scroll.addView(page);
        page.addView(brandHeader("BRUMCOMPANION"));
        page.addView(text("Sua segunda tela.", 28, TEXT, true), margins(-1, 28, -1, 7));
        page.addView(text("Consulte e atualize suas anotações sem interromper o jogo.", 11, MUTED, false));
        if (!bridgeClient.isConfigured()) {
            page.addView(text("Conecte este celular em PERFIL para identificar o jogo ativo.", 12, ACCENT, true), margins(-1, 34, -1, 0));
            page.addView(text("As anotações já armazenadas continuam disponíveis na Biblioteca.", 10, MUTED, false), margins(-1, 8, -1, 0));
            setScreen("companion", scroll); return;
        }
        TextView liveStatus = text("●  " + syncDetail.toUpperCase(Locale.ROOT), 8, "connected".equals(syncState) ? ACCENT : MUTED, true);
        liveStatus.setLetterSpacing(.1f); page.addView(liveStatus, margins(-1, 22, -1, 16));

        String activeGameId = companion.optString("gameId", "");
        Game activeGame = null;
        for (Game candidate : games) if (candidate.id.equals(activeGameId)) { activeGame = candidate; break; }
        boolean activeWithoutNotes = companion.optBoolean("active", false) && activeGame != null && !bridgeClient.hasCompanionNotes(activeGame);
        // Reserve a container even before the first sample; events only update it,
        // so a session can begin without rebuilding the user's note editor.
        performancePanel = column();
        page.addView(performancePanel);
        addPerformancePanel(performancePanel);
        if (!companion.optBoolean("active", false) || activeGame == null || activeWithoutNotes) {
            LinearLayout idle = column(); idle.setPadding(dp(18), dp(20), dp(18), dp(20)); idle.setBackground(background(SURFACE, 4, LINE, 1));
            idle.addView(text(activeWithoutNotes ? "NENHUMA ANOTAÇÃO PARA EXIBIR" : "AGUARDANDO UMA SESSÃO", 8, MUTED, true));
            idle.addView(text(activeWithoutNotes ? "O jogo continua oculto; o desempenho permanece disponível." : "Abra um jogo pelo BRUMCLASSICS OFICIAL.", 17, TEXT, true), margins(-1, 9, -1, 0));
            idle.addView(text(activeWithoutNotes ? "Sem Onde parei, Objetivos, Dicas ou Comandos, o título não aparece aqui. O painel acima mostra apenas as métricas do computador." : "Assim que um jogo com anotações for detectado, o conteúdo aparecerá aqui automaticamente.", 10, MUTED, false), margins(-1, 8, -1, 0));
            page.addView(idle);
            int pending = bridgeClient.pendingCompanionNotes();
            if (pending > 0) page.addView(text(pending + " rascunho(s) aguardando sincronização.", 9, ACCENT, true), margins(-1, 14, -1, 0));
            page.addView(sectionHeading("ANOTAÇÕES RECENTES", "", null), margins(-1, 34, -1, 12));
            int shown = 0;
            for (Game game : games) {
                if (shown >= 4 || !bridgeClient.hasCompanionNotes(game)) continue;
                LinearLayout row = row(); row.setGravity(Gravity.CENTER_VERTICAL); row.setPadding(dp(12), dp(10), dp(12), dp(10)); row.setBackground(background(SURFACE, 3, LINE, 1));
                LinearLayout copy = column(); copy.addView(text(game.title, 11, TEXT, true)); copy.addView(text("Disponível offline", 7, MUTED, true), margins(-1, 3, -1, 0)); row.addView(copy, new LinearLayout.LayoutParams(0, -2, 1));
                Button open = button("ABRIR"); open.setTextSize(8); open.setTextColor(ACCENT); open.setBackgroundColor(Color.TRANSPARENT); open.setOnClickListener(v -> showDetails(game)); row.addView(open, new LinearLayout.LayoutParams(dp(70), dp(38)));
                page.addView(row, margins(-1, 5, -1, 0)); shown++;
            }
            if (shown == 0) page.addView(text("Nenhuma anotação criada ainda.", 10, MUTED, false));
            Button gallery = primaryButton("ABRIR BRUMMOMENTS");
            gallery.setOnClickListener(v -> showMoments()); page.addView(gallery, margins(-1, 20, -1, 0, 48));
            page.addView(space(30)); setScreen("companion", scroll); return;
        }

        final Game game = activeGame;
        LinearLayout hero = row(); hero.setGravity(Gravity.CENTER_VERTICAL); hero.setPadding(dp(12), dp(12), dp(12), dp(12)); hero.setBackground(background(SURFACE, 4, ACCENT, 1));
        hero.addView(cover(game, 78, 108), new LinearLayout.LayoutParams(dp(78), dp(108)));
        LinearLayout heroCopy = column(); heroCopy.addView(eyebrow("● JOGO ATIVO")); heroCopy.addView(text(game.title, 18, TEXT, true), margins(-1, 7, -1, 0)); heroCopy.addView(text(game.platform + (game.genre.isEmpty() ? "" : " · " + game.genre), 9, MUTED, false), margins(-1, 5, -1, 0)); hero.addView(heroCopy, weightedMargins(14, 0, 0, 0));
        page.addView(hero);

        LinearLayout momentActions = row();
        Button capture = primaryButton("CAPTURAR MOMENTO");
        capture.setOnClickListener(v -> captureMoment(game, capture));
        momentActions.addView(capture, weightedMargins(0, 0, 5, 0));
        Button gallery = button("GALERIA"); gallery.setTextSize(8); gallery.setTextColor(ACCENT); gallery.setBackground(background(SURFACE, 3, ACCENT, 1));
        gallery.setOnClickListener(v -> showMoments()); momentActions.addView(gallery, weightedMargins(5, 0, 0, 0));
        page.addView(momentActions, margins(-1, 12, -1, 6, 48));

        org.json.JSONObject notes = bridgeClient.companionNotes(game);
        boolean pending = notes.optBoolean("pending", false);
        boolean conflict = notes.optBoolean("conflict", false);
        String noteState = conflict ? "CONFLITO · ESCOLHA QUAL VERSÃO MANTER" : pending ? "SALVO NO CELULAR · SINCRONIZAÇÃO PENDENTE" : "SINCRONIZADO COM O LAUNCHER";
        page.addView(text(noteState, 8, conflict ? Color.rgb(255, 184, 77) : pending ? MUTED : ACCENT, true), margins(-1, 18, -1, 8));

        EditText whereStopped = companionEditor("ONDE PAREI", notes.optString("whereStopped", ""), "Ex.: antes do chefe, na entrada da cidade...");
        EditText objectives = companionEditor("OBJETIVOS", notes.optString("objectives", ""), "Missões, itens e próximos passos...");
        EditText tips = companionEditor("DICAS", notes.optString("tips", ""), "Estratégias e lembretes pessoais...");
        EditText commands = companionEditor("COMANDOS", notes.optString("commands", ""), "Atalhos, combinações e controles...");
        page.addView(companionField("ONDE PAREI", whereStopped), margins(-1, 8, -1, 0));
        page.addView(companionField("OBJETIVOS", objectives), margins(-1, 8, -1, 0));
        page.addView(companionField("DICAS", tips), margins(-1, 8, -1, 0));
        page.addView(companionField("COMANDOS", commands), margins(-1, 8, -1, 0));
        TextView saveState = text("Cada campo aceita até 6.000 caracteres.", 8, MUTED, false);
        page.addView(saveState, margins(-1, 10, -1, 8));
        Button save = primaryButton("SALVAR NO BRUMCOMPANION");
        save.setOnClickListener(v -> saveCompanionDraft(game, whereStopped, objectives, tips, commands, false, saveState));
        page.addView(save, new LinearLayout.LayoutParams(-1, dp(50)));
        if (conflict) {
            Button resolve = button("RESOLVER CONFLITO"); resolve.setTextSize(8); resolve.setTextColor(Color.rgb(255, 184, 77)); resolve.setBackground(background(SURFACE, 3, Color.rgb(255, 184, 77), 1));
            resolve.setOnClickListener(v -> showCompanionConflict(game, whereStopped, objectives, tips, commands, saveState));
            page.addView(resolve, margins(-1, 8, -1, 0, 48));
        }
        page.addView(space(34)); setScreen("companion", scroll);
    }

    private void addPerformancePanel(LinearLayout page) {
        boolean detailed = getSharedPreferences("brum_companion", MODE_PRIVATE).getBoolean("performance_detailed", false);
        page.addView(sectionHeading("DESEMPENHO AO VIVO", detailed ? "VISÃO SIMPLES" : "VER DETALHES", v -> {
            getSharedPreferences("brum_companion", MODE_PRIVATE).edit().putBoolean("performance_detailed", !detailed).apply(); showCompanion();
        }), margins(-1, 8, -1, 10));
        LinearLayout first = row();
        first.addView(performanceMetricCard("cpu", "CPU"), weightedMargins(0, 0, 5, 0));
        first.addView(performanceMetricCard("gpuTemp", "TEMP. GPU"), weightedMargins(5, 0, 0, 0));
        page.addView(first);
        LinearLayout second = row();
        second.addView(performanceMetricCard("gpu", "USO GPU"), weightedMargins(0, 8, 5, 0));
        second.addView(performanceMetricCard("fps", "FPS"), weightedMargins(5, 8, 0, 0));
        page.addView(second);
        if (detailed) {
            LinearLayout third = row();
            third.addView(performanceMetricCard("ram", "RAM"), weightedMargins(0, 8, 5, 0));
            third.addView(performanceMetricCard("vram", "VRAM"), weightedMargins(5, 8, 0, 0));
            page.addView(third);
            LinearLayout fourth = row();
            fourth.addView(performanceMetricCard("gameCpu", "CPU DO JOGO"), weightedMargins(0, 8, 5, 0));
            fourth.addView(performanceMetricCard("gameRam", "RAM DO JOGO"), weightedMargins(5, 8, 0, 0));
            page.addView(fourth);
            org.json.JSONObject cpu = performance.optJSONObject("cpu"); org.json.JSONObject gpu = performance.optJSONObject("gpu");
            String detail = "CPU TEMP. · " + (cpu != null && !cpu.isNull("temperatureC") ? metricNumber(cpu.optDouble("temperatureC"), " °C") : "sensor indisponível")
                + "\nGPU · " + (gpu == null ? "indisponível" : gpu.optString("name", "indisponível"));
            TextView sessionDetail = text(detail, 8, MUTED, false); performanceValues.put("sessionDetail", sessionDetail);
            page.addView(sessionDetail, margins(-1, 9, -1, 0));
        }
        refreshPerformanceValues();
    }

    private View performanceMetricCard(String key, String label) {
        LinearLayout card = column(); card.setPadding(dp(13), dp(13), dp(13), dp(13)); card.setBackground(background(SURFACE, 4, LINE, 1));
        TextView value = text("—", 18, TEXT, true); performanceValues.put(key, value); card.addView(value);
        TextView small = text(label, 7, MUTED, true); small.setLetterSpacing(.12f); card.addView(small, margins(-1, 6, -1, 0)); return card;
    }

    private void refreshPerformanceValues() {
        if (performancePanel != null) performancePanel.setVisibility(
            performanceLive.isLive(companion.optString("gameId", ""), SystemClock.elapsedRealtime()) ? View.VISIBLE : View.GONE);
        if (performanceValues.isEmpty()) return;
        org.json.JSONObject cpu = performance.optJSONObject("cpu"); org.json.JSONObject gpu = performance.optJSONObject("gpu");
        org.json.JSONObject memory = performance.optJSONObject("memory"); org.json.JSONObject process = performance.optJSONObject("process"); org.json.JSONObject fps = performance.optJSONObject("fps");
        setPerformanceValue("cpu", availableNumber(cpu, "usagePercent", "%"));
        setPerformanceValue("gpuTemp", availableNumber(gpu, "temperatureC", " °C"));
        setPerformanceValue("gpu", availableNumber(gpu, "usagePercent", "%"));
        setPerformanceValue("fps", fps != null && fps.optBoolean("available", false) && !fps.isNull("value") ? metricNumber(fps.optDouble("value"), "") : "INDISP.");
        setPerformanceValue("ram", memory != null && memory.optBoolean("available", false) ? bytesPair(memory.optDouble("usedBytes"), memory.optDouble("totalBytes")) : "INDISP.");
        setPerformanceValue("vram", gpu != null && gpu.optBoolean("available", false) && !gpu.isNull("memoryUsedBytes") ? bytesPair(gpu.optDouble("memoryUsedBytes"), gpu.optDouble("memoryTotalBytes")) : "INDISP.");
        setPerformanceValue("gameCpu", availableNumber(process, "cpuPercent", "%"));
        setPerformanceValue("gameRam", process != null && process.optBoolean("available", false) && !process.isNull("ramBytes") ? bytesShort(process.optDouble("ramBytes")) : "INDISP.");
        TextView sessionDetail = performanceValues.get("sessionDetail");
        if (sessionDetail != null) {
            long seconds = Math.max(0L, performance.optLong("sessionSeconds", 0L));
            String duration = String.format(Locale.ROOT, "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60);
            String cpuTemperature = cpu != null && !cpu.isNull("temperatureC") ? metricNumber(cpu.optDouble("temperatureC"), " °C") : "sensor indisponível";
            sessionDetail.setText("SESSÃO · " + duration + "\nCPU TEMP. · " + cpuTemperature + "\nGPU · " + (gpu == null ? "indisponível" : gpu.optString("name", "indisponível")));
        }
    }

    private String availableNumber(org.json.JSONObject object, String key, String suffix) {
        return object != null && object.optBoolean("available", false) && !object.isNull(key) ? metricNumber(object.optDouble(key), suffix) : "INDISP.";
    }
    private String metricNumber(double value, String suffix) { return String.format(Locale.ROOT, value >= 100 ? "%.0f%s" : "%.1f%s", value, suffix); }
    private String bytesShort(double value) { return value <= 0 ? "0 MB" : value >= 1073741824d ? String.format(Locale.ROOT, "%.1f GB", value / 1073741824d) : String.format(Locale.ROOT, "%.0f MB", value / 1048576d); }
    private String bytesPair(double used, double total) { return bytesShort(used) + " / " + bytesShort(total); }
    private void setPerformanceValue(String key, String value) { TextView view = performanceValues.get(key); if (view != null) view.setText(value); }

    private void captureMoment(Game game, Button button) {
        button.setEnabled(false); button.setText("CAPTURANDO...");
        bridgeClient.captureMoment(game, new BridgeClient.MomentCallback() {
            @Override public void onCaptured(byte[] png, org.json.JSONObject metadata) {
                button.setEnabled(true); button.setText("CAPTURAR MOMENTO"); showMomentMetadataDialog(png, metadata);
            }
            @Override public void onError(String error) {
                button.setEnabled(true); button.setText("CAPTURAR MOMENTO"); Toast.makeText(MainActivity.this, error, Toast.LENGTH_LONG).show();
            }
        });
    }

    private void showMomentMetadataDialog(byte[] png, org.json.JSONObject metadata) {
        LinearLayout form = column(); form.setPadding(dp(20), dp(5), dp(20), 0);
        EditText location = pairingField("LOCALIZAÇÃO · Ex.: Castelo, sala do chefe", "");
        EditText note = companionEditor("ANOTAÇÃO", "", "O que aconteceu ou por que voltar aqui?");
        EditText category = pairingField("CATEGORIA · Bonito, engraçado, segredo...", "MOMENTO");
        form.addView(location, margins(-1, 0, -1, 8, 48)); form.addView(note, margins(-1, 0, -1, 8)); form.addView(category, margins(-1, 0, -1, 0, 48));
        AlertDialog dialog = new AlertDialog.Builder(this).setTitle("SALVAR BRUMMOMENT").setView(form)
            .setNegativeButton("DESCARTAR", null).setPositiveButton("SALVAR", null).create();
        dialog.setOnShowListener(ignored -> dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v -> {
            try {
                momentRepository.save(png, metadata, location.getText().toString(), note.getText().toString(), category.getText().toString());
                dialog.dismiss(); Toast.makeText(this, "Momento salvo na galeria offline.", Toast.LENGTH_LONG).show(); showMoments();
            } catch (Exception error) { note.setError("Não foi possível salvar este momento."); }
        }));
        dialog.show();
    }

    private void showNotifications() {
        ScrollView scroll = scroll(); LinearLayout page = page(); scroll.addView(page);
        page.addView(backHeader("CENTRAL BRUM", this::showHome));
        page.addView(text("Notificações", 29, TEXT, true), margins(-1, 24, -1, 7));
        page.addView(text("Conquistas, sessões, saves, instalações e avisos do launcher.", 10, MUTED, false));
        int unread = Math.max(0, notificationSnapshot.optInt("unread", 0));
        page.addView(sectionHeading(unread > 0 ? unread + (unread == 1 ? " NÃO LIDA" : " NÃO LIDAS") : "TUDO EM DIA", unread > 0 ? "MARCAR TODAS" : "", v -> {
            bridgeClient.markNotificationRead("", true, new BridgeClient.NotificationCallback() {
                @Override public void onSuccess(int remaining) {
                    try {
                        notificationSnapshot.put("unread", remaining);
                        org.json.JSONArray current = notificationSnapshot.optJSONArray("entries");
                        if (current != null) for (int i = 0; i < current.length(); i++) if (current.optJSONObject(i) != null) current.optJSONObject(i).put("readAt", "agora");
                    } catch (Exception ignored) {}
                    showNotifications();
                }
                @Override public void onError(String message) { Toast.makeText(MainActivity.this, message, Toast.LENGTH_LONG).show(); }
            });
        }), margins(-1, 28, -1, 12));
        org.json.JSONArray entries = notificationSnapshot.optJSONArray("entries");
        if (entries == null || entries.length() == 0) {
            LinearLayout empty = column(); empty.setPadding(dp(18), dp(20), dp(18), dp(20)); empty.setBackground(background(SURFACE, 4, LINE, 1));
            empty.addView(eyebrow("NENHUMA NOTIFICAÇÃO"));
            empty.addView(text(bridgeClient.isConfigured() ? "Quando algo importante acontecer no launcher, aparecerá aqui." : "Conecte-se ao launcher atualizado para sincronizar sua central.", 10, MUTED, false), margins(-1, 9, -1, 0));
            page.addView(empty);
        } else {
            for (int index = 0; index < entries.length(); index++) {
                org.json.JSONObject item = entries.optJSONObject(index);
                if (item == null) continue;
                String id = item.optString("id", "");
                String gameId = item.optString("gameId", "");
                boolean read = !item.optString("readAt", "").isEmpty();
                String severity = item.optString("severity", "info");
                int tone = "error".equals(severity) ? Color.rgb(255, 91, 91) : "warning".equals(severity) ? Color.rgb(255, 176, 66) : "success".equals(severity) ? ACCENT : Color.rgb(74, 203, 255);
                LinearLayout card = column(); card.setPadding(dp(15), dp(14), dp(15), dp(14)); card.setBackground(background(SURFACE, 4, read ? LINE : Color.argb(105, 157, 255, 59), 1));
                LinearLayout top = row(); top.setGravity(Gravity.CENTER_VERTICAL);
                TextView category = text(item.optString("category", "AVISO").toUpperCase(Locale.ROOT), 7, tone, true); category.setLetterSpacing(.14f);
                top.addView(category, new LinearLayout.LayoutParams(0, -2, 1));
                if (!read) top.addView(text("●", 11, ACCENT, true));
                card.addView(top);
                card.addView(text(item.optString("title", "BRUMCLASSICS"), 15, TEXT, true), margins(-1, 8, -1, 0));
                String message = item.optString("message", ""); if (!message.isEmpty()) card.addView(text(message, 10, MUTED, false), margins(-1, 6, -1, 0));
                String gameTitle = item.optString("gameTitle", "");
                String when = notificationTime(item.optString("createdAt", ""));
                if (!gameTitle.isEmpty() || !when.isEmpty()) card.addView(text(gameTitle + (!gameTitle.isEmpty() && !when.isEmpty() ? " · " : "") + when, 7, MUTED, true), margins(-1, 10, -1, 0));
                card.setAlpha(read ? .68f : 1f);
                card.setOnClickListener(v -> {
                    if (!read) bridgeClient.markNotificationRead(id, false, new BridgeClient.NotificationCallback() {
                        @Override public void onSuccess(int remaining) { }
                        @Override public void onError(String error) { Toast.makeText(MainActivity.this, error, Toast.LENGTH_LONG).show(); }
                    });
                    if (!gameId.isEmpty()) for (Game game : games) if (game.id.equals(gameId)) { detailsReturnScreen = "notifications"; showDetails(game); return; }
                });
                page.addView(card, margins(-1, 0, -1, 9));
            }
        }
        page.addView(space(30)); setScreen("notifications", scroll);
    }

    private String notificationTime(String value) {
        if (value == null || value.isEmpty()) return "";
        String clean = value.replace('T', ' ');
        return clean.length() >= 16 ? clean.substring(0, 16) : clean;
    }

    private void showMoments() {
        ScrollView scroll = scroll(); LinearLayout page = page(); scroll.addView(page);
        page.addView(brandHeader("BRUMMOMENTS"));
        page.addView(text("Seus momentos, sempre com você.", 25, TEXT, true), margins(-1, 28, -1, 7));
        page.addView(text("Capturas, localizações e lembranças salvas no celular para consulta offline.", 10, MUTED, false));
        List<Moment> moments = momentRepository.all();
        page.addView(sectionHeading(moments.size() + (moments.size() == 1 ? " MOMENTO" : " MOMENTOS"), "VOLTAR", v -> showCompanion()), margins(-1, 30, -1, 12));
        if (moments.isEmpty()) {
            page.addView(text("Abra um jogo, entre no BRUMCOMPANION e toque em CAPTURAR MOMENTO.", 12, MUTED, false), margins(-1, 16, -1, 0));
        }
        for (Moment moment : moments) {
            LinearLayout card = column(); card.setPadding(dp(10), dp(10), dp(10), dp(13)); card.setBackground(background(SURFACE, 4, LINE, 1));
            ImageView image = new ImageView(this); image.setScaleType(ImageView.ScaleType.CENTER_CROP); image.setImageBitmap(decodeMomentPreview(moment.imagePath));
            card.addView(image, new LinearLayout.LayoutParams(-1, dp(205)));
            card.addView(eyebrow(moment.category.toUpperCase(Locale.ROOT) + (moment.favorite ? " · ★" : "")), margins(-1, 12, -1, 4));
            card.addView(text(moment.gameTitle, 15, TEXT, true));
            if (!moment.location.isEmpty()) card.addView(text("⌖ " + moment.location, 9, ACCENT, true), margins(-1, 6, -1, 0));
            if (!moment.note.isEmpty()) card.addView(text(moment.note, 10, MUTED, false), margins(-1, 7, -1, 0));
            LinearLayout actions = row();
            Button favorite = button(moment.favorite ? "★ FAVORITO" : "☆ FAVORITAR"); favorite.setTextSize(7); favorite.setTextColor(ACCENT); favorite.setBackgroundColor(Color.TRANSPARENT);
            favorite.setOnClickListener(v -> { try { momentRepository.update(moment.id, moment.location, moment.note, moment.category, !moment.favorite); showMoments(); } catch (Exception ignored) { } });
            actions.addView(favorite, new LinearLayout.LayoutParams(0, dp(40), 1));
            Button remove = button("EXCLUIR"); remove.setTextSize(7); remove.setTextColor(MUTED); remove.setBackgroundColor(Color.TRANSPARENT);
            remove.setOnClickListener(v -> new AlertDialog.Builder(this).setTitle("Excluir este momento?").setMessage("A imagem será removida somente da galeria do celular.")
                .setNegativeButton("CANCELAR", null).setPositiveButton("EXCLUIR", (d, w) -> { try { momentRepository.remove(moment.id); showMoments(); } catch (Exception ignored) { } }).show());
            actions.addView(remove, new LinearLayout.LayoutParams(0, dp(40), 1)); card.addView(actions, margins(-1, 5, -1, 0));
            page.addView(card, margins(-1, 8, -1, 0));
        }
        page.addView(space(32)); setScreen("moments", scroll);
    }

    private android.graphics.Bitmap decodeMomentPreview(String path) {
        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(path, bounds);
        int sample = 1;
        while (bounds.outWidth / sample > 1400 || bounds.outHeight / sample > 1400) sample *= 2;
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inSampleSize = sample;
        options.inPreferredConfig = android.graphics.Bitmap.Config.RGB_565;
        return BitmapFactory.decodeFile(path, options);
    }

    private EditText companionEditor(String label, String value, String hint) {
        EditText editor = new EditText(this);
        editor.setHint(hint); editor.setHintTextColor(MUTED); editor.setTextColor(TEXT); editor.setText(value); editor.setContentDescription(label);
        editor.setTextSize(11); editor.setGravity(Gravity.TOP); editor.setMinLines(3); editor.setMaxLines(8); editor.setFilters(new InputFilter[]{new InputFilter.LengthFilter(6000)});
        editor.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        editor.setPadding(dp(14), dp(12), dp(14), dp(12)); editor.setBackground(background(SURFACE, 4, LINE, 1));
        return editor;
    }

    private View companionField(String label, EditText editor) {
        LinearLayout field = column();
        field.addView(text(label, 8, ACCENT, true));
        field.addView(editor, margins(-1, 6, -1, 0));
        return field;
    }

    private org.json.JSONObject companionNotePayload(EditText whereStopped, EditText objectives, EditText tips, EditText commands) {
        org.json.JSONObject result = new org.json.JSONObject();
        try { result.put("whereStopped", whereStopped.getText().toString()); result.put("objectives", objectives.getText().toString()); result.put("tips", tips.getText().toString()); result.put("commands", commands.getText().toString()); } catch (Exception ignored) {}
        return result;
    }

    private void saveCompanionDraft(Game game, EditText whereStopped, EditText objectives, EditText tips, EditText commands, boolean force, TextView state) {
        state.setText("Salvando..."); state.setTextColor(MUTED);
        org.json.JSONObject payload = companionNotePayload(whereStopped, objectives, tips, commands);
        bridgeClient.saveCompanionNotes(game, payload, force, (result, message) -> {
            state.setText(message); state.setTextColor("saved".equals(result) ? ACCENT : "conflict".equals(result) ? Color.rgb(255, 184, 77) : MUTED);
            if ("conflict".equals(result)) showCompanionConflict(game, whereStopped, objectives, tips, commands, state);
            else if (("saved".equals(result) || "queued".equals(result)) && !hasCompanionNoteContent(payload)) showCompanion();
        });
    }

    private boolean hasCompanionNoteContent(org.json.JSONObject notes) {
        return notes != null && (!notes.optString("whereStopped", "").trim().isEmpty()
            || !notes.optString("objectives", "").trim().isEmpty()
            || !notes.optString("tips", "").trim().isEmpty()
            || !notes.optString("commands", "").trim().isEmpty());
    }

    private void showCompanionConflict(Game game, EditText whereStopped, EditText objectives, EditText tips, EditText commands, TextView state) {
        new AlertDialog.Builder(this).setTitle("Anotações alteradas nos dois dispositivos")
            .setMessage("Seu rascunho está preservado. Escolha manter o texto do celular ou recarregar a versão salva no launcher.")
            .setPositiveButton("MANTER CELULAR", (dialog, which) -> saveCompanionDraft(game, whereStopped, objectives, tips, commands, true, state))
            .setNegativeButton("USAR LAUNCHER", (dialog, which) -> { bridgeClient.discardCompanionDraft(game.id); state.setText("Recarregando anotações do launcher..."); })
            .setNeutralButton("CANCELAR", null).show();
    }

    private void showEditNotesDialog(Game game) {
        org.json.JSONObject notes = bridgeClient.companionNotes(game);
        LinearLayout form = column(); form.setPadding(dp(18), dp(4), dp(18), 0);
        EditText whereStopped = companionEditor("ONDE PAREI", notes.optString("whereStopped"), "Onde você parou?");
        EditText objectives = companionEditor("OBJETIVOS", notes.optString("objectives"), "Próximos objetivos");
        EditText tips = companionEditor("DICAS", notes.optString("tips"), "Dicas e lembretes");
        EditText commands = companionEditor("COMANDOS", notes.optString("commands"), "Atalhos e comandos");
        form.addView(companionField("ONDE PAREI", whereStopped)); form.addView(companionField("OBJETIVOS", objectives), margins(-1, 7, -1, 0));
        form.addView(companionField("DICAS", tips), margins(-1, 7, -1, 0)); form.addView(companionField("COMANDOS", commands), margins(-1, 7, -1, 0));
        AlertDialog dialog = new AlertDialog.Builder(this).setTitle("ANOTAÇÕES · " + game.title).setView(form)
            .setNegativeButton("CANCELAR", null).setPositiveButton("SALVAR", null).create();
        dialog.setOnShowListener(ignored -> dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v -> {
            TextView state = text("Salvando...", 8, MUTED, false); form.addView(state);
            bridgeClient.saveCompanionNotes(game, companionNotePayload(whereStopped, objectives, tips, commands), false, (result, message) -> {
                Toast.makeText(this, message, Toast.LENGTH_LONG).show();
                if ("conflict".equals(result)) showCompanionConflict(game, whereStopped, objectives, tips, commands, state);
                else { dialog.dismiss(); showDetails(game); }
            });
        }));
        dialog.show();
    }

    private void setScreen(String name, View view) {
        currentScreen = name;
        content.removeAllViews();
        content.addView(view, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        view.setAlpha(0f);
        view.setTranslationY(dp(9));
        view.animate().alpha(1f).translationY(0).setDuration(220).setInterpolator(new DecelerateInterpolator()).start();
        for (Button nav : navButtons) {
            boolean active = name.equals(nav.getTag());
            nav.setTextColor(active ? TEXT : MUTED);
            nav.setBackground(active ? background(Color.argb(13, 157, 255, 59), 3, Color.TRANSPARENT, 0) : null);
        }
    }

    private void showLoading() {
        LinearLayout loading = column();
        loading.setGravity(Gravity.CENTER);
        loading.setBackgroundColor(BG);
        ImageView mark = new ImageView(this);
        mark.setImageResource(com.brumclassics.mobile.R.drawable.ic_launcher);
        loading.addView(mark, new LinearLayout.LayoutParams(dp(48), dp(48)));
        TextView title = text("BRUMCLASSICS", 18, TEXT, true);
        title.setLetterSpacing(.07f);
        loading.addView(title, margins(-1, -2, -1, 6));
        TextView state = text("CARREGANDO BIBLIOTECA LOCAL", 7, MUTED, true);
        state.setLetterSpacing(.18f);
        loading.addView(state);
        setScreen("loading", loading);
    }

    private void showError(String message) {
        LinearLayout error = column();
        error.setGravity(Gravity.CENTER);
        error.setPadding(dp(32), dp(32), dp(32), dp(32));
        error.addView(text("ALGO SAIU DO EIXO", 10, ACCENT, true));
        TextView copy = text(message, 16, TEXT, true);
        copy.setGravity(Gravity.CENTER);
        error.addView(copy, margins(-1, 12, -1, 24));
        Button retry = primaryButton("TENTAR NOVAMENTE");
        retry.setOnClickListener(v -> { games = repository.all(); showHome(); });
        error.addView(retry, new LinearLayout.LayoutParams(-1, dp(48)));
        setScreen("error", error);
    }

    private void showHome() {
        ScrollView scroll = scroll();
        LinearLayout page = page();
        scroll.addView(page);
        page.addView(brandHeader(bridgeClient.isConfigured() && "connected".equals(syncState) ? "CONECTADO" : "VISÃO GERAL"));

        TextView greeting = text("Boa noite.", 12, ACCENT, true);
        greeting.setLetterSpacing(.12f);
        page.addView(greeting, margins(-1, 28, -1, 7));
        TextView headline = text("Sua biblioteca,\nem qualquer lugar.", 31, TEXT, true);
        headline.setLineSpacing(0, .93f);
        page.addView(headline);
        page.addView(text("Continue de onde parou ou encontre a próxima história.", 12, MUTED, false), margins(-1, 12, -1, 27));

        LinearLayout notificationsAccess = row();
        notificationsAccess.setGravity(Gravity.CENTER_VERTICAL);
        notificationsAccess.setPadding(dp(16), dp(14), dp(14), dp(14));
        notificationsAccess.setBackground(background(SURFACE, 5, LINE, 1));
        LinearLayout notificationsCopy = column();
        int unreadNotifications = Math.max(0, notificationSnapshot.optInt("unread", 0));
        notificationsCopy.addView(text("NOTIFICAÇÕES" + (unreadNotifications > 0 ? " · " + unreadNotifications : ""), 15, TEXT, true));
        notificationsCopy.addView(text(unreadNotifications > 0 ? "Avisos não lidos sincronizados com o launcher" : "Conquistas, sessões, saves e atualizações", 9, MUTED, false), margins(-1, 5, -1, 0));
        notificationsAccess.addView(notificationsCopy, new LinearLayout.LayoutParams(0, -2, 1));
        TextView notificationsArrow = text(unreadNotifications > 0 ? "●" : "›", unreadNotifications > 0 ? 14 : 28, unreadNotifications > 0 ? ACCENT : MUTED, true);
        notificationsArrow.setGravity(Gravity.CENTER);
        notificationsAccess.addView(notificationsArrow, new LinearLayout.LayoutParams(dp(42), dp(42)));
        notificationsAccess.setOnClickListener(v -> showNotifications());
        page.addView(notificationsAccess, margins(-1, 0, -1, 18));

        if (!repository.isSynchronizedLibrary()) {
            LinearLayout demo = column();
            demo.setPadding(dp(14), dp(12), dp(14), dp(12));
            demo.setBackground(background(Color.argb(22, 157, 255, 59), 4, ACCENT, 1));
            demo.addView(eyebrow("MODO DEMONSTRAÇÃO"));
            demo.addView(text("Estes jogos são exemplos. Abra Perfil → Conectar ao launcher para carregar sua biblioteca real.", 9, TEXT, false), margins(-1, 6, -1, 0));
            page.addView(demo, margins(-1, 0, -1, 18));
        }

        LinearLayout bCardAccess = row();
        bCardAccess.setGravity(Gravity.CENTER_VERTICAL);
        bCardAccess.setPadding(dp(16), dp(14), dp(14), dp(14));
        bCardAccess.setBackground(background(Color.argb(24, 157, 255, 59), 5, Color.argb(90, 157, 255, 59), 1));
        LinearLayout bCardCopy = column();
        TextView bCardTitle = text("B-CARD", 15, TEXT, true);
        bCardTitle.setLetterSpacing(.12f);
        bCardCopy.addView(bCardTitle);
        bCardCopy.addView(text("Envie um jogo instalado para o computador.", 9, MUTED, false), margins(-1, 5, -1, 0));
        bCardAccess.addView(bCardCopy, new LinearLayout.LayoutParams(0, -2, 1));
        TextView bCardArrow = text("↑", 26, ACCENT, true);
        bCardArrow.setGravity(Gravity.CENTER);
        bCardAccess.addView(bCardArrow, new LinearLayout.LayoutParams(dp(42), dp(42)));
        bCardAccess.setOnClickListener(v -> showBCardLibrary());
        bCardAccess.setFocusable(true);
        page.addView(bCardAccess, margins(-1, 0, -1, 18));

        LinearLayout classicsAccess = row();
        classicsAccess.setGravity(Gravity.CENTER_VERTICAL);
        classicsAccess.setPadding(dp(16), dp(14), dp(14), dp(14));
        classicsAccess.setBackground(background(SURFACE, 5, LINE, 1));
        LinearLayout classicsCopy = column();
        classicsCopy.addView(text("CLASSICS Everywhere", 15, TEXT, true));
        classicsCopy.addView(text("Suas ROMs locais · jogar no RetroArch", 9, MUTED, false), margins(-1, 5, -1, 0));
        classicsAccess.addView(classicsCopy, new LinearLayout.LayoutParams(0, -2, 1));
        TextView classicsArrow = text("›", 28, ACCENT, true); classicsArrow.setGravity(Gravity.CENTER);
        classicsAccess.addView(classicsArrow, new LinearLayout.LayoutParams(dp(42), dp(42)));
        classicsAccess.setOnClickListener(v -> showClassics());
        page.addView(classicsAccess, margins(-1, 0, -1, 18));

        LocalClassic recentClassic = null;
        for (LocalClassic item : classicsRepository.all()) if (item.lastPlayedAt > 0 && (recentClassic == null || item.lastPlayedAt > recentClassic.lastPlayedAt)) recentClassic = item;
        if (recentClassic != null) {
            final LocalClassic selectedClassic = recentClassic;
            LinearLayout recent = column(); recent.setPadding(dp(15), dp(14), dp(15), dp(14)); recent.setBackground(background(SURFACE, 4, LINE, 1));
            recent.addView(eyebrow("ÚLTIMO CLASSIC JOGADO NO CELULAR")); recent.addView(text(recentClassic.title, 17, TEXT, true), margins(-1, 7, -1, 4));
            recent.addView(text(classicPlatform(recentClassic.filename) + " · " + formatClassicTime(recentClassic.creditedSeconds), 8, MUTED, true));
            recent.setOnClickListener(v -> showClassicDetails(selectedClassic)); page.addView(recent, margins(-1, 0, -1, 18));
        }

        if (games.isEmpty()) {
            LinearLayout empty = column();
            empty.setGravity(Gravity.CENTER);
            empty.setPadding(dp(24), dp(34), dp(24), dp(34));
            empty.setBackground(background(SURFACE, 4, LINE, 1));
            empty.addView(text("BIBLIOTECA VAZIA", 11, TEXT, true));
            TextView emptyCopy = text("Abra o launcher no computador e sincronize quando estiver na mesma rede.", 11, MUTED, false);
            emptyCopy.setGravity(Gravity.CENTER);
            empty.addView(emptyCopy, margins(-1, 10, -1, 0));
            page.addView(empty);
            page.addView(space(28));
            setScreen("home", scroll);
            return;
        }

        Game featured = HomeLibrary.lastPlayed(games);
        LinearLayout hero = row();
        hero.setGravity(Gravity.CENTER_VERTICAL);
        hero.setPadding(dp(14), dp(14), dp(14), dp(14));
        hero.setBackground(background(SURFACE, 4, LINE, 1));
        CoverView heroCover = cover(featured, 122, 172);
        hero.addView(heroCover);
        LinearLayout heroInfo = column();
        heroInfo.setPadding(dp(16), 0, 0, 0);
        heroInfo.addView(eyebrow(featured.lastPlayedAt.isEmpty() ? "DESTAQUE DA BIBLIOTECA" : "ÚLTIMO JOGO JOGADO"));
        heroInfo.addView(text(featured.title, 20, TEXT, true), margins(-1, 8, -1, 4));
        heroInfo.addView(text(featured.platform + " · " + featured.playedLabel(), 9, MUTED, false));
        if (featured.achievementsAvailable) heroInfo.addView(progress(featured.progress), margins(-1, 17, -1, 8));
        heroInfo.addView(text(featured.achievementsAvailable ? featured.progress + "% CONCLUÍDO" : "CONQUISTAS INDISPONÍVEIS", 7, ACCENT, true));
        hero.addView(heroInfo, new LinearLayout.LayoutParams(0, -2, 1));
        hero.setOnClickListener(v -> showDetails(featured));
        page.addView(hero);

        List<Game> favorites = new ArrayList<>();
        List<Game> wantToPlay = new ArrayList<>();
        for (Game game : games) {
            if (isFavorite(game)) favorites.add(game);
            if (bridgeClient.wantToPlay(game)) wantToPlay.add(game);
        }
        page.addView(sectionHeading("FAVORITOS", "VER BIBLIOTECA", v -> { favoriteOnly = true; showLibrary(); }), margins(-1, 32, -1, 15));
        page.addView(homeGameShelf(favorites, "Marque jogos como favoritos no launcher ou no Perfil do Jogo."));

        page.addView(sectionHeading("QUERO JOGAR", "VER TODOS", v -> { statusFilter = "QUERO JOGAR"; showLibrary(); }), margins(-1, 32, -1, 15));
        page.addView(homeGameShelf(wantToPlay, "Sua lista está vazia. Marque um jogo para lembrar dele depois."));

        page.addView(sectionHeading("SUA JORNADA", "", null), margins(-1, 32, -1, 14));
        LinearLayout summary = row();
        summary.addView(metricCard(String.valueOf(games.size()), "JOGOS"), weightedMargins(0, 0, 6, 0));
        summary.addView(metricCard(totalHours() + " h", "TEMPO JOGADO"), weightedMargins(6, 0, 0, 0));
        page.addView(summary);
        LinearLayout progressSummary = row();
        progressSummary.addView(metricCard(String.valueOf(countStatus(Game.Status.COMPLETED)), "CONCLUÍDOS"), weightedMargins(0, 12, 6, 0));
        progressSummary.addView(metricCard(averageProgress() + "%", "PROGRESSO MÉDIO"), weightedMargins(6, 12, 0, 0));
        page.addView(progressSummary);
        page.addView(space(28));
        setScreen("home", scroll);
    }

    private void showClassics() {
        LinearLayout root = column(); root.setBackgroundColor(BG);
        LinearLayout header = page(); header.setPadding(dp(20), dp(18), dp(20), dp(12));
        header.addView(backHeader("CLASSICS EVERYWHERE", this::showHome));
        header.addView(text("Seus clássicos no Android", 26, TEXT, true), margins(-1, 20, -1, 5));
        header.addView(text("ROMs da pasta autorizada, abertas diretamente no RetroArch.", 10, MUTED, false));
        Button refresh = primaryButton(classicsRepository.romFolderConfigured() ? "VERIFICAR " + classicsRepository.romFolderName().toUpperCase(Locale.ROOT) : "SELECIONAR PASTA DE ROMS");
        refresh.setOnClickListener(v -> {
            if (!classicsRepository.romFolderConfigured()) { chooseTree(REQUEST_ROM_TREE); return; }
            refresh.setEnabled(false); refresh.setText("VERIFICANDO...");
            modelExecutor.execute(() -> {
                try { classicsRepository.scan(); handler.post(this::showClassics); }
                catch (Exception error) { handler.post(() -> { Toast.makeText(this, "Autorize novamente a pasta de ROMs. " + error.getMessage(), Toast.LENGTH_LONG).show(); showClassicSettings(); }); }
            });
        });
        header.addView(refresh, margins(-1, 17, -1, 0, 48)); root.addView(header);

        List<LocalClassic> localGames = classicsRepository.all();
        if (!classicsRepository.romFolderConfigured() || localGames.isEmpty()) {
            LinearLayout empty = column(); empty.setGravity(Gravity.CENTER); empty.setPadding(dp(30), dp(42), dp(30), dp(42));
            empty.addView(text(classicsRepository.romFolderConfigured() ? "NENHUMA ROM COMPATÍVEL" : "PASTA NÃO CONFIGURADA", 12, TEXT, true));
            TextView copy = text(classicsRepository.romFolderConfigured()
                ? "Formatos suportados incluem GB, GBA, NES, SNES, N64, NDS, Mega Drive, CHD, ISO, CUE, M3U e ZIP."
                : "Escolha uma pasta uma vez. O Android preservará somente a permissão de leitura.", 10, MUTED, false);
            copy.setGravity(Gravity.CENTER); empty.addView(copy, margins(-1, 10, -1, 0));
            root.addView(empty, new LinearLayout.LayoutParams(-1, 0, 1)); setScreen("classics", root); return;
        }

        GridView grid = new GridView(this); grid.setNumColumns(getResources().getConfiguration().screenWidthDp >= 600 ? 3 : 2);
        grid.setHorizontalSpacing(dp(12)); grid.setVerticalSpacing(dp(16)); grid.setStretchMode(GridView.STRETCH_COLUMN_WIDTH);
        grid.setClipToPadding(false); grid.setVerticalScrollBarEnabled(false); grid.setPadding(dp(14), dp(10), dp(14), dp(30));
        grid.setAdapter(new BaseAdapter() {
            @Override public int getCount() { return localGames.size(); }
            @Override public LocalClassic getItem(int position) { return localGames.get(position); }
            @Override public long getItemId(int position) { return getItem(position).id.hashCode(); }
            @Override public View getView(int position, View convertView, ViewGroup parent) {
                LocalClassic game = getItem(position); LinearLayout card = column(); Game launcherGame = launcherGameFor(game);
                if (launcherGame != null) card.addView(cover(launcherGame, -1, 214), new LinearLayout.LayoutParams(-1, dp(214)));
                else card.addView(localClassicArtwork(game, 214), new LinearLayout.LayoutParams(-1, dp(214)));
                card.addView(text(classicPlatform(game.filename), 7, ACCENT, true), margins(-1, 9, -1, 3));
                card.addView(text(game.title, 12, TEXT, true));
                String progress = game.achievements.isEmpty() ? "CONQUISTAS NÃO CONSULTADAS" : game.unlockedCount() + "/" + game.achievements.size() + " · " + game.progressPercent() + "%";
                card.addView(text(progress, 7, MUTED, true), margins(-1, 4, -1, 0));
                card.setOnClickListener(v -> showClassicDetails(game)); return card;
            }
        });
        root.addView(grid, new LinearLayout.LayoutParams(-1, 0, 1)); setScreen("classics", root);
    }

    private void showClassicDetails(LocalClassic game) {
        currentClassicId = game.id; ScrollView scroll = scroll(); LinearLayout page = page(); scroll.addView(page);
        page.addView(backHeader("CLASSICS EVERYWHERE", this::showClassics)); Game launcherGame = launcherGameFor(game);
        if (launcherGame != null) {
            LinearLayout.LayoutParams coverLp = margins(210, 25, -1, 0, 294); coverLp.gravity = Gravity.CENTER_HORIZONTAL;
            page.addView(cover(launcherGame, 210, 294), coverLp);
        } else {
            LinearLayout.LayoutParams coverLp = margins(210, 25, -1, 0, 294); coverLp.gravity = Gravity.CENTER_HORIZONTAL;
            page.addView(localClassicArtwork(game, 294), coverLp);
        }
        TextView platform = eyebrow(classicPlatform(game.filename) + " · RETROARCH"); platform.setGravity(Gravity.CENTER);
        page.addView(platform, margins(-1, launcherGame == null ? 28 : 20, -1, 8));
        TextView title = text(game.title, 27, TEXT, true); title.setGravity(Gravity.CENTER); page.addView(title);
        page.addView(text(game.filename, 8, MUTED, false), margins(-1, 7, -1, 20));

        Button play = primaryButton("JOGAR NO RETROARCH"); play.setOnClickListener(v -> launchLocalClassic(game));
        page.addView(play, new LinearLayout.LayoutParams(-1, dp(50)));
        page.addView(text("O jogo roda no RetroArch. Instale o núcleo correspondente antes do primeiro uso.", 8, MUTED, false), margins(-1, 8, -1, 0));

        page.addView(sectionHeading("HORAS NO ANDROID", "ATUALIZAR", v -> syncClassic(game, true)), margins(-1, 28, -1, 10));
        long pending = Math.max(0L, game.creditedSeconds - Math.max(0L, game.acknowledgedSeconds));
        page.addView(metricCard(formatClassicTime(game.creditedSeconds), pending > 0 ? (pending / 60) + " MIN PENDENTES NO PC" : game.acknowledgedSeconds < 0 ? "AGUARDANDO VÍNCULO" : "SINCRONIZADO"));
        if (game.counterReset) {
            Button baseline = button("REESTABELECER PONTO DE PARTIDA"); baseline.setTextColor(ACCENT); baseline.setBackground(background(SURFACE, 3, ACCENT, 1));
            baseline.setOnClickListener(v -> modelExecutor.execute(() -> { try { classicsRepository.rebaseline(game.id); handler.post(() -> showClassicDetails(classicsRepository.find(game.id))); } catch (Exception error) { handler.post(() -> Toast.makeText(this, error.getMessage(), Toast.LENGTH_LONG).show()); } }));
            page.addView(baseline, margins(-1, 8, -1, 0, 46));
        }

        page.addView(sectionHeading("VÍNCULOS", "EDITAR", v -> editClassicLinks(game)), margins(-1, 28, -1, 10));
        page.addView(noteCard("MESMO JOGO NO LAUNCHER", launcherGame == null ? "Não vinculado" : launcherGame.title));
        page.addView(noteCard("RETROACHIEVEMENTS", game.raGameId > 0 ? "ID " + game.raGameId : "ID não informado"), margins(-1, 6, -1, 0));

        page.addView(sectionHeading("CONQUISTAS · " + game.unlockedCount() + "/" + game.achievements.size(), "ATUALIZAR", v -> syncClassic(game, true)), margins(-1, 28, -1, 10));
        if (game.achievements.isEmpty()) page.addView(text("Informe o ID oficial e configure a Web API Key em Perfil → CLASSICS no Android.", 9, MUTED, false));
        int shown = 0;
        for (LocalClassic.Achievement achievement : game.achievements) {
            if (shown++ >= 100) break;
            LinearLayout row = row(); row.setGravity(Gravity.CENTER_VERTICAL); row.setPadding(dp(13), dp(13), dp(13), dp(13)); row.setBackground(background(SURFACE, 3, LINE, 1));
            row.addView(text(achievement.unlocked ? "◆" : "◇", 15, achievement.unlocked ? ACCENT : MUTED, true), new LinearLayout.LayoutParams(dp(30), -2));
            LinearLayout copy = column(); copy.addView(text(achievement.title, 11, achievement.unlocked ? TEXT : MUTED, true));
            if (!achievement.description.isEmpty()) copy.addView(text(achievement.description, 8, MUTED, false), margins(-1, 4, -1, 0));
            row.addView(copy, new LinearLayout.LayoutParams(0, -2, 1));
            if (achievement.points > 0) row.addView(text(achievement.points + " PTS", 7, achievement.unlocked ? ACCENT : MUTED, true));
            page.addView(row, margins(-1, 5, -1, 0));
        }
        page.addView(space(28)); setScreen("classic-details", scroll);
    }

    private void showClassicSettings() {
        ScrollView scroll = scroll(); LinearLayout page = page(); scroll.addView(page);
        page.addView(backHeader("CLASSICS NO ANDROID", this::showProfile));
        page.addView(text("RetroArch e RetroAchievements", 25, TEXT, true), margins(-1, 22, -1, 6));
        page.addView(text("Configuração equivalente ao CLASSICS Everywhere do iPhone, adaptada ao armazenamento do Android.", 10, MUTED, false));

        page.addView(sectionHeading("1 · PASTA DE ROMS", "", null), margins(-1, 28, -1, 10));
        page.addView(text(classicsRepository.romFolderConfigured() ? "Autorizada: " + classicsRepository.romFolderName() : "Nenhuma pasta autorizada.", 10, TEXT, true));
        Button roms = primaryButton(classicsRepository.romFolderConfigured() ? "TROCAR PASTA DE ROMS" : "SELECIONAR PASTA DE ROMS"); roms.setOnClickListener(v -> chooseTree(REQUEST_ROM_TREE));
        page.addView(roms, margins(-1, 10, -1, 0, 47));

        page.addView(sectionHeading("2 · RETROARCH", "", null), margins(-1, 28, -1, 10));
        page.addView(text("O BRUMCLASSICS envia a URI autorizada da ROM e o núcleo sugerido ao RetroArch. Para formatos ambíguos, abra o conteúdo pelo próprio emulador.", 9, MUTED, false));
        Button openRetro = button("ABRIR RETROARCH"); openRetro.setTextColor(ACCENT); openRetro.setBackground(background(SURFACE, 3, ACCENT, 1)); openRetro.setOnClickListener(v -> openRetroArchMenu());
        page.addView(openRetro, margins(-1, 10, -1, 0, 46));

        page.addView(sectionHeading("3 · RETROACHIEVEMENTS", "", null), margins(-1, 28, -1, 10));
        page.addView(text("No RetroArch, ative Settings → Achievements e entre com usuário e senha. A Web API Key abaixo serve somente para consultar o progresso.", 9, MUTED, false));
        EditText username = pairingField("USUÁRIO RETROACHIEVEMENTS", classicsRepository.raUsername());
        EditText apiKey = pairingField("WEB API KEY", classicsRepository.raKey()); apiKey.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        page.addView(username, margins(-1, 12, -1, 8, 48)); page.addView(apiKey, new LinearLayout.LayoutParams(-1, dp(48)));
        Button saveAccount = primaryButton("SALVAR CONTA"); saveAccount.setOnClickListener(v -> {
            try { classicsRepository.configureRetroAchievements(username.getText().toString(), apiKey.getText().toString()); Toast.makeText(this, "Conta salva com proteção do Android Keystore.", Toast.LENGTH_LONG).show(); }
            catch (Exception error) { Toast.makeText(this, error.getMessage(), Toast.LENGTH_LONG).show(); }
        }); page.addView(saveAccount, margins(-1, 10, -1, 0, 47));

        page.addView(sectionHeading("4 · HORAS OFFLINE", "", null), margins(-1, 28, -1, 10));
        page.addView(text("Recomendado: no RetroArch ative Save runtime log (aggregate) e selecione abaixo a pasta Runtime Logs. Sem ela, usamos o intervalo entre sair para o emulador e voltar ao BRUMCLASSICS.", 9, MUTED, false));
        page.addView(text(classicsRepository.runtimeFolderConfigured() ? "Autorizada: " + classicsRepository.runtimeFolderName() : "Cronômetro de contingência ativo.", 9, TEXT, true), margins(-1, 8, -1, 0));
        Button logs = button(classicsRepository.runtimeFolderConfigured() ? "REATORIZAR PASTA DE LOGS" : "AUTORIZAR PASTA DE LOGS"); logs.setTextColor(ACCENT); logs.setBackground(background(SURFACE, 3, ACCENT, 1)); logs.setOnClickListener(v -> chooseTree(REQUEST_RUNTIME_TREE));
        page.addView(logs, margins(-1, 10, -1, 0, 46)); page.addView(space(28)); setScreen("classic-settings", scroll);
    }

    private void chooseTree(int requestCode) {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION | Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);
        startActivityForResult(intent, requestCode);
    }

    private void syncAllClassicsIfDue() {
        android.content.SharedPreferences state = getSharedPreferences("brum_classics_android", MODE_PRIVATE);
        long now = System.currentTimeMillis(); if (now - state.getLong("last_auto_sync", 0L) < 60_000L) return;
        state.edit().putLong("last_auto_sync", now).apply();
        for (LocalClassic game : classicsRepository.all()) {
            if (game.raGameId > 0 || game.creditedSeconds > game.acknowledgedSeconds) syncClassic(game, false);
        }
    }

    private void editClassicLinks(LocalClassic game) {
        LinearLayout form = column(); form.setPadding(dp(18), dp(4), dp(18), 0);
        EditText raId = pairingField("ID DO JOGO NO RETROACHIEVEMENTS", game.raGameId > 0 ? String.valueOf(game.raGameId) : ""); raId.setInputType(InputType.TYPE_CLASS_NUMBER);
        TextView linked = text(launcherGameFor(game) == null ? "Mesmo jogo no launcher: não vinculado" : "Mesmo jogo no launcher: " + launcherGameFor(game).title, 9, TEXT, true);
        Button choose = button("ESCOLHER JOGO DO LAUNCHER"); choose.setTextColor(ACCENT); choose.setBackground(background(SURFACE, 3, ACCENT, 1));
        final String[] selected = {game.launcherGameId}; choose.setOnClickListener(v -> chooseLauncherClassic(selected, linked));
        form.addView(raId, new LinearLayout.LayoutParams(-1, dp(48))); form.addView(linked, margins(-1, 12, -1, 7)); form.addView(choose, new LinearLayout.LayoutParams(-1, dp(44)));
        AlertDialog dialog = new AlertDialog.Builder(this).setTitle("VÍNCULOS · " + game.title).setView(form).setNegativeButton("CANCELAR", null).setPositiveButton("SALVAR", null).create();
        dialog.setOnShowListener(ignored -> dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v -> {
            try { int id = raId.getText().toString().trim().isEmpty() ? 0 : Integer.parseInt(raId.getText().toString().trim()); classicsRepository.updateLinks(game.id, id, selected[0]); dialog.dismiss(); showClassicDetails(classicsRepository.find(game.id)); }
            catch (Exception error) { raId.setError("Informe um número válido."); }
        })); dialog.show();
    }

    private void chooseLauncherClassic(String[] selected, TextView label) {
        List<Game> classics = new ArrayList<>(); for (Game game : games) if (isClassicGame(game)) classics.add(game);
        String[] labels = new String[classics.size() + 1]; labels[0] = "Não vinculado"; int checked = 0;
        for (int index = 0; index < classics.size(); index++) { labels[index + 1] = classics.get(index).title + " · " + classics.get(index).platform; if (classics.get(index).id.equals(selected[0])) checked = index + 1; }
        final int initial = checked;
        new AlertDialog.Builder(this).setTitle("MESMO JOGO NO LAUNCHER").setSingleChoiceItems(labels, initial, (dialog, which) -> {
            selected[0] = which == 0 ? "" : classics.get(which - 1).id; label.setText(which == 0 ? "Mesmo jogo no launcher: não vinculado" : "Mesmo jogo no launcher: " + classics.get(which - 1).title); dialog.dismiss();
        }).setNegativeButton("CANCELAR", null).show();
    }

    private Game launcherGameFor(LocalClassic local) {
        if (local == null) return null;
        if (!local.launcherGameId.isEmpty()) for (Game game : games) if (game.id.equals(local.launcherGameId)) return game;
        String wanted = ClassicsRules.normalizedTitle(local.title); Game match = null; int count = 0;
        for (Game game : games) if (isClassicGame(game) && ClassicsRules.normalizedTitle(game.title).equals(wanted)) { match = game; count++; }
        return count == 1 ? match : null;
    }

    private void launchLocalClassic(LocalClassic game) {
        Game launcherGame = launcherGameFor(game);
        try { if (game.launcherGameId.isEmpty() && launcherGame != null) classicsRepository.updateLinks(game.id, game.raGameId, launcherGame.id); }
        catch (Exception ignored) {}
        List<String> packages = installedRetroArchPackages();
        if (packages.isEmpty()) { new AlertDialog.Builder(this).setTitle("RetroArch não encontrado").setMessage("Instale o RetroArch oficial e tente novamente.").setPositiveButton("ABRIR SITE", (d, w) -> startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://www.retroarch.com/?page=platforms")))).setNegativeButton("CANCELAR", null).show(); return; }
        String preferred = getSharedPreferences("brum_classics_android", MODE_PRIVATE).getString("retroarch_package", "");
        if (packages.contains(preferred)) { startRetroArch(game, preferred); return; }
        if (packages.size() == 1) { getSharedPreferences("brum_classics_android", MODE_PRIVATE).edit().putString("retroarch_package", packages.get(0)).apply(); startRetroArch(game, packages.get(0)); return; }
        String[] labels = new String[packages.size()]; for (int i = 0; i < packages.size(); i++) labels[i] = retroArchLabel(packages.get(i));
        new AlertDialog.Builder(this).setTitle("ESCOLHA O RETROARCH").setItems(labels, (d, which) -> { String selected = packages.get(which); getSharedPreferences("brum_classics_android", MODE_PRIVATE).edit().putString("retroarch_package", selected).apply(); startRetroArch(game, selected); }).show();
    }

    private void startRetroArch(LocalClassic game, String packageName) {
        try {
            classicsRepository.prepareLaunch(game); Uri rom = Uri.parse(game.uri); String core = defaultCore(game.filename);
            if (core == null) { classicsRepository.cancelSession(); Toast.makeText(this, "Formato ambíguo: abra esta ROM pelo Load Content do RetroArch.", Toast.LENGTH_LONG).show(); openRetroArchMenu(packageName); return; }
            Intent intent = new Intent(); intent.setComponent(new ComponentName(packageName, "com.retroarch.browser.retroactivity.RetroActivityFuture"));
            intent.putExtra("ROM", rom.toString()); intent.putExtra("LIBRETRO", "/data/user/0/" + packageName + "/cores/" + core + "_libretro_android.so");
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_CLEAR_TOP); intent.setClipData(ClipData.newRawUri("ROM", rom));
            launchingClassic = true; startActivity(intent);
        } catch (Exception error) { launchingClassic = false; classicsRepository.cancelSession(); Toast.makeText(this, "Não foi possível abrir no RetroArch: " + error.getMessage(), Toast.LENGTH_LONG).show(); }
    }

    private String defaultCore(String filename) {
        String extension = ClassicsRules.extension(filename);
        if ("gba".equals(extension)) return "mgba"; if ("gb".equals(extension) || "gbc".equals(extension)) return "gambatte";
        if ("nes".equals(extension)) return "mesen"; if ("sfc".equals(extension) || "smc".equals(extension)) return "snes9x";
        if ("n64".equals(extension) || "z64".equals(extension) || "v64".equals(extension)) return "mupen64plus_next";
        if ("nds".equals(extension)) return "melondsds"; if ("sms".equals(extension) || "gg".equals(extension) || "md".equals(extension) || "gen".equals(extension)) return "genesis_plus_gx";
        if ("pce".equals(extension)) return "mednafen_pce_fast"; return null;
    }

    private List<String> installedRetroArchPackages() {
        String[] known = {"com.retroarch.aarch64", "com.retroarch", "com.retroarch.ra64", "com.retroarch.ra32"}; List<String> result = new ArrayList<>();
        for (String name : known) try { getPackageManager().getPackageInfo(name, 0); result.add(name); } catch (Exception ignored) {}
        return result;
    }

    private String retroArchLabel(String packageName) {
        try { return getPackageManager().getApplicationLabel(getPackageManager().getApplicationInfo(packageName, 0)).toString(); }
        catch (Exception ignored) { return "RetroArch · " + packageName; }
    }

    private void openRetroArchMenu() { List<String> packages = installedRetroArchPackages(); if (packages.isEmpty()) Toast.makeText(this, "RetroArch não encontrado.", Toast.LENGTH_LONG).show(); else openRetroArchMenu(packages.get(0)); }
    private void openRetroArchMenu(String packageName) { Intent intent = getPackageManager().getLaunchIntentForPackage(packageName); if (intent != null) startActivity(intent); else Toast.makeText(this, "RetroArch não pode ser aberto.", Toast.LENGTH_LONG).show(); }

    private void syncClassic(LocalClassic game, boolean announce) {
        if (game == null) return;
        String username = classicsRepository.raUsername(); String key = classicsRepository.raKey();
        if (game.raGameId > 0 && !username.isEmpty() && !key.isEmpty()) {
            retroAchievements.fetch(game.raGameId, username, key, new RetroAchievementsClient.Callback() {
                @Override public void onSuccess(String title, List<LocalClassic.Achievement> achievements) {
                    try { classicsRepository.updateProgress(game.id, username, title, achievements); }
                    catch (Exception error) { Toast.makeText(MainActivity.this, "Não foi possível salvar as conquistas.", Toast.LENGTH_LONG).show(); return; }
                    LocalClassic current = classicsRepository.find(game.id);
                    if (current != null && !current.launcherGameId.isEmpty() && bridgeClient.isConfigured()) bridgeClient.syncClassicAchievements(current.launcherGameId, current.raGameId, username, new BridgeClient.ClassicsCallback() {
                        public void onResult(org.json.JSONObject result) { bridgeClient.fetchSnapshot(); }
                        public void onError(String message) { Toast.makeText(MainActivity.this, message, Toast.LENGTH_LONG).show(); }
                    });
                    if (announce) Toast.makeText(MainActivity.this, achievements.size() + " conquistas atualizadas.", Toast.LENGTH_LONG).show();
                    refreshCurrentScreen();
                }
                @Override public void onError(String message) { if (announce) Toast.makeText(MainActivity.this, message, Toast.LENGTH_LONG).show(); }
            });
        } else if (announce) Toast.makeText(this, "Configure a conta e o ID do jogo para atualizar conquistas.", Toast.LENGTH_LONG).show();

        LocalClassic current = classicsRepository.find(game.id);
        if (current == null || current.creditedSeconds <= current.acknowledgedSeconds || !bridgeClient.isConfigured()) return;
        try { if (!current.launcherGameId.isEmpty()) classicsRepository.bindForServer(current, bridgeClient.serverFingerprint()); }
        catch (Exception error) { Toast.makeText(this, error.getMessage(), Toast.LENGTH_LONG).show(); return; }
        long outgoing = current.creditedSeconds;
        bridgeClient.syncClassicTime(current.launcherGameId, current.streamId, current.filename, current.title, outgoing, current.lastPlayedAt, new BridgeClient.ClassicsCallback() {
            @Override public void onResult(org.json.JSONObject result) {
                try {
                    long accepted = result.optLong("acceptedSeconds", -1L); String resolved = result.optString("gameId", current.launcherGameId);
                    classicsRepository.acknowledge(current.id, outgoing, accepted, resolved);
                    LocalClassic updated = classicsRepository.find(current.id); if (updated != null && !updated.launcherGameId.isEmpty()) classicsRepository.bindForServer(updated, bridgeClient.serverFingerprint());
                    bridgeClient.fetchSnapshot(); if (announce) Toast.makeText(MainActivity.this, "Horas sincronizadas com o PC.", Toast.LENGTH_LONG).show(); refreshCurrentScreen();
                } catch (Exception error) { Toast.makeText(MainActivity.this, error.getMessage(), Toast.LENGTH_LONG).show(); }
            }
            @Override public void onError(String message) { if (announce) Toast.makeText(MainActivity.this, message, Toast.LENGTH_LONG).show(); }
        });
    }

    private String classicPlatform(String filename) {
        String extension = ClassicsRules.extension(filename).toUpperCase(Locale.ROOT);
        if ("SFC".equals(extension) || "SMC".equals(extension)) return "SUPER NINTENDO";
        if ("MD".equals(extension) || "GEN".equals(extension)) return "MEGA DRIVE";
        if ("Z64".equals(extension) || "V64".equals(extension)) return "N64";
        return extension.isEmpty() ? "CLASSICS" : extension;
    }

    private String formatClassicTime(long seconds) { return String.format(Locale.ROOT, "%d h %02d min", seconds / 3600L, (seconds % 3600L) / 60L); }

    private View localClassicArtwork(LocalClassic game, int height) {
        FrameLayout frame = new FrameLayout(this); frame.setBackground(background(Color.rgb(28, 45, 36), 5, Color.argb(95, 157, 255, 59), 1));
        TextView fallback = text(game.title, 17, TEXT, true); fallback.setGravity(Gravity.CENTER); fallback.setPadding(dp(14), dp(14), dp(14), dp(14));
        frame.addView(fallback, new FrameLayout.LayoutParams(-1, -1));
        ImageView image = new ImageView(this); image.setScaleType(ImageView.ScaleType.CENTER_CROP); image.setVisibility(View.INVISIBLE);
        frame.addView(image, new FrameLayout.LayoutParams(-1, -1));
        localArtwork.load(game, bitmap -> {
            if (isFinishing() || isDestroyed()) return;
            image.setImageBitmap(bitmap); image.setVisibility(View.VISIBLE);
        });
        return frame;
    }

    private void showBCardLibrary() {
        LinearLayout root = column();
        root.setBackgroundColor(BG);
        LinearLayout header = page();
        header.setPadding(dp(20), dp(18), dp(20), dp(13));
        header.addView(backHeader("B-CARD", this::showHome));
        header.addView(text("Escolha um jogo instalado", 25, TEXT, true), margins(-1, 21, -1, 5));
        header.addView(text("O cartão será enviado ao computador pelo canal seguro do BRUMCOMPANION.", 9, MUTED, false));
        LinearLayout categories = row();
        String[] categoryIds = {"modern", "classic"};
        String[] labels = {"JOGOS", "CLASSICS"};
        for (int i = 0; i < categoryIds.length; i++) {
            final String category = categoryIds[i];
            boolean selected = category.equals(bCardCategory);
            Button tab = filterChip(labels[i] + " · " + BCardLibrary.installed(games, category).size(), v -> {
                bCardCategory = category;
                showBCardLibrary();
            });
            tab.setSelected(selected);
            tab.setTextColor(selected ? BG : TEXT);
            tab.setBackground(background(selected ? ACCENT : RAISED, 20, LINE, 1));
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(0, dp(42), 1);
            if (i == 0) params.rightMargin = dp(10);
            categories.addView(tab, params);
        }
        header.addView(categories, margins(-1, 16, -1, 0));
        root.addView(header);

        List<Game> installed = BCardLibrary.installed(games, bCardCategory);
        if (installed.isEmpty()) {
            LinearLayout empty = column();
            empty.setGravity(Gravity.CENTER);
            empty.setPadding(dp(32), dp(42), dp(32), dp(42));
            empty.addView(text("classic".equals(bCardCategory) ? "NENHUM CLASSIC INSTALADO" : "NENHUM JOGO INSTALADO", 12, TEXT, true));
            TextView copy = text(repository.isSynchronizedLibrary()
                ? "Sincronize o launcher depois de instalar ou verificar um jogo."
                : "Conecte o celular ao launcher para receber a lista real de jogos instalados.", 10, MUTED, false);
            copy.setGravity(Gravity.CENTER);
            empty.addView(copy, margins(-1, 10, -1, 0));
            root.addView(empty, new LinearLayout.LayoutParams(-1, 0, 1));
            setScreen("bcard-list", root);
            return;
        }

        GridView grid = new GridView(this);
        grid.setNumColumns(getResources().getConfiguration().screenWidthDp >= 600 ? 3 : 2);
        grid.setHorizontalSpacing(dp(12));
        grid.setVerticalSpacing(dp(16));
        grid.setStretchMode(GridView.STRETCH_COLUMN_WIDTH);
        grid.setClipToPadding(false);
        grid.setVerticalScrollBarEnabled(false);
        grid.setPadding(dp(14), dp(10), dp(14), dp(30));
        grid.setAdapter(new BaseAdapter() {
            @Override public int getCount() { return installed.size(); }
            @Override public Game getItem(int position) { return installed.get(position); }
            @Override public long getItemId(int position) { return getItem(position).id.hashCode(); }
            @Override public View getView(int position, View convertView, ViewGroup parent) {
                Game game = getItem(position);
                LinearLayout card = column();
                card.addView(cover(game, -1, 214), new LinearLayout.LayoutParams(-1, dp(214)));
                TextView platform = text(game.platform.toUpperCase(Locale.ROOT), 7, ACCENT, true);
                platform.setLetterSpacing(.1f);
                card.addView(platform, margins(-1, 9, -1, 3));
                card.addView(text(game.title, 12, TEXT, true));
                card.addView(text("PRONTO NO COMPUTADOR", 7, MUTED, true), margins(-1, 4, -1, 0));
                card.setOnClickListener(v -> showBCard(game));
                card.setFocusable(true);
                return card;
            }
        });
        root.addView(grid, new LinearLayout.LayoutParams(-1, 0, 1));
        setScreen("bcard-list", root);
    }

    private boolean isClassicGame(Game game) {
        return "classic".equals(game.category);
    }

    private void showBCard(Game game) {
        bCardGameId = game.id;
        FrameLayout space = new FrameLayout(this);
        space.setBackground(background(BG, 0, Color.TRANSPARENT, 0));

        LinearLayout chrome = column();
        chrome.setPadding(dp(20), dp(18), dp(20), dp(18));
        chrome.addView(backHeader("B-CARD", this::showBCardLibrary));
        TextView status = text(bridgeClient.isConfigured() ? "ARRASTE O CARTÃO PARA CIMA" : "COMPUTADOR FORA DE ALCANCE", 8, bridgeClient.isConfigured() ? ACCENT : MUTED, true);
        status.setGravity(Gravity.CENTER);
        status.setLetterSpacing(.12f);
        chrome.addView(status, margins(-1, 15, -1, 0));
        space.addView(chrome, new FrameLayout.LayoutParams(-1, -2));

        final String[] launchMode = { isClassicGame(game) ? "continue-auto" : "new" };
        LinearLayout card = column();
        card.setGravity(Gravity.CENTER_HORIZONTAL);
        card.setPadding(dp(17), dp(17), dp(17), dp(18));
        card.setBackground(background(SURFACE, 12, Color.argb(100, 157, 255, 59), 1));
        card.setElevation(dp(18));
        CoverView artwork = cover(game, -1, 330);
        card.addView(artwork, new LinearLayout.LayoutParams(-1, dp(330)));
        TextView platform = text(game.platform.toUpperCase(Locale.ROOT), 8, ACCENT, true);
        platform.setLetterSpacing(.12f);
        card.addView(platform, margins(-1, 14, -1, 5));
        card.addView(text(game.title, 20, TEXT, true));
        card.addView(text(game.playedLabel() + " · " + game.genre.toUpperCase(Locale.ROOT), 8, MUTED, false), margins(-1, 6, -1, 0));

        if (isClassicGame(game)) {
            TextView selectedMode = text("CONTINUAR DO AUTOSAVE", 8, ACCENT, true);
            selectedMode.setGravity(Gravity.CENTER);
            card.addView(selectedMode, margins(-1, 14, -1, 6));
            LinearLayout modes = row();
            Button fresh = filterChip("NOVO", v -> { launchMode[0] = "new"; selectedMode.setText("NOVO JOGO"); });
            Button automatic = filterChip("AUTO", v -> { launchMode[0] = "continue-auto"; selectedMode.setText("CONTINUAR DO AUTOSAVE"); });
            Button manual = filterChip("MANUAL", v -> { launchMode[0] = "continue-manual"; selectedMode.setText("CONTINUAR DO SAVE MANUAL"); });
            modes.addView(fresh, weightedMargins(0, 0, 4, 0));
            modes.addView(automatic, weightedMargins(4, 0, 4, 0));
            modes.addView(manual, weightedMargins(4, 0, 0, 0));
            card.addView(modes);
        }

        TextView gesture = text("↑  DESLIZE E SOLTE PARA JOGAR", 8, TEXT, true);
        gesture.setGravity(Gravity.CENTER);
        gesture.setLetterSpacing(.1f);
        card.addView(gesture, margins(-1, 16, -1, 0));

        FrameLayout.LayoutParams cardParams = new FrameLayout.LayoutParams(-1, -2, Gravity.CENTER);
        cardParams.leftMargin = dp(35); cardParams.rightMargin = dp(35); cardParams.topMargin = dp(68); cardParams.bottomMargin = dp(34);
        space.addView(card, cardParams);

        final float[] downY = {0f};
        final boolean[] sending = {false};
        card.setOnTouchListener((view, event) -> {
            if (sending[0]) return true;
            if (event.getActionMasked() == MotionEvent.ACTION_DOWN) {
                downY[0] = event.getRawY();
                view.animate().cancel();
                return true;
            }
            if (event.getActionMasked() == MotionEvent.ACTION_MOVE) {
                float distance = Math.min(0f, event.getRawY() - downY[0]);
                view.setTranslationY(distance);
                view.setRotation(distance / dp(28));
                float progress = Math.min(1f, Math.abs(distance) / dp(180));
                view.setScaleX(1f - progress * .08f);
                view.setScaleY(1f - progress * .08f);
                status.setText(distance <= -dp(120) ? "SOLTE PARA JOGAR" : "CONTINUE ARRASTANDO");
                return true;
            }
            if (event.getActionMasked() == MotionEvent.ACTION_UP || event.getActionMasked() == MotionEvent.ACTION_CANCEL) {
                if (view.getTranslationY() <= -dp(120) && bridgeClient.isConfigured()) {
                    sending[0] = true;
                    view.performHapticFeedback(HapticFeedbackConstants.CONFIRM);
                    status.setText("ENVIANDO B-CARD...");
                    view.animate().translationY(-Math.max(space.getHeight(), dp(720))).rotation(7f).scaleX(.72f).scaleY(.72f).alpha(0f)
                        .setDuration(430).setInterpolator(new DecelerateInterpolator()).withEndAction(() -> {
                            status.setText("VALIDANDO NO COMPUTADOR...");
                            bridgeClient.launchBCard(game, launchMode[0], new BridgeClient.BCardCallback() {
                                @Override public void onResult(org.json.JSONObject result) {
                                    status.setText("JOGO INICIADO NO COMPUTADOR");
                                    status.setTextColor(ACCENT);
                                    Toast.makeText(MainActivity.this, result.optString("message", "Jogo iniciado."), Toast.LENGTH_LONG).show();
                                    bridgeClient.fetchSnapshot();
                                }
                                @Override public void onError(String safeMessage) {
                                    sending[0] = false;
                                    status.setText("NÃO FOI POSSÍVEL ENVIAR · TENTE NOVAMENTE");
                                    status.setTextColor(Color.rgb(255, 118, 118));
                                    view.setAlpha(1f);
                                    view.animate().translationY(0).rotation(0).scaleX(1f).scaleY(1f).setDuration(280).start();
                                    Toast.makeText(MainActivity.this, safeMessage, Toast.LENGTH_LONG).show();
                                }
                            });
                        }).start();
                } else {
                    if (!bridgeClient.isConfigured()) Toast.makeText(this, "Conecte o celular ao launcher para usar o B-CARD.", Toast.LENGTH_LONG).show();
                    status.setText(bridgeClient.isConfigured() ? "ARRASTE O CARTÃO PARA CIMA" : "COMPUTADOR FORA DE ALCANCE");
                    view.animate().translationY(0).rotation(0).scaleX(1f).scaleY(1f).alpha(1f).setDuration(240).start();
                }
                return true;
            }
            return true;
        });
        setScreen("bcard", space);
    }

    private View homeGameShelf(List<Game> source, String emptyMessage) {
        if (source.isEmpty()) {
            TextView empty = text(emptyMessage, 9, MUTED, false);
            empty.setPadding(dp(14), dp(16), dp(14), dp(16));
            empty.setBackground(background(SURFACE, 4, LINE, 1));
            return empty;
        }
        HorizontalScrollView scroll = new HorizontalScrollView(this);
        scroll.setHorizontalScrollBarEnabled(false);
        LinearLayout shelf = row();
        int count = 0;
        for (Game game : source) {
            if (count++ >= 12) break;
            shelf.addView(compactGameCard(game), margins(138, 0, 13, 0));
        }
        scroll.addView(shelf);
        return scroll;
    }

    private boolean isFavorite(Game game) {
        if (repository.isSynchronizedLibrary()) return bridgeClient.favorite(game);
        return bridgeClient.favorite(game) || repository.isFavorite(game.id);
    }

    private void showLibrary() {
        LinearLayout root = column();
        root.setBackgroundColor(BG);
        LinearLayout header = page();
        header.setPadding(dp(20), dp(18), dp(20), dp(8));
        header.addView(brandHeader("BIBLIOTECA"));
        TextView title = text("Todos os jogos", 27, TEXT, true);
        header.addView(title, margins(-1, 24, -1, 4));
        header.addView(text(games.size() + " ITENS NA BIBLIOTECA", 8, MUTED, true));
        if (!repository.isSynchronizedLibrary()) {
            header.addView(text("MODO DEMONSTRAÇÃO · CONECTE AO LAUNCHER PARA VER SEUS JOGOS", 7, ACCENT, true), margins(-1, 8, -1, 0));
        }

        EditText search = new EditText(this);
        search.setSingleLine(true);
        search.setHint("Pesquisar por nome...");
        search.setHintTextColor(Color.rgb(78, 84, 94));
        search.setTextColor(TEXT);
        search.setTextSize(12);
        search.setPadding(dp(15), 0, dp(15), 0);
        search.setBackground(background(SURFACE, 3, LINE, 1));
        search.setText(query);
        header.addView(search, margins(-1, 18, -1, 12, 46));

        HorizontalScrollView filterScroll = new HorizontalScrollView(this);
        filterScroll.setHorizontalScrollBarEnabled(false);
        LinearLayout filters = row();
        filters.addView(filterChip("PLATAFORMA · " + platformFilter, v -> chooseFilter("Plataforma", platforms(), platformFilter, value -> { platformFilter = value; showLibrary(); })));
        filters.addView(filterChip("GÊNERO · " + genreFilter, v -> chooseFilter("Gênero", genres(), genreFilter, value -> { genreFilter = value; showLibrary(); })), margins(-2, 0, 8, 0));
        filters.addView(filterChip("STATUS · " + statusFilter, v -> chooseFilter("Status", new String[]{"TODOS", "JOGANDO", "CONCLUÍDOS", "QUERO JOGAR", "ABANDONADOS"}, statusFilter, value -> { statusFilter = value; showLibrary(); })), margins(-2, 0, 8, 0));
        filters.addView(filterChip("PROGRESSO · " + progressFilter, v -> chooseFilter("Progresso", new String[]{"TODOS", "NÃO INICIADOS", "EM PROGRESSO", "100%"}, progressFilter, value -> { progressFilter = value; showLibrary(); })), margins(-2, 0, 8, 0));
        filters.addView(filterChip(favoriteOnly ? "★ FAVORITOS" : "☆ FAVORITOS", v -> { favoriteOnly = !favoriteOnly; showLibrary(); }), margins(-2, 0, 8, 0));
        filterScroll.addView(filters);
        header.addView(filterScroll);
        root.addView(header);

        FrameLayout resultsHost = new FrameLayout(this);
        root.addView(resultsHost, new LinearLayout.LayoutParams(-1, 0, 1));
        Runnable render = () -> renderLibraryResults(resultsHost);
        search.addTextChangedListener(new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int st, int c, int a) {}
            public void onTextChanged(CharSequence s, int st, int before, int count) { query = s.toString(); render.run(); }
            public void afterTextChanged(Editable e) {}
        });
        render.run();
        setScreen("library", root);
    }

    private void renderLibraryResults(FrameLayout host) {
        host.removeAllViews();
        List<Game> filtered = filteredGames();
        if (filtered.isEmpty()) {
            LinearLayout empty = column();
            empty.setGravity(Gravity.CENTER);
            empty.setPadding(dp(32), dp(32), dp(32), dp(32));
            empty.addView(text("NENHUM JOGO ENCONTRADO", 11, TEXT, true));
            TextView note = text("Ajuste a pesquisa ou remova alguns filtros.", 11, MUTED, false);
            note.setGravity(Gravity.CENTER);
            empty.addView(note, margins(-1, 9, -1, 0));
            host.addView(empty, new FrameLayout.LayoutParams(-1, -1));
            return;
        }
        GridView grid = new GridView(this);
        int columns = getResources().getConfiguration().screenWidthDp >= 600 ? 3 : 2;
        grid.setNumColumns(columns);
        grid.setHorizontalSpacing(dp(12));
        grid.setVerticalSpacing(dp(14));
        grid.setStretchMode(GridView.STRETCH_COLUMN_WIDTH);
        grid.setClipToPadding(false);
        grid.setVerticalScrollBarEnabled(false);
        grid.setPadding(dp(14), dp(14), dp(14), dp(30));
        grid.setAdapter(new BaseAdapter() {
            @Override public int getCount() { return filtered.size(); }
            @Override public Game getItem(int position) { return filtered.get(position); }
            @Override public long getItemId(int position) { return getItem(position).id.hashCode(); }
            @Override public View getView(int position, View convertView, ViewGroup parent) {
                return libraryGameCard(getItem(position));
            }
        });
        host.addView(grid, new FrameLayout.LayoutParams(-1, -1));
    }

    private List<Game> filteredGames() {
        List<Game> result = new ArrayList<>();
        String normalized = query.trim().toLowerCase(Locale.ROOT);
        for (Game game : games) {
            if (!normalized.isEmpty() && !game.title.toLowerCase(Locale.ROOT).contains(normalized)) continue;
            if (!"TODAS".equals(platformFilter) && !game.platform.toUpperCase().equals(platformFilter)) continue;
            if (!"TODOS".equals(genreFilter) && !game.genre.toUpperCase().equals(genreFilter)) continue;
            if (favoriteOnly && !isFavorite(game)) continue;
            if (!matchesStatus(game) || !matchesProgress(game)) continue;
            result.add(game);
        }
        return result;
    }

    private boolean matchesStatus(Game game) {
        if ("TODOS".equals(statusFilter)) return true;
        if ("JOGANDO".equals(statusFilter)) return game.status == Game.Status.PLAYING;
        if ("CONCLUÍDOS".equals(statusFilter)) return game.status == Game.Status.COMPLETED;
        if ("QUERO JOGAR".equals(statusFilter)) return bridgeClient.wantToPlay(game);
        return game.status == Game.Status.ABANDONED;
    }

    private boolean matchesProgress(Game game) {
        if ("TODOS".equals(progressFilter)) return true;
        if (!game.achievementsAvailable) return false;
        if ("NÃO INICIADOS".equals(progressFilter)) return game.progress == 0;
        if ("EM PROGRESSO".equals(progressFilter)) return game.progress > 0 && game.progress < 100;
        return game.progress == 100;
    }

    private View libraryGameCard(Game game) {
        LinearLayout card = column();
        CoverView cover = cover(game, -1, 226);
        card.addView(cover, new LinearLayout.LayoutParams(-1, dp(226)));
        TextView platform = text(game.platform.toUpperCase(), 7, ACCENT, true);
        platform.setLetterSpacing(.1f);
        card.addView(platform, margins(-1, 10, -1, 4));
        card.addView(text(game.title, 13, TEXT, true));
        card.addView(text(game.statusLabel() + " · " + game.progressLabel(), 8, MUTED, false), margins(-1, 4, -1, 0));
        card.setOnClickListener(v -> showDetails(game));
        card.setFocusable(true);
        return card;
    }

    private View compactGameCard(Game game) {
        LinearLayout card = column();
        card.addView(cover(game, 132, 186));
        card.addView(text(game.title, 11, TEXT, true), margins(-1, 9, -1, 3));
        card.addView(text(game.platform.toUpperCase(), 7, MUTED, true));
        card.setOnClickListener(v -> showDetails(game));
        return card;
    }

    private void showDetails(Game game) {
        if (!"details".equals(currentScreen)) detailsReturnScreen = currentScreen;
        currentGameId = game.id;
        ScrollView scroll = scroll();
        LinearLayout page = page();
        scroll.addView(page);
        page.addView(backHeader("DETALHES DO JOGO", () -> navigate(detailsReturnScreen)));

        CoverView cover = cover(game, 210, 294);
        LinearLayout.LayoutParams coverLp = margins(210, 26, -1, 0, 294);
        coverLp.gravity = Gravity.CENTER_HORIZONTAL;
        page.addView(cover, coverLp);
        TextView platform = eyebrow(game.platform.toUpperCase() + " · " + game.genre.toUpperCase());
        platform.setGravity(Gravity.CENTER);
        page.addView(platform, margins(-1, 22, -1, 8));
        TextView title = text(game.title, 29, TEXT, true);
        title.setGravity(Gravity.CENTER);
        page.addView(title);
        TextView status = text(game.statusLabel(), 8, ACCENT, true);
        status.setGravity(Gravity.CENTER);
        status.setLetterSpacing(.14f);
        page.addView(status, margins(-1, 8, -1, 22));

        page.addView(text(game.description, 13, Color.rgb(184, 188, 195), false));
        org.json.JSONObject detailNotes = bridgeClient.companionNotes(game);
        page.addView(sectionHeading("ANOTAÇÕES", "EDITAR", v -> showEditNotesDialog(game)), margins(-1, 30, -1, 10));
        if (!detailNotes.optString("whereStopped").isEmpty()) page.addView(noteCard("ONDE PAREI", detailNotes.optString("whereStopped")), margins(-1, 5, -1, 0));
        if (!detailNotes.optString("objectives").isEmpty()) page.addView(noteCard("OBJETIVOS", detailNotes.optString("objectives")), margins(-1, 5, -1, 0));
        if (!detailNotes.optString("tips").isEmpty()) page.addView(noteCard("DICAS", detailNotes.optString("tips")), margins(-1, 5, -1, 0));
        if (!detailNotes.optString("commands").isEmpty()) page.addView(noteCard("COMANDOS", detailNotes.optString("commands")), margins(-1, 5, -1, 0));
        if (detailNotes.optString("whereStopped").isEmpty() && detailNotes.optString("objectives").isEmpty() && detailNotes.optString("tips").isEmpty() && detailNotes.optString("commands").isEmpty())
            page.addView(text("Nenhuma anotação. Toque em EDITAR; funciona também fora da rede local.", 9, MUTED, false));
        if (game.achievementsAvailable) page.addView(progress(game.progress), margins(-1, 25, -1, 9));
        LinearLayout progressLegend = row();
        progressLegend.addView(text("PROGRESSO", 7, MUTED, true), new LinearLayout.LayoutParams(0, -2, 1));
        progressLegend.addView(text(game.progressLabel(), 8, ACCENT, true));
        page.addView(progressLegend);

        LinearLayout metrics = row();
        metrics.addView(metricCard(game.playedLabel(), "TEMPO JOGADO"), weightedMargins(0, 0, 6, 0));
        metrics.addView(metricCard(game.genre, "GÊNERO"), weightedMargins(6, 0, 0, 0));
        page.addView(metrics, margins(-1, 24, -1, 0));

        if (game.achievementsAvailable && !game.achievements.isEmpty()) {
            int unlocked = 0; for (Game.Achievement achievement : game.achievements) if (achievement.unlocked) unlocked++;
            page.addView(sectionHeading("CONQUISTAS · " + unlocked + "/" + game.achievements.size(), "", null), margins(-1, 32, -1, 10));
            int shown = 0;
            for (Game.Achievement achievement : game.achievements) {
                if (shown++ >= 12) break;
                LinearLayout achievementRow = row();
                achievementRow.setGravity(Gravity.CENTER_VERTICAL);
                achievementRow.setPadding(dp(13), dp(13), dp(13), dp(13));
                achievementRow.setBackground(background(SURFACE, 3, LINE, 1));
                TextView symbol = text(achievement.unlocked ? "◆" : "◇", 15, achievement.unlocked ? ACCENT : MUTED, true);
                achievementRow.addView(symbol, new LinearLayout.LayoutParams(dp(30), -2));
                LinearLayout achievementCopy = column();
                achievementCopy.addView(text(achievement.title, 11, achievement.unlocked ? TEXT : MUTED, true));
                if (!achievement.description.isEmpty()) achievementCopy.addView(text(achievement.description, 8, MUTED, false), margins(-1, 4, -1, 0));
                achievementRow.addView(achievementCopy, new LinearLayout.LayoutParams(0, -2, 1));
                if (achievement.points > 0) achievementRow.addView(text(achievement.points + " PTS", 7, achievement.unlocked ? ACCENT : MUTED, true));
                page.addView(achievementRow, margins(-1, 5, -1, 0));
            }
        } else if (!game.achievementsAvailable) {
            page.addView(sectionHeading("CONQUISTAS", "", null), margins(-1, 32, -1, 10));
            page.addView(text("INDISPONÍVEL · A loja não forneceu um progresso verificável para este jogo.", 9, MUTED, false));
        }

        boolean favored = isFavorite(game);
        Button favorite = primaryButton(favored ? "★ REMOVER DOS FAVORITOS" : "☆ ADICIONAR AOS FAVORITOS");
        favorite.setOnClickListener(v -> {
            favorite.setEnabled(false);
            bridgeClient.saveFavorite(game, !favored, false, (state, message) -> {
                Toast.makeText(this, message, Toast.LENGTH_LONG).show();
                if ("conflict".equals(state)) new AlertDialog.Builder(this).setTitle("Favorito alterado nos dois dispositivos")
                    .setMessage("Escolha manter a decisão feita no celular ou recarregar a escolha do launcher.")
                    .setPositiveButton("MANTER CELULAR", (d, w) -> bridgeClient.saveFavorite(game, !favored, true, (result, detail) -> { Toast.makeText(this, detail, Toast.LENGTH_LONG).show(); showDetails(game); }))
                    .setNegativeButton("USAR LAUNCHER", (d, w) -> { bridgeClient.discardLibraryState(game.id); showDetails(game); })
                    .setNeutralButton("CANCELAR", null).show();
                else showDetails(game);
            });
        });
        page.addView(favorite, margins(-1, 24, -1, 0, 50));
        boolean wants = bridgeClient.wantToPlay(game);
        Button want = button(wants ? "✓ NA LISTA QUERO JOGAR" : "+ QUERO JOGAR ESTE JOGO");
        want.setTextSize(8); want.setLetterSpacing(.1f); want.setTextColor(wants ? Color.rgb(8, 11, 8) : ACCENT);
        want.setBackground(background(wants ? ACCENT : SURFACE, 3, ACCENT, 1));
        want.setOnClickListener(v -> {
            want.setEnabled(false);
            bridgeClient.saveWantToPlay(game, !wants, false, (state, message) -> {
                Toast.makeText(this, message, Toast.LENGTH_LONG).show();
                if ("conflict".equals(state)) new AlertDialog.Builder(this).setTitle("Lista alterada nos dois dispositivos")
                    .setMessage("Escolha manter a decisão feita no celular ou recarregar a escolha do launcher.")
                    .setPositiveButton("MANTER CELULAR", (d, w) -> bridgeClient.saveWantToPlay(game, !wants, true, (result, detail) -> { Toast.makeText(this, detail, Toast.LENGTH_LONG).show(); showDetails(game); }))
                    .setNegativeButton("USAR LAUNCHER", (d, w) -> { bridgeClient.discardLibraryState(game.id); showDetails(game); })
                    .setNeutralButton("CANCELAR", null).show();
                else showDetails(game);
            });
        });
        page.addView(want, margins(-1, 8, -1, 0, 50));
        TextView future = text("DADOS SINCRONIZADOS PELO BRUMCLASSICS OFICIAL", 7, MUTED, true);
        future.setGravity(Gravity.CENTER);
        future.setLetterSpacing(.11f);
        page.addView(future, margins(-1, 15, -1, 28));
        setScreen("details", scroll);
    }

    private void showStats() {
        ScrollView scroll = scroll();
        LinearLayout page = page();
        scroll.addView(page);
        page.addView(brandHeader("ESTATÍSTICAS"));
        page.addView(text("Sua jornada", 29, TEXT, true), margins(-1, 26, -1, 5));
        page.addView(text("Um retrato da biblioteca demonstrativa neste dispositivo.", 11, MUTED, false));

        LinearLayout first = row();
        first.addView(metricCard(String.valueOf(games.size()), "JOGOS"), weightedMargins(0, 0, 6, 0));
        first.addView(metricCard(totalHours() + " h", "HORAS JOGADAS"), weightedMargins(6, 0, 0, 0));
        page.addView(first, margins(-1, 26, -1, 0));
        LinearLayout second = row();
        second.addView(metricCard(String.valueOf(countStatus(Game.Status.COMPLETED)), "CONCLUÍDOS"), weightedMargins(0, 0, 6, 0));
        second.addView(metricCard(averageProgress() + "%", "PROGRESSO MÉDIO"), weightedMargins(6, 0, 0, 0));
        page.addView(second, margins(-1, 12, -1, 0));
        List<LocalClassic> phoneClassics = classicsRepository.all();
        long localSeconds = 0; for (LocalClassic game : phoneClassics) localSeconds += game.creditedSeconds;
        if (!phoneClassics.isEmpty()) {
            page.addView(sectionHeading("CLASSICS NO ANDROID", "ABRIR", v -> showClassics()), margins(-1, 30, -1, 12));
            LinearLayout local = row();
            local.addView(metricCard(String.valueOf(phoneClassics.size()), "ROMS LOCAIS"), weightedMargins(0, 0, 6, 0));
            local.addView(metricCard(formatClassicTime(localSeconds), "TEMPO LOCAL"), weightedMargins(6, 0, 0, 0));
            page.addView(local);
        }

        org.json.JSONObject sessionSummary = experience.optJSONObject("sessions") == null ? new org.json.JSONObject() : experience.optJSONObject("sessions").optJSONObject("summary");
        org.json.JSONObject achievementSummary = experience.optJSONObject("achievements") == null ? new org.json.JSONObject() : experience.optJSONObject("achievements");
        page.addView(sectionHeading("ESTADO AO VIVO", "", null), margins(-1, 34, -1, 14));
        LinearLayout live = row();
        int activeSessions = sessionSummary == null ? 0 : sessionSummary.optInt("active", 0);
        int completedSessions = sessionSummary == null ? 0 : sessionSummary.optInt("completed", 0);
        live.addView(metricCard(String.valueOf(activeSessions), "SESSÕES ATIVAS"), weightedMargins(0, 0, 6, 0));
        live.addView(metricCard(String.valueOf(completedSessions), "SESSÕES CONCLUÍDAS"), weightedMargins(6, 0, 0, 0));
        page.addView(live);
        org.json.JSONObject nextCompletion = achievementSummary.optJSONObject("nextCompletion");
        if (nextCompletion != null) {
            LinearLayout target = column(); target.setPadding(dp(14), dp(14), dp(14), dp(14)); target.setBackground(background(SURFACE, 4, LINE, 1));
            target.addView(eyebrow("PRÓXIMO 100%"));
            target.addView(text(nextCompletion.optString("gameTitle", "Jogo"), 14, TEXT, true), margins(-1, 7, -1, 3));
            target.addView(text(nextCompletion.optInt("percent", 0) + "% · faltam " + nextCompletion.optInt("remaining", 0) + " conquistas", 9, ACCENT, true));
            page.addView(target, margins(-1, 10, -1, 0));
        }

        page.addView(sectionHeading("DISTRIBUIÇÃO POR PLATAFORMA", "", null), margins(-1, 34, -1, 18));
        for (String platform : uniquePlatforms()) {
            int count = countPlatform(platform);
            LinearLayout legend = row();
            legend.addView(text(platform.toUpperCase(), 8, TEXT, true), new LinearLayout.LayoutParams(0, -2, 1));
            legend.addView(text(count + " JOGO" + (count == 1 ? "" : "S"), 7, MUTED, true));
            page.addView(legend);
            page.addView(progress(Math.round(count * 100f / games.size())), margins(-1, 8, -1, 17));
        }
        page.addView(space(24));
        setScreen("stats", scroll);
    }

    private void showProfile() {
        ScrollView scroll = scroll();
        LinearLayout page = page();
        scroll.addView(page);
        page.addView(brandHeader("PERFIL"));

        LinearLayout identity = row();
        identity.setGravity(Gravity.CENTER_VERTICAL);
        ImageView avatar = new ImageView(this);
        avatar.setImageResource(com.brumclassics.mobile.R.drawable.ic_launcher);
        avatar.setBackground(background(SURFACE, 40, LINE, 1));
        identity.addView(avatar, new LinearLayout.LayoutParams(dp(70), dp(70)));
        LinearLayout name = column();
        name.setPadding(dp(16), 0, 0, 0);
        name.addView(text("JOGADOR LOCAL", 18, TEXT, true));
        name.addView(text(repository.isSynchronizedLibrary() ? "BIBLIOTECA SINCRONIZADA" : "PERFIL DE DEMONSTRAÇÃO", 7, ACCENT, true), margins(-1, 5, -1, 0));
        identity.addView(name, new LinearLayout.LayoutParams(0, -2, 1));
        page.addView(identity, margins(-1, 28, -1, 30));

        page.addView(sectionHeading("CONFIGURAÇÕES", "", null));
        page.addView(settingToggle("ANIMAÇÕES SUAVES", "Transições curtas inspiradas no launcher oficial", true), margins(-1, 14, -1, 0));
        page.addView(settingToggle("BIBLIOTECA OFFLINE", "Capas, conquistas e estatísticas ficam salvas automaticamente", true, false));
        page.addView(settingToggle("NOTIFICAÇÕES", "Novidades e atividade da biblioteca", true));

        page.addView(sectionHeading("INTEGRAÇÃO", "", null), margins(-1, 34, -1, 14));
        LinearLayout integration = column();
        integration.setPadding(dp(16), dp(16), dp(16), dp(16));
        integration.setBackground(background(SURFACE, 4, LINE, 1));
        integration.addView(eyebrow("LAUNCHER BRUMCLASSICS"));
        boolean configured = bridgeClient.isConfigured();
        integration.addView(text(configured ? "Launcher interligado" : "Conecte ao seu computador", 15, TEXT, true), margins(-1, 8, -1, 5));
        integration.addView(text(configured ? bridgeClient.endpointLabel() + " · " + syncDetail : "Use o código temporário exibido em Configurações → MOVEL.", 10, MUTED, false));
        if (repository.isSynchronizedLibrary()) integration.addView(text(bridgeClient.offlineSummary(), 8, MUTED, false), margins(-1, 7, -1, 0));
        TextView offline = text("●  " + (configured ? syncState.toUpperCase(Locale.ROOT) : "DADOS DEMONSTRATIVOS"), 7, "connected".equals(syncState) ? ACCENT : MUTED, true);
        offline.setLetterSpacing(.1f);
        integration.addView(offline, margins(-1, 14, -1, 0));
        Button bridgeAction = primaryButton(configured ? "SINCRONIZAR AGORA" : "CONECTAR AO LAUNCHER");
        bridgeAction.setOnClickListener(v -> { if (configured) bridgeClient.fetchSnapshot(); else showPairDialog("", 46991, "", ""); });
        integration.addView(bridgeAction, margins(-1, 15, -1, 0, 46));
        if (configured) {
            Button disconnect = button("DESCONECTAR ESTE CELULAR");
            disconnect.setTextSize(7); disconnect.setLetterSpacing(.1f); disconnect.setTextColor(MUTED);
            disconnect.setBackgroundColor(Color.TRANSPARENT);
            disconnect.setOnClickListener(v -> bridgeClient.disconnect(new BridgeClient.PairCallback() {
                public void onSuccess() { syncState = "offline"; syncDetail = "Dados locais"; showProfile(); }
                public void onError(String error) { Toast.makeText(MainActivity.this, error, Toast.LENGTH_LONG).show(); }
            }));
            integration.addView(disconnect, margins(-1, 8, -1, 0, 40));
        }
        page.addView(integration);
        page.addView(sectionHeading("CLASSICS NO ANDROID", "", null), margins(-1, 30, -1, 12));
        LinearLayout classicsSettings = column(); classicsSettings.setPadding(dp(16), dp(16), dp(16), dp(16)); classicsSettings.setBackground(background(SURFACE, 4, LINE, 1));
        classicsSettings.addView(eyebrow("RETROARCH · RETROACHIEVEMENTS"));
        classicsSettings.addView(text(classicsRepository.romFolderConfigured() ? classicsRepository.all().size() + " ROM(s) em " + classicsRepository.romFolderName() : "Selecione sua pasta de ROMs", 14, TEXT, true), margins(-1, 8, -1, 5));
        classicsSettings.addView(text("Abertura direta, horas offline, capas do launcher e conquistas oficiais.", 9, MUTED, false));
        Button configureClassics = primaryButton("CONFIGURAR CLASSICS"); configureClassics.setOnClickListener(v -> showClassicSettings());
        classicsSettings.addView(configureClassics, margins(-1, 14, -1, 0, 46)); page.addView(classicsSettings);
        page.addView(sectionHeading("ATUALIZAÇÕES", "", null), margins(-1, 30, -1, 12));
        LinearLayout updateCard = column();
        updateCard.setPadding(dp(16), dp(16), dp(16), dp(16));
        updateCard.setBackground(background(SURFACE, 4, LINE, 1));
        String updateHeading = mobileUpdate == null ? "BRUMCLASSICS MOVEL " + MobileUpdateManager.CURRENT_VERSION : "NOVA VERSÃO " + mobileUpdate.version;
        updateCard.addView(eyebrow("ATUALIZAÇÃO DO APLICATIVO"));
        updateCard.addView(text(updateHeading, 14, TEXT, true), margins(-1, 8, -1, 5));
        updateCard.addView(text(mobileUpdateDetail, 9, MUTED, false));
        if ("downloading".equals(mobileUpdateState) || "ready".equals(mobileUpdateState) || "permission".equals(mobileUpdateState)) {
            updateCard.addView(progress(mobileUpdatePercent), margins(-1, 13, -1, 0));
        }
        if (mobileUpdate != null) {
            String source = "github".equals(mobileUpdate.source) ? "GITHUB OFICIAL" : "REDE LOCAL";
            updateCard.addView(text(source + " · " + formatMegabytes(mobileUpdate.size) + " · SHA-256 VERIFICADO", 7, ACCENT, true), margins(-1, 10, -1, 0));
            if (!mobileUpdate.notes.trim().isEmpty()) updateCard.addView(text(mobileUpdate.notes, 8, MUTED, false), margins(-1, 8, -1, 0));
        }
        Button updateAction = primaryButton(mobileUpdate == null ? "VERIFICAR AGORA" : "ATUALIZAR");
        updateAction.setEnabled(!"checking".equals(mobileUpdateState) && !"downloading".equals(mobileUpdateState));
        updateAction.setOnClickListener(v -> {
            if (mobileUpdate == null) updateManager.check(true); else updateManager.downloadAndInstall();
        });
        updateCard.addView(updateAction, margins(-1, 15, -1, 0, 46));
        updateCard.addView(text("O Android sempre pedirá sua confirmação antes de instalar. Biblioteca offline, capas e anotações permanecem no aparelho.", 7, MUTED, false), margins(-1, 10, -1, 0));
        page.addView(updateCard);
        page.addView(text("BRUMCLASSICS MOVEL · " + MobileUpdateManager.DISPLAY_VERSION, 7, Color.rgb(66, 71, 80), true), margins(-1, 32, -1, 28));
        setScreen("profile", scroll);
    }

    private void handleBackNavigation() {
        if ("loading".equals(currentScreen)) return;
        if ("details".equals(currentScreen)) {
            navigate(detailsReturnScreen);
        } else if ("moments".equals(currentScreen)) {
            showCompanion();
        } else if ("bcard".equals(currentScreen)) {
            showBCardLibrary();
        } else if ("bcard-list".equals(currentScreen)) {
            showHome();
        } else if ("classic-details".equals(currentScreen)) {
            showClassics();
        } else if ("classics".equals(currentScreen)) {
            showHome();
        } else if ("classic-settings".equals(currentScreen)) {
            showProfile();
        } else if ("library".equals(currentScreen) && !query.trim().isEmpty()) {
            query = "";
            showLibrary();
        } else if ("library".equals(currentScreen) && (!"TODAS".equals(platformFilter) || !"TODOS".equals(genreFilter) || !"TODOS".equals(statusFilter) || !"TODOS".equals(progressFilter) || favoriteOnly)) {
            platformFilter = "TODAS";
            genreFilter = "TODOS";
            statusFilter = "TODOS";
            progressFilter = "TODOS";
            favoriteOnly = false;
            showLibrary();
        } else if (!"home".equals(currentScreen) && !"loading".equals(currentScreen)) {
            showHome();
        } else {
            long now = SystemClock.elapsedRealtime();
            if (now - lastRootBackAt <= 1800L) {
                finishAndRemoveTask();
                return;
            }
            lastRootBackAt = now;
            Toast.makeText(this, "Pressione novamente para sair", Toast.LENGTH_SHORT).show();
        }
    }

    @Override public void onBackPressed() {
        handleBackNavigation();
    }

    private View brandHeader(String section) {
        LinearLayout bar = row();
        bar.setGravity(Gravity.CENTER_VERTICAL);
        ImageView mark = new ImageView(this);
        mark.setImageResource(com.brumclassics.mobile.R.drawable.ic_launcher);
        bar.addView(mark, new LinearLayout.LayoutParams(dp(31), dp(31)));
        TextView brand = text("BRUMCLASSICS", 12, TEXT, true);
        brand.setLetterSpacing(.08f);
        bar.addView(brand, margins(-2, 8, 0, 0));
        Space spacer = new Space(this);
        bar.addView(spacer, new LinearLayout.LayoutParams(0, 1, 1));
        TextView label = text(section, 7, MUTED, true);
        label.setLetterSpacing(.16f);
        bar.addView(label);
        return bar;
    }

    private View backHeader(String label, Runnable onBack) {
        LinearLayout bar = row();
        bar.setGravity(Gravity.CENTER_VERTICAL);
        Button back = button("‹");
        back.setTextSize(28);
        back.setTextColor(ACCENT);
        back.setBackgroundColor(Color.TRANSPARENT);
        back.setPadding(0, 0, dp(13), 0);
        back.setOnClickListener(v -> onBack.run());
        bar.addView(back, new LinearLayout.LayoutParams(dp(42), dp(44)));
        TextView text = text(label, 8, MUTED, true);
        text.setLetterSpacing(.16f);
        bar.addView(text);
        return bar;
    }

    private View sectionHeading(String title, String action, View.OnClickListener listener) {
        LinearLayout line = row();
        line.setGravity(Gravity.CENTER_VERTICAL);
        TextView heading = text(title, 8, MUTED, true);
        heading.setLetterSpacing(.17f);
        line.addView(heading, new LinearLayout.LayoutParams(0, -2, 1));
        if (!action.isEmpty()) {
            Button button = button(action);
            button.setTextSize(7);
            button.setTextColor(ACCENT);
            button.setLetterSpacing(.1f);
            button.setBackgroundColor(Color.TRANSPARENT);
            button.setOnClickListener(listener);
            line.addView(button);
        }
        return line;
    }

    private View metricCard(String value, String label) {
        LinearLayout card = column();
        card.setPadding(dp(14), dp(15), dp(14), dp(15));
        card.setBackground(background(SURFACE, 4, LINE, 1));
        card.addView(text(value, value.length() > 12 ? 14 : 23, TEXT, true));
        TextView small = text(label, 7, MUTED, true);
        small.setLetterSpacing(.13f);
        card.addView(small, margins(-1, 7, -1, 0));
        return card;
    }

    private View noteCard(String label, String value) {
        LinearLayout card = column();
        card.setPadding(dp(13), dp(12), dp(13), dp(12));
        card.setBackground(background(SURFACE, 3, LINE, 1));
        TextView heading = text(label, 7, ACCENT, true);
        heading.setLetterSpacing(.12f);
        card.addView(heading);
        card.addView(text(value, 10, Color.rgb(202, 205, 211), false), margins(-1, 6, -1, 0));
        return card;
    }

    private View settingToggle(String title, String subtitle, boolean checked) {
        return settingToggle(title, subtitle, checked, true);
    }

    private View settingToggle(String title, String subtitle, boolean checked, boolean enabled) {
        LinearLayout item = row();
        item.setGravity(Gravity.CENTER_VERTICAL);
        item.setPadding(0, dp(16), 0, dp(16));
        item.setBackground(background(Color.TRANSPARENT, 0, LINE, 1));
        LinearLayout copy = column();
        copy.addView(text(title, 10, TEXT, true));
        copy.addView(text(subtitle, 9, MUTED, false), margins(-1, 4, -1, 0));
        item.addView(copy, new LinearLayout.LayoutParams(0, -2, 1));
        Switch toggle = new Switch(this);
        toggle.setChecked(checked);
        toggle.setEnabled(enabled);
        toggle.setButtonTintList(null);
        item.addView(toggle);
        return item;
    }

    private Button filterChip(String label, View.OnClickListener listener) {
        Button chip = button(label);
        chip.setTextSize(7);
        chip.setLetterSpacing(.08f);
        chip.setTextColor(TEXT);
        chip.setPadding(dp(13), 0, dp(13), 0);
        chip.setBackground(background(RAISED, 20, LINE, 1));
        chip.setOnClickListener(listener);
        chip.setLayoutParams(new LinearLayout.LayoutParams(-2, dp(38)));
        return chip;
    }

    private void chooseFilter(String title, String[] options, String selected, ValueCallback callback) {
        int checked = 0;
        for (int i = 0; i < options.length; i++) if (options[i].equals(selected)) checked = i;
        AlertDialog dialog = new AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert)
            .setTitle(title.toUpperCase())
            .setSingleChoiceItems(options, checked, (d, which) -> { callback.accept(options[which]); d.dismiss(); })
            .setNegativeButton("CANCELAR", null)
            .create();
        dialog.setOnShowListener(d -> {
            dialog.getWindow().setBackgroundDrawable(background(RAISED, 4, LINE, 1));
            dialog.getButton(AlertDialog.BUTTON_NEGATIVE).setTextColor(ACCENT);
        });
        dialog.show();
    }

    private String[] platforms() {
        Set<String> values = new LinkedHashSet<>(); values.add("TODAS");
        for (Game game : games) values.add(game.platform.toUpperCase());
        return values.toArray(new String[0]);
    }

    private String[] genres() {
        Set<String> values = new LinkedHashSet<>(); values.add("TODOS");
        for (Game game : games) values.add(game.genre.toUpperCase());
        return values.toArray(new String[0]);
    }

    private int totalHours() { int minutes = 0; for (Game game : games) if (game.playtimeAvailable) minutes += game.minutesPlayed; return minutes / 60; }
    private int countStatus(Game.Status status) { int n = 0; for (Game game : games) if (game.status == status) n++; return n; }
    private int averageProgress() { int n = 0, available = 0; for (Game game : games) if (game.achievementsAvailable) { n += game.progress; available++; } return available == 0 ? 0 : Math.round(n / (float) available); }
    private Set<String> uniquePlatforms() { Set<String> set = new LinkedHashSet<>(); for (Game game : games) set.add(game.platform); return set; }
    private int countPlatform(String platform) { int n = 0; for (Game game : games) if (game.platform.equals(platform)) n++; return n; }
    private String formatMegabytes(long bytes) { return String.format(Locale.ROOT, "%.1f MB", bytes / (1024d * 1024d)); }

    private CoverView cover(Game game, int width, int height) {
        CoverView cover = new CoverView(this);
        cover.setGame(game);
        if (bridgeClient != null && !game.artworkPath.isEmpty()) {
            cover.setArtworkRequest(() -> bridgeClient.loadArtwork(game, cover::setArtworkBitmap));
        }
        cover.setLayoutParams(new LinearLayout.LayoutParams(width < 0 ? width : dp(width), dp(height)));
        return cover;
    }

    private List<Game> startupArtworkGames() {
        List<Game> priority = new ArrayList<>();
        if (!games.isEmpty()) priority.add(games.get(0));
        for (Game game : games) {
            if (priority.size() >= 4) break;
            if (game.recent && !priority.contains(game)) priority.add(game);
        }
        return priority;
    }

    private ProgressBar progress(int value) {
        ProgressBar bar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        bar.setMax(100);
        bar.setProgress(value);
        bar.setProgressTintList(android.content.res.ColorStateList.valueOf(ACCENT));
        bar.setProgressBackgroundTintList(android.content.res.ColorStateList.valueOf(Color.rgb(43, 47, 54)));
        bar.setLayoutParams(new LinearLayout.LayoutParams(-1, dp(3)));
        return bar;
    }

    private TextView eyebrow(String value) {
        TextView view = text(value, 7, ACCENT, true);
        view.setLetterSpacing(.15f);
        return view;
    }

    private TextView text(String value, int sp, int color, boolean bold) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(sp);
        view.setTextColor(color);
        view.setTypeface(Typeface.create("sans", bold ? Typeface.BOLD : Typeface.NORMAL));
        view.setLineSpacing(dp(2), 1f);
        return view;
    }

    private Button button(String value) {
        Button view = new Button(this);
        view.setText(value);
        view.setAllCaps(false);
        view.setTypeface(Typeface.create("sans", Typeface.BOLD));
        view.setStateListAnimator(null);
        view.setMinHeight(0); view.setMinWidth(0);
        return view;
    }

    private Button primaryButton(String value) {
        Button view = button(value);
        view.setTextSize(8);
        view.setLetterSpacing(.12f);
        view.setTextColor(Color.rgb(8, 11, 8));
        view.setBackground(background(ACCENT, 3, Color.TRANSPARENT, 0));
        return view;
    }

    private LinearLayout page() {
        LinearLayout page = column();
        page.setPadding(dp(20), dp(18), dp(20), 0);
        return page;
    }

    private LinearLayout row() { LinearLayout v = new LinearLayout(this); v.setOrientation(LinearLayout.HORIZONTAL); return v; }
    private LinearLayout column() { LinearLayout v = new LinearLayout(this); v.setOrientation(LinearLayout.VERTICAL); return v; }
    private ScrollView scroll() { ScrollView s = new ScrollView(this); s.setFillViewport(true); s.setVerticalScrollBarEnabled(false); s.setBackgroundColor(BG); return s; }
    private Space space(int height) { Space s = new Space(this); s.setLayoutParams(new LinearLayout.LayoutParams(1, dp(height))); return s; }

    private GradientDrawable background(int color, int radiusDp, int strokeColor, int strokeDp) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(dp(radiusDp));
        if (strokeDp > 0) drawable.setStroke(dp(strokeDp), strokeColor);
        return drawable;
    }

    private LinearLayout.LayoutParams margins(int width, int top, int right, int bottom) { return margins(width, top, right, bottom, -2); }
    private LinearLayout.LayoutParams margins(int width, int top, int right, int bottom, int height) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(width < 0 ? width : dp(width), height < 0 ? height : dp(height));
        lp.setMargins(0, dp(top), right < 0 ? 0 : dp(right), dp(bottom));
        return lp;
    }
    private LinearLayout.LayoutParams weightedMargins(int left, int top, int right, int bottom) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, -2, 1);
        lp.setMargins(dp(left), dp(top), dp(right), dp(bottom));
        return lp;
    }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }
    private interface ValueCallback { void accept(String value); }

    private void handlePairingIntent(Intent intent) {
        Uri data = intent == null ? null : intent.getData();
        if (data == null || !"brumclassics".equals(data.getScheme()) || !"pair".equals(data.getHost())) return;
        String host = data.getQueryParameter("host");
        String code = data.getQueryParameter("code");
        String pin = data.getQueryParameter("pin");
        int port = 46991;
        try { port = Integer.parseInt(data.getQueryParameter("port")); } catch (Exception ignored) {}
        intent.setData(null);
        showPairDialog(host == null ? "" : host, port, code == null ? "" : code, pin == null ? "" : pin);
    }

    private void showPairDialog(String hostValue, int portValue, String codeValue, String pinValue) {
        LinearLayout form = column();
        form.setPadding(dp(22), dp(8), dp(22), 0);
        TextView note = text("O computador e o celular precisam estar na mesma rede Wi-Fi.", 10, MUTED, false);
        form.addView(note, margins(-1, 0, -1, 15));
        EditText host = pairingField("Endereço do computador", hostValue);
        EditText port = pairingField("Porta", String.valueOf(portValue));
        port.setInputType(android.text.InputType.TYPE_CLASS_NUMBER);
        EditText code = pairingField("Código de 6 números", codeValue);
        code.setInputType(android.text.InputType.TYPE_CLASS_NUMBER);
        EditText pin = pairingField("Impressão TLS do launcher", pinValue);
        form.addView(host, margins(-1, 0, -1, 9, 48));
        form.addView(port, margins(-1, 0, -1, 9, 48));
        form.addView(code, margins(-1, 0, -1, 9, 48));
        form.addView(pin, margins(-1, 0, -1, 0, 48));
        AlertDialog dialog = new AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert)
            .setTitle("CONECTAR AO LAUNCHER")
            .setView(form)
            .setNegativeButton("CANCELAR", null)
            .setPositiveButton("CONECTAR", null)
            .create();
        dialog.setOnShowListener(ignored -> {
            dialog.getWindow().setBackgroundDrawable(background(RAISED, 4, LINE, 1));
            dialog.getButton(AlertDialog.BUTTON_NEGATIVE).setTextColor(MUTED);
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setTextColor(ACCENT);
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v -> {
                int selectedPort;
                try { selectedPort = Integer.parseInt(port.getText().toString()); } catch (Exception error) { port.setError("Porta inválida"); return; }
                dialog.getButton(AlertDialog.BUTTON_POSITIVE).setEnabled(false);
                bridgeClient.pair(host.getText().toString(), selectedPort, code.getText().toString(), pin.getText().toString(), new BridgeClient.PairCallback() {
                    public void onSuccess() { dialog.dismiss(); syncState = "connecting"; syncDetail = bridgeClient.endpointLabel(); showProfile(); }
                    public void onError(String error) { dialog.getButton(AlertDialog.BUTTON_POSITIVE).setEnabled(true); code.setError(error); }
                });
            });
        });
        dialog.show();
    }

    private EditText pairingField(String hint, String value) {
        EditText field = new EditText(this);
        field.setSingleLine(true); field.setHint(hint); field.setText(value);
        field.setTextColor(TEXT); field.setHintTextColor(Color.rgb(78, 84, 94)); field.setTextSize(11);
        field.setPadding(dp(13), 0, dp(13), 0); field.setBackground(background(SURFACE, 3, LINE, 1));
        return field;
    }
}
