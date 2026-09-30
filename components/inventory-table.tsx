import { DataTable } from "./data-table"
import { columns } from "./columns"
import type { InventoryItem } from "@/types/inventory"

export function InventoryTable({ items }: { items: InventoryItem[] }) {
  return <DataTable columns={columns} data={items} />
}