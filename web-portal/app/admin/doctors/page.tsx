'use client'
export const dynamic = 'force-dynamic'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'
import Sidebar from '@/components/Sidebar'

interface Doctor { id: string; user_id: string; full_name: string; email: string; specialty?: string; hospital?: string; license_number?: string; approval_status: string; created_at: string; approved_at?: string }

const STATUS_BADGE: Record<string, string> = { approved: 'badge-green', pending: 'badge-yellow', rejected: 'badge-red' }

export default function AdminDoctorsPage() {
  const router = useRouter()
  const supabase = createClient()
  const [doctors, setDoctors] = useState<Doctor[]>([])
  const [filter, setFilter] = useState<'all' | 'pending' | 'approved' | 'rejected'>('all')
  const [loading, setLoading] = useState(true)
  const [actionId, setActionId] = useState<string | null>(null)
  const [adminName, setAdminName] = useState('')

  useEffect(() => {
    const init = async () => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/login'); return }
      const { data: role } = await supabase.from('user_roles').select('role').eq('user_id', user.id).eq('role', 'admin').single()
      if (!role) { router.push('/login'); return }
      setAdminName(user.email || 'Admin')
      const { data } = await supabase.from('doctor_profiles').select('*').order('created_at', { ascending: false })
      setDoctors(data || [])
      setLoading(false)
    }
    init()
  }, [])

  const updateStatus = async (doc: Doctor, status: 'approved' | 'rejected') => {
    setActionId(doc.id)
    await supabase.from('doctor_profiles').update({ approval_status: status, ...(status === 'approved' ? { approved_at: new Date().toISOString() } : {}) }).eq('id', doc.id)
    if (status === 'approved') await supabase.from('user_roles').upsert({ user_id: doc.user_id, role: 'doctor', is_active: true })
    setDoctors(prev => prev.map(d => d.id === doc.id ? { ...d, approval_status: status } : d))
    setActionId(null)
  }

  const filtered = doctors.filter(d => filter === 'all' || d.approval_status === filter)

  if (loading) return <div style={{ minHeight: '100vh', background: 'var(--bg)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><div style={{ color: 'var(--muted)' }}>Loading...</div></div>

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--bg)' }}>
      <Sidebar role="admin" userName={adminName} />
      <main style={{ flex: 1, marginLeft: '240px', padding: '32px' }}>
        <div style={{ marginBottom: '28px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
          <div>
            <h1 style={{ fontSize: '22px', fontWeight: 800, margin: '0 0 4px' }}>Doctors Management</h1>
            <p style={{ color: 'var(--muted)', margin: 0, fontSize: '14px' }}>{doctors.length} total registrations</p>
          </div>
          {/* Filter pills */}
          <div style={{ display: 'flex', gap: '8px' }}>
            {(['all', 'pending', 'approved', 'rejected'] as const).map(f => (
              <button key={f} onClick={() => setFilter(f)} style={{ padding: '7px 16px', borderRadius: '20px', border: `1px solid ${filter === f ? 'var(--primary)' : 'var(--border)'}`, background: filter === f ? 'rgba(0,201,167,0.1)' : 'transparent', color: filter === f ? 'var(--primary)' : 'var(--muted)', fontSize: '12px', fontWeight: 600, cursor: 'pointer', textTransform: 'capitalize' }}>
                {f} {f !== 'all' && `(${doctors.filter(d => d.approval_status === f).length})`}
              </button>
            ))}
          </div>
        </div>

        <div className="card" style={{ padding: 0 }}>
          <div className="table-wrap">
            <table>
              <thead>
                <tr><th>Doctor</th><th>Specialty</th><th>Hospital</th><th>License</th><th>Status</th><th>Applied</th><th>Actions</th></tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr><td colSpan={7} style={{ textAlign: 'center', padding: '40px', color: 'var(--muted)' }}>No doctors found</td></tr>
                ) : filtered.map(doc => (
                  <tr key={doc.id}>
                    <td>
                      <div style={{ fontWeight: 600 }}>{doc.full_name}</div>
                      <div style={{ color: 'var(--muted)', fontSize: '12px' }}>{doc.email}</div>
                    </td>
                    <td style={{ color: 'var(--muted)', fontSize: '13px' }}>{doc.specialty || '—'}</td>
                    <td style={{ color: 'var(--muted)', fontSize: '13px' }}>{doc.hospital || '—'}</td>
                    <td style={{ color: 'var(--muted)', fontSize: '13px', fontFamily: 'monospace' }}>{doc.license_number || '—'}</td>
                    <td><span className={`badge ${STATUS_BADGE[doc.approval_status] || 'badge-gray'}`} style={{ textTransform: 'capitalize' }}>{doc.approval_status}</span></td>
                    <td style={{ color: 'var(--muted)', fontSize: '13px' }}>{new Date(doc.created_at).toLocaleDateString()}</td>
                    <td>
                      {doc.approval_status === 'pending' && (
                        <div style={{ display: 'flex', gap: '6px' }}>
                          <button className="btn-success" onClick={() => updateStatus(doc, 'approved')} disabled={actionId === doc.id} style={{ fontSize: '11px', padding: '5px 10px' }}>
                            {actionId === doc.id ? '...' : '✓ Approve'}
                          </button>
                          <button className="btn-danger" onClick={() => updateStatus(doc, 'rejected')} disabled={actionId === doc.id} style={{ fontSize: '11px', padding: '5px 10px' }}>
                            ✗ Reject
                          </button>
                        </div>
                      )}
                      {doc.approval_status === 'approved' && (
                        <button className="btn-danger" onClick={() => updateStatus(doc, 'rejected')} style={{ fontSize: '11px', padding: '5px 10px' }}>Revoke</button>
                      )}
                      {doc.approval_status === 'rejected' && (
                        <button className="btn-success" onClick={() => updateStatus(doc, 'approved')} style={{ fontSize: '11px', padding: '5px 10px' }}>Re-approve</button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </main>
    </div>
  )
}
