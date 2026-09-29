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
