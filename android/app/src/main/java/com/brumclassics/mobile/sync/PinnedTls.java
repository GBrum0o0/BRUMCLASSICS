package com.brumclassics.mobile.sync;

import java.net.HttpURLConnection;
import java.net.URL;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import java.util.Locale;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

public final class PinnedTls {
    private PinnedTls() {}

    public static HttpURLConnection open(String value, String fingerprint) throws Exception {
        String pin = normalize(fingerprint);
        if (pin.isEmpty()) throw new IllegalStateException("Conexão antiga sem proteção TLS. Faça o pareamento novamente.");
        URL url = new URL(value);
        if (!"https".equalsIgnoreCase(url.getProtocol())) throw new IllegalArgumentException("A ponte móvel exige HTTPS.");
        HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();
        X509TrustManager trust = new X509TrustManager() {
            public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
            public void checkClientTrusted(X509Certificate[] chain, String authType) { throw new SecurityException("Cliente TLS inesperado."); }
            public void checkServerTrusted(X509Certificate[] chain, String authType) throws java.security.cert.CertificateException {
                if (chain == null || chain.length == 0) throw new java.security.cert.CertificateException("Certificado ausente.");
                try {
                    String actual = hex(MessageDigest.getInstance("SHA-256").digest(chain[0].getEncoded()));
                    if (!MessageDigest.isEqual(actual.getBytes(java.nio.charset.StandardCharsets.US_ASCII), pin.getBytes(java.nio.charset.StandardCharsets.US_ASCII))) {
                        throw new java.security.cert.CertificateException("A identidade do launcher mudou. Faça o pareamento novamente.");
                    }
                } catch (java.security.cert.CertificateException error) { throw error; }
                catch (Exception error) { throw new java.security.cert.CertificateException("Não foi possível validar o launcher.", error); }
            }
        };
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(null, new TrustManager[]{trust}, new SecureRandom());
        connection.setSSLSocketFactory(context.getSocketFactory());
        connection.setHostnameVerifier((hostname, session) -> true);
        return connection;
    }

    public static String normalize(String value) {
        String pin = value == null ? "" : value.replaceAll("[^a-fA-F0-9]", "").toLowerCase(Locale.ROOT);
        if (!pin.isEmpty() && !pin.matches("[a-f0-9]{64}")) throw new IllegalArgumentException("Impressão TLS inválida.");
        return pin;
    }

    private static String hex(byte[] input) {
        StringBuilder output = new StringBuilder(input.length * 2);
        for (byte value : input) output.append(String.format(Locale.ROOT, "%02x", value & 0xff));
        return output.toString();
    }
}
