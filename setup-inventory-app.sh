#!/usr/bin/env bash
# =============================================================================
# setup-inventory-app.sh
# Scaffolds the inventory app on top of a fresh `create-next-app` project
# (root-level app/, components/, lib/ — no src/ folder).
#
# Usage (from the project root):
#   chmod +x setup-inventory-app.sh && ./setup-inventory-app.sh
#
# Safe to re-run: existing files are skipped. Use FORCE=1 to overwrite.
# Assumes the "@/*" import alias points to the project root (create-next-app default).
# =============================================================================
set -euo pipefail

[[ -f package.json ]] || { echo "Run this from the project root (package.json not found)."; exit 1; }

# write_file <path>  — reads file content from stdin, skips if it already exists
write_file() {
  local f="$1"
  mkdir -p "$(dirname "$f")"
  if [[ -e "$f" && "${FORCE:-0}" != "1" ]]; then
    echo "  skip    $f"
    cat >/dev/null
  else
    cat >"$f"
    echo "  create  $f"
  fi
}

echo "==> 1/6 Installing dependencies"
npm install @supabase/ssr @supabase/supabase-js zod papaparse server-only \
  @t3-oss/env-nextjs @upstash/ratelimit @upstash/redis
# vitest needs @types/node >= 22 (create-next-app pins ^20), so bump it in the same install
npm install -D @types/node@^22 @types/papaparse husky vitest tsx

echo "==> 2/6 Adding shadcn/ui components"
npx shadcn@latest add button textarea card input label table alert-dialog sonner badge skeleton -y \
  || echo "  (shadcn add failed — run it manually later)"

echo "==> 3/6 Creating files"

# ---------------------------------------------------------------- env & git --
write_file .env.example <<'EOF'
# Copy to .env.local and fill in. NEVER commit .env.local.

# Safe for the browser (protected by Row Level Security)
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=

# SERVER ONLY — bypasses RLS. Used only by scripts/create-admin.ts.
# In production, keep it out of Vercel unless you really need it.
SUPABASE_SERVICE_ROLE_KEY=

# Optional: rate limiting (https://upstash.com)
UPSTASH_REDIS_REST_URL=
UPSTASH_REDIS_REST_TOKEN=
EOF

# Make sure real env files are ignored but .env.example is tracked
grep -qxF '.env*' .gitignore 2>/dev/null || echo '.env*' >> .gitignore
grep -qxF '!.env.example' .gitignore 2>/dev/null || echo '!.env.example' >> .gitignore

write_file .gitleaks.toml <<'EOF'
# Uses gitleaks' default ruleset. Add allowlists here if needed.
[extend]
useDefault = true
EOF

write_file lib/env.ts <<'EOF'
// Validates env vars at build/start. Missing or misplaced vars fail loudly.
import { createEnv } from "@t3-oss/env-nextjs";
import { z } from "zod";

export const env = createEnv({
  server: {
    SUPABASE_SERVICE_ROLE_KEY: z.string().min(1).optional(),
    UPSTASH_REDIS_REST_URL: z.string().url().optional(),
    UPSTASH_REDIS_REST_TOKEN: z.string().min(1).optional(),
  },
  client: {
    NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
    NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
  },
  runtimeEnv: {
    SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
    UPSTASH_REDIS_REST_URL: process.env.UPSTASH_REDIS_REST_URL,
    UPSTASH_REDIS_REST_TOKEN: process.env.UPSTASH_REDIS_REST_TOKEN,
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  },
});
EOF

# ----------------------------------------------------------- supabase / sql --
write_file supabase/migrations/0001_create_inventory.sql <<'EOF'
-- One row per device. raw_text is the source of truth; other columns are parsed.
create table public.inventory_items (
  id                  uuid primary key default gen_random_uuid(),
  raw_text            text not null,
  hostname            text,
  make_model          text,
  serial_number       text unique,      -- prevents duplicate devices
  cpu                 text,
  ram_gb              numeric,
  storage_gb          numeric,
  gpu                 text,
  os                  text,
  purchase_date       text,             -- free text, e.g. "Not tracked natively (...)"
  warranty_expiration text,
  mac_addresses       text,
  created_by          uuid not null references auth.users(id) default auth.uid(),
  created_at          timestamptz not null default now()
);

