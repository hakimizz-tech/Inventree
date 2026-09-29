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
