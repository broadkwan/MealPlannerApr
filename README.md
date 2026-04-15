# Meal Planner App

Native SwiftUI app scaffold for rebuilding the Apple-device meal planner around an iPhone-first experience with:

- calendar browsing for daily lunch and dinner
- menu detail pages with ingredients, where-to-buy notes, and instructions
- recipe creation from the `Recipes` tab
- daily menu assignment for lunch and dinner
- Supabase setup/export helpers

## Project Layout

- `MealPlannerApp/`: Xcode project and SwiftUI app source
- `scripts/export_supabase_data.sh`: backup/export script for existing Supabase content
- `supabase/schema.sql`: suggested schema for normalized menu items and daily assignments
- `backups/`: local export destination

## Before Opening In Xcode

1. Copy `MealPlannerApp/MealPlannerApp/Resources/Secrets.xcconfig.example` to `MealPlannerApp/MealPlannerApp/Resources/Secrets.xcconfig`.
2. Fill in your real Supabase values.
3. Open `MealPlannerApp/MealPlannerApp.xcodeproj` in Xcode.

## Backup Existing Supabase Data

Create `MealPlannerApp/MealPlannerApp/Resources/.env.supabase` or export these variables in your shell:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_MENU_TABLE` default: `menu_items`
- `SUPABASE_ASSIGNMENTS_TABLE` default: `daily_menu_assignments`

Then run:

```bash
./scripts/export_supabase_data.sh
```

The script writes timestamped JSON backups into `backups/`.

## Suggested Build Flow

1. Create a fresh Supabase project.
2. Run the SQL in `supabase/schema.sql` in the Supabase SQL editor.
3. Fill in the Xcode secrets config.
4. Run the app on simulator or device.
5. Add recipes from the `Recipes` tab and assign lunch/dinner on the `Planner` tab.

## Notes

- The app uses Supabase REST and Auth endpoints directly, so there is no extra SDK dependency to untangle.
- Public reads use the anon key.
- The current app can also save locally before Supabase is connected, which helps you keep building while backend setup is in progress.
