'use client'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'

interface NavItem { href: string; icon: string; label: string }

interface SidebarProps {
  role: 'doctor' | 'admin'
  userName?: string
}

const doctorNav: NavItem[] = [
  { href: '/doctor', icon: '📊', label: 'Dashboard' },
  { href: '/doctor/patients', icon: '👥', label: 'My Patients' },
  { href: '/doctor/request-access', icon: '📋', label: 'Request Access' },
  { href: '/doctor/activity', icon: '📜', label: 'My Activity' },
]

const adminNav: NavItem[] = [
  { href: '/admin', icon: '📊', label: 'Dashboard' },
  { href: '/admin/doctors', icon: '🏥', label: 'Doctors' },
  { href: '/admin/users', icon: '👥', label: 'Patients' },
  { href: '/admin/consents', icon: '🔐', label: 'Consents' },
  { href: '/admin/audit', icon: '📜', label: 'Audit Logs' },
]

export default function Sidebar({ role, userName }: SidebarProps) {
  const pathname = usePathname()
  const router = useRouter()
  const supabase = createClient()
  const nav = role === 'doctor' ? doctorNav : adminNav

  const signOut = async () => {
    await supabase.auth.signOut()
    router.push('/login')
  }

  return (
    <aside style={{
      width: '240px', minHeight: '100vh', background: 'var(--surface)',
      borderRight: '1px solid var(--border)', display: 'flex', flexDirection: 'column',
      position: 'fixed', left: 0, top: 0, bottom: 0, zIndex: 10
    }}>
      {/* Logo */}
      <div style={{ padding: '24px 20px', borderBottom: '1px solid var(--border)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <div style={{ width: '36px', height: '36px', background: 'linear-gradient(135deg, var(--primary), #00a589)', borderRadius: '9px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '18px' }}>🏥</div>
          <div>
            <div style={{ fontWeight: 800, fontSize: '15px', color: 'var(--text)' }}>MediLocker</div>
            <div style={{ fontSize: '11px', color: 'var(--primary)', fontWeight: 600, textTransform: 'capitalize' }}>{role} Portal</div>
          </div>
        </div>
      </div>

      {/* Nav items */}
      <nav style={{ flex: 1, padding: '16px 12px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
        {nav.map(item => {
          const isActive = pathname === item.href || (item.href !== `/${role}` && pathname.startsWith(item.href))
          return (
            <Link key={item.href} href={item.href} style={{
              display: 'flex', alignItems: 'center', gap: '10px',
              padding: '10px 12px', borderRadius: '10px', textDecoration: 'none',
              background: isActive ? 'rgba(0,201,167,0.1)' : 'transparent',
              color: isActive ? 'var(--primary)' : 'var(--muted)',
              fontWeight: isActive ? 600 : 400, fontSize: '14px',
              transition: 'all 0.15s',
              border: isActive ? '1px solid rgba(0,201,167,0.2)' : '1px solid transparent',
            }}>
              <span style={{ fontSize: '16px' }}>{item.icon}</span>
              {item.label}
            </Link>
          )
        })}
      </nav>

      {/* User + Sign out */}
      <div style={{ padding: '16px 12px', borderTop: '1px solid var(--border)' }}>
        {userName && (
          <div style={{ padding: '10px 12px', marginBottom: '8px' }}>
            <div style={{ fontSize: '12px', color: 'var(--muted)' }}>Signed in as</div>
            <div style={{ fontSize: '13px', color: 'var(--text)', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{userName}</div>
          </div>
        )}
        <button onClick={signOut} style={{
          width: '100%', display: 'flex', alignItems: 'center', gap: '10px',
          padding: '10px 12px', borderRadius: '10px', border: '1px solid var(--border)',
          background: 'transparent', color: 'var(--muted)', fontSize: '14px', cursor: 'pointer',
          transition: 'all 0.15s'
        }}
          onMouseOver={e => { (e.currentTarget as HTMLElement).style.color = 'var(--error)'; (e.currentTarget as HTMLElement).style.borderColor = 'rgba(255,107,107,0.3)' }}
          onMouseOut={e => { (e.currentTarget as HTMLElement).style.color = 'var(--muted)'; (e.currentTarget as HTMLElement).style.borderColor = 'var(--border)' }}
        >
          <span>🚪</span> Sign Out
        </button>
      </div>
    </aside>
  )
}
