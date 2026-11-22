package com.brumclassics.mobile.emulation;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ColorFilter;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.text.TextUtils;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.net.URL;
import java.util.ArrayDeque;
import java.util.Collections;
import java.util.HashSet;
import java.util.Locale;
import java.util.Queue;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * BRUM CLASSICS achievement overlay conforming to the mandatory dark charcoal & neon-green mold.
 * Non-focusable and touch-transparent over gameplay, with strict eventId deduplication.
 */
public final class BrumAchievementOverlay {
    public static final class Payload {
        public final String eventId;
        public final String achievementId;
        public final String eyebrow;
        public final String title;
        public final String description;
        public final int points;
        public final String pillText;
        public final String badgeUrl;
        public final int pokedexNationalDexNumber;
        public final boolean isShinyDiscovery;

        public Payload(String eventId, String achievementId, String title, String description, int points, String badgeUrl) {
            this(eventId, achievementId, "CONQUISTA DESBLOQUEADA", title, description, points, "", badgeUrl, 0, false);
        }

        public Payload(
                String eventId,
                String achievementId,
                String eyebrow,
                String title,
                String description,
                int points,
                String pillText,
                String badgeUrl,
                int pokedexNationalDexNumber,
                boolean isShinyDiscovery
        ) {
            BrumAchievementModel.Payload normalized = new BrumAchievementModel.Payload(eventId, achievementId, title, description, points, badgeUrl);
            this.achievementId = normalized.achievementId;
            this.eventId = normalized.eventId;
            String cleanEyebrow = eyebrow == null ? "" : eyebrow.trim();
            this.eyebrow = cleanEyebrow.isEmpty() ? "CONQUISTA DESBLOQUEADA" : cleanEyebrow;
            this.title = normalized.title;
            this.description = normalized.description;
            this.points = normalized.points;
            this.pillText = pillText == null ? "" : pillText.trim();
            this.badgeUrl = normalized.badgeUrl;
            this.pokedexNationalDexNumber = Math.max(0, pokedexNationalDexNumber);
            this.isShinyDiscovery = isShinyDiscovery;
        }

        public static String sanitizeBadgeUrl(String raw) {
            return BrumAchievementModel.sanitizeBadgeUrl(raw);
        }

        public static Payload fromBridgeEvent(JSONObject payload) {
            if (payload == null) return null;
            JSONObject ach = payload.optJSONObject("achievement");
            if (ach == null) ach = payload;
            String title = ach.optString("title", "").trim();
            if (title.isEmpty()) return null;
            String id = ach.optString("id", ach.optString("achievementId", "")).trim();
            String gameId = payload.optString("gameId", ach.optString("gameId", "")).trim();
            String eventId = ach.optString("eventId", payload.optString("eventId", "")).trim();
            if (eventId.isEmpty() && !id.isEmpty()) {
                eventId = "ra:" + gameId + ":" + id;
            }
            String desc = ach.optString("description", "").trim();
            int pts = Math.max(0, ach.optInt("points", 0));
            String badge = ach.optString("badgeUrl", ach.optString("badge", ""));
            return new Payload(eventId, id, title, desc, pts, badge);
        }

        public static Payload fromPokedexBridgeEvent(JSONObject payload) {
            if (payload == null) return null;
            JSONObject disc = payload.optJSONObject("discovery");
            if (disc == null) disc = payload;
            int dex = disc.optInt("nationalDexNumber", 0);
            if (dex < 1 || dex > 802) return null;
            boolean isShiny = disc.optBoolean("isShiny", "shiny".equalsIgnoreCase(disc.optString("category", "")));
            String formatted = disc.optString("formattedNumber", String.format(Locale.ROOT, "%03d", dex));
            String species = disc.optString("speciesName", "Pokémon #" + formatted);
            String headline = disc.optString("headline", formatted + " — " + species);
            String gameTitle = disc.optString("gameTitle", "Brum Classics");
            String subtitle = disc.optString("subtitle", "Registrado na Pokédex Universal");
            String eventId = disc.optString("eventId", payload.optString("eventId", "pokedex-discovery:primary:" + dex + ":" + (isShiny ? "shiny" : "normal")));
            String eyebrow = isShiny ? "✦ NOVO POKÉMON SHINY DESCOBERTO!" : "NOVO POKÉMON DESCOBERTO!";
            String pill = isShiny ? "✦ SHINY" : "#" + formatted;
            return new Payload(
                    eventId,
                    "pokedex:" + dex + ":" + (isShiny ? "shiny" : "normal"),
                    eyebrow,
                    headline,
                    gameTitle + " · " + subtitle,
                    0,
                    pill,
                    "",
                    dex,
                    isShiny
            );
        }

