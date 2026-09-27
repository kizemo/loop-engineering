// templates/openclaw/core/index.test.ts
// Unit tests for the 5 guard rail checks (node:test).
// Run with: node --test templates/openclaw/core/*.test.ts

import { test } from "node:test";
import assert from "node:assert/strict";

import { checkSecretFiles } from "./check-secret-path.ts";
import { checkMainBranchPush } from "./check-main-branch-push.ts";
import { checkDbMigration } from "./check-db-migration.ts";
import { checkPackagePublish } from "./check-package-publish.ts";
import { checkInstallerPath } from "./check-installer-path.ts";
import { normalize, normalizeToolName, TOOL_ALIAS } from "./normalize.ts";

function ctx(toolName: string, params: Record<string, unknown>) {
  return { toolName: normalizeToolName(TOOL_ALIAS[toolName] ?? toolName), params };
}

// ---- normalize ----
test("normalize: maps Bash → exec", () => {
  const c = normalize({ tool_name: "Bash", tool_input: { command: "ls" } });
  assert.equal(c.toolName, "exec");
  assert.equal((c.params as any).command, "ls");
});

test("normalize: maps OpenClaw exec → exec", () => {
  const c = normalize({ toolName: "exec", params: { command: "ls" } });
  assert.equal(c.toolName, "exec");
});

test("normalize: handles empty params", () => {
  const c = normalize({ tool_name: "Write", tool_input: {} });
  assert.equal(c.toolName, "write");
});

// ---- secret-files ----
test("checkSecretFiles: blocks .env", () => {
  const r = checkSecretFiles(ctx("Write", { file_path: "src/.env" }));
  assert.equal(r.block, true);
  assert.match(r.reason ?? "", /guard-secret-files/);
});

test("checkSecretFiles: blocks .pem", () => {
  const r = checkSecretFiles(ctx("Write", { file_path: "certs/server.pem" }));
  assert.equal(r.block, true);
});

test("checkSecretFiles: allows .md", () => {
  const r = checkSecretFiles(ctx("Write", { file_path: "docs/readme.md" }));
  assert.equal(r.block, false);
});

test("checkSecretFiles: blocks Windows backslash path", () => {
  const r = checkSecretFiles(ctx("Write", { file_path: "C:\\Users\\foo\\credentials.json" }));
  assert.equal(r.block, true);
});

test("checkSecretFiles: empty file_path → allow", () => {
  const r = checkSecretFiles(ctx("Write", {}));
  assert.equal(r.block, false);
});

// ---- main-branch-push ----
test("checkMainBranchPush: blocks git push origin main", () => {
  const r = checkMainBranchPush(ctx("Bash", { command: "git push origin main" }));
  assert.equal(r.block, true);
});

test("checkMainBranchPush: blocks force push", () => {
  const r = checkMainBranchPush(ctx("Bash", { command: "git push -f origin dev" }));
  assert.equal(r.block, true);
});

test("checkMainBranchPush: allows feature branch", () => {
  const r = checkMainBranchPush(ctx("Bash", { command: "git push origin feature-x" }));
  assert.equal(r.block, false);
});

test("checkMainBranchPush: allows --dry-run", () => {
  const r = checkMainBranchPush(ctx("Bash", { command: "git push --dry-run origin main" }));
  assert.equal(r.block, false);
});

test("checkMainBranchPush: non-git command → allow", () => {
  const r = checkMainBranchPush(ctx("Bash", { command: "echo hello" }));
  assert.equal(r.block, false);
});

// ---- db-migration ----
test("checkDbMigration: blocks alembic upgrade without --sql", () => {
  const r = checkDbMigration(ctx("Bash", { command: "alembic upgrade head" }));
  assert.equal(r.block, true);
});

test("checkDbMigration: allows alembic upgrade --sql", () => {
  const r = checkDbMigration(ctx("Bash", { command: "alembic upgrade head --sql" }));
  assert.equal(r.block, false);
});

test("checkDbMigration: blocks manage.py migrate without --plan", () => {
  const r = checkDbMigration(ctx("Bash", { command: "python manage.py migrate" }));
  assert.equal(r.block, true);
});

test("checkDbMigration: allows manage.py migrate --plan", () => {
  const r = checkDbMigration(ctx("Bash", { command: "python manage.py migrate --plan" }));
  assert.equal(r.block, false);
});