alter table public.inventory_items enable row level security;
EOF

write_file supabase/migrations/0002_rls_policies.sql <<'EOF'
-- Only the admin (app_metadata.role = 'admin') can read or write.
-- app_metadata can only be set with the service-role key, so users can't self-promote.
create policy "admin full access"
on public.inventory_items
for all
to authenticated
using      ( (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin' )
with check ( (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin' );
EOF

write_file scripts/create-admin.ts <<'EOF'
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
EOF

# ------------------------------------------------------------ supabase libs --
write_file lib/supabase/client.ts <<'EOF'
// Browser client — anon key only. Rarely needed since most work is server-side.
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
EOF

write_file lib/supabase/server.ts <<'EOF'
// Server client for Server Components, Server Actions and Route Handlers.
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createClient() {
  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll(list) {
          try {
            list.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
          } catch {
            // Called from a Server Component; the proxy/middleware refreshes cookies instead.
          }
        },
      },
    }
  );
}
EOF

write_file lib/supabase/admin.ts <<'EOF'
// Service-role client. BYPASSES RLS. Server only — `server-only` fails the build
// if a client component ever imports this. Use sparingly.
import "server-only";
import { createClient } from "@supabase/supabase-js";

export function createAdminClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}
EOF

write_file lib/supabase/middleware.ts <<'EOF'
// Refreshes the session cookie on each request and guards routes.
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll(list) {
          list.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          list.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
        },
      },
    }
  );

  // getUser() re-validates the token with Supabase (unlike getSession()).
  const { data: { user } } = await supabase.auth.getUser();
  const isAdmin = user?.app_metadata?.role === "admin";
  const onLogin = request.nextUrl.pathname.startsWith("/login");

  if (!isAdmin && !onLogin) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  if (isAdmin && onLogin) {
    return NextResponse.redirect(new URL("/dashboard", request.url));
  }
  return response;
}
EOF

# Next.js 16 renamed middleware.ts -> proxy.ts. Detect the installed major version.
NEXT_MAJOR=$(node -p "require('next/package.json').version.split('.')[0]")
if [[ "$NEXT_MAJOR" -ge 16 ]]; then
  write_file proxy.ts <<'EOF'
