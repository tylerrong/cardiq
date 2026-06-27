# Supabase setup for CardIQ

The app is wired for Supabase but **keyless by default**: with no credentials it
falls back to mock services and runs exactly as before. Follow these steps when
you're ready to turn it on.

## 1. Create the project

1. Go to <https://supabase.com/dashboard> and create a new project.
2. Pick a region close to your users and save the database password somewhere safe.

## 2. Create the schema

1. In the dashboard, open **SQL Editor → New query**.
2. Paste the contents of [`supabase/schema.sql`](supabase/schema.sql) and click **Run**.
   This creates the `profiles` and `collection_items` tables, the private
   `card-images` storage bucket, and row-level-security policies that scope every
   row/file to its owner. It is safe to re-run.

## 3. Enable Sign in with Apple

1. In Xcode, select the **CardIQ** target → **Signing & Capabilities** → **+ Capability** → **Sign in with Apple**.
2. In the Supabase dashboard, go to **Authentication → Providers → Apple** and enable it.
   - For native iOS Sign in with Apple (what this app uses), set the **Client ID** to
     your app's bundle id (`tyler.CardIQ`) under "Authorized Client IDs".
   - The native flow exchanges an Apple identity token directly, so you do **not**
     need the Services ID / redirect web flow for the in-app button.

## 4. Add your keys to the app

1. From the repo root:
   ```sh
   cp Supabase-Info.example.plist CardIQ/Supabase-Info.plist
   ```
2. In the Supabase dashboard, open **Project Settings → API** and copy:
   - **Project URL** → `SUPABASE_URL`
   - **anon / public** key → `SUPABASE_ANON_KEY`
3. Paste both into `CardIQ/Supabase-Info.plist`.

`CardIQ/Supabase-Info.plist` is gitignored, so your keys never get committed. The
anon key is safe to ship in the app — data access is protected by the row-level
security policies from step 2.

## 5. Run

Build and run. On launch the app detects the credentials and swaps the live
Supabase implementations in for:

| Protocol                | Live implementation                  | Backed by              |
|-------------------------|--------------------------------------|------------------------|
| `AuthenticationService` | `SupabaseAuthenticationService`      | Supabase Auth (Apple)  |
| `ImageStorageService`   | `SupabaseImageStorageService`        | Storage `card-images`  |
| `CollectionRepository`  | `SupabaseCollectionRepository`       | Postgres `collection_items` |

If the plist is missing or still has placeholder values, the app uses mocks.

## Notes / follow-ups

- **Account deletion**: `deleteAccount()` clears the user's `profiles` row and
  signs out. Deleting the underlying auth identity requires the service role, so
  add a Supabase **Edge Function** (using the service-role key) if you need full
  GDPR-style deletion, and call it from `deleteAccount()`.
- **Collection sync wiring**: the repository is registered in `ServiceContainer`
  as `collectionRepository` and is ready to use, but the collection UI still reads
  and writes through SwiftData locally. Hooking the views to push/pull through
  `collectionRepository` (or a sync layer over SwiftData) is the next step to make
  the vault follow a user across devices.
