'use client'
export const dynamic = 'force-dynamic'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'
import Sidebar from '@/components/Sidebar'

interface AuditLog { id: string; actor_id: string; actor_role: string; action: string; patient_id?: string; doctor_id?: string; metadata: Record<string, string>; created_at: string }

const ACTION_ICONS: Record<string, string> = {
  consent_requested: '📋', consent_approved: '✅', consent_rejected: '❌',
  consent_revoked: '🚫', document_viewed: '👁️', document_uploaded: '📤',
  document_deleted: '🗑️', otp_generated: '🔑', otp_verified: '🔐',
}
const ACTION_COLORS: Record<string, string> = {
  consent_approved: 'var(--primary)', consent_rejected: 'var(--error)', consent_revoked: 'var(--error)',
  consent_requested: 'var(--warning)', document_viewed: 'var(--secondary)',
}

export default function AdminAuditPage() {
  const router = useRouter()
  const supabase = createClient()
  const [logs, setLogs] = useState<AuditLog[]>([])
  const [search, setSearch] = useState('')
  const [actionFilter, setActionFilter] = useState('all')
  const [loading, setLoading] = useState(true)
  const [adminName, setAdminName] = useState('')
  const [page, setPage] = useState(0)
  const PAGE_SIZE = 25

  useEffect(() => {
    const init = async () => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/login'); return }
      const { data: role } = await supabase.from('user_roles').select('role').eq('user_id', user.id).eq('role', 'admin').single()
      if (!role) { router.push('/login'); return }
      setAdminName(user.email || 'Admin')
      const { data } = await supabase.from('audit_logs').select('*').order('created_at', { ascending: false }).limit(500)
      setLogs(data || [])
      setLoading(false)
    }
    init()
  }, [])

  const uniqueActions = ['all', ...Array.from(new Set(logs.map(l => l.action)))]
  const filtered = logs.filter(l => {
    const matchAction = actionFilter === 'all' || l.action === actionFilter
    const matchSearch = !search || l.action.includes(search) || (l.metadata?.doctor_name || '').toLowerCase().includes(search.toLowerCase())
    return matchAction && matchSearch
  })
  const paginated = filtered.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE)

  if (loading) return <div style={{ minHeight: '100vh', background: 'var(--bg)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><div style={{ color: 'var(--muted)' }}>Loading...</div></div>

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--bg)' }}>
      <Sidebar role="admin" userName={adminName} />
      <main style={{ flex: 1, marginLeft: '240px', padding: '32px' }}>
        <div style={{ marginBottom: '28px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
          <div>
            <h1 style={{ fontSize: '22px', fontWeight: 800, margin: '0 0 4px' }}>Audit Logs</h1>
            <p style={{ color: 'var(--muted)', margin: 0, fontSize: '14px' }}>{filtered.length} events recorded</p>
          </div>
          <div style={{ display: 'flex', gap: '10px' }}>
            <input value={search} onChange={e => { setSearch(e.target.value); setPage(0) }} placeholder="Search..." style={{ width: '200px' }} />
            <select value={actionFilter} onChange={e => { setActionFilter(e.target.value); setPage(0) }} style={{ width: '180px' }}>
              {uniqueActions.map(a => <option key={a} value={a} style={{ textTransform: 'capitalize' }}>{a === 'all' ? 'All Actions' : a.replace(/_/g, ' ')}</option>)}
            </select>
          </div>
        </div>

        <div className="card" style={{ padding: 0 }}>
          <div className="table-wrap">
            <table>
              <thead><tr><th>Event</th><th>Action</th><th>Role</th><th>Doctor</th><th>Time</th></tr></thead>
              <tbody>
                {paginated.length === 0 ? (
                  <tr><td colSpan={5} style={{ textAlign: 'center', padding: '40px', color: 'var(--muted)' }}>No events found</td></tr>
                ) : paginated.map(log => {
                  const color = ACTION_COLORS[log.action] || 'var(--muted)'
                  const icon = ACTION_ICONS[log.action] || '📌'
                  const dt = new Date(log.created_at)
                  return (
                    <tr key={log.id}>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                          <div style={{ width: '32px', height: '32px', background: `${color}22`, borderRadius: '8px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '14px', flexShrink: 0 }}>{icon}</div>
                          <div>
                            <div style={{ fontWeight: 600, fontSize: '13px', color, textTransform: 'capitalize' }}>{log.action.replace(/_/g, ' ')}</div>
                            {log.metadata?.scope && <div style={{ color: 'var(--muted)', fontSize: '11px' }}>Scope: {log.metadata.scope}</div>}
                          </div>
                        </div>
                      </td>
                      <td><span className="badge badge-gray" style={{ textTransform: 'capitalize', fontSize: '10px' }}>{log.action.replace(/_/g, ' ')}</span></td>
                      <td><span className={`badge ${log.actor_role === 'admin' ? 'badge-red' : log.actor_role === 'doctor' ? 'badge-blue' : 'badge-green'}`}>{log.actor_role}</span></td>
                      <td style={{ color: 'var(--muted)', fontSize: '12px' }}>{log.metadata?.doctor_name || (log.doctor_id ? log.doctor_id.slice(0, 8) + '...' : '—')}</td>
                      <td style={{ color: 'var(--muted)', fontSize: '12px', whiteSpace: 'nowrap' }}>
                        <div>{dt.toLocaleDateString()}</div>
                        <div>{dt.toLocaleTimeString()}</div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
          {/* Pagination */}
          {filtered.length > PAGE_SIZE && (
            <div style={{ display: 'flex', justifyContent: 'center', gap: '8px', padding: '16px', borderTop: '1px solid var(--border)' }}>
              <button className="btn-secondary" onClick={() => setPage(p => Math.max(0, p - 1))} disabled={page === 0} style={{ padding: '6px 16px' }}>← Prev</button>
              <span style={{ color: 'var(--muted)', alignSelf: 'center', fontSize: '13px' }}>Page {page + 1} of {Math.ceil(filtered.length / PAGE_SIZE)}</span>
              <button className="btn-secondary" onClick={() => setPage(p => p + 1)} disabled={(page + 1) * PAGE_SIZE >= filtered.length} style={{ padding: '6px 16px' }}>Next →</button>
            </div>
          )}
        </div>
      </main>
    </div>
  )
}
