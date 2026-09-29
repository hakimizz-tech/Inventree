// Browser client — anon key only. Rarely needed since most work is server-side.
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  // Uses the browser-safe anon key; relies on RLS for security.
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
