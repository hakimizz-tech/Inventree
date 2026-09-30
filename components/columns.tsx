"use client"

import { ColumnDef } from "@tanstack/react-table"
import { ArrowUpDown } from "lucide-react"
import { Button, buttonVariants } from "@/components/ui/button"
import type { InventoryItem } from "@/types/inventory"
import { deleteItem } from "@/app/(protected)/dashboard/actions"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog"

export const columns: ColumnDef<InventoryItem>[] = [
  {
    accessorKey: "hostname",
    header: ({ column }) => {
      return (
        <Button
          variant="ghost"
          className="-ml-4"
          onClick={() => column.toggleSorting(column.getIsSorted() === "asc")}
        >
          Hostname
          <ArrowUpDown className="ml-2 h-4 w-4" />
        </Button>
      )
    },
  },
  {
    accessorKey: "make_model",
    header: "Model",
  },
  {
    accessorKey: "serial_number",
    header: "Serial",
  },
  {
    accessorKey: "cpu",
    header: "CPU",
  },
  {
    accessorKey: "ram_gb",
    header: "RAM (GB)",
  },
  {
    accessorKey: "storage_gb",
    header: "Storage (GB)",
  },
  {
    id: "actions",
    cell: ({ row }) => {
      const item = row.original

      return (
        <AlertDialog>
          <AlertDialogTrigger 
            className={`${buttonVariants({ variant: "ghost", size: "sm" })} text-destructive hover:text-destructive`}
          >
            Delete
          </AlertDialogTrigger>
          <AlertDialogContent>
            <AlertDialogHeader>
               <AlertDialogTitle>Are you absolutely sure?</AlertDialogTitle>
               <AlertDialogDescription>
                 This will permanently delete <strong>{item.hostname}</strong> (S/N: {item.serial_number}) from the database. This action cannot be undone.
               </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
               <AlertDialogCancel>Cancel</AlertDialogCancel>
               <form action={deleteItem.bind(null, item.id)}>
                 <AlertDialogAction 
                   type="submit" 
                   className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                 >
                   Delete Device
                 </AlertDialogAction>
               </form>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      )
    },
  },
]