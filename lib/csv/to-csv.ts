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


