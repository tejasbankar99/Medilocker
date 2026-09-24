'use client'
export const dynamic = 'force-dynamic'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'
import Sidebar from '@/components/Sidebar'

const PURPOSES = ['Treatment', 'Second Opinion', 'Referral', 'Research', 'Follow-up', 'Other']
const CATEGORIES = ['Lab Report', 'Prescription', 'Hospital Record', 'Doctor Note', 'Vaccination', 'Radiology', 'Cardiology', 'Dental', 'Insurance', 'Other']
const DURATIONS = [{ label: '24 hours', days: 1 }, { label: '3 days', days: 3 }, { label: '7 days', days: 7 }, { label: '14 days', days: 14 }, { label: '30 days', days: 30 }]

export default function RequestAccessPage() {
  const router = useRouter()
  const supabase = createClient()
  const [doctorId, setDoctorId] = useState('')
  const [doctorName, setDoctorName] = useState('')
  const [form, setForm] = useState({ patientEmail: '', purpose: PURPOSES[0], scope: 'all', scopeValue: '', durationDays: 7, message: '' })
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)
  const [loading, setLoading] = useState(false)
  const [checking, setChecking] = useState(true)

  useEffect(() => {
    const init = async () => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/login'); return }
      setDoctorId(user.id)
      const { data: profile } = await supabase.from('doctor_profiles').select('full_name, approval_status').eq('user_id', user.id).single()
      setDoctorName(profile?.full_name || '')
      if (profile?.approval_status !== 'approved') {
        setError('Your account is pending admin approval. You cannot send access requests yet.')
      }
      setChecking(false)
    }
    init()
  }, [])

  const set = (k: string, v: string | number) => setForm(f => ({ ...f, [k]: v }))

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true); setError('')

    // Look up patient by email using a secure SECURITY DEFINER function
    // that queries auth.users directly — bypasses RLS safely
    const { data: patientId, error: lookupErr } = await supabase
      .rpc('find_patient_by_email', { patient_email: form.patientEmail.trim().toLowerCase() })

    if (lookupErr || !patientId) {
      setError('No patient found with that email address. Make sure they are registered in the MediLocker mobile app.')
      setLoading(false); return
    }

    // Check for duplicate pending request
    const { data: existing } = await supabase
      .from('consent_requests')
      .select('id')
      .eq('doctor_id', doctorId)
      .eq('patient_id', patientId)
      .eq('status', 'pending')
      .maybeSingle()

    if (existing) {
      setError('You already have a pending access request for this patient. Please wait for their response.')
      setLoading(false); return
    }

    const { error: reqErr } = await supabase.from('consent_requests').insert({
      doctor_id: doctorId,
      patient_id: patientId,
      purpose: form.purpose,
      scope: form.scope,
      scope_value: form.scope !== 'all' ? form.scopeValue : null,
      duration_days: form.durationDays,
      doctor_message: form.message || null,
    })

    if (reqErr) { setError(reqErr.message); setLoading(false); return }

    // Log audit
    await supabase.from('audit_logs').insert({
      actor_id: doctorId, actor_role: 'doctor',
      action: 'consent_requested', target_type: 'consent_request',
      patient_id: patientId, doctor_id: doctorId,
      metadata: { doctor_name: doctorName, purpose: form.purpose, scope: form.scope }
    })

    setSuccess(true); setLoading(false)
  }

  if (checking) return <div style={{ minHeight: '100vh', background: 'var(--bg)' }} />

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--bg)' }}>
      <Sidebar role="doctor" userName={doctorName} />
      <main style={{ flex: 1, marginLeft: '240px', padding: '32px', maxWidth: '720px' }}>
        <div style={{ marginBottom: '28px' }}>
          <h1 style={{ fontSize: '22px', fontWeight: 800, margin: '0 0 4px' }}>Request Patient Access</h1>
          <p style={{ color: 'var(--muted)', margin: 0, fontSize: '14px' }}>Send a request to view a patient's medical records</p>
        </div>

        {success ? (
          <div className="card" style={{ textAlign: 'center', padding: '40px' }}>
            <div style={{ fontSize: '48px', marginBottom: '16px' }}>✅</div>
            <h2 style={{ color: 'var(--primary)', fontWeight: 800, marginBottom: '8px' }}>Request Sent!</h2>
            <p style={{ color: 'var(--muted)', marginBottom: '24px' }}>The patient will receive a notification and can approve or reject your request.</p>
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
              <button className="btn-primary" onClick={() => setSuccess(false)}>Send Another</button>
              <a href="/doctor" className="btn-secondary" style={{ textDecoration: 'none', display: 'inline-flex', alignItems: 'center', padding: '12px 24px', borderRadius: '10px', border: '1px solid var(--border)', color: 'var(--muted)', fontWeight: 600 }}>Back to Dashboard</a>
            </div>
          </div>
        ) : (
          <div className="card">
            {error && <div style={{ background: 'rgba(255,107,107,0.1)', border: '1px solid rgba(255,107,107,0.3)', borderRadius: '8px', padding: '12px', marginBottom: '16px', color: 'var(--error)', fontSize: '13px' }}>{error}</div>}

            <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
              {/* Patient email */}
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--muted)', fontWeight: 600, marginBottom: '6px' }}>PATIENT EMAIL *</label>
                <input type="email" value={form.patientEmail} onChange={e => set('patientEmail', e.target.value)} placeholder="patient@email.com" required />
                <p style={{ color: 'var(--muted)', fontSize: '11px', margin: '4px 0 0' }}>Patient must have a MediLocker account with this email</p>
              </div>

              {/* Purpose */}
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--muted)', fontWeight: 600, marginBottom: '6px' }}>PURPOSE *</label>
                <select value={form.purpose} onChange={e => set('purpose', e.target.value)}>
                  {PURPOSES.map(p => <option key={p} value={p}>{p}</option>)}
                </select>
              </div>

              {/* Scope */}
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--muted)', fontWeight: 600, marginBottom: '8px' }}>ACCESS SCOPE *</label>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {[
                    { value: 'all', label: 'All Records', desc: 'Full access to all patient documents' },
                    { value: 'category', label: 'By Category', desc: 'Access limited to one category' },
                  ].map(opt => (
                    <label key={opt.value} style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '12px', background: form.scope === opt.value ? 'rgba(0,201,167,0.06)' : 'var(--surface)', borderRadius: '10px', border: `1px solid ${form.scope === opt.value ? 'rgba(0,201,167,0.3)' : 'var(--border)'}`, cursor: 'pointer' }}>
                      <input type="radio" name="scope" value={opt.value} checked={form.scope === opt.value} onChange={e => set('scope', e.target.value)} style={{ width: 'auto', border: 'none', padding: 0 }} />
                      <div>
                        <div style={{ color: form.scope === opt.value ? 'var(--primary)' : 'var(--text)', fontWeight: 600, fontSize: '14px' }}>{opt.label}</div>
                        <div style={{ color: 'var(--muted)', fontSize: '12px' }}>{opt.desc}</div>
                      </div>
                    </label>
                  ))}
                </div>
                {form.scope === 'category' && (
                  <div style={{ marginTop: '10px' }}>
                    <select value={form.scopeValue} onChange={e => set('scopeValue', e.target.value)} required>
                      <option value="">Select category...</option>
                      {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
                    </select>
                  </div>
                )}
              </div>

              {/* Duration */}
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--muted)', fontWeight: 600, marginBottom: '8px' }}>ACCESS DURATION *</label>
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                  {DURATIONS.map(d => (
                    <button key={d.days} type="button" onClick={() => set('durationDays', d.days)} style={{ padding: '8px 16px', borderRadius: '8px', border: `1px solid ${form.durationDays === d.days ? 'var(--primary)' : 'var(--border)'}`, background: form.durationDays === d.days ? 'rgba(0,201,167,0.1)' : 'transparent', color: form.durationDays === d.days ? 'var(--primary)' : 'var(--muted)', cursor: 'pointer', fontWeight: 600, fontSize: '13px' }}>
                      {d.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Message */}
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--muted)', fontWeight: 600, marginBottom: '6px' }}>MESSAGE TO PATIENT (optional)</label>
                <textarea value={form.message} onChange={e => set('message', e.target.value)} placeholder="Explain why you need access..." rows={3} style={{ resize: 'vertical' }} />
              </div>

              {/* Info box */}
              <div style={{ background: 'rgba(0,201,167,0.05)', border: '1px solid rgba(0,201,167,0.2)', borderRadius: '10px', padding: '14px', fontSize: '13px', color: 'var(--muted)' }}>
                🔒 The patient will be notified and must approve this request with OTP verification. Access can be revoked by the patient at any time.
              </div>

              <button type="submit" className="btn-primary" disabled={loading} style={{ alignSelf: 'flex-start' }}>
                {loading ? 'Sending...' : '📋 Send Access Request'}
              </button>
            </form>
          </div>
        )}
      </main>
    </div>
  )
}
