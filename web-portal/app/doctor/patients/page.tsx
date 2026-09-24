'use client'
export const dynamic = 'force-dynamic'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'
import Sidebar from '@/components/Sidebar'

interface Grant {
  id: string; patient_id: string; scope: string; scope_value?: string;
  purpose: string; expires_at: string; granted_at: string; is_revoked: boolean
}
interface Document { id: string; title: string; category: string; document_date?: string; doctor_name?: string; hospital_name?: string; file_url?: string; created_at: string }

export default function PatientsPage() {
  const router = useRouter()
  const supabase = createClient()
  const [doctorId, setDoctorId] = useState('')
  const [doctorName, setDoctorName] = useState('')
  const [grants, setGrants] = useState<Grant[]>([])
  const [selectedGrant, setSelectedGrant] = useState<Grant | null>(null)
  const [documents, setDocuments] = useState<Document[]>([])
  const [docsLoading, setDocsLoading] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const init = async () => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/login'); return }
      setDoctorId(user.id)
      const { data: profile } = await supabase.from('doctor_profiles').select('full_name').eq('user_id', user.id).single()
      setDoctorName(profile?.full_name || user.email!)

      const { data } = await supabase
        .from('consent_grants').select('*')
        .eq('doctor_id', user.id).eq('is_revoked', false)
        .gt('expires_at', new Date().toISOString())
        .order('granted_at', { ascending: false })
      setGrants(data || [])
      setLoading(false)
    }
    init()
  }, [])

  const viewRecords = async (grant: Grant) => {
    setSelectedGrant(grant)
    setDocsLoading(true)
    setDocuments([])

    // Log audit
    await supabase.from('audit_logs').insert({
      actor_id: doctorId, actor_role: 'doctor',
      action: 'document_viewed', target_type: 'patient_records',
      patient_id: grant.patient_id, doctor_id: doctorId,
      metadata: { grant_id: grant.id, scope: grant.scope }
    })

    // Fetch documents based on scope
    let query = supabase.from('medical_documents').select('*').eq('user_id', grant.patient_id).order('document_date', { ascending: false })
    if (grant.scope === 'category' && grant.scope_value) query = query.eq('category', grant.scope_value)

    const { data: docs } = await query
    setDocuments(docs || [])
    setDocsLoading(false)
  }

  const getCategoryColor = (cat: string) => {
    const map: Record<string, string> = { 'Lab Report': '#00c9a7', 'Prescription': '#4fc3f7', 'Hospital Record': '#ce93d8', 'Vaccination': '#81c784', 'Radiology': '#ff8a65', 'Cardiology': '#f48fb1' }
    return map[cat] || '#8ba0b8'
  }

  if (loading) return <div style={{ minHeight: '100vh', background: 'var(--bg)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><div style={{ color: 'var(--muted)' }}>Loading...</div></div>

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--bg)' }}>
      <Sidebar role="doctor" userName={doctorName} />
      <main style={{ flex: 1, marginLeft: '240px', padding: '32px' }}>
        <div style={{ marginBottom: '28px' }}>
          <h1 style={{ fontSize: '22px', fontWeight: 800, margin: '0 0 4px' }}>My Patients</h1>
          <p style={{ color: 'var(--muted)', margin: 0, fontSize: '14px' }}>Patients who have given you active access to their records</p>
        </div>

        {grants.length === 0 ? (
          <div className="card" style={{ textAlign: 'center', padding: '48px' }}>
            <div style={{ fontSize: '48px', marginBottom: '12px' }}>👥</div>
            <h3 style={{ fontWeight: 700, marginBottom: '8px' }}>No Active Consents</h3>
            <p style={{ color: 'var(--muted)', marginBottom: '20px' }}>You need patient approval to view their records.</p>
            <a href="/doctor/request-access" className="btn-primary" style={{ textDecoration: 'none', display: 'inline-block' }}>Request Access</a>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: '340px 1fr', gap: '24px', alignItems: 'start' }}>
            {/* Grants list */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {grants.map(g => (
                <div key={g.id} onClick={() => viewRecords(g)} style={{ background: selectedGrant?.id === g.id ? 'rgba(0,201,167,0.08)' : 'var(--card)', border: `1px solid ${selectedGrant?.id === g.id ? 'rgba(0,201,167,0.4)' : 'var(--border)'}`, borderRadius: '14px', padding: '16px', cursor: 'pointer', transition: 'all 0.15s' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '8px' }}>
                    <div style={{ fontWeight: 700, fontSize: '14px' }}>Patient #{g.patient_id.slice(0, 8)}</div>
                    <span className={`badge ${g.scope === 'all' ? 'badge-green' : 'badge-blue'}`}>{g.scope === 'all' ? 'All Records' : g.scope_value || g.scope}</span>
                  </div>
                  <div style={{ color: 'var(--muted)', fontSize: '12px' }}>Purpose: {g.purpose}</div>
                  <div style={{ color: 'var(--muted)', fontSize: '12px', marginTop: '4px' }}>Expires: {new Date(g.expires_at).toLocaleDateString()}</div>
                </div>
              ))}
            </div>

            {/* Records panel */}
            <div>
              {!selectedGrant ? (
                <div className="card" style={{ textAlign: 'center', padding: '48px', color: 'var(--muted)' }}>
                  <div style={{ fontSize: '36px', marginBottom: '8px' }}>👈</div>
                  <div>Select a patient to view their records</div>
                </div>
              ) : docsLoading ? (
                <div className="card" style={{ textAlign: 'center', padding: '48px', color: 'var(--muted)' }}>Loading records...</div>
              ) : (
                <div className="card">
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                    <h3 style={{ margin: 0, fontWeight: 700 }}>Medical Records ({documents.length})</h3>
                    <span className="badge badge-green">🔐 Consented Access</span>
                  </div>
                  {documents.length === 0 ? (
                    <div style={{ textAlign: 'center', padding: '32px', color: 'var(--muted)' }}>No records found for this scope.</div>
                  ) : (
                    <div className="table-wrap">
                      <table>
                        <thead><tr><th>Title</th><th>Category</th><th>Date</th><th>Doctor</th><th>Hospital</th></tr></thead>
                        <tbody>
                          {documents.map(doc => (
                            <tr key={doc.id}>
                              <td style={{ fontWeight: 600 }}>{doc.title}</td>
                              <td><span style={{ background: `${getCategoryColor(doc.category)}22`, color: getCategoryColor(doc.category), padding: '3px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: 700 }}>{doc.category}</span></td>
                              <td style={{ color: 'var(--muted)', fontSize: '13px' }}>{doc.document_date ? new Date(doc.document_date).toLocaleDateString() : '—'}</td>
                              <td style={{ color: 'var(--muted)', fontSize: '13px' }}>{doc.doctor_name || '—'}</td>
                              <td style={{ color: 'var(--muted)', fontSize: '13px' }}>{doc.hospital_name || '—'}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        )}
      </main>
    </div>
  )
}
