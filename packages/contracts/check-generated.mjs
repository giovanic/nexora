// Fails when the committed types differ from what the contract generates, so
// clients can never compile against an outdated contract.
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const fresh = join(mkdtempSync(join(tmpdir(), "contracts-")), "api.d.ts");
const generated = spawnSync("npx", ["openapi-typescript", "openapi.yaml", "-o", fresh], { stdio: "inherit" });

if (generated.status !== 0) {
  process.exit(generated.status ?? 1);
}

if (readFileSync(fresh, "utf8") !== readFileSync("generated/api.d.ts", "utf8")) {
  console.error("generated/api.d.ts is out of date. Run: npm run generate -w @app/contracts");
  process.exit(1);
}
