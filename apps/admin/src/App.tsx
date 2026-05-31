import { useEffect, useState } from 'react';
import {
  ApiError,
  AnalyticsSummary,
  clearSession,
  EventsClientStatus,
  fetchAnalyticsSummary,
  fetchEventsClientStatus,
  fetchHealthReady,
  fetchHealthVersion,
  fetchOpenReports,
  fetchOpsSummary,
  fetchSystemHealth,
  getSession,
  getApiBase,
  HealthReady,
  HealthVersion,
  login,
  refreshSignals,
  ReportItem,
  Session,
  setApiBase,
  setSession,
  type MetricBlock,
  type OpsSummary,
  type SystemHealthSnapshot,
} from './api';

const DOC_LINKS: { label: string; path: string; what: string }[] = [
  {
    label: 'BETA_READINESS',
    path: 'docs/BETA_READINESS.md',
    what: 'feature map, architecture, go/no-go',
  },
  {
    label: 'BETA_LAUNCH_RUNBOOK',
    path: 'docs/BETA_LAUNCH_RUNBOOK.md',
    what: 'deploy sequence, env, smoke, rollback, incident response',
  },
  {
    label: 'BETA_QA_SCRIPT',
    path: 'docs/BETA_QA_SCRIPT.md',
    what: 'manual QA flows for cut-over',
  },
  {
    label: 'STAGING_SMOKE',
    path: 'docs/STAGING_SMOKE.md',
    what: 'how to point scripts/smoke.sh at staging',
  },
];

const REQUIRED_ROLES = ['CURATOR', 'MODERATOR', 'ADMIN'];

function hasAdminRole(session: Session | null): boolean {
  if (!session) return false;
  return session.roles.some((r) => REQUIRED_ROLES.includes(r));
}

export function App() {
  const [session, setSessionState] = useState<Session | null>(getSession());

  if (!session) {
    return <LoginView onSession={(s) => setSessionState(s)} />;
  }
  if (!hasAdminRole(session)) {
    return (
      <div className="layout">
        <header className="topbar">
          <span className="title">PRISM Club / Admin</span>
          <span className="who">{session.nickname ?? session.user_id}</span>
          <button
            onClick={() => {
              clearSession();
              setSessionState(null);
            }}
          >
            로그아웃
          </button>
        </header>
        <main className="body" style={{ gridTemplateColumns: '1fr' }}>
          <div className="banner warn">
            현재 계정({session.roles.join(', ') || 'MEMBER'})은 운영 콘솔에 접근할 수
            있는 권한이 없습니다. CURATOR, MODERATOR, 또는 ADMIN 역할이 필요합니다.
          </div>
        </main>
      </div>
    );
  }
  return (
    <Dashboard session={session} onSignOut={() => setSessionState(null)} />
  );
}

function LoginView({ onSession }: { onSession: (s: Session) => void }) {
  const [userId, setUserId] = useState('');
  const [apiBase, setApiBaseState] = useState(getApiBase());
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      setApiBase(apiBase);
      const res = await login(userId.trim());
      setSession(res.access_token, res.session);
      onSession(res.session);
    } catch (e) {
      const msg = e instanceof ApiError ? e.message : String(e);
      setError(msg);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="login">
      <h1>PRISM Club / Admin — 로그인</h1>
      <form onSubmit={submit}>
        <label>
          API base URL
          <input
            type="text"
            value={apiBase}
            onChange={(e) => setApiBaseState(e.target.value)}
            placeholder="http://localhost:3000/v1"
          />
        </label>
        <label>
          User ID (seeded persona UUID)
          <input
            type="text"
            value={userId}
            onChange={(e) => setUserId(e.target.value)}
            placeholder="44444444-4444-4444-4444-444444444444 (coral)"
            autoFocus
          />
        </label>
        <button disabled={submitting || userId.trim().length === 0}>
          {submitting ? '로그인 중...' : '로그인'}
        </button>
        {error && <p className="err">{error}</p>}
      </form>
    </div>
  );
}