        public static Payload fromPokedexNotification(com.brumclassics.mobile.extensions.PokedexUniversalEngine.DiscoveryNotification note) {
            if (note == null) return null;
            boolean isShiny = note.isShiny;
            String eyebrow = isShiny ? "✦ NOVO POKÉMON SHINY DESCOBERTO!" : "NOVO POKÉMON DESCOBERTO!";
            String pill = isShiny ? "✦ SHINY" : "#" + note.formattedNumber;
            return new Payload(
                    note.eventId,
                    "pokedex:" + note.nationalDexNumber + ":" + note.category,
                    eyebrow,
                    note.headline,
                    note.gameTitle + " · " + note.subtitle,
                    0,
                    pill,
                    "",
                    note.nationalDexNumber,
                    isShiny
            );
        }
    }

    private static final int COLOR_CHARCOAL = Color.rgb(9, 13, 14);
    private static final int COLOR_BORDER = Color.rgb(53, 65, 63);
    private static final int COLOR_NEON_GREEN = Color.rgb(157, 255, 59);
    private static final int COLOR_MUTED = Color.rgb(173, 182, 178);
    private static final int COLOR_PILL = Color.rgb(26, 36, 34);
    private static final int COLOR_BADGE_BG = Color.rgb(16, 23, 24);

    private final Context context;
    private final FrameLayout hostContainer;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Queue<Payload> queue = new ArrayDeque<>();
    private final ExecutorService imageExecutor = Executors.newSingleThreadExecutor();

    private LinearLayout cardRoot;
    private View accentStripe;
    private ImageView badgeImage;
    private TextView eyebrowView;
    private TextView titleView;
    private TextView descriptionView;
    private TextView pointsView;
    private String currentEventId = "";
    private boolean showing = false;
    private boolean destroyed = false;

    public BrumAchievementOverlay(Context context, FrameLayout hostContainer) {
        this.context = context.getApplicationContext();
        this.hostContainer = hostContainer;
        buildCard();
    }

    public static boolean markEventIfNew(String eventId) {
        return BrumAchievementModel.markEventIfNew(eventId);
    }

    public static void clearSeenEventsForTest() {
        BrumAchievementModel.clearSeenEventsForTest();
    }

    public void enqueue(Payload payload) {
        if (payload == null || destroyed) return;
        if (!markEventIfNew(payload.eventId)) return;
        mainHandler.post(() -> {
            if (destroyed) return;
            queue.add(payload);
            if (!showing) showNext();
        });
    }

    public void destroy() {
        destroyed = true;
        mainHandler.removeCallbacksAndMessages(null);
        imageExecutor.shutdownNow();
        if (cardRoot != null && cardRoot.getParent() == hostContainer) {
            hostContainer.removeView(cardRoot);
        }
    }

    private void buildCard() {
        cardRoot = new LinearLayout(context) {
            @Override public boolean dispatchTouchEvent(MotionEvent ev) { return false; }
            @Override public boolean onTouchEvent(MotionEvent event) { return false; }
        };
        cardRoot.setOrientation(LinearLayout.HORIZONTAL);
        cardRoot.setFocusable(false);
        cardRoot.setFocusableInTouchMode(false);
        cardRoot.setClickable(false);
        cardRoot.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS);
        cardRoot.setVisibility(View.GONE);
        cardRoot.setClipToOutline(true);

