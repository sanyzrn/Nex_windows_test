# Shared media behavior

Windows follows Android `DbsNex` commit `5561c01` (1.80.0), particularly
`detail_type_body.dart`, `detail_actions.dart`, `detail_ai_panel.dart` and
`note_editor_sheet.dart` under `apps/client/lib/`.

The caption is read once from `Note.caption`, with a separate add/edit dialog
and explicit Save/Cancel. Empty saves clear the caption. Legacy media titles
remain stored but are not displayed as captions. OCR and transcription are
stored independently in `ocr_text` and `transcript_text`, displayed with AI
results, and remain available without running the model again. Adding a result
to an existing caption offers append/replace/cancel. Append is atomic and
idempotent; replacement checks the caption that was presented for approval.

The shared Note model, database schema, backup format and wire field names are
unchanged. Caption edits preserve IDs, media hashes, titles and derived text,
and use the existing revision/device/sync-state rules. The Android backup
round-trip regression checks these fields after editing on Windows. This
maintains the existing data contract; it does not implement cross-device sync.

Android uses its native EditText. Windows retains Flutter text input and
normalizes an RTL line-end hit synchronously before the caret paints. The
regression runs as Windows and checks the first frame while the mouse is held,
as well as typing after releasing it.
