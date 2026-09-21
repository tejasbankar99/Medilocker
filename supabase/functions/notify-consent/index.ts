import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => { 
  try {
    const payload = await req.json()

    // Handle both Supabase Dashboard Webhook format {record:{...}}
    // AND pg_net trigger format where the record is sent directly
    const record = payload.record ?? payload
    if (!record || !record.patient_id) {
      return new Response('No valid record', { status: 400 })
    }

    const { patient_id, doctor_id, purpose, scope, scope_value, duration_days } = record

    // Admin Supabase client to access auth.users
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // Get patient email
    const { data: { user: patient } } = await supabase.auth.admin.getUserById(patient_id)
    if (!patient?.email) return new Response('Patient not found', { status: 404 })

    // Get doctor profile
    const { data: doctor } = await supabase
      .from('doctor_profiles')
      .select('full_name, specialty, hospital')
      .eq('user_id', doctor_id)
      .single()

    const doctorName = doctor?.full_name ?? 'A doctor'
    const specialty = doctor?.specialty ? ` (${doctor.specialty})` : ''
    const hospital = doctor?.hospital ? ` at ${doctor.hospital}` : ''
    const scopeText = scope === 'all' ? 'All your medical records' : `${scope_value ?? scope}`
    const resendKey = Deno.env.get('RESEND_API_KEY')

    if (!resendKey) {
      console.warn('RESEND_API_KEY not set — skipping email')
      return new Response(JSON.stringify({ skipped: true }), { status: 200 })
    }

    const emailBody = `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8" /></head>
<body style="font-family:sans-serif;background:#0a1628;color:#e2e8f0;padding:32px;max-width:600px;margin:0 auto">
  <div style="background:#122036;border-radius:16px;padding:32px;border:1px solid #1e3a5f">
    <div style="text-align:center;margin-bottom:24px">
      <div style="width:60px;height:60px;background:rgba(0,201,167,0.15);border-radius:50%;display:inline-flex;align-items:center;justify-content:center;font-size:28px">🏥</div>
      <h2 style="color:#00c9a7;margin:12px 0 4px;font-size:20px">New Access Request</h2>
      <p style="color:#8ba0b8;margin:0;font-size:14px">MediLocker · Doctor Access Notification</p>
    </div>
    
    <p style="color:#e2e8f0;font-size:15px;margin-bottom:20px">
      <strong style="color:#fff">${doctorName}</strong>${specialty}${hospital} has requested access to your medical records.
    </p>
    
    <div style="background:#0a1628;border-radius:10px;padding:16px;margin-bottom:20px;border-left:3px solid #00c9a7">
      <p style="margin:0 0 8px;color:#8ba0b8;font-size:12px;text-transform:uppercase;letter-spacing:0.05em">Request Details</p>
      <p style="margin:4px 0;font-size:14px"><span style="color:#8ba0b8">Purpose:</span> <strong>${purpose}</strong></p>
      <p style="margin:4px 0;font-size:14px"><span style="color:#8ba0b8">Access to:</span> <strong>${scopeText}</strong></p>
      <p style="margin:4px 0;font-size:14px"><span style="color:#8ba0b8">Duration:</span> <strong>${duration_days} days</strong></p>
    </div>
    
    <div style="background:rgba(255,183,77,0.08);border:1px solid rgba(255,183,77,0.2);border-radius:10px;padding:14px;margin-bottom:24px;font-size:13px;color:#8ba0b8">
      🔒 Your data will only be shared after <strong style="color:#fff">OTP verification</strong> in the MediLocker app. You can reject or revoke access at any time.
    </div>
    
    <div style="text-align:center">
      <p style="color:#8ba0b8;font-size:13px;margin-bottom:8px">Open your MediLocker app → <strong style="color:#00c9a7">Access tab</strong> to review this request</p>
      <p style="color:#8ba0b8;font-size:11px;margin:0">This is an automated notification from MediLocker. Do not reply to this email.</p>
    </div>
  </div>
</body>
</html>`

    // Send email via Resend
    const emailRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'MediLocker <onboarding@resend.dev>',
        to: [patient.email],
        subject: `🏥 ${doctorName} has requested access to your medical records`,
        html: emailBody,
      }),
    })

    const emailData = await emailRes.json()
    console.log('Email sent:', emailData)

    return new Response(JSON.stringify({ success: true, emailData }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (err) {
    console.error('notify-consent error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
