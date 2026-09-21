import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { patient_id, request_id, doctor_name } = await req.json()

    if (!patient_id || !request_id) {
      return new Response(
        JSON.stringify({ error: 'patient_id and request_id are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // ── 1. Generate secure 6-digit OTP ────────────────────────────────────
    const code = Math.floor(100000 + Math.random() * 900000).toString()
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString() // 10 minutes

    const { data: otpRow, error: otpErr } = await supabase
      .from('otp_verifications')
      .insert({
        user_id: patient_id,
        otp_code: code,
        purpose: 'consent_approval',
        reference_id: request_id,
        expires_at: expiresAt,
      })
      .select('id')
      .single()

    if (otpErr || !otpRow) {
      console.error('OTP insert error:', otpErr)
      return new Response(
        JSON.stringify({ error: 'Failed to generate OTP' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ── 2. Get patient email ───────────────────────────────────────────────
    const { data: { user: patient } } = await supabase.auth.admin.getUserById(patient_id)
    if (!patient?.email) {
      return new Response(
        JSON.stringify({ error: 'Patient email not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ── 3. Send OTP via email (Resend) ────────────────────────────────────
    const resendKey = Deno.env.get('RESEND_API_KEY')

    if (resendKey) {
      const emailHtml = `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family:sans-serif;background:#0a1628;color:#e2e8f0;padding:32px;max-width:520px;margin:0 auto">
  <div style="background:#122036;border-radius:16px;padding:32px;border:1px solid #1e3a5f;text-align:center">
    <div style="width:64px;height:64px;background:rgba(0,201,167,0.15);border-radius:50%;display:inline-flex;align-items:center;justify-content:center;font-size:32px;margin-bottom:16px">🔐</div>
    <h2 style="color:#00c9a7;margin:0 0 8px;font-size:22px">Consent Verification Code</h2>
    <p style="color:#8ba0b8;margin:0 0 28px;font-size:14px">
      <strong style="color:#fff">${doctor_name ?? 'A doctor'}</strong> has requested access to your medical records.
      Use this code to confirm or deny access.
    </p>
    
    <div style="background:#0a1628;border-radius:14px;padding:28px;margin-bottom:24px;border:2px dashed rgba(0,201,167,0.3)">
      <p style="color:#8ba0b8;font-size:12px;letter-spacing:0.08em;text-transform:uppercase;margin:0 0 12px">Your One-Time Code</p>
      <div style="font-size:42px;font-weight:900;letter-spacing:14px;color:#00c9a7;font-family:monospace">${code}</div>
      <p style="color:#8ba0b8;font-size:12px;margin:12px 0 0">⏱ Valid for <strong style="color:#fff">10 minutes</strong></p>
    </div>
    
    <div style="background:rgba(255,107,107,0.06);border:1px solid rgba(255,107,107,0.2);border-radius:10px;padding:14px;margin-bottom:20px;font-size:13px;color:#8ba0b8;text-align:left">
      ⚠️ <strong style="color:#fff">Never share this code.</strong> MediLocker will never ask you for this code via phone or chat. If you did not request this, ignore this email — no access will be granted.
    </div>
    
    <p style="color:#8ba0b8;font-size:12px;margin:0">Open MediLocker app → Access tab → Enter code to approve</p>
  </div>
</body>
</html>`

      const emailRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: 'MediLocker <onboarding@resend.dev>',
          to: [patient.email],        // primary recipient
          reply_to: patient.email,
          subject: `🔐 Your MediLocker verification code: ${code}`,
          html: emailHtml,
        }),
      })

      const emailData = await emailRes.json()
      if (!emailRes.ok) {
        console.warn('Email send failed:', emailData)
        // Non-fatal — OTP is stored, user can retry
      } else {
        console.log('OTP email sent to:', patient.email)
      }
    } else {
      console.warn('RESEND_API_KEY not set — OTP generated but email skipped')
    }

    // ── 4. Return ONLY the OTP ID — never the code ───────────────────────
    return new Response(
      JSON.stringify({ otpId: otpRow.id, email: patient.email }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    console.error('generate-otp error:', err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
