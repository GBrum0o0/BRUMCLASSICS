package com.brumclassics.mobile.extensions;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;

import java.util.HashMap;
import java.util.Map;

public final class PokedexSpriteRenderer {
    public static final int MODE_SILHOUETTE = 0;
    public static final int MODE_NORMAL = 1;
    public static final int MODE_SHINY = 2;

    private static final Map<Integer, String[]> CURATED = new HashMap<>();

    static {
        CURATED.put(1, new String[]{ // Bulbasaur (#001)
                ".....OOOOOO.....",
                "...OOSSSSSSOO...",
                "..OSSSSSSSSSSO..",
                ".OSSSSSHHSSSSSO.",
                ".OSSSSOOOOSSSSO.",
                ".OOOOPPPPPPOOOO.",
                "OOPPPPPPPPPPPPOO",
                "OPPHOPPPPPPOHPPO",
                "OPPAOPPPPPPOAPPO",
                "OPPPPPPPPPPPPPPO",
                ".OPPPPOOOOPPPPO.",
                ".OPPP.OOOO.PPPO.",
                ".OPPO......OPPO.",
                "..OO........OO..",
                "................",
                "................"
        });
        CURATED.put(4, new String[]{ // Charmander (#004)
                "....OOOOOO......",
                "...OPPPPPPO.....",
                "..OPPPPPPPHO....",
                "..OPPHO..PPO....",
                "..OPPPPPPPPO..A.",
                "...OOPPPPPOO.ASA",
                "....OPPSSPPO.ASA",
                "...OPPPSSPPPO.S.",
                "..OPO.PSSP.OPO..",
                "..OO..PSSP..OOO.",
                ".....OPSSPO..SO.",
                ".....OPPPPO.OO..",
                "....OPO..OPOO...",
                "....OO....OO....",
                "................",
                "................"
        });
        CURATED.put(6, new String[]{ // Charizard (#006)
                ".OO....OOOO....O",
                "OSSO..OPPPPO..OS",
                "OSSSOOPPPPPPOOSS",
                "OSSSSOPPHO.POSS.",
                ".OSSSOPPPPPPOSSO",
                "..OOOOPPSSPPOOO.",
                "....OPPPSSPPPO..",
                "...OPPPPSSPPPPO.",
                "...OPO.PSSP.OPO.",
                ".......PSSP..OOA",
                "......OPSSPO..SA",
                ".....OPPPPPPO.O.",
                ".....OPO..OPO...",
                ".....OO....OO...",
                "................",
                "................"
        });
        CURATED.put(7, new String[]{ // Squirtle (#007)
                "....OOOOOO......",
                "...OPPPPPPO.....",
                "..OPPPPPPPHO....",
                "..OPPHO..PPO....",
                "..OPPPPPPPPO....",
                "...OOPPPPPOO....",
                "..OOSSSSSSSSOO..",
                ".OSSSSSSPPSSSSO.",
                ".OSSSSSPPPPSSSOO",
                ".OSSSSSSPPSSSSPO",
                "..OOSSSSSSSSOPPO",
                "...OPPP..PPPOOO.",
                "...OPO....OPO...",
                "...OO......OO...",
                "................",
                "................"
        });
        CURATED.put(25, new String[]{ // Pikachu (#025)
                ".OO..........OO.",
                ".OPO........OPO.",
                "..OPO......OPO..",
                "..OPPOO..OOPPO..",
                "...OPPPPPPPPO...",
                "..OPPPPPPPPPPO..",
                "..OPHO.PP.OHPO..",
                "..OPPPPPPPPPPO..",
                "..OAPPPPPPPPAO..",
                "...OPPPPPPPPO.OO",
                "...OPPPSSPPPOSSO",
                "..OPPPPSSPPPPSO.",
                "..OPPPPPPPPPPPO.",
                "...OPPP..PPPPO..",
                "...OOO....OOO...",
                "................"
        });
        CURATED.put(133, new String[]{ // Eevee (#133)
                ".OO..........OO.",
                ".OPO........OPO.",
                ".OPP........PPO.",
                "..OPPOO..OOPPO..",
                "...OPPPPPPPPO...",
                "..OPHO.PP.OHPO..",
                "..OPPPPPPPPPPO..",
                "..OOSSSSSSSSOO..",
                ".OSSSSSSSSSSSSO.",
                "..OOSSSSSSSSOO..",
                "...OPPPPPPPPO.OO",
                "...OPPPPPPPPPSPO",
                "...OPPP..PPPPOO.",
                "...OOO....OOO...",
                "................",
                "................"
        });
        CURATED.put(143, new String[]{ // Snorlax (#143)
                "...OO......OO...",
                "..OPPOO..OOPPO..",
                ".OPPPPPPPPPPPPO.",
                ".OPP.OO..OO.PPO.",
                ".OPPSSPPPPSSPPO.",
                "OOPSSSSSSSSSSPOO",
                "OPSSSSSSSSSSSSPO",
                "OPSSSSSSSSSSSSPO",
                "OPSSSSSSSSSSSSPO",
                "OOPSSSSSSSSSSPOO",
                ".OPSSSSSSSSSSPO.",
                ".OPPPPPPPPPPPPO.",
                ".OSSSSO..OSSSSO.",
                "..OOOO....OOOO..",
                "................",
                "................"
        });
        CURATED.put(150, new String[]{ // Mewtwo (#150)
                "....OO....OO....",
                "...OPO....OPO...",
                "...OPPPPPPPPO...",
                "...OPHO..OHPO...",
                "....OPPPPPPO....",
                ".....OOPPOO.....",
                "...OOPPPPPPOO...",
                "..OPO.PSSP.OPO..",
                "..OO..PSSP..OO..",
                ".....OSSSSO..OO.",
                "....OSSSSSSO.SO.",
                "....OSP..PSOOO..",
                "...OPPO..OPPO...",
                "...OOO....OOO...",
                "................",
                "................"
        });
        CURATED.put(151, new String[]{ // Mew (#151)
                "....OO....OO....",
                "...OPPOO.OPPO...",
                "..OPPPPPPPPPPO..",
                "..OPPHO..OHPPO..",
                "..OPPPPPPPPPPO..",
                "...OOPPPPPPOO...",
                "....OPPPPPPO..OO",
                "...OPPPPPPPPO.PO",
                "...OO.PPPP.OO.PO",
                ".....OPPPPPO.PO.",
                "....OPPP.PPPOO..",
                "....OPO...OPO...",
                "....OO.....OO...",
                "................",
                "................",
                "................"
        });
    }