        GradientDrawable cardBg = new GradientDrawable();
        cardBg.setColor(Color.argb(245, 9, 13, 14));
        cardBg.setCornerRadius(dp(14));
        cardBg.setStroke(Math.max(1, dp(1)), COLOR_BORDER);
        cardRoot.setBackground(cardBg);
        cardRoot.setElevation(dp(12));

        accentStripe = new View(context);
        accentStripe.setBackgroundColor(COLOR_NEON_GREEN);
        cardRoot.addView(accentStripe, new LinearLayout.LayoutParams(dp(4), LinearLayout.LayoutParams.MATCH_PARENT));

        LinearLayout inner = new LinearLayout(context);
        inner.setOrientation(LinearLayout.HORIZONTAL);
        inner.setGravity(Gravity.CENTER_VERTICAL);
        inner.setPadding(dp(12), dp(10), dp(12), dp(10));
        cardRoot.addView(inner, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        FrameLayout badgeBox = new FrameLayout(context);
        GradientDrawable badgeBg = new GradientDrawable();
        badgeBg.setColor(COLOR_BADGE_BG);
        badgeBg.setCornerRadius(dp(10));
        badgeBg.setStroke(Math.max(1, dp(1)), COLOR_BORDER);
        badgeBox.setBackground(badgeBg);
        badgeBox.setClipToOutline(true);

        badgeImage = new ImageView(context);
        badgeImage.setScaleType(ImageView.ScaleType.FIT_CENTER);
        badgeImage.setImageDrawable(new CartridgeDrawable(COLOR_NEON_GREEN));
        FrameLayout.LayoutParams badgeImgLp = new FrameLayout.LayoutParams(dp(46), dp(46), Gravity.CENTER);
        badgeBox.addView(badgeImage, badgeImgLp);
        inner.addView(badgeBox, new LinearLayout.LayoutParams(dp(56), dp(56)));

        LinearLayout textCol = new LinearLayout(context);
        textCol.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams textColLp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        textColLp.setMargins(dp(12), 0, dp(8), 0);

        eyebrowView = new TextView(context);
        eyebrowView.setText("CONQUISTA DESBLOQUEADA");
        eyebrowView.setTextColor(COLOR_NEON_GREEN);
        eyebrowView.setTypeface(Typeface.DEFAULT_BOLD);
        eyebrowView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        eyebrowView.setSingleLine(true);
        textCol.addView(eyebrowView);

        titleView = new TextView(context);
        titleView.setTextColor(Color.WHITE);
        titleView.setTypeface(Typeface.DEFAULT_BOLD);
        titleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f);
        titleView.setMaxLines(2);
        titleView.setEllipsize(TextUtils.TruncateAt.END);
        textCol.addView(titleView);