import type { NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export async function proxy(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  // Run on everything except static assets
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
EOF
else
  write_file middleware.ts <<'EOF'
import type { NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export async function middleware(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
EOF
fi

# ---------------------------------------------------------------- auth/limit --
write_file lib/auth/require-admin.ts <<'EOF'
// Call at the top of EVERY Server Action and Route Handler.
import "server-only";
import { createClient } from "@/lib/supabase/server";

export async function requireAdmin() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user || user.app_metadata?.role !== "admin") {
    throw new Error("Unauthorized");
  }
  return { supabase, user };
}
EOF

write_file lib/ratelimit.ts <<'EOF'
// Optional: becomes null (no limiting) when Upstash env vars are not set, e.g. in local dev.
import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

const url = process.env.UPSTASH_REDIS_REST_URL;
const token = process.env.UPSTASH_REDIS_REST_TOKEN;

export const limiter =
  url && token
    ? new Ratelimit({
        redis: new Redis({ url, token }),
        limiter: Ratelimit.slidingWindow(5, "1 m"), // 5 requests / minute
        prefix: "inventory",
      })
    : null;
EOF

# ------------------------------------------------------- parser / csv / zod --
write_file lib/parser/parse-device-text.ts <<'EOF'
// Turns "Label : value" lines into typed columns.
export type ParsedDevice = {
  hostname?: string;
  make_model?: string;
  serial_number?: string;
  cpu?: string;
  ram_gb?: number | null;
  storage_gb?: number | null;
  gpu?: string;
  os?: string;
  purchase_date?: string;
  warranty_expiration?: string;
  mac_addresses?: string;
};

const LABELS: Record<string, keyof ParsedDevice> = {
  "device hostname": "hostname",
  "make & model": "make_model",
  "serial number (s/n)": "serial_number",
  "processor (cpu)": "cpu",
  "ram (gb)": "ram_gb",
  "storage (gb)": "storage_gb",
  "gpu / graphics": "gpu",
  "operating system": "os",
  "purchase date": "purchase_date",
  "warranty expiration": "warranty_expiration",
  "mac address": "mac_addresses",
};

const NUMERIC = new Set<keyof ParsedDevice>(["ram_gb", "storage_gb"]);

export function parseDeviceText(text: string): ParsedDevice {
  const out: Record<string, string | number | null> = {};

  for (const line of text.split(/\r?\n/)) {
    const i = line.indexOf(":"); // FIRST colon only — MACs and dates contain more
    if (i < 0) continue;
    const key = LABELS[line.slice(0, i).trim().toLowerCase()];
    if (!key) continue; // unknown labels stay in raw_text only
    const value = line.slice(i + 1).trim();
    if (NUMERIC.has(key)) {
      const n = parseFloat(value);
      out[key] = Number.isFinite(n) ? n : null;
    } else {
      out[key] = value;
    }
  }
  return out as ParsedDevice;
}
EOF

write_file lib/parser/parse-device-text.test.ts <<'EOF'
import { describe, expect, it } from "vitest";
import { parseDeviceText } from "./parse-device-text";

const SAMPLE = `Device Hostname     : DESKTOP-3FLBBON
Make & Model        : HP HP All-in-One Desktop 24-cr0xxx
Serial Number (S/N) : 8CC5432QLF
RAM (GB)            : 15.68
Purchase Date       : Not tracked natively (OS Install Date: 2026-07-09)
MAC Address         : AC:F4:66:B8:17:B8, 00:50:56:C0:00:01`;

describe("parseDeviceText", () => {
  it("parses labels, numbers, and values containing colons", () => {
    const r = parseDeviceText(SAMPLE);
    expect(r.hostname).toBe("DESKTOP-3FLBBON");
    expect(r.serial_number).toBe("8CC5432QLF");
    expect(r.ram_gb).toBe(15.68);
    expect(r.purchase_date).toContain("2026-07-09");
    expect(r.mac_addresses).toContain("AC:F4:66:B8:17:B8");
  });
});
EOF

write_file lib/csv/to-csv.ts <<'EOF'
import Papa from "papaparse";

// Cells starting with these characters can execute as formulas in Excel/Sheets.
const FORMULA_START = /^[=+\-@\t\r]/;

export function toCsv(rows: Record<string, unknown>[]): string {
  const safe = rows.map((row) =>
    Object.fromEntries(
      Object.entries(row).map(([k, v]) => [
        k,
        typeof v === "string" && FORMULA_START.test(v) ? `'${v}` : v,
      ])
    )
  );
  return Papa.unparse(safe, { quotes: true }); // quotes: MAC lists contain commas
}
EOF

write_file lib/validation/inventory.ts <<'EOF'
import { z } from "zod";

export const inventoryInputSchema = z.object({
  rawText: z
    .string()
    .trim()
    .min(10, "Paste the device report first.")
    .max(5000, "Text is too long (max 5,000 characters)."),
});

// Required labels after parsing
export const requiredParsedSchema = z.object({
  hostname: z.string().min(1, "Missing 'Device Hostname'"),
  serial_number: z.string().min(1, "Missing 'Serial Number (S/N)'"),
});
EOF

write_file types/inventory.ts <<'EOF'
export type InventoryItem = {
  id: string;
  raw_text: string;
  hostname: string | null;
  make_model: string | null;
  serial_number: string | null;
  cpu: string | null;
  ram_gb: number | null;
  storage_gb: number | null;
  gpu: string | null;
  os: string | null;
  purchase_date: string | null;
  warranty_expiration: string | null;
  mac_addresses: string | null;
  created_at: string;
};
EOF

# ---------------------------------------------------------------- app routes --
FORCE=1 write_file app/page.tsx <<'EOF'
import { redirect } from "next/navigation";

export default function Home() {
  redirect("/dashboard");
}
EOF

write_file app/login/actions.ts <<'EOF'
"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { limiter } from "@/lib/ratelimit";

export type LoginState = { error?: string };

export async function signIn(_prev: LoginState, formData: FormData): Promise<LoginState> {
  const ip = (await headers()).get("x-forwarded-for")?.split(",")[0] ?? "unknown";
  if (limiter) {
    const { success } = await limiter.limit(`login:${ip}`);
    if (!success) return { error: "Too many attempts. Try again in a minute." };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: String(formData.get("email") ?? ""),
    password: String(formData.get("password") ?? ""),
  });
  if (error) return { error: "Invalid email or password." }; // generic on purpose

  redirect("/dashboard");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
EOF

write_file app/login/page.tsx <<'EOF'
"use client";

import { useActionState } from "react";
import { signIn, type LoginState } from "./actions";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export default function LoginPage() {
  const [state, action, pending] = useActionState<LoginState, FormData>(signIn, {});

  return (
    <main className="flex min-h-screen items-center justify-center p-4">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Admin sign in</CardTitle>
        </CardHeader>
        <CardContent>
          <form action={action} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input id="email" name="email" type="email" autoComplete="email" required />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <Input id="password" name="password" type="password" autoComplete="current-password" required />
            </div>
            {state.error && <p className="text-sm text-red-600">{state.error}</p>}
            <Button type="submit" className="w-full" disabled={pending}>
              {pending ? "Signing in…" : "Sign in"}
            </Button>
          </form>
        </CardContent>
      </Card>
    </main>
  );
}
EOF

write_file "app/(protected)/layout.tsx" <<'EOF'
import { redirect } from "next/navigation";
import { requireAdmin } from "@/lib/auth/require-admin";
import { LogoutButton } from "@/components/logout-button";
import { Toaster } from "@/components/ui/sonner";

export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  try {
    await requireAdmin();
  } catch {
    redirect("/login");
  }
  return (
    <div className="mx-auto max-w-5xl p-6">
      <header className="mb-6 flex items-center justify-between">
        <h1 className="text-xl font-semibold">Inventory</h1>
        <LogoutButton />
      </header>
      {children}
      <Toaster />
    </div>
  );
}
EOF

write_file "app/(protected)/dashboard/actions.ts" <<'EOF'
"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth/require-admin";
import { limiter } from "@/lib/ratelimit";
import { parseDeviceText } from "@/lib/parser/parse-device-text";
import { inventoryInputSchema, requiredParsedSchema } from "@/lib/validation/inventory";

export type SaveState = { ok?: boolean; message?: string; ts?: number };

export async function saveItem(_prev: SaveState, formData: FormData): Promise<SaveState> {
  try {
    const { supabase, user } = await requireAdmin();

    if (limiter) {
      const { success } = await limiter.limit(`save:${user.id}`);
      if (!success) return { message: "Slow down — too many saves." };
    }

    const input = inventoryInputSchema.safeParse({ rawText: formData.get("rawText") });
    if (!input.success) return { message: input.error.issues[0].message };

    const parsed = parseDeviceText(input.data.rawText);
    const required = requiredParsedSchema.safeParse(parsed);
    if (!required.success) return { message: required.error.issues.map((i) => i.message).join(", ") };

    const { error } = await supabase
      .from("inventory_items")
      .insert({ raw_text: input.data.rawText, ...parsed });

    if (error?.code === "23505") return { message: "A device with this serial number already exists." };
    if (error) return { message: "Could not save. Please try again." };

    revalidatePath("/dashboard");
    return { ok: true, message: "Device saved.", ts: Date.now() };
  } catch {
    return { message: "Unauthorized." };
  }
}

export async function deleteItem(id: string): Promise<void> {
  const { supabase } = await requireAdmin();
  await supabase.from("inventory_items").delete().eq("id", id);
  revalidatePath("/dashboard");
}
EOF

write_file "app/(protected)/dashboard/page.tsx" <<'EOF'
import { requireAdmin } from "@/lib/auth/require-admin";
import { InventoryForm } from "@/components/inventory-form";
import { InventoryTable } from "@/components/inventory-table";
import { ExportButton } from "@/components/export-button";
import type { InventoryItem } from "@/types/inventory";

export default async function DashboardPage() {
  const { supabase } = await requireAdmin();
  const { data } = await supabase
    .from("inventory_items")
    .select("*")
    .order("created_at", { ascending: false });

  return (
    <div className="space-y-8">
      <InventoryForm />
      <section className="space-y-3">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-medium">Devices ({data?.length ?? 0})</h2>
          <ExportButton />
        </div>
        <InventoryTable items={(data ?? []) as InventoryItem[]} />
      </section>
    </div>
  );
}
EOF

write_file "app/(protected)/dashboard/loading.tsx" <<'EOF'
import { Skeleton } from "@/components/ui/skeleton";

export default function Loading() {
  return <Skeleton className="h-64 w-full" />;
}
EOF

write_file app/api/export/route.ts <<'EOF'
import { requireAdmin } from "@/lib/auth/require-admin";
import { toCsv } from "@/lib/csv/to-csv";

export async function GET() {
  try {
    const { supabase } = await requireAdmin();

    const { data, error } = await supabase
      .from("inventory_items")
      .select(
        "hostname, make_model, serial_number, cpu, ram_gb, storage_gb, gpu, os, purchase_date, warranty_expiration, mac_addresses, created_at"
      )
      .order("created_at", { ascending: false });

    if (error) return new Response("Export failed", { status: 500 });

    const date = new Date().toISOString().slice(0, 10);
    return new Response(toCsv(data ?? []), {
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": `attachment; filename="inventory-${date}.csv"`,
        "Cache-Control": "no-store",
      },
    });
  } catch {
    return new Response("Unauthorized", { status: 401 });
  }
}
EOF

