import { useEffect, useState } from 'react';
import {
  ApiError,
  AnalyticsSummary,
  clearSession,
  EventsClientStatus,
  fetchAnalyticsSummary,
  fetchEventsClientStatus,
  fetchOpenReports,
  fetchOpsSummary,
  getSession,
  getApiBase,
  login,
  refreshSignals,
  ReportItem,
  Session,
  setApiBase,
  setSession,
  type OpsSummary,
} from './api';

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
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [signalMsg, setSignalMsg] = useState<string | null>(null);

  async function reload() {
    setLoading(true);
    setError(null);
    try {
      const [s, r, ec, an] = await Promise.all([
        fetchOpsSummary(),
        fetchOpenReports(),
        fetchEventsClientStatus().catch(() => null),
        fetchAnalyticsSummary().catch(() => null),
      ]);
      setSummary(s);
      setReports(r.items);
      setEventsStatus(ec);
      setAnalytics(an);
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
