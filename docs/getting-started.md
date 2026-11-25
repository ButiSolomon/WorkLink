# Getting Lekwa WorkLink online (no coding needed)

This guide takes you from the code on GitHub to a link you can open on your phone. It takes about 20 minutes.
You will create two free accounts: **Supabase** (the database) and **Vercel** (the website host).
Sign up for both with the same GitHub account that owns the `worklink` repository.

> Good to know: Vercel's free "Hobby" plan is for personal, non-commercial use. It is fine for testing.
> Before Lekwa WorkLink takes real payments from employers, upgrade to Vercel Pro (about US$20/month).

---

## Part 1: Create the database (Supabase)

1. Go to **https://supabase.com** and click **Start your project**. Choose **Continue with GitHub**.
2. Create an organisation called **Reminisce Tech** (choose the **Free** plan).
3. Click **New project** and fill in:
   - **Name:** `worklink`
   - **Database password:** click **Generate a password**, then save it in a safe place (a password manager).
   - **Region:** choose the one closest to South Africa in the list.
4. Click **Create new project** and wait about two minutes until it says the project is ready.

### Load the Lekwa WorkLink tables

You will copy three files from GitHub into Supabase, **in this order**:

1. `supabase/migrations/20261125000100_locations.sql`
2. `supabase/migrations/20261125000200_core_schema.sql`
3. `supabase/migrations/20261125000300_security.sql`

For each file:

1. On GitHub, open the `worklink` repository, click the `supabase` folder, then `migrations`, then the file.
2. Click the **Copy raw file** button (two overlapping squares, top right of the file).
3. In Supabase, click **SQL Editor** in the left menu, then **New query** (the **+** button).
4. Paste, then click **Run** (bottom right). You should see **Success. No rows returned.**

If a file shows an error, stop and send a screenshot of the error to Claude.

### Copy your two Supabase keys

1. In Supabase, click the **Connect** button at the top of the project page.
2. Open the **App Frameworks** tab and pick **Next.js**.
3. Copy the two values it shows and keep them in a note for Part 2:
   - `NEXT_PUBLIC_SUPABASE_URL` (looks like `https://abcd1234.supabase.co`)
   - the publishable key (starts with `sb_publishable_`; older projects show `NEXT_PUBLIC_SUPABASE_ANON_KEY`, which also works)

Never share the **secret** / **service_role** key with anyone, and never paste it into the website settings below.

---

## Part 2: Put the website online (Vercel)

1. Go to **https://vercel.com/signup**, choose **Hobby**, enter your name, then **Continue with GitHub**.
2. Click **Add New…** → **Project**.
3. Find `worklink` in the list and click **Import**.
   If it is not listed, click **Adjust GitHub App Permissions**, allow access to `worklink`, and come back.
4. Next to **Root Directory**, click **Edit**, choose **apps/web**, and click **Continue**.
   The framework should now show **Next.js**.
5. Open **Environment Variables** and add these two (name on the left, value on the right):

   | Name | Value |
   | --- | --- |
   | `NEXT_PUBLIC_SUPABASE_URL` | the URL from Supabase |
   | `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | the publishable key from Supabase |

6. Click **Deploy** and wait about two minutes.
7. When you see **Congratulations**, click **Continue to Dashboard**. Your link is under **Domains**,
   for example `worklink-abc123.vercel.app`.

### Tell Supabase your new address

1. In Supabase, go to **Authentication** → **URL Configuration**.
2. Set **Site URL** to your Vercel link (for example `https://worklink-abc123.vercel.app`) and click **Save**.

---

## Part 3: Open it on your phone

1. Open your Vercel link in Chrome (Android) or Safari (iPhone).
2. Install it like an app:
   - **Android (Chrome):** tap the **⋮** menu → **Add to Home screen** → **Install**.
   - **iPhone (Safari):** tap **Share** → **Add to Home Screen** → **Add**.

The jobs page will say there are no open jobs yet. That is expected: real jobs appear once employer posting and
admin approval are built and the first employers post. Without the Supabase keys, the site shows clearly labelled
sample jobs instead.

From now on, every change merged into `main` on GitHub updates the website automatically.

## Adding a domain later

When you buy a domain (for example a `.co.za`), add it in Vercel under **Settings → Domains**, then update the
**Site URL** in Supabase to match.
