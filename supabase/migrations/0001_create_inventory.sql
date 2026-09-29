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
  purchase_date       text,             -- free text: "Not tracked natively (...)"
  warranty_expiration text,
  mac_addresses       text,
  created_by          uuid not null references auth.users(id) default auth.uid(),
  created_at          timestamptz not null default now()
);

alter table public.inventory_items enable row level security;