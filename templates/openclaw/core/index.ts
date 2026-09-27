// templates/openclaw/core/index.ts
// Unified entry point for all loop-engineering guard rail checks.
// Pure logic, no I/O — safe to import from any context (CC hook, OpenClaw adapter, IPC server, tests).

import type { CheckFunction, CheckName } from "./types.ts";

import { checkSecretFiles } from "./check-secret-path.ts";
import { checkMainBranchPush } from "./check-main-branch-push.ts";
import { checkDbMigration } from "./check-db-migration.ts";
import { checkPackagePublish } from "./check-package-publish.ts";
import { checkInstallerPath } from "./check-installer-path.ts";

export const checks: Record<CheckName, CheckFunction> = {
  "secret-files": checkSecretFiles,
  "main-branch-push": checkMainBranchPush,
  "db-migration": checkDbMigration,
  "package-publish": checkPackagePublish,
  "installer-path": checkInstallerPath,
};

export { checkSecretFiles, checkMainBranchPush, checkDbMigration, checkPackagePublish, checkInstallerPath };
export { normalize, normalizeToolName, extractTarget, TOOL_ALIAS } from "./normalize.ts";
export type { ToolName, CheckResult, CheckContext, CheckFunction, CheckName, HookEvent } from "./types.ts";
