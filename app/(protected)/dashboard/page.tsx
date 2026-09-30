import { requireAdmin } from "@/lib/auth/require-admin";
import { InventoryForm } from "@/components/inventory-form";
import { InventoryTable } from "@/components/inventory-table";
import { ExportButton } from "@/components/export-button";
import type { InventoryItem } from "@/types/inventory";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

export default async function DashboardPage() {
  const { supabase } = await requireAdmin();
  const { data } = await supabase
    .from("inventory_items")
    .select("*")
    .order("created_at", { ascending: false });

  const items = (data ?? []) as InventoryItem[];

  return (
    <div className="space-y-8">
      <Tabs defaultValue="record" className="w-full">
        <TabsList className="grid w-full max-w-100 grid-cols-2 mb-6">
          <TabsTrigger value="record">Record Device</TabsTrigger>
          <TabsTrigger value="table">View Devices ({items.length})</TabsTrigger>
        </TabsList>

        <TabsContent value="record" className="mt-0">
          <InventoryForm />
        </TabsContent>

        <TabsContent value="table" className="mt-0">
          <section className="space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-medium">Inventory List</h2>
              <ExportButton />
            </div>
            <InventoryTable items={items} />
          </section>
        </TabsContent>
      </Tabs>
    </div>
  );
}