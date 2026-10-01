package com.brumclassics.mobile.classics;

public final class SaveManifest {
    public static final int SCHEMA_VERSION = 1;
    public final int schemaVersion;
    public final String canonicalGameId;
    public final String systemId;
    public final String coreId;
    public final String slot;
    public final long generation;
    public final String payloadSha256;
    public final long sizeBytes;
    public final long updatedAt;
    public final String deviceId;
    public final int formatVersion;

    public SaveManifest(String canonicalGameId, String systemId, String coreId, long generation,
                        String payloadSha256, long sizeBytes, long updatedAt, String deviceId) {
        this.schemaVersion = SCHEMA_VERSION;
        this.canonicalGameId = canonicalGameId;
        this.systemId = systemId;
        this.coreId = coreId;
        this.slot = "battery";
        this.generation = generation;
        this.payloadSha256 = payloadSha256;
        this.sizeBytes = sizeBytes;
        this.updatedAt = updatedAt;
        this.deviceId = deviceId;
        this.formatVersion = 1;
    }

    public static SaveManifest next(SaveManifest previous, EmulationIdentity identity, String coreId,
                                    String payloadSha256, long sizeBytes, long updatedAt, String deviceId) {
        boolean unchanged = previous != null && previous.payloadSha256.equals(payloadSha256);
        long generation = unchanged ? previous.generation : (previous == null ? 1 : previous.generation + 1);
        long timestamp = unchanged ? previous.updatedAt : updatedAt;
        return new SaveManifest(identity.canonicalGameId(), identity.systemId, coreId, generation,
            payloadSha256, sizeBytes, timestamp, deviceId);
    }
}
