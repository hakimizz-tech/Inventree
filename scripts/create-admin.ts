// Creates the single admin user. Run locally, never deploy this.
//   npx tsx --env-file=.env.local scripts/create-admin.ts you@example.com 'a-long-password'
import { createClient } from "@supabase/supabase-js";

async function main() {
  const [email, password] = process.argv.slice(2);
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!email || !password) throw new Error("Usage: create-admin.ts <email> <password>");
  if (!url || !key) throw new Error("Missing Supabase env vars in .env.local");

  const supabase = createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    app_metadata: { role: "admin" }, // <- what RLS and requireAdmin() check
  });
  if (error) throw error;
  console.log("Admin created:", data.user.id);
}

main().catch((e) => {
  console.error(e.message ?? e);
  process.exit(1);
});