    private PokedexSpriteRenderer() {}

    public static Bitmap createBitmap(int nationalDexNumber, int mode, int pixelScale) {
        int dex = Math.max(1, Math.min(802, nationalDexNumber));
        int scale = Math.max(2, Math.min(12, pixelScale));
        String[] grid = CURATED.containsKey(dex) ? CURATED.get(dex) : proceduralGrid(dex);
        int[] palette = paletteFor(dex, mode);

        Bitmap bmp = Bitmap.createBitmap(16 * scale, 16 * scale, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bmp);
        Paint paint = new Paint();
        paint.setAntiAlias(false);
        paint.setStyle(Paint.Style.FILL);

        for (int y = 0; y < Math.min(16, grid.length); y++) {
            String row = grid[y];
            for (int x = 0; x < Math.min(16, row.length()); x++) {
                char ch = row.charAt(x);
                if (ch == '.') continue;
                int color;
                if (mode == MODE_SILHOUETTE) {
                    color = Color.BLACK;
                } else {
                    switch (ch) {
                        case 'O': color = palette[0]; break;
                        case 'P': color = palette[1]; break;
                        case 'S': color = palette[2]; break;
                        case 'H': color = palette[3]; break;
                        case 'A': color = palette[4]; break;
                        default: color = palette[1]; break;
                    }
                }
                paint.setColor(color);
                canvas.drawRect(x * scale, y * scale, (x + 1) * scale, (y + 1) * scale, paint);
            }
        }

        if (mode == MODE_SHINY) {
            paint.setColor(Color.rgb(255, 224, 64));
            int[][] sparkles = {{1, 1}, {1, 2}, {2, 1}, {14, 2}, {13, 3}, {14, 3}};
            for (int[] sp : sparkles) {
                canvas.drawRect(sp[0] * scale, sp[1] * scale, (sp[0] + 1) * scale, (sp[1] + 1) * scale, paint);
            }
        }
        return bmp;
    }

