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
