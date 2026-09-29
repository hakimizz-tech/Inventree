import { createClient } from "@supabase/supabase-js";

async function main() {
  const [uid, newPassword] = process.argv.slice(2);
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!uid || !newPassword) {
    throw new Error("Usage: change-password.ts <uid> <new_password>");
  }
  if (!url || !key) {
    throw new Error("Missing Supabase env vars in .env.local");
  }

  const supabase = createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data, error } = await supabase.auth.admin.updateUserById(uid, {
    password: newPassword,
  });
  
  if (error) throw error;
  console.log("Password successfully updated for:", data.user.email);
}

main().catch((e) => {
  console.error(e.message ?? e);
  process.exit(1);
});