package com.brumclassics.mobile.update;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileNotFoundException;

public final class UpdateFileProvider extends ContentProvider {
    public static final String AUTHORITY = "com.brumclassics.mobile.updates";
    public static final Uri APK_URI = Uri.parse("content://" + AUTHORITY + "/apk");

    public static File updateFile(android.content.Context context) {
        return new File(new File(context.getFilesDir(), "mobile-updates"), "pending-update.apk");
    }

    @Override public boolean onCreate() { return true; }

    @Override public String getType(Uri uri) {
        return isApk(uri) ? "application/vnd.android.package-archive" : null;
    }

    @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!isApk(uri) || !"r".equals(mode)) throw new FileNotFoundException("Arquivo de atualização inválido.");
        File file = updateFile(getContext());
        if (!file.isFile()) throw new FileNotFoundException("Atualização ainda não foi baixada.");
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY);
    }

    @Override public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
        if (!isApk(uri)) return null;
        File file = updateFile(getContext());
        String[] columns = projection == null ? new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE} : projection;
        MatrixCursor cursor = new MatrixCursor(columns, 1);
        MatrixCursor.RowBuilder row = cursor.newRow();
        for (String column : columns) {
            if (OpenableColumns.DISPLAY_NAME.equals(column)) row.add("BRUMCLASSICS-MOVEL-update.apk");
            else if (OpenableColumns.SIZE.equals(column)) row.add(file.isFile() ? file.length() : 0L);
            else row.add(null);
        }
        return cursor;
    }

    @Override public Uri insert(Uri uri, ContentValues values) { throw new UnsupportedOperationException(); }
    @Override public int delete(Uri uri, String selection, String[] selectionArgs) { return 0; }
    @Override public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) { return 0; }

    private boolean isApk(Uri uri) {
        return uri != null && AUTHORITY.equals(uri.getAuthority()) && "/apk".equals(uri.getPath());
    }
}