test("checkDbMigration: blocks prisma migrate deploy", () => {
  const r = checkDbMigration(ctx("Bash", { command: "prisma migrate deploy" }));
  assert.equal(r.block, true);
});

test("checkDbMigration: blocks dbt run tag:prod", () => {
  const r = checkDbMigration(ctx("Bash", { command: "dbt run --select tag:prod" }));
  assert.equal(r.block, true);
});

test("checkDbMigration: allows dbt run tag:dev", () => {
  const r = checkDbMigration(ctx("Bash", { command: "dbt run --select tag:dev" }));
  assert.equal(r.block, false);
});

test("checkDbMigration: blocks DROP TABLE", () => {
  const r = checkDbMigration(ctx("Bash", { command: 'psql -c "DROP TABLE users;"' }));
  assert.equal(r.block, true);
});

test("checkDbMigration: allows SELECT", () => {
  const r = checkDbMigration(ctx("Bash", { command: 'psql -c "SELECT * FROM users;"' }));
  assert.equal(r.block, false);
});

// ---- package-publish ----
test("checkPackagePublish: blocks npm publish", () => {
  const r = checkPackagePublish(ctx("Bash", { command: "npm publish" }));
  assert.equal(r.block, true);
});

test("checkPackagePublish: allows npm publish --dry-run", () => {
  const r = checkPackagePublish(ctx("Bash", { command: "npm publish --dry-run" }));
  assert.equal(r.block, false);
});

test("checkPackagePublish: allows npm publish --tag next", () => {
  const r = checkPackagePublish(ctx("Bash", { command: "npm publish --tag next" }));
  assert.equal(r.block, false);
});

test("checkPackagePublish: blocks twine upload", () => {
  const r = checkPackagePublish(ctx("Bash", { command: "twine upload dist/*" }));
  assert.equal(r.block, true);
});

test("checkPackagePublish: allows twine upload testpypi", () => {
  const r = checkPackagePublish(ctx("Bash", { command: "twine upload --repository testpypi dist/*" }));
  assert.equal(r.block, false);
});

test("checkPackagePublish: blocks vsce publish", () => {
  const r = checkPackagePublish(ctx("Bash", { command: "vsce publish" }));
  assert.equal(r.block, true);
});

test("checkPackagePublish: blocks gh release create (no --draft)", () => {
  const r = checkPackagePublish(ctx("Bash", { command: "gh release create v1.0.0" }));
  assert.equal(r.block, true);
});

test("checkPackagePublish: allows gh release create --draft", () => {
  const r = checkPackagePublish(ctx("Bash", { command: "gh release create v1.0.0 --draft" }));
  assert.equal(r.block, false);
});

test("checkPackagePublish: blocks cargo publish", () => {
  const r = checkPackagePublish(ctx("Bash", { command: "cargo publish" }));
  assert.equal(r.block, true);
});

test("checkPackagePublish: allows cargo publish --dry-run", () => {
  const r = checkPackagePublish(ctx("Bash", { command: "cargo publish --dry-run" }));
  assert.equal(r.block, false);
});

// ---- installer-path ----
test("checkInstallerPath: allows target/release/bundle/", () => {
  const r = checkInstallerPath(ctx("Write", { file_path: "target/release/bundle/installer.exe" }));
  assert.equal(r.block, false);
});

test("checkInstallerPath: blocks /usr/bin/installer.exe", () => {
  const r = checkInstallerPath(ctx("Write", { file_path: "/usr/bin/installer.exe" }));
  assert.equal(r.block, true);
});

test("checkInstallerPath: blocks C:\\Windows\\installer.exe", () => {
  const r = checkInstallerPath(ctx("Write", { file_path: "C:\\Windows\\installer.exe" }));
  assert.equal(r.block, true);
});

test("checkInstallerPath: blocks Bash writing to root", () => {
  const r = checkInstallerPath(ctx("Bash", { command: "curl -o /usr/local/bin/installer.exe https://example.com/installer.exe" }));
  assert.equal(r.block, true);
});

test("checkInstallerPath: allows .md file", () => {
  const r = checkInstallerPath(ctx("Write", { file_path: "docs/readme.md" }));
  assert.equal(r.block, false);
});

test("checkInstallerPath: no installer files → allow", () => {
  const r = checkInstallerPath(ctx("Bash", { command: "echo hello" }));
  assert.equal(r.block, false);
});