    private static int[] paletteFor(int dex, int mode) {
        if (mode == MODE_SILHOUETTE) {
            return new int[]{Color.BLACK, Color.BLACK, Color.BLACK, Color.BLACK, Color.BLACK};
        }
        float shift = (mode == MODE_SHINY) ? 96f : 0f;
        if (dex == 25 || dex == 26) {
            return new int[]{
                    Color.rgb(51, 36, 10),
                    mode == MODE_SHINY ? Color.rgb(255, 164, 32) : Color.rgb(255, 224, 46),
                    Color.rgb(142, 82, 26),
                    Color.WHITE,
                    Color.rgb(245, 62, 62)
            };
        }
        if (dex >= 4 && dex <= 6) {
            return new int[]{
                    Color.rgb(51, 23, 12),
                    (mode == MODE_SHINY && dex == 6) ? Color.rgb(56, 61, 72) : Color.HSVToColor(new float[]{(22f + shift) % 360f, 0.88f, 0.96f}),
                    Color.rgb(252, 219, 112),
                    Color.WHITE,
                    Color.rgb(255, 90, 38)
            };
        }
        float baseHue = ((dex * 47) % 360 + shift) % 360f;
        float secHue = (baseHue + 50f) % 360f;
        float accHue = (baseHue + 172f) % 360f;
        return new int[]{
                Color.HSVToColor(new float[]{baseHue, 0.65f, 0.18f}),
                Color.HSVToColor(new float[]{baseHue, 0.76f, 0.90f}),
                Color.HSVToColor(new float[]{secHue, 0.55f, 0.95f}),
                Color.WHITE,
                Color.HSVToColor(new float[]{accHue, 0.85f, 0.96f})
        };
    }

    public static String[] proceduralGrid(int dex) {
        char[][] grid = new char[16][16];
        for (int y = 0; y < 16; y++) {
            for (int x = 0; x < 16; x++) grid[y][x] = '.';
        }
        long seed = ((long) dex * 2654435761L) & 0xFFFFFFFFL;
        int earType = dex % 4;
        int bodyWidth = 4 + (dex % 3);
        boolean hasWings = (dex % 5 == 0);
        boolean hasCrest = (dex % 3 == 0);

        if (earType == 0) {
            grid[1][3] = 'O'; grid[2][3] = 'P'; grid[2][4] = 'O';
            grid[1][12] = 'O'; grid[2][12] = 'P'; grid[2][11] = 'O';
        } else if (earType == 1) {
            grid[1][5] = 'O'; grid[2][5] = 'A';
            grid[1][10] = 'O'; grid[2][10] = 'A';
        } else if (hasCrest) {
            grid[1][7] = 'A'; grid[1][8] = 'A'; grid[2][7] = 'P'; grid[2][8] = 'P';
        }

        for (int y = 3; y <= 7; y++) {
            int halfW = (y == 3 || y == 7) ? 3 : 4;
            for (int dx = 0; dx <= halfW; dx++) {
                char ch = (dx == halfW || y == 3) ? 'O' : 'P';
                grid[y][7 - dx] = ch;
                grid[y][8 + dx] = ch;
            }
        }
        grid[5][5] = 'H'; grid[5][6] = 'O';
        grid[5][10] = 'H'; grid[5][9] = 'O';
        if (dex % 2 == 0) {
            grid[6][4] = 'A'; grid[6][11] = 'A';
        }

        for (int y = 8; y <= 12; y++) {
            int halfW = Math.min(6, bodyWidth + (y == 10 ? 1 : 0));
            for (int dx = 0; dx <= halfW; dx++) {
                seed = (seed * 1664525L + 1013904223L) & 0xFFFFFFFFL;
                char ch;
                if (dx == halfW || y == 12) {
                    ch = 'O';
                } else if (dx <= 1 && y >= 9 && y <= 11) {
                    ch = 'S';
                } else {
                    ch = (((seed >>> 16) & 3L) == 0L) ? 'S' : 'P';
                }
                grid[y][7 - dx] = ch;
                grid[y][8 + dx] = ch;
            }
        }

        if (hasWings) {
            for (int y = 6; y <= 10; y++) {
                grid[y][1] = 'O'; grid[y][2] = 'S';
                grid[y][14] = 'O'; grid[y][13] = 'S';
            }
        }

        grid[13][4] = 'O'; grid[13][5] = 'P'; grid[13][6] = 'O';
        grid[13][11] = 'O'; grid[13][10] = 'P'; grid[13][9] = 'O';
        grid[14][4] = 'O'; grid[14][5] = 'O';
        grid[14][11] = 'O'; grid[14][10] = 'O';

        String[] rows = new String[16];
        for (int y = 0; y < 16; y++) rows[y] = new String(grid[y]);
        return rows;
    }
}
