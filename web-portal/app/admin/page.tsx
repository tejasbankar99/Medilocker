'use client'
export const dynamic = 'force-dynamic'
import { useEffect, useState, useCallback, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'
import Sidebar from '@/components/Sidebar'

interface Stats { patients: number; doctors: number; pending: number; consents: number; logs: number }
interface DoctorPending {
  id: string; user_id: string; full_name: string; email: string;
  specialty?: string; hospital?: string; approval_status?: string; created_at: string
}

const POLL_INTERVAL = 15 // seconds

export default function AdminDashboard() {
  const router = useRouter()
  const supabase = createClient()
  const [adminName, setAdminName] = useState('')
  const [adminId, setAdminId] = useState('')
  const [stats, setStats] = useState<Stats>({ patients: 0, doctors: 0, pending: 0, consents: 0, logs: 0 })
  const [pendingDoctors, setPendingDoctors] = useState<DoctorPending[]>([])
  const [loading, setLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState<string | null>(null)
  const [newAlert, setNewAlert] = useState(false)
  const [lastRefreshed, setLastRefreshed] = useState<Date>(new Date())
  const [countdown, setCountdown] = useState(POLL_INTERVAL)
  const countdownRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const loadData = useCallback(async (uid: string, silent = false) => {
    const [patientsRes, doctorsRes, pendingRes, consentsRes, logsRes] = await Promise.all([
      supabase.from('user_roles').select('*', { count: 'exact', head: true }).eq('role', 'patient'),
      supabase.from('user_roles').select('*', { count: 'exact', head: true }).eq('role', 'doctor'),
      supabase.from('doctor_profiles').select('*').eq('approval_status', 'pending').order('created_at', { ascending: false }),
      supabase.from('consent_grants').select('*', { count: 'exact', head: true }).eq('is_revoked', false),
      supabase.from('audit_logs').select('*', { count: 'exact', head: true }),
    ])

    const newPending = pendingRes.data || []
    if (silent) {
      // Check if count increased (new registration came in)
      setPendingDoctors(prev => {
        if (newPending.length > prev.length) setNewAlert(true)
        return newPending
      })
    } else {
      setPendingDoctors(newPending)
    }

    setStats({
      patients: patientsRes.count || 0,
      doctors: doctorsRes.count || 0,
      pending: newPending.length,
      consents: consentsRes.count || 0,
      logs: logsRes.count || 0,
    })
    setLastRefreshed(new Date())
  }, [])

  const startCountdown = useCallback((uid: string) => {
    if (countdownRef.current) clearInterval(countdownRef.current)
    if (pollRef.current) clearInterval(pollRef.current)

    setCountdown(POLL_INTERVAL)

    // Countdown display
    countdownRef.current = setInterval(() => {
      setCountdown(c => {
        if (c <= 1) return POLL_INTERVAL
        return c - 1
      })
    }, 1000)

    // Auto-poll
    pollRef.current = setInterval(() => {
      loadData(uid, true)
    }, POLL_INTERVAL * 1000)
  }, [loadData])

  const manualRefresh = useCallback(() => {
    if (adminId) {
      loadData(adminId, false)
      setCountdown(POLL_INTERVAL)
    }
  }, [adminId, loadData])

  useEffect(() => {
    const init = async () => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/login'); return }

      const { data: role } = await supabase
        .from('user_roles').select('role').eq('user_id', user.id).eq('role', 'admin').single()
      if (!role) { router.push('/login'); return }

      setAdminId(user.id)
      setAdminName(user.email || 'Admin')
      await loadData(user.id)
      setLoading(false)
      startCountdown(user.id)
    }
    init()

    return () => {
      if (countdownRef.current) clearInterval(countdownRef.current)
      if (pollRef.current) clearInterval(pollRef.current)
    }
  }, [])

  // Supabase Realtime subscription (bonus — works if realtime is enabled on table)
  useEffect(() => {
    if (!adminId) return
    const channel = supabase
      .channel('admin-realtime')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'doctor_profiles' },
        (payload) => {
          const d = payload.new as DoctorPending
          if (!d.approval_status || d.approval_status === 'pending') {
            setPendingDoctors(prev => [d, ...prev])
            setStats(s => ({ ...s, pending: s.pending + 1 }))
            setNewAlert(true)
          }
        }
      )
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [adminId])

  const approveDoctor = async (doc: DoctorPending) => {
    setActionLoading(doc.id)
    await supabase.from('doctor_profiles')
      .update({ approval_status: 'approved', approved_at: new Date().toISOString() })
      .eq('id', doc.id)
    await supabase.from('user_roles')
      .upsert({ user_id: doc.user_id, role: 'doctor', is_active: true }, { onConflict: 'user_id,role' })
    setPendingDoctors(p => p.filter(d => d.id !== doc.id))
    setStats(s => ({ ...s, pending: s.pending - 1, doctors: s.doctors + 1 }))
    setActionLoading(null)
  }

  const rejectDoctor = async (doc: DoctorPending) => {
    setActionLoading(doc.id)
    await supabase.from('doctor_profiles').update({ approval_status: 'rejected' }).eq('id', doc.id)
    setPendingDoctors(p => p.filter(d => d.id !== doc.id))
    setStats(s => ({ ...s, pending: s.pending - 1 }))
    setActionLoading(null)
  }

  if (loading) return (
    <div style={{ minHeight: '100vh', background: 'var(--bg)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ color: 'var(--muted)', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px' }}>
        <div style={{ width: '32px', height: '32px', border: '3px solid var(--border)', borderTop: '3px solid var(--primary)', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
        <span>Loading dashboard...</span>
      </div>
    </div>
  )

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--bg)' }}>
      <Sidebar role="admin" userName={adminName} />
      <main style={{ flex: 1, marginLeft: '240px', padding: '32px' }}>

        {/* Header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '32px' }}>
          <div>
            <h1 style={{ fontSize: '24px', fontWeight: 800, margin: '0 0 6px' }}>Admin Dashboard 🛡️</h1>
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <span style={{ color: 'var(--muted)', fontSize: '13px' }}>
                Updated {lastRefreshed.toLocaleTimeString()}
              </span>
              <span style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '12px', color: 'var(--primary)' }}>
                <span style={{ width: '7px', height: '7px', borderRadius: '50%', background: 'var(--primary)', display: 'inline-block', animation: 'pulse 2s infinite' }} />
                Live · refreshes in {countdown}s
              </span>
            </div>
          </div>
          <button onClick={manualRefresh} className="btn-secondary" style={{ fontSize: '13px', padding: '9px 18px', display: 'flex', alignItems: 'center', gap: '7px' }}>
            🔄 Refresh Now
          </button>
        </div>

        {/* New registration banner */}
        {newAlert && (
          <div style={{ background: 'rgba(255,183,77,0.08)', border: '1px solid rgba(255,183,77,0.35)', borderRadius: '12px', padding: '14px 18px', marginBottom: '24px', display: 'flex', alignItems: 'center', gap: '12px' }}>
            <span style={{ fontSize: '22px' }}>🔔</span>
            <div style={{ flex: 1 }}>
              <div style={{ color: 'var(--warning)', fontWeight: 700, fontSize: '14px' }}>New doctor registration received!</div>
              <div style={{ color: 'var(--muted)', fontSize: '12px', marginTop: '2px' }}>Review the pending approvals below.</div>
            </div>
            <button onClick={() => setNewAlert(false)} style={{ background: 'none', border: 'none', color: 'var(--muted)', cursor: 'pointer', fontSize: '18px', lineHeight: 1 }}>✕</button>
          </div>
        )}

        {/* Stats grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: '14px', marginBottom: '32px' }}>
          {[
            { label: 'Total Patients', value: stats.patients, icon: '👤', color: 'var(--primary)' },
            { label: 'Active Doctors', value: stats.doctors, icon: '🏥', color: 'var(--secondary)' },
            { label: 'Pending Approvals', value: stats.pending, icon: '⏳', color: 'var(--warning)', alert: stats.pending > 0 },
            { label: 'Active Consents', value: stats.consents, icon: '🔐', color: '#ce93d8' },
            { label: 'Audit Events', value: stats.logs, icon: '📜', color: '#81c784' },
          ].map(s => (
            <div key={s.label} className="stat-card" style={{ borderColor: s.alert ? 'rgba(255,183,77,0.5)' : 'var(--border)', position: 'relative', overflow: 'hidden' }}>
              {s.alert && <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: '3px', background: 'var(--warning)' }} />}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '10px' }}>
                <span style={{ fontSize: '22px' }}>{s.icon}</span>
                <span style={{ color: s.color, fontSize: '28px', fontWeight: 800 }}>{s.value}</span>
              </div>
              <div style={{ color: 'var(--muted)', fontSize: '11px', fontWeight: 600 }}>{s.label}</div>
            </div>
          ))}
        </div>

        {/* Pending approvals */}
        <div className="card" style={{ marginBottom: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
            <h3 style={{ fontWeight: 800, margin: 0, fontSize: '16px', display: 'flex', alignItems: 'center', gap: '10px' }}>
              Pending Doctor Approvals
              {stats.pending > 0 && (
                <span style={{ background: 'rgba(255,183,77,0.15)', color: 'var(--warning)', fontSize: '11px', fontWeight: 700, padding: '3px 10px', borderRadius: '20px', border: '1px solid rgba(255,183,77,0.3)' }}>
                  {stats.pending} pending
                </span>
              )}
            </h3>
            <a href="/admin/doctors" style={{ color: 'var(--primary)', fontSize: '13px', fontWeight: 600, textDecoration: 'none' }}>View All →</a>
          </div>

          {pendingDoctors.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '36px', color: 'var(--muted)' }}>
              <div style={{ fontSize: '36px', marginBottom: '10px' }}>✅</div>
              <div style={{ fontWeight: 600, marginBottom: '4px' }}>No pending approvals</div>
              <div style={{ fontSize: '13px' }}>Auto-checking every {POLL_INTERVAL} seconds for new registrations.</div>
            </div>
          ) : (
            <div className="table-wrap">
              <table>
                <thead><tr><th>Name</th><th>Email</th><th>Specialty</th><th>Hospital</th><th>Applied</th><th>Actions</th></tr></thead>
                <tbody>
                  {pendingDoctors.map(doc => (
                    <tr key={doc.id}>
                      <td style={{ fontWeight: 600 }}>{doc.full_name}</td>
                      <td style={{ color: 'var(--muted)', fontSize: '13px' }}>{doc.email}</td>
                      <td style={{ color: 'var(--muted)', fontSize: '13px' }}>{doc.specialty || '—'}</td>
                      <td style={{ color: 'var(--muted)', fontSize: '13px' }}>{doc.hospital || '—'}</td>
                      <td style={{ color: 'var(--muted)', fontSize: '13px', whiteSpace: 'nowrap' }}>{new Date(doc.created_at).toLocaleDateString()}</td>
                      <td>
                        <div style={{ display: 'flex', gap: '8px' }}>
                          <button className="btn-success" onClick={() => approveDoctor(doc)} disabled={actionLoading === doc.id} style={{ fontSize: '12px', padding: '7px 14px' }}>
                            {actionLoading === doc.id ? '⏳' : '✓ Approve'}
                          </button>
                          <button className="btn-danger" onClick={() => rejectDoctor(doc)} disabled={actionLoading === doc.id} style={{ fontSize: '12px', padding: '7px 14px' }}>
                            ✗ Reject
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* Quick nav */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '14px' }}>
          {[
            { href: '/admin/doctors', icon: '🏥', label: 'Manage Doctors', color: 'var(--secondary)', desc: `${stats.pending} pending approval` },
            { href: '/admin/users', icon: '👥', label: 'Manage Patients', color: 'var(--primary)', desc: `${stats.patients} registered` },
            { href: '/admin/consents', icon: '🔐', label: 'View Consents', color: '#ce93d8', desc: `${stats.consents} active` },
            { href: '/admin/audit', icon: '📜', label: 'Audit Logs', color: '#81c784', desc: `${stats.logs} events` },
          ].map(nav => (
            <a key={nav.href} href={nav.href} style={{ textDecoration: 'none' }}>
              <div className="stat-card" style={{ textAlign: 'center', cursor: 'pointer', transition: 'border-color 0.2s' }}
                onMouseOver={e => (e.currentTarget.style.borderColor = nav.color)}
                onMouseOut={e => (e.currentTarget.style.borderColor = 'var(--border)')}>
                <div style={{ fontSize: '28px', marginBottom: '8px' }}>{nav.icon}</div>
                <div style={{ color: nav.color, fontWeight: 700, fontSize: '14px', marginBottom: '2px' }}>{nav.label}</div>
                <div style={{ color: 'var(--muted)', fontSize: '12px' }}>{nav.desc}</div>
              </div>
            </a>
          ))}
        </div>

        <style>{`
          @keyframes spin { to { transform: rotate(360deg); } }
          @keyframes pulse { 0%,100% { opacity:1; } 50% { opacity:0.4; } }
        `}</style>
      </main>
    </div>
  )
}
