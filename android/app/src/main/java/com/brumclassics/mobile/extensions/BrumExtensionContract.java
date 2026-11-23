package com.brumclassics.mobile.extensions;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;

public final class BrumExtensionContract {
    public static final String POKEDEX_EXTENSION_ID = "brum.ext.pokedex";
    public static final String CODE_EXECUTION_POLICY_NATIVE_ONLY = "native-compiled-only";

    private static final Pattern ID_PATTERN = Pattern.compile("^[a-z0-9]+(?:\\.[a-z0-9_-]+){2,6}$");
    private static final Pattern VERSION_PATTERN = Pattern.compile("^\\d+\\.\\d+\\.\\d+$");
    private static final Set<String> ALLOWED_PERMISSIONS = Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
            "brum-core:events.read",
            "brum-core:memory.read",
            "storage:isolated.readwrite",
            "sync:lan.readwrite",
            "gamepad:ui.extension",
            "notifications:discovery.emit"
    )));

    public static final class ExtensionManifest {
        public final String id;
        public final String number;
        public final int schemaVersion;
        public final String version;
        public final String title;
        public final String shortTitle;
        public final String description;
        public final String codeExecutionPolicy;
        public final boolean defaultEnabled;
        public final List<String> permissions;
        public final List<String> capabilities;
        public final List<String> tabs;

        public ExtensionManifest(
                String id,
                String number,
                int schemaVersion,
                String version,
                String title,
                String shortTitle,
                String description,
                String codeExecutionPolicy,
                boolean defaultEnabled,
                List<String> permissions,
                List<String> capabilities,
                List<String> tabs
        ) {
            this.id = id == null ? "" : id.trim();
            this.number = number == null ? "001" : number.trim();
            this.schemaVersion = schemaVersion;
            this.version = version == null ? "" : version.trim();
            this.title = title == null ? "" : title.trim();
            this.shortTitle = shortTitle == null ? "" : shortTitle.trim();
            this.description = description == null ? "" : description.trim();
            this.codeExecutionPolicy = codeExecutionPolicy == null ? "" : codeExecutionPolicy.trim();
            this.defaultEnabled = defaultEnabled;
            this.permissions = permissions == null ? Collections.emptyList() : Collections.unmodifiableList(permissions);
            this.capabilities = capabilities == null ? Collections.emptyList() : Collections.unmodifiableList(capabilities);
            this.tabs = tabs == null ? Collections.emptyList() : Collections.unmodifiableList(tabs);
        }

        public void validate() {
            if (schemaVersion != 1) {
                throw new IllegalArgumentException("Schema de extensão não suportado: " + schemaVersion);
            }
            if (!CODE_EXECUTION_POLICY_NATIVE_ONLY.equals(codeExecutionPolicy)) {
                throw new SecurityException("Execução arbitrária de código baixado não é permitida.");
            }
            if (!ID_PATTERN.matcher(id).matches()) {
                throw new IllegalArgumentException("Identificador de extensão inválido: " + id);
            }
            if (!VERSION_PATTERN.matcher(version).matches()) {
                throw new IllegalArgumentException("Versão de extensão inválida: " + version);
            }
            for (String perm : permissions) {
                if (!ALLOWED_PERMISSIONS.contains(perm)) {
                    throw new IllegalArgumentException("Permissão não reconhecida: " + perm);
                }
            }
        }
    }

    public static ExtensionManifest pokedexManifest() {
        ExtensionManifest manifest = new ExtensionManifest(
                POKEDEX_EXTENSION_ID,
                "001",
                1,
                "1.0.0",
                "Pokédex Universal",
                "Pokédex",
                "Coleção permanente e sincronizada de Pokémon descobertos pelo jogador no ecossistema Brum Classics.",
                CODE_EXECUTION_POLICY_NATIVE_ONLY,
                true,
                Arrays.asList(
                        "brum-core:events.read",
                        "brum-core:memory.read",
                        "storage:isolated.readwrite",
                        "sync:lan.readwrite",
                        "gamepad:ui.extension",
                        "notifications:discovery.emit"
                ),
                Arrays.asList(
                        "universal-collection",
                        "normal-and-shiny-tabs",
                        "automatic-capture-detection",
                        "offline-first-lan-sync",
                        "verified-backup-restore",
                        "discovery-notifications"
                ),
                Arrays.asList("pokemon", "shinies")
        );
        manifest.validate();
        return manifest;
    }

    private BrumExtensionContract() {}
}
