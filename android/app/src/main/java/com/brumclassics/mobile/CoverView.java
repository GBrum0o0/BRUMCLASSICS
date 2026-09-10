package com.brumclassics.mobile;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Rect;
import android.graphics.Shader;
import android.util.AttributeSet;
import android.view.View;

import com.brumclassics.mobile.model.Game;

public final class CoverView extends View {
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path clipPath = new Path();
    private Game game;
    private Bitmap artworkBitmap;
    private Runnable artworkRequest;
    private boolean artworkRequested;

    public CoverView(Context context) { super(context); }
    public CoverView(Context context, AttributeSet attrs) { super(context, attrs); }

    public void setGame(Game game) {
        this.game = game;
        setContentDescription("Capa de " + game.title);
        invalidate();
    }

    public void setArtworkRequest(Runnable request) {
        artworkRequest = request;
        artworkRequested = false;
        invalidate();
    }

    public void setArtworkBitmap(Bitmap bitmap) {
        artworkBitmap = bitmap;
        invalidate();
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        if (game == null || getWidth() == 0 || getHeight() == 0) return;
        paint.reset();
        paint.setAntiAlias(true);
        paint.setFilterBitmap(true);
        paint.setDither(true);
        paint.setAlpha(255);
        paint.setColorFilter(null);
        paint.setShader(null);
        paint.setStyle(Paint.Style.FILL);
        if (!artworkRequested && artworkRequest != null) {
            artworkRequested = true;
            post(artworkRequest);
        }

        float w = getWidth();
        float h = getHeight();
        float radius = Math.max(4f, w * .035f);
        clipPath.reset();
        clipPath.addRoundRect(new RectF(0, 0, w, h), radius, radius, Path.Direction.CW);
        canvas.save();
        canvas.clipPath(clipPath);

        if (artworkBitmap != null && !artworkBitmap.isRecycled()) {
            float sourceRatio = artworkBitmap.getWidth() / (float) artworkBitmap.getHeight();
            float targetRatio = w / h;
            Rect source;
            if (sourceRatio > targetRatio) {
                float sourceWidth = artworkBitmap.getHeight() * targetRatio;
                float left = (artworkBitmap.getWidth() - sourceWidth) / 2f;
                source = new Rect(Math.round(left), 0, Math.round(left + sourceWidth), artworkBitmap.getHeight());
            } else {
                float sourceHeight = artworkBitmap.getWidth() / targetRatio;
                float top = (artworkBitmap.getHeight() - sourceHeight) / 2f;
                source = new Rect(0, Math.round(top), artworkBitmap.getWidth(), Math.round(top + sourceHeight));
            }
            canvas.drawBitmap(artworkBitmap, source, new RectF(0, 0, w, h), paint);
        } else {
            paint.setShader(new LinearGradient(0, 0, w, h, game.colorStart, game.colorEnd, Shader.TileMode.CLAMP));
            canvas.drawRect(0, 0, w, h, paint);
            paint.setShader(null);

            paint.setColor(Color.argb(38, 255, 255, 255));
            canvas.drawCircle(w * .82f, h * .22f, w * .62f, paint);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(Math.max(1f, w * .008f));
            paint.setColor(Color.argb(85, 255, 255, 255));
            canvas.drawCircle(w * .78f, h * .28f, w * .42f, paint);
            canvas.drawCircle(w * .78f, h * .28f, w * .31f, paint);
            paint.setStyle(Paint.Style.FILL);

            paint.setColor(Color.argb(115, 5, 8, 10));
            Path slash = new Path();
            slash.moveTo(-w * .15f, h * .72f);
            slash.lineTo(w * .88f, h * .18f);
            slash.lineTo(w * 1.15f, h * .34f);
            slash.lineTo(w * .12f, h * .88f);
            slash.close();
            canvas.drawPath(slash, paint);
        }

        paint.setTypeface(android.graphics.Typeface.create("sans", android.graphics.Typeface.BOLD));
        paint.setTextSize(Math.max(9f, w * .052f));
        paint.setLetterSpacing(.12f);
        paint.setColor(Color.argb(205, 255, 255, 255));
        canvas.drawText(game.platform.toUpperCase(), w * .09f, h * .11f, paint);

        if (artworkBitmap == null) {
            paint.setLetterSpacing(.01f);
            paint.setTextSize(Math.max(18f, w * .135f));
            paint.setColor(Color.WHITE);
            String[] words = game.title.toUpperCase().split(" ");
            float y = h * .67f;
            StringBuilder line = new StringBuilder();
            int rows = 0;
            for (String word : words) {
                String candidate = line.length() == 0 ? word : line + " " + word;
                if (paint.measureText(candidate) > w * .82f && line.length() > 0) {
                    canvas.drawText(line.toString(), w * .09f, y, paint);
                    y += paint.getTextSize() * 1.03f;
                    line = new StringBuilder(word);
                    rows++;
                    if (rows == 2) break;
                } else line = new StringBuilder(candidate);
            }
            if (rows < 2 && line.length() > 0) canvas.drawText(line.toString(), w * .09f, y, paint);
        }

        paint.setColor(Color.argb(225, 157, 255, 59));
        canvas.drawRect(w * .09f, h * .92f, w * .31f, h * .928f, paint);
        canvas.restore();

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(Math.max(1f, w * .007f));
        paint.setColor(Color.argb(40, 255, 255, 255));
        canvas.drawRoundRect(new RectF(.5f, .5f, w - .5f, h - .5f), radius, radius, paint);
        paint.setStyle(Paint.Style.FILL);
    }
}