# ---------------------------------------------------------------- components --
write_file components/inventory-form.tsx <<'EOF'
"use client";

import { useActionState, useEffect, useRef } from "react";
import { toast } from "sonner";
import { saveItem, type SaveState } from "@/app/(protected)/dashboard/actions";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";

export function InventoryForm() {
  const [state, action, pending] = useActionState<SaveState, FormData>(saveItem, {});
  const formRef = useRef<HTMLFormElement>(null);

  useEffect(() => {
    if (!state.message) return;
    if (state.ok) {
      toast.success(state.message);
      formRef.current?.reset(); // clear the textbox after a successful save
    } else {
      toast.error(state.message);
    }
  }, [state]);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Record a device</CardTitle>
      </CardHeader>
      <CardContent>
        <form ref={formRef} action={action} className="space-y-4">
          <Textarea
            name="rawText"
            rows={12}
            maxLength={5000}
            className="font-mono text-sm"
            placeholder={"Device Hostname     : DESKTOP-XXXX\nSerial Number (S/N) : ..."}
            required
          />
          <Button type="submit" disabled={pending}>
            {pending ? "Saving…" : "Save device"}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
EOF

write_file components/inventory-table.tsx <<'EOF'
import { deleteItem } from "@/app/(protected)/dashboard/actions";
import { Button } from "@/components/ui/button";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { InventoryItem } from "@/types/inventory";

// TODO: swap for shadcn DataTable (TanStack) for sorting/search, and AlertDialog to confirm deletes.
export function InventoryTable({ items }: { items: InventoryItem[] }) {
  if (items.length === 0) return <p className="text-sm text-muted-foreground">No devices yet.</p>;

  return (
    <div className="overflow-x-auto rounded-md border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Hostname</TableHead>
            <TableHead>Model</TableHead>
            <TableHead>Serial</TableHead>
            <TableHead>CPU</TableHead>
            <TableHead>RAM (GB)</TableHead>
            <TableHead>Storage (GB)</TableHead>
            <TableHead />
          </TableRow>
        </TableHeader>
        <TableBody>
          {items.map((i) => (
            <TableRow key={i.id}>
              <TableCell>{i.hostname}</TableCell>
              <TableCell>{i.make_model}</TableCell>
              <TableCell>{i.serial_number}</TableCell>
              <TableCell>{i.cpu}</TableCell>
              <TableCell>{i.ram_gb}</TableCell>
              <TableCell>{i.storage_gb}</TableCell>
              <TableCell>
                <form action={deleteItem.bind(null, i.id)}>
                  <Button variant="ghost" size="sm" type="submit">Delete</Button>
                </form>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
EOF

write_file components/export-button.tsx <<'EOF'
import { Button } from "@/components/ui/button";

export function ExportButton() {
  // Plain <a>: the browser handles the download from /api/export
  return (
    <Button asChild variant="outline">
      <a href="/api/export" download>Export CSV</a>
    </Button>
  );
}
EOF

write_file components/logout-button.tsx <<'EOF'
import { signOut } from "@/app/login/actions";
import { Button } from "@/components/ui/button";

export function LogoutButton() {
  return (
    <form action={signOut}>
      <Button variant="outline" type="submit">Sign out</Button>
    </form>
  );
}
EOF

echo "==> 4/6 Security headers (next.config.ts)"
if [[ -f next.config.ts && ! -f next.config.ts.bak ]]; then cp next.config.ts next.config.ts.bak; fi
FORCE=1 write_file next.config.ts <<'EOF'
import type { NextConfig } from "next";

// NOTE: add a Content-Security-Policy separately (needs a per-request nonce with
// Next.js inline scripts): https://nextjs.org/docs/app/guides/content-security-policy
const securityHeaders = [
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
];

const nextConfig: NextConfig = {
  poweredByHeader: false,
  async headers() {
    return [{ source: "/(.*)", headers: securityHeaders }];
  },
};

export default nextConfig;
EOF

echo "==> 5/6 npm scripts + git hook"
npm pkg set scripts.test="vitest run" >/dev/null
npm pkg set scripts.create-admin="tsx --env-file=.env.local scripts/create-admin.ts" >/dev/null

if [[ -d .git ]]; then
  npx husky init >/dev/null 2>&1 || true
  cat > .husky/pre-commit <<'EOF'
# Block commits that contain secrets (install: https://github.com/gitleaks/gitleaks)
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks protect --staged --redact -v
else
  echo "warning: gitleaks not installed, skipping secret scan"
fi
EOF
  echo "  create  .husky/pre-commit"
else
  echo "  (no .git directory — skipped husky)"
fi

echo "==> 6/6 Done"
cat <<'EOF'

Next steps:
  1. Create a Supabase project. In Auth settings, DISABLE "Allow new users to sign up".
  2. cp .env.example .env.local   and fill in the URL, anon key and service-role key.
  3. Run supabase/migrations/0001 then 0002 in the Supabase SQL editor.
  4. npm run create-admin -- you@example.com 'a-long-password'
  5. npm run test && npm run dev  → open http://localhost:3000
  6. Enable MFA on the admin account, then deploy to Vercel and set env vars there.
EOF