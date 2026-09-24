'use client'
export const dynamic = 'force-dynamic'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'
import Sidebar from '@/components/Sidebar'

interface Stats { patients: number; activeConsents: number; pendingRequests: number; totalViews: number }
interface ConsentGrant { id: string; patient_id: string; scope: string; expires_at: string; granted_at: string; profiles?: { full_name?: string } }

export default function DoctorDashboard() {
  const router = useRouter()
  const supabase = createClient()
  const [user, setUser] = useState<{ id: string; email: string } | null>(null)
  const [doctorName, setDoctorName] = useState('')
  const [stats, setStats] = useState<Stats>({ patients: 0, activeConsents: 0, pendingRequests: 0, totalViews: 0 })
  const [recentGrants, setRecentGrants] = useState<ConsentGrant[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const init = async () => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/login'); return }

      // Verify doctor role
      const { data: role } = await supabase.from('user_roles').select('role').eq('user_id', user.id).eq('role', 'doctor').single()
      if (!role) { router.push('/login'); return }

      setUser({ id: user.id, email: user.email! })

      // Load doctor profile
      const { data: profile } = await supabase.from('doctor_profiles').select('full_name, approval_status').eq('user_id', user.id).single()
      if (profile?.approval_status !== 'approved') {
        // Doctor not yet approved
        setLoading(false)
        setDoctorName(profile?.full_name || user.email!)
        return
      }
      setDoctorName(profile?.full_name || user.email!)

      // Load stats
      const [grantsRes, requestsRes, auditRes] = await Promise.all([
        supabase.from('consent_grants').select('*').eq('doctor_id', user.id).eq('is_revoked', false).gt('expires_at', new Date().toISOString()),
        supabase.from('consent_requests').select('*').eq('doctor_id', user.id).eq('status', 'pending'),
        supabase.from('audit_logs').select('*').eq('doctor_id', user.id).eq('action', 'document_viewed'),
      ])

      const activeGrants = grantsRes.data || []
      setStats({
        patients: new Set(activeGrants.map((g: ConsentGrant) => g.patient_id)).size,
        activeConsents: activeGrants.length,
        pendingRequests: requestsRes.data?.length || 0,
        totalViews: auditRes.data?.length || 0,
      })
      setRecentGrants(activeGrants.slice(0, 5))
      setLoading(false)
    }
    init()
  }, [])

  if (loading) return <div style={{ minHeight: '100vh', background: 'var(--bg)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><div style={{ color: 'var(--muted)' }}>Loading...</div></div>

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--bg)' }}>
      <Sidebar role="doctor" userName={doctorName} />
      <main style={{ flex: 1, marginLeft: '240px', padding: '32px', maxWidth: 'calc(100% - 240px)' }}>
        {/* Header */}
        <div style={{ marginBottom: '32px' }}>
          <h1 style={{ fontSize: '24px', fontWeight: 800, margin: '0 0 4px' }}>Welcome, {doctorName.split(' ')[0]} 👋</h1>
          <p style={{ color: 'var(--muted)', margin: 0, fontSize: '14px' }}>Here's your patient access overview</p>
        </div>

        {/* Stats Grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px', marginBottom: '32px' }}>
          {[
            { label: 'Patients with Access', value: stats.patients, icon: '👥', color: 'var(--primary)' },
            { label: 'Active Consents', value: stats.activeConsents, icon: '🔐', color: 'var(--secondary)' },
            { label: 'Pending Requests', value: stats.pendingRequests, icon: '⏳', color: 'var(--warning)' },
            { label: 'Records Viewed', value: stats.totalViews, icon: '📄', color: '#ce93d8' },
          ].map(stat => (
            <div key={stat.label} className="stat-card">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '12px' }}>
                <span style={{ fontSize: '24px' }}>{stat.icon}</span>
                <span style={{ color: stat.color, fontSize: '28px', fontWeight: 800 }}>{stat.value}</span>
              </div>
              <div style={{ color: 'var(--muted)', fontSize: '12px', fontWeight: 600 }}>{stat.label}</div>
            </div>
          ))}
        </div>

        {/* Quick Actions */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '32px' }}>
          <a href="/doctor/request-access" style={{ textDecoration: 'none' }}>
            <div style={{ background: 'linear-gradient(135deg, rgba(0,201,167,0.1), rgba(0,201,167,0.05))', border: '1px solid rgba(0,201,167,0.3)', borderRadius: '14px', padding: '20px', cursor: 'pointer', transition: 'border-color 0.2s' }}>
              <div style={{ fontSize: '28px', marginBottom: '8px' }}>📋</div>
              <div style={{ color: 'var(--primary)', fontWeight: 700, fontSize: '15px', marginBottom: '4px' }}>Request Patient Access</div>
              <div style={{ color: 'var(--muted)', fontSize: '13px' }}>Send an access request to a patient</div>
            </div>
          </a>
          <a href="/doctor/patients" style={{ textDecoration: 'none' }}>
            <div style={{ background: 'linear-gradient(135deg, rgba(79,195,247,0.1), rgba(79,195,247,0.05))', border: '1px solid rgba(79,195,247,0.3)', borderRadius: '14px', padding: '20px', cursor: 'pointer' }}>
              <div style={{ fontSize: '28px', marginBottom: '8px' }}>👥</div>
              <div style={{ color: 'var(--secondary)', fontWeight: 700, fontSize: '15px', marginBottom: '4px' }}>View My Patients</div>
              <div style={{ color: 'var(--muted)', fontSize: '13px' }}>View records of patients who approved</div>
            </div>
          </a>
        </div>

        {/* Recent consents */}
        <div className="card">
          <h3 style={{ fontSize: '15px', fontWeight: 700, margin: '0 0 16px' }}>Active Patient Consents</h3>
          {recentGrants.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '32px', color: 'var(--muted)' }}>
              <div style={{ fontSize: '36px', marginBottom: '8px' }}>🔐</div>
              <div>No active consents. Request access from a patient to get started.</div>
            </div>
          ) : (
            <div className="table-wrap">
              <table>
                <thead><tr><th>Patient</th><th>Access Scope</th><th>Expires</th><th>Actions</th></tr></thead>
                <tbody>
                  {recentGrants.map((g) => (
                    <tr key={g.id}>
                      <td style={{ color: 'var(--text)' }}>Patient</td>
                      <td><span className={`badge ${g.scope === 'all' ? 'badge-green' : 'badge-blue'}`}>{g.scope === 'all' ? 'All Records' : g.scope}</span></td>
                      <td style={{ color: 'var(--muted)', fontSize: '13px' }}>{new Date(g.expires_at).toLocaleDateString()}</td>
                      <td><a href={`/doctor/patients`} style={{ color: 'var(--primary)', fontSize: '13px', fontWeight: 600, textDecoration: 'none' }}>View Records →</a></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </main>
    </div>
  )
}
