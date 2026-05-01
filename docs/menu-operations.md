# Menu Operations

The live ordering menu is stored in `menu_categories` and `menu_items`.

Production contract:

- Venue staff edit live menu categories and items through the venue portal.
- `menu_ocr_parse` supports immediate AI extraction from an uploaded photo in the portal.
- `menu_ingest_create` stores uploaded OCR files in the private `menu-ocr-queue` bucket and creates a `pending_menu_imports` row.
- `menu_ingest_worker` processes pending imports, writes extracted items to `pending_menu_imports.review_payload`, and leaves publishing to a venue user review flow.
- OCR output must not create live menu items without a venue member action.

Operational checks:

- `pending_menu_imports.status = review` means extracted items are ready for review.
- `pending_menu_imports.status = failed` includes a safe `error_message` and error metadata in `extracted_payload`.
- Staff-facing menu writes depend on venue membership RLS and authenticated `INSERT`, `UPDATE`, and `DELETE` grants.