function Dashboard({
  session,
  onSignOut,
}: {
  session: Session;
  onSignOut: () => void;
}) {
  const [summary, setSummary] = useState<OpsSummary | null>(null);
  const [reports, setReports] = useState<ReportItem[]>([]);
  const [eventsStatus, setEventsStatus] = useState<EventsClientStatus | null>(
    null,
  );
  const [analytics, setAnalytics] = useState<AnalyticsSummary | null>(null);
  const [version, setVersion] = useState<HealthVersion | null>(null);
  const [ready, setReady] = useState<HealthReady | null>(null);
  const [systemHealth, setSystemHealth] =
    useState<SystemHealthSnapshot | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [signalMsg, setSignalMsg] = useState<string | null>(null);

  async function reload() {
    setLoading(true);
    setError(null);
    try {
      const [s, r, ec, an, v, rd, sh] = await Promise.all([
        fetchOpsSummary(),
        fetchOpenReports(),
        fetchEventsClientStatus().catch(() => null),
        fetchAnalyticsSummary().catch(() => null),
        fetchHealthVersion().catch(() => null),
        fetchHealthReady().catch(() => null),
        fetchSystemHealth().catch(() => null),
      ]);
      setSummary(s);
      setReports(r.items);
      setEventsStatus(ec);
      setAnalytics(an);
      setVersion(v);
      setReady(rd);
      setSystemHealth(sh);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void reload();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function doRefreshSignals() {
    setRefreshing(true);
    setSignalMsg(null);
    try {
      const out = await refreshSignals();
      setSignalMsg(
        `Refreshed ${out.hubs_processed} hubs · ${out.signals_written} signals written`,
      );
    } catch (e) {
      setSignalMsg(`Failed: ${e instanceof ApiError ? e.message : String(e)}`);
    } finally {
      setRefreshing(false);
    }
  }

  return (
    <div className="layout">
      <header className="topbar">
        <span className="title">PRISM Club / Admin</span>
        <span className="tag">{session.roles.join(' · ')}</span>
        <span className="who">{session.nickname ?? session.user_id}</span>
        <button className="btn" onClick={() => void reload()}>
          새로고침
        </button>
        <button
          className="btn"
          onClick={() => {
            clearSession();
            onSignOut();
          }}
        >
          로그아웃
        </button>
      </header>
      <main className="body">
        {loading && <div className="banner">로딩 중...</div>}
        {error && <div className="banner warn">로드 실패: {error}</div>}

        <BetaLaunchCard
          version={version}
          ready={ready}
          eventsStatus={eventsStatus}
          analytics={analytics}
          summary={summary}
        />

        {summary && (
          <>
            <div className="card">
              <h3>Pending contributions</h3>
              <div className="big">{summary.pending_contributions.count}</div>
              <div className="row">
                <span className="label">큐레이션 큐</span>
                <span className="value">
                  <a
                    href={`${getApiBase().replace(/\/v1$/, '')}/v1/admin/reports`}
                    target="_blank"
                    rel="noreferrer"
                  >
                    /v1/admin/reports
                  </a>
                </span>
              </div>
            </div>

            <div className="card">
              <h3>Open reports</h3>
              <div className="big">{summary.open_reports.count}</div>
              <div className="row">
                <span className="label">최근</span>
                <span className="value">
                  {reports.length === 0
                    ? '없음'
                    : `${reports.length}건 대기 중`}
                </span>
              </div>
            </div>

            <div className="card">
              <h3>Recruitment posts</h3>
              <div className="big">
                {summary.recruitment_posts.count_open} /{' '}
                {summary.recruitment_posts.count_total}
              </div>
              <div className="row">
                <span className="label">열림 / 전체</span>
                <span className="value">VERIFIED_PLANNER 영역</span>
              </div>
            </div>

            <div className="card">
              <h3>Scoped DM (P6.9)</h3>
              <div className="big">{summary.dm.reports_24h}</div>
              <div className="row">
                <span className="label">24h 신고 / 열린 채널</span>
                <span className="value">
                  {summary.dm.reports_24h} / {summary.dm.channels_open}
                </span>
              </div>
            </div>

            <div className="card">
              <h3>Signals</h3>
              <p style={{ color: 'var(--muted)', margin: '0 0 8px' }}>
                Recalculate TopicSignal entries from real activity.
              </p>
              <button
                className="btn primary"
                disabled={refreshing}
                onClick={() => void doRefreshSignals()}
              >
                {refreshing ? '새로고침 중...' : '시그널 새로고침'}
              </button>
              {signalMsg && (
                <p style={{ marginTop: 8, color: 'var(--muted)' }}>{signalMsg}</p>
              )}
            </div>

            {eventsStatus && (
              <div className="card">
                <h3>Events client</h3>
                <div className="row">
                  <span className="label">Mode</span>
                  <span className="value">
                    <span className="tag">{eventsStatus.mode}</span>
                  </span>
                </div>
                <div className="row">
                  <span className="label">Base URL</span>
                  <span className="value">
                    {eventsStatus.base_url_configured ? '✓ configured' : '— not set —'}
                  </span>
                </div>
                <div className="row">
                  <span className="label">parsed_ok</span>
                  <span className="value">{eventsStatus.stats.parsed_ok}</span>
                </div>
                <div className="row">
                  <span className="label">parse_failed</span>
                  <span className="value">{eventsStatus.stats.parse_failed}</span>
                </div>
                <div className="row">
                  <span className="label">http_errors</span>
                  <span className="value">{eventsStatus.stats.http_errors}</span>
                </div>
                <div className="row">
                  <span className="label">timeouts</span>
                  <span className="value">{eventsStatus.stats.timeouts}</span>
                </div>
                {eventsStatus.stats.last_error && (
                  <p style={{ marginTop: 8, color: 'var(--muted)' }}>
                    last error: {eventsStatus.stats.last_error}
                  </p>
                )}
              </div>
            )}

            {analytics && (
              <div className="card">
                <h3>Analytics ({analytics.window_days}d)</h3>
                <div className="list">
                  {analytics.counts.length === 0 && (
                    <div className="item" style={{ color: 'var(--muted)' }}>
                      — 이벤트 없음 —
                    </div>
                  )}
                  {analytics.counts.map((c) => (
                    <div className="item" key={c.event_type}>
                      <div>{c.event_type}</div>
                      <div className="meta">{c.count}</div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {systemHealth && (
              <SystemHealthCard snapshot={systemHealth} />
            )}

            <div className="card">
              <h3>Recent users ({summary.recent_users.count})</h3>
              <div className="list">
                {summary.recent_users.items.length === 0 && (
                  <div className="item" style={{ color: 'var(--muted)' }}>
                    — 없음 —
                  </div>
                )}
                {summary.recent_users.items.map((u) => (
                  <div className="item" key={u.id}>
                    <div>{u.nickname ?? u.id.substring(0, 8)}</div>
                    <div className="meta">{u.created_at.substring(0, 10)}</div>
                  </div>
                ))}
              </div>
            </div>

            <div className="card">
              <h3>Recent rooms ({summary.recent_rooms.count})</h3>
              <div className="list">
                {summary.recent_rooms.items.length === 0 && (
                  <div className="item" style={{ color: 'var(--muted)' }}>
                    — 없음 —
                  </div>
                )}
                {summary.recent_rooms.items.map((r) => (
                  <div className="item" key={r.id}>
                    <div>{r.name}</div>
                    <div className="meta">{r.slug}</div>
                  </div>
                ))}
              </div>
            </div>

            <div className="card" style={{ gridColumn: '1 / -1' }}>
              <h3>Open report queue</h3>
              {reports.length === 0 && (
                <div className="item" style={{ color: 'var(--muted)' }}>
                  대기 중인 신고가 없습니다.
                </div>
              )}
              {reports.length > 0 && (
                <div className="list">
                  {reports.map((r) => (
                    <div className="item" key={r.id}>
                      <span className="tag">{r.target_type}</span>
                      <strong>{r.reason}</strong>{' '}
                      <span className="meta">
                        by {r.reporter.nickname ?? r.reporter.id.substring(0, 6)}{' '}
                        · {r.created_at.substring(0, 10)}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </>
        )}
      </main>
    </div>
  );
}

/**
 * Compact "Beta Launch" checklist card. Pure derivation from already-
 * fetched diagnostics — no new product API. Renders read-only signals
 * (API ready, build metadata, events client mode, analytics 30-day
 * volume, open report + pending contribution counts) plus repo-relative
 * paths to the operational docs.
 */
function BetaLaunchCard({
  version,
  ready,
  eventsStatus,
  analytics,
  summary,
}: {
  version: HealthVersion | null;
  ready: HealthReady | null;
  eventsStatus: EventsClientStatus | null;
  analytics: AnalyticsSummary | null;
  summary: OpsSummary | null;
}) {
  const apiReady = ready?.ok === true && ready?.db === 'up';
  const dbState = ready?.db ?? 'unknown';
  const eventsMode = eventsStatus?.mode ?? 'unknown';
  const eventsParseFailed = eventsStatus?.stats.parse_failed ?? 0;
  const eventsHttpErrors = eventsStatus?.stats.http_errors ?? 0;
  const analyticsTotal =
    analytics?.counts.reduce((acc, c) => acc + c.count, 0) ?? 0;
  const eventsClean =
    eventsStatus !== null && eventsParseFailed === 0 && eventsHttpErrors === 0;

  return (
    <div className="card" style={{ gridColumn: '1 / -1' }}>
      <h3>Beta launch checklist</h3>
      <div className="list" style={{ marginBottom: 12 }}>
        <ChecklistRow
          label="API ready"
          status={apiReady ? 'ok' : ready ? 'warn' : 'unknown'}
          value={
            ready
              ? `db=${dbState}` + (ready.error ? ` · ${ready.error}` : '')
              : '…'
          }
        />
        <ChecklistRow
          label="Build"
          status={version && version.app_version !== 'unknown' ? 'ok' : 'warn'}
          value={
            version
              ? `${version.app_version} · ${version.git_sha.slice(0, 12)} · ${version.release_channel}`
              : '— unavailable —'
          }
        />
        <ChecklistRow
          label="Events client"
          status={
            eventsStatus === null
              ? 'unknown'
              : eventsClean
                ? 'ok'
                : 'warn'
          }
          value={
            eventsStatus
              ? `${eventsMode} · parsed_ok=${eventsStatus.stats.parsed_ok} · parse_failed=${eventsParseFailed} · http_errors=${eventsHttpErrors} · timeouts=${eventsStatus.stats.timeouts}`
              : '— unavailable —'
          }
        />
        <ChecklistRow
          label="Analytics (30d)"
          status={analytics === null ? 'unknown' : 'ok'}
          value={
            analytics
              ? `${analytics.counts.length} event types · ${analyticsTotal} events`
              : '— unavailable —'
          }
        />
        <ChecklistRow
          label="Open reports"
          status={
            summary === null
              ? 'unknown'
              : summary.open_reports.count === 0
                ? 'ok'
                : 'warn'
          }
          value={summary ? `${summary.open_reports.count}` : '— unavailable —'}
        />
        <ChecklistRow
          label="Pending contributions"
          status={summary === null ? 'unknown' : 'ok'}
          value={
            summary ? `${summary.pending_contributions.count}` : '— unavailable —'
          }
        />
      </div>
      <p style={{ color: 'var(--muted)', margin: '0 0 6px' }}>
        Operational docs (paths in the PRISM Club repo):
      </p>
      <ul style={{ margin: 0, paddingLeft: 18, fontSize: 12 }}>
        {DOC_LINKS.map((d) => (
          <li key={d.path}>
            <code>{d.path}</code> — {d.what}
          </li>
        ))}
      </ul>
    </div>
  );
}

function SystemHealthCard({ snapshot }: { snapshot: SystemHealthSnapshot }) {
  // Group by subsystem prefix (everything before the first dot) so the
  // operator scans search vs notification vs media at a glance instead of
  // a flat 11-row list.
  const groups = new Map<string, MetricBlock[]>();
  for (const m of snapshot.metrics) {
    const dot = m.key.indexOf('.');
    const subsystem = dot >= 0 ? m.key.slice(0, dot) : 'other';
    const arr = groups.get(subsystem) ?? [];
    arr.push(m);
    groups.set(subsystem, arr);
  }
  const generatedAgo = formatAgo(snapshot.generated_at);

  return (
    <div className="card" style={{ gridColumn: '1 / -1' }}>
      <h3>System health</h3>
      <div className="row">
        <span className="label">Snapshot</span>
        <span className="value">{generatedAgo}</span>
      </div>
      {[...groups.entries()].map(([subsystem, blocks]) => (
        <div key={subsystem} style={{ marginTop: 8 }}>
          <div
            style={{
              fontSize: 12,
              fontWeight: 600,
              color: 'var(--muted, #888)',
              textTransform: 'uppercase',
              letterSpacing: 0.4,
              marginBottom: 4,
            }}
          >
            {subsystem}
          </div>
          <div className="list">
            {blocks.map((b) => (
              <div className="item" key={b.key}>
                <div>{b.key.slice(subsystem.length + 1) || b.key}</div>
                <div className="meta">
                  {formatMetricSummary(b)}
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function formatMetricSummary(b: MetricBlock): string {
  const parts: string[] = [];
  parts.push(`${b.count_1h}/h`);
  if (b.count_24h !== b.count_1h) parts.push(`${b.count_24h}/24h`);
  if (b.p95_1h !== null) parts.push(`p95 ${formatNumber(b.p95_1h)}`);
  if (b.p50_1h !== null && b.p50_1h !== b.p95_1h) {
    parts.push(`p50 ${formatNumber(b.p50_1h)}`);
  }
  if (b.avg_1h !== null && b.p95_1h === null) {
    parts.push(`avg ${formatNumber(b.avg_1h)}`);
  }
  return parts.join(' · ');
}

function formatNumber(n: number): string {
  if (n >= 1000) return `${(n / 1000).toFixed(1)}k`;
  if (n >= 10) return n.toFixed(0);
  return n.toFixed(1);
}

function formatAgo(iso: string): string {
  const t = new Date(iso).getTime();
  const diff = Date.now() - t;
  const s = Math.round(diff / 1000);
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.round(s / 60)}m ago`;
  return `${Math.round(s / 3600)}h ago`;
}

function ChecklistRow({
  label,
  status,
  value,
}: {
  label: string;
  status: 'ok' | 'warn' | 'unknown';
  value: string;
}) {
  const dot = status === 'ok' ? '●' : status === 'warn' ? '▲' : '○';
  const color =
    status === 'ok'
      ? 'var(--good, #2ecc71)'
      : status === 'warn'
        ? 'var(--warn, #f39c12)'
        : 'var(--muted, #888)';
  return (
    <div className="item">
      <div>
        <span style={{ color, marginRight: 8 }}>{dot}</span>
        {label}
      </div>
      <div className="meta">{value}</div>
    </div>
  );
}