        descriptionView = new TextView(context);
        descriptionView.setTextColor(COLOR_MUTED);
        descriptionView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f);
        descriptionView.setMaxLines(2);
        descriptionView.setEllipsize(TextUtils.TruncateAt.END);
        textCol.addView(descriptionView);
        inner.addView(textCol, textColLp);

        LinearLayout rightCol = new LinearLayout(context);
        rightCol.setOrientation(LinearLayout.VERTICAL);
        rightCol.setGravity(Gravity.END);

        pointsView = new TextView(context);
        pointsView.setTextColor(COLOR_NEON_GREEN);
        pointsView.setTypeface(Typeface.DEFAULT_BOLD);
        pointsView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f);
        GradientDrawable pillBg = new GradientDrawable();
        pillBg.setColor(COLOR_PILL);
        pillBg.setCornerRadius(dp(12));
        pointsView.setBackground(pillBg);
        pointsView.setPadding(dp(9), dp(4), dp(9), dp(4));
        rightCol.addView(pointsView, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        View spacer = new View(context);
        rightCol.addView(spacer, new LinearLayout.LayoutParams(dp(1), dp(14)));

        LinearLayout brandRow = new LinearLayout(context);
        brandRow.setOrientation(LinearLayout.HORIZONTAL);
        brandRow.setGravity(Gravity.CENTER_VERTICAL);
        ImageView miniCartridge = new ImageView(context);
        miniCartridge.setImageDrawable(new CartridgeDrawable(COLOR_NEON_GREEN));
        brandRow.addView(miniCartridge, new LinearLayout.LayoutParams(dp(15), dp(15)));

        TextView brandText = new TextView(context);
        brandText.setText("BRUM CLASSICS");
        brandText.setTextColor(Color.rgb(240, 245, 243));
        brandText.setTypeface(Typeface.DEFAULT_BOLD);
        brandText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        LinearLayout.LayoutParams brandTxtLp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        brandTxtLp.setMarginStart(dp(5));
        brandRow.addView(brandText, brandTxtLp);

        rightCol.addView(brandRow, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT));
        inner.addView(rightCol, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        int maxWidthPx = Math.min(dp(440), Math.max(dp(260), context.getResources().getDisplayMetrics().widthPixels - dp(24)));
        FrameLayout.LayoutParams cardLp = new FrameLayout.LayoutParams(maxWidthPx, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.TOP | Gravity.CENTER_HORIZONTAL);
        cardLp.setMargins(dp(12), dp(14), dp(12), 0);
        cardRoot.setOnApplyWindowInsetsListener((view, insets) -> {
            int topInset = 0;
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                topInset = insets.getInsets(android.view.WindowInsets.Type.statusBars() | android.view.WindowInsets.Type.displayCutout()).top;
            } else {
                topInset = insets.getSystemWindowInsetTop();
            }
            FrameLayout.LayoutParams lp = (FrameLayout.LayoutParams) view.getLayoutParams();
            int desiredTop = topInset + dp(12);
            if (lp.topMargin != desiredTop) {
                lp.topMargin = desiredTop;
                view.setLayoutParams(lp);
            }
            return insets;
        });
        hostContainer.addView(cardRoot, cardLp);
    }

    private void showNext() {
        if (destroyed || showing || queue.isEmpty()) return;
        Payload next = queue.poll();
        if (next == null) return;
        showing = true;
        currentEventId = next.eventId;

        int activeAccent = next.isShinyDiscovery ? Color.rgb(255, 214, 64) : COLOR_NEON_GREEN;
        if (accentStripe != null) accentStripe.setBackgroundColor(activeAccent);
        if (eyebrowView != null) {
            eyebrowView.setText(next.eyebrow);
            eyebrowView.setTextColor(activeAccent);
        }
        titleView.setText(next.title);
        descriptionView.setText(next.description);
        descriptionView.setVisibility(next.description.isEmpty() ? View.GONE : View.VISIBLE);
        if (!next.pillText.isEmpty()) {
            pointsView.setText(next.pillText);
            pointsView.setTextColor(activeAccent);
            pointsView.setVisibility(View.VISIBLE);
        } else if (next.points > 0) {
            pointsView.setText("+" + next.points + " PTS");
            pointsView.setTextColor(COLOR_NEON_GREEN);
            pointsView.setVisibility(View.VISIBLE);
        } else {
            pointsView.setVisibility(View.GONE);
        }
        if (next.pokedexNationalDexNumber > 0) {
            int mode = next.isShinyDiscovery
                    ? com.brumclassics.mobile.extensions.PokedexSpriteRenderer.MODE_SHINY
                    : com.brumclassics.mobile.extensions.PokedexSpriteRenderer.MODE_NORMAL;
            badgeImage.setImageBitmap(com.brumclassics.mobile.extensions.PokedexSpriteRenderer.createBitmap(
                    next.pokedexNationalDexNumber, mode, 3
            ));
        } else {
            badgeImage.setImageDrawable(new CartridgeDrawable(COLOR_NEON_GREEN));
            if (!next.badgeUrl.isEmpty()) {
                loadBadgeAsync(next.eventId, next.badgeUrl);
            }
        }

        hostContainer.bringChildToFront(cardRoot);
        cardRoot.setVisibility(View.VISIBLE);
        boolean reduceMotion = isReducedMotion();
        cardRoot.setAlpha(0f);
        cardRoot.setTranslationY(reduceMotion ? 0f : -dp(14));
        cardRoot.animate()
            .alpha(1f)
            .translationY(0f)
            .setDuration(reduceMotion ? 120 : 220)
            .start();

        mainHandler.postDelayed(this::hideCurrent, 4000);
    }

    private void hideCurrent() {
        if (destroyed) return;
        boolean reduceMotion = isReducedMotion();
        cardRoot.animate()
            .alpha(0f)
            .translationY(reduceMotion ? 0f : -dp(10))
            .setDuration(reduceMotion ? 120 : 200)
            .withEndAction(() -> {
                cardRoot.setVisibility(View.GONE);
                cardRoot.setTranslationY(0f);
                showing = false;
                showNext();
            })
            .start();
    }

    private boolean isReducedMotion() {
        try {
            return Settings.Global.getFloat(context.getContentResolver(), Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f;
        } catch (Exception ignored) {
            return false;
        }
    }

    private void loadBadgeAsync(String expectedEventId, String urlString) {
        imageExecutor.execute(() -> {
            HttpURLConnection conn = null;
            try {
                conn = (HttpURLConnection) new URL(urlString).openConnection();
                conn.setConnectTimeout(6000);
                conn.setReadTimeout(6000);
                conn.setRequestProperty("User-Agent", "BRUMCLASSICSAndroid/0.34.0");
                if (conn.getResponseCode() >= 200 && conn.getResponseCode() < 300) {
                    try (InputStream in = conn.getInputStream(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                        byte[] buf = new byte[8192];
                        int total = 0;
                        int n;
                        while ((n = in.read(buf)) > 0) {
                            total += n;
                            if (total > 2 * 1024 * 1024) return;
                            out.write(buf, 0, n);
                        }
                        byte[] bytes = out.toByteArray();
                        Bitmap bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
                        if (bmp != null) {
                            mainHandler.post(() -> {
                                if (!destroyed && expectedEventId.equals(currentEventId)) {
                                    badgeImage.setImageBitmap(bmp);
                                }
                            });
                        }
                    }
                }
            } catch (Exception ignored) {
            } finally {
                if (conn != null) conn.disconnect();
            }
        });
    }

    private int dp(int value) {
        return Math.round(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, context.getResources().getDisplayMetrics()));
    }

    private static final class CartridgeDrawable extends Drawable {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Path cached = new Path();
        private final Matrix matrix = new Matrix();
        private final Path basePath;

        CartridgeDrawable(int color) {
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(color);
            basePath = buildBasePath();
        }

        private static Path buildBasePath() {
            Path p = new Path();
            p.setFillType(Path.FillType.EVEN_ODD);
            p.moveTo(44, 38); p.lineTo(212, 38); p.lineTo(230, 56); p.lineTo(230, 196);
            p.lineTo(208, 218); p.lineTo(48, 218); p.lineTo(26, 196); p.lineTo(26, 56); p.close();
            p.moveTo(52, 66); p.lineTo(204, 66); p.lineTo(216, 78); p.lineTo(216, 153);
            p.lineTo(204, 165); p.lineTo(52, 165); p.lineTo(40, 153); p.lineTo(40, 78); p.close();
            p.addRect(72, 182, 184, 218, Path.Direction.CW);
            Path pins = new Path();
            for (int x : new int[]{83, 108, 133, 158}) {
                pins.addRect(x, 190, x + 16, 218, Path.Direction.CW);
            }
            p.op(pins, Path.Op.UNION);
            return p;
        }

        @Override public void draw(Canvas canvas) {
            android.graphics.Rect b = getBounds();
            if (b.isEmpty()) return;
            matrix.reset();
            matrix.setScale(b.width() / 256f, b.height() / 256f);
            matrix.postTranslate(b.left, b.top);
            basePath.transform(matrix, cached);
            canvas.drawPath(cached, paint);
        }

        @Override public void setAlpha(int alpha) { paint.setAlpha(alpha); }
        @Override public void setColorFilter(ColorFilter colorFilter) { paint.setColorFilter(colorFilter); }
        @Override @SuppressWarnings("deprecation") public int getOpacity() { return PixelFormat.TRANSLUCENT; }
    }
}
