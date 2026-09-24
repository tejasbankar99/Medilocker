import { createClient } from '@supabase/supabase-js'
import { NextRequest, NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function POST(req: NextRequest) {
  try {
    const { fullName, email, password, specialty, hospital, license, phone } = await req.json()

    if (!fullName || !email || !password) {
      return NextResponse.json({ error: 'Name, email, and password are required.' }, { status: 400 })
    }
    if (password.length < 8) {
      return NextResponse.json({ error: 'Password must be at least 8 characters.' }, { status: 400 })
    }

    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // ── 1. Create auth user ─────────────────────────────────────────────────
    // IMPORTANT: pass user_metadata so the handle_new_user() trigger can
    // populate the profiles table without a NOT NULL failure on full_name
    const { data: userData, error: authErr } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,         // Auto-confirm so doctor can log in after admin approves
      user_metadata: {
        full_name: fullName,       // satisfies handle_new_user() trigger
        avatar_url: '',
        role: 'doctor_pending',
      },
    })

    if (authErr) {
      console.error('[register-doctor] auth.admin.createUser error:', authErr)
      return NextResponse.json(
        { error: `Auth error: ${authErr.message}` },
        { status: 400 }
      )
    }

    const userId = userData.user.id

    // ── 2. Assign base 'patient' role (upgraded to 'doctor' on approval) ───
    const { error: roleErr } = await supabase
      .from('user_roles')
      .upsert(
        { user_id: userId, role: 'patient', is_active: true },
        { onConflict: 'user_id,role' }
      )

    if (roleErr) {
      console.error('[register-doctor] user_roles upsert error:', roleErr)
      // Non-fatal — continue anyway
    }

    // ── 3. Create doctor profile with 'pending' approval status ────────────
    const { error: profileErr } = await supabase.from('doctor_profiles').insert({
      user_id: userId,
      full_name: fullName,
      email,
      specialty: specialty || null,
      hospital: hospital || null,
      license_number: license || null,
      phone: phone || null,
      approval_status: 'pending',
    })

    if (profileErr) {
      console.error('[register-doctor] doctor_profiles insert error:', profileErr)
      // Rollback auth user
      await supabase.auth.admin.deleteUser(userId)
      return NextResponse.json(
        { error: `Profile error: ${profileErr.message}` },
        { status: 400 }
      )
    }

    return NextResponse.json({ success: true })
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Unknown error'
    console.error('[register-doctor] unexpected error:', msg)
    return NextResponse.json({ error: msg }, { status: 500 })
  }
}
