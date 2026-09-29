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
