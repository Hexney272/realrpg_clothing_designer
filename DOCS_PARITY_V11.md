# DOCS PARITY V11

A user által küldött docs rész alapján beépített pontok:

## Template Discovery Rules
- `templates/cloth_templates/male/`
- `templates/cloth_templates/female/`
- támogatott component folder lista beépítve
- folder + filename prefix ellenőrzés
- hibás folder/file naming skipelve és `skippedFiles` resultban visszaadva

## Optional Preview Images
- `templates/template_previews/<gender>/<component>/<file>.(png|webp|jpg|jpeg)` támogatott
- ha nincs preview, managed placeholder `.png` bejegyzés létrejön
- `managed_preview` SQL mező jelzi, hogy generált/kezelt preview-ról van szó

## Optional Default Slot YTD Files
- `templates/template_slots/<template_key>/` layout támogatott
- slot folder felismerés `.ytd` alapján
- `slot_path` SQL mező

## Startup Sync Behavior
- workspace mappák létrehozása
- template scan induláskor
- preview placeholder generálás
- temp preview cache marker

## Export Flow
- addon-first export
- replace export disabled
- output előkészítés:
  - `exports/`
  - `../realrpg_clothing_exports/`
  - `data/workspace/`
- restart hint: `restart realrpg_clothing_exports`

## Nem 100% azonos még
- Valódi preview render/screenshot képgenerálás a hiányzó preview-khoz még a későbbi stream/model teszt után lesz véglegesítve.
- A runtime ZIP létrehozása hostfüggő, ezért V11 export foldert és zip marker fájlt készít.
