'use client'
export const dynamic = 'force-dynamic'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'

export default function LoginPage() {
  const router = useRouter()
  const supabase = createClient()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    const { data, error: authError } = await supabase.auth.signInWithPassword({ email, password })
    if (authError) { setError(authError.message); setLoading(false); return }

    const { data: roleData } = await supabase
      .from('user_roles')
      .select('role')
      .eq('user_id', data.user.id)
      .in('role', ['doctor', 'admin'])
      .limit(1)
      .single()

    if (!roleData) {
      await supabase.auth.signOut()
      setError('Access denied. This portal is for doctors and admins only. Use the MediLocker mobile app for patient access.')
      setLoading(false)
      return
    }

    if (roleData.role === 'admin') router.push('/admin')
    else router.push('/doctor')
  }

  return (
    <div style={{ minHeight: '100vh', background: 'var(--bg)', display: 'grid', gridTemplateColumns: '1fr 1fr', }}>

      {/* Left panel — branding */}
      <div style={{ background: 'linear-gradient(160deg, #0f2540 0%, #0a1628 60%, #061020 100%)', borderRight: '1px solid var(--border)', display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '60px 56px', position: 'relative', overflow: 'hidden' }}>
        {/* Glow blobs */}
        <div style={{ position: 'absolute', top: '-80px', left: '-80px', width: '300px', height: '300px', background: 'radial-gradient(circle, rgba(0,201,167,0.12) 0%, transparent 70%)', pointerEvents: 'none' }} />
        <div style={{ position: 'absolute', bottom: '-60px', right: '-60px', width: '260px', height: '260px', background: 'radial-gradient(circle, rgba(79,195,247,0.08) 0%, transparent 70%)', pointerEvents: 'none' }} />

        <div style={{ position: 'relative' }}>
          {/* Logo */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '56px' }}>
            <div style={{ width: '52px', height: '52px', background: 'linear-gradient(135deg, var(--primary), #00a589)', borderRadius: '14px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '26px', flexShrink: 0 }}>🏥</div>
            <div>
              <div style={{ fontWeight: 800, fontSize: '20px', color: 'var(--text)' }}>MediLocker</div>
              <div style={{ fontSize: '12px', color: 'var(--primary)', fontWeight: 600, letterSpacing: '0.08em' }}>PROFESSIONAL PORTAL</div>
            </div>
          </div>

          <h1 style={{ fontSize: '32px', fontWeight: 900, color: 'var(--text)', lineHeight: 1.2, margin: '0 0 16px' }}>
            Secure Healthcare<br />
            <span style={{ color: 'var(--primary)' }}>Record Management</span>
          </h1>
          <p style={{ color: 'var(--muted)', fontSize: '15px', lineHeight: 1.7, margin: '0 0 48px' }}>
            A secure platform for healthcare professionals to access patient records with full consent, audit trails, and AI-driven insights.
          </p>

          {/* Feature list */}
          {[
            { icon: '🔐', text: 'OTP-verified patient consent' },
            { icon: '📊', text: 'AI-powered medical insights' },
            { icon: '📜', text: 'Complete audit trail' },
            { icon: '⚡', text: 'Real-time record access' },
          ].map(f => (
            <div key={f.text} style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '14px' }}>
              <div style={{ width: '32px', height: '32px', background: 'rgba(0,201,167,0.1)', borderRadius: '8px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '15px', flexShrink: 0 }}>{f.icon}</div>
              <span style={{ color: 'var(--text)', fontSize: '14px' }}>{f.text}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Right panel — login form */}
      <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '60px 56px' }}>
        <div style={{ maxWidth: '400px', width: '100%' }}>

          <h2 style={{ fontSize: '26px', fontWeight: 800, color: 'var(--text)', margin: '0 0 6px' }}>Sign In</h2>
          <p style={{ color: 'var(--muted)', fontSize: '14px', margin: '0 0 32px' }}>Access your doctor or admin dashboard</p>

          {error && (
            <div style={{ background: 'rgba(255,107,107,0.1)', border: '1px solid rgba(255,107,107,0.3)', borderRadius: '10px', padding: '14px 16px', marginBottom: '20px', color: 'var(--error)', fontSize: '13px', lineHeight: 1.5 }}>
              ⚠️ {error}
            </div>
          )}

          <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '11px', color: 'var(--muted)', fontWeight: 700, marginBottom: '6px', letterSpacing: '0.06em' }}>EMAIL ADDRESS</label>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="you@hospital.com" required />
            </div>
            <div>
              <label style={{ display: 'block', fontSize: '11px', color: 'var(--muted)', fontWeight: 700, marginBottom: '6px', letterSpacing: '0.06em' }}>PASSWORD</label>
              <input type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" required />
            </div>
            <button type="submit" className="btn-primary" disabled={loading} style={{ width: '100%', justifyContent: 'center', fontSize: '15px', padding: '14px', marginTop: '4px' }}>
              {loading ? '⏳ Signing in...' : '→ Sign In'}
            </button>
          </form>

          {/* Roles info */}
          <div style={{ marginTop: '28px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <div style={{ background: 'rgba(0,201,167,0.05)', border: '1px solid rgba(0,201,167,0.2)', borderRadius: '12px', padding: '16px' }}>
              <div style={{ fontSize: '20px', marginBottom: '6px' }}>👨‍⚕️</div>
              <div style={{ fontWeight: 700, fontSize: '14px', color: 'var(--primary)', marginBottom: '4px' }}>Doctor</div>
              <div style={{ color: 'var(--muted)', fontSize: '12px', lineHeight: 1.5 }}>View consented patient records and request access</div>
            </div>
            <div style={{ background: 'rgba(255,183,77,0.05)', border: '1px solid rgba(255,183,77,0.2)', borderRadius: '12px', padding: '16px' }}>
              <div style={{ fontSize: '20px', marginBottom: '6px' }}>🛡️</div>
              <div style={{ fontWeight: 700, fontSize: '14px', color: 'var(--warning)', marginBottom: '4px' }}>Admin</div>
              <div style={{ color: 'var(--muted)', fontSize: '12px', lineHeight: 1.5 }}>Approve doctors, manage users, view system audit logs</div>
            </div>
          </div>

          {/* Register CTA */}
          <div style={{ marginTop: '28px', padding: '20px', background: 'var(--card)', border: '1px solid var(--border)', borderRadius: '14px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <div style={{ width: '42px', height: '42px', background: 'rgba(79,195,247,0.1)', borderRadius: '10px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '20px', flexShrink: 0 }}>📝</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 700, fontSize: '14px', color: 'var(--text)', marginBottom: '2px' }}>New to MediLocker?</div>
                <div style={{ color: 'var(--muted)', fontSize: '12px' }}>Register as a doctor and await admin approval</div>
              </div>
              <a href="/register" style={{ flexShrink: 0, background: 'rgba(79,195,247,0.1)', border: '1px solid rgba(79,195,247,0.3)', color: 'var(--secondary)', fontWeight: 700, fontSize: '13px', padding: '8px 16px', borderRadius: '8px', textDecoration: 'none', whiteSpace: 'nowrap' }}>
                Register →
              </a>
            </div>
          </div>

          <p style={{ textAlign: 'center', color: 'var(--muted)', fontSize: '12px', marginTop: '24px' }}>
            Patient access is only available in the <strong style={{ color: 'var(--text)' }}>MediLocker mobile app</strong>
          </p>
        </div>
      </div>
    </div>
  )
}
