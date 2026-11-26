package com.brumclassics.mobile.emulation;

import java.util.List;

public final class GraphicsResolutionPackTest {
    public static void main(String[] args) {
        List<GraphicsResolutionRules.CatalogEntry> catalog = GraphicsResolutionRules.catalog();
        if (catalog.size() < 32) {
            throw new AssertionError("Catálogo gráfico deve cobrir todos os consoles (atual=" + catalog.size() + ")");
        }

        GraphicsResolutionRules.Settings autoSettings = new GraphicsResolutionRules.Settings();
        GraphicsResolutionRules.ResolvedConfig pspHigh = GraphicsResolutionRules.resolve(autoSettings, "psp", GraphicsResolutionRules.TIER_HIGH);
        if (!"1440x816".equals(pspHigh.coreVariables.get("ppsspp_internal_resolution")) || pspHigh.internalMultiplier != 3) {
            throw new AssertionError("PSP em tier alto deveria renderizar em 3x (1440x816)");
        }
        if (!pspHigh.preserveAspectRatio) {
            throw new AssertionError("Proporção original do PSP deve ser preservada");
        }

        GraphicsResolutionRules.ResolvedConfig pspLow = GraphicsResolutionRules.resolve(autoSettings, "psp", GraphicsResolutionRules.TIER_LOW);
        if (!"480x272".equals(pspLow.coreVariables.get("ppsspp_internal_resolution")) || pspLow.internalMultiplier != 1) {
            throw new AssertionError("PSP em tier baixo deveria recuar com segurança para 1x (480x272)");
        }

        GraphicsResolutionRules.ResolvedConfig gbaAuto = GraphicsResolutionRules.resolve(autoSettings, "gba", GraphicsResolutionRules.TIER_HIGH);
        if (gbaAuto.is3D || gbaAuto.internalMultiplier != 1 || !gbaAuto.integerScalingEnabled || !gbaAuto.preserveAspectRatio) {
            throw new AssertionError("2D portátil (GBA) deve manter 1x interno + integer scale + aspect ratio");
        }

        GraphicsResolutionRules.Settings enhanced = new GraphicsResolutionRules.Settings();
        enhanced.profile = GraphicsResolutionRules.PROFILE_ENHANCED;
        GraphicsResolutionRules.ResolvedConfig snesEnhanced = GraphicsResolutionRules.resolve(enhanced, "sfc", GraphicsResolutionRules.TIER_MEDIUM);
        if (!"snes".equals(snesEnhanced.systemId) || !GraphicsResolutionRules.FILTER_CRT_SCANLINES.equals(snesEnhanced.videoFilterMode) || !snesEnhanced.integerScalingEnabled) {
            throw new AssertionError("SNES enhanced deve habilitar CRT Scanlines + integer scale");
        }
        GraphicsResolutionRules.ResolvedConfig gbcEnhanced = GraphicsResolutionRules.resolve(enhanced, "gbc", GraphicsResolutionRules.TIER_MEDIUM);
        if (!GraphicsResolutionRules.FILTER_LCD_GRID.equals(gbcEnhanced.videoFilterMode)) {
            throw new AssertionError("Portátil 2D enhanced deve usar grade LCD sutil");
        }

        GraphicsResolutionRules.Settings original = new GraphicsResolutionRules.Settings();
        original.profile = GraphicsResolutionRules.PROFILE_ORIGINAL;
        GraphicsResolutionRules.ResolvedConfig n3dsOrig = GraphicsResolutionRules.resolve(original, "3ds", GraphicsResolutionRules.TIER_HIGH);
        if (!"1x Native".equals(n3dsOrig.coreVariables.get("citra_resolution_factor")) || !GraphicsResolutionRules.FILTER_NONE.equals(n3dsOrig.videoFilterMode)) {
            throw new AssertionError("Original deve restaurar 1x nativo sem filtros");
        }

        GraphicsResolutionRules.Settings custom = new GraphicsResolutionRules.Settings();
        custom.profile = GraphicsResolutionRules.PROFILE_CUSTOM;
        GraphicsResolutionRules.SystemOverride gbaOv = new GraphicsResolutionRules.SystemOverride();
        gbaOv.multiplier = 4; // Deve ser limitado a 1x em 2D
        gbaOv.scaleMode = GraphicsResolutionRules.SCALE_INTEGER;
        gbaOv.videoFilter = GraphicsResolutionRules.FILTER_LCD_GRID;
        custom.systems.put("gba", gbaOv);
        GraphicsResolutionRules.ResolvedConfig gbaCustom = GraphicsResolutionRules.resolve(custom, "gba", GraphicsResolutionRules.TIER_HIGH);
        if (gbaCustom.internalMultiplier != 1 || !GraphicsResolutionRules.FILTER_LCD_GRID.equals(gbaCustom.videoFilterMode)) {
            throw new AssertionError("GBA custom não pode fingir resolução 3D interna");
        }

        for (String shader : new String[] {
            GraphicsResolutionRules.FILTER_CAS_SHARPEN,
            GraphicsResolutionRules.FILTER_SHARP_BILINEAR,
            GraphicsResolutionRules.FILTER_EDGE_UPSCALE_2X
        }) {
            GraphicsResolutionRules.Settings shaderSettings = new GraphicsResolutionRules.Settings();
            shaderSettings.profile = GraphicsResolutionRules.PROFILE_CUSTOM;
            shaderSettings.globalVideoFilter = shader;
            GraphicsResolutionRules.ResolvedConfig snesShader = GraphicsResolutionRules.resolve(shaderSettings, "snes", GraphicsResolutionRules.TIER_HIGH);
            if (!shader.equals(snesShader.videoFilterMode)) {
                throw new AssertionError("Shader eficiente 2D não preservado: " + shader);
            }
            GraphicsResolutionRules.ResolvedConfig pspShader = GraphicsResolutionRules.resolve(shaderSettings, "psp", GraphicsResolutionRules.TIER_HIGH);
            if (!shader.equals(pspShader.videoFilterMode)) {
                throw new AssertionError("Shader eficiente 3D não preservado: " + shader);
            }
        }

        if (!GraphicsResolutionRules.TIER_HIGH.equals(GraphicsResolutionRules.detectHardwareTier(8L * 1024 * 1024 * 1024, 8))) {
            throw new AssertionError("Tier alto não reconhecido");
        }

        System.out.println("GraphicsResolutionPackTest: OK (catálogo completo, multiplicadores 3D, integer/filtros 2D, rollback original)");
    }
}
