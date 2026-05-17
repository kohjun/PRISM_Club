/**
 * Build metadata for the running API.
 *
 * Values come from environment variables at process boot and are
 * SAFE TO EXPOSE — no secrets, no DB connection strings, no env dump.
 * Each field defaults to `'unknown'` when the variable is not set, so
 * an unconfigured dev boot still produces a stable response shape.
 */

export type ReleaseChannel = 'local' | 'staging' | 'beta' | 'production';

export interface BuildMetadata {
  app_version: string;
  git_sha: string;
  build_time: string | null;
  release_channel: ReleaseChannel | 'unknown';
  node_env: string;
}

const VALID_CHANNELS: ReleaseChannel[] = [
  'local',
  'staging',
  'beta',
  'production',
];

function readVersion(): string {
  return process.env.APP_VERSION?.trim() || 'unknown';
}

function readGitSha(): string {
  const raw = process.env.GIT_SHA?.trim();
  if (!raw) return 'unknown';
  // Short SHA only — long SHAs are fine but trim trailing whitespace.
  return raw;
}

function readBuildTime(): string | null {
  const raw = process.env.BUILD_TIME?.trim();
  if (!raw) return null;
  // Parse-and-rewrite so we surface a normalized ISO 8601 string when
  // the input was a valid date, and fall back to the raw value (still
  // useful) when it wasn't.
  const parsed = Date.parse(raw);
  if (Number.isNaN(parsed)) return raw;
  return new Date(parsed).toISOString();
}

function readReleaseChannel(): ReleaseChannel | 'unknown' {
  const raw = process.env.RELEASE_CHANNEL?.trim().toLowerCase();
  if (!raw) return 'unknown';
  return (VALID_CHANNELS as string[]).includes(raw)
    ? (raw as ReleaseChannel)
    : 'unknown';
}

export function readBuildMetadata(): BuildMetadata {
  return {
    app_version: readVersion(),
    git_sha: readGitSha(),
    build_time: readBuildTime(),
    release_channel: readReleaseChannel(),
    node_env: process.env.NODE_ENV ?? 'development',
  };
}
