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
