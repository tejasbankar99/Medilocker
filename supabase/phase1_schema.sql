-- ================================================================
-- MediLocker Phase 1: Database Upgrade
-- Run in Supabase SQL Editor → New Query → Paste → Run
-- ================================================================

-- Helper: auto-update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ language 'plpgsql';

-- NOTE: get_my_role() is defined AFTER user_roles table below

-- ----------------------------------------------------------------
-- TABLE: user_roles
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('patient', 'doctor', 'admin')),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, role)
);

-- Helper: check role (defined here, AFTER user_roles table exists)
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT AS $$
  SELECT role FROM user_roles WHERE user_id = auth.uid() AND is_active = TRUE LIMIT 1;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Auto-assign 'patient' role on profile creation
CREATE OR REPLACE FUNCTION assign_patient_role()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_roles (user_id, role)
  VALUES (NEW.id, 'patient')
  ON CONFLICT (user_id, role) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_profile_created_assign_role ON profiles;
CREATE TRIGGER on_profile_created_assign_role
  AFTER INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION assign_patient_role();

-- Backfill roles for existing users
INSERT INTO user_roles (user_id, role)
SELECT id, 'patient' FROM profiles
ON CONFLICT (user_id, role) DO NOTHING;

-- ----------------------------------------------------------------
-- TABLE: doctor_profiles
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS doctor_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  specialty TEXT,
  hospital TEXT,
  license_number TEXT,
  phone TEXT,
  bio TEXT,
  approval_status TEXT DEFAULT 'pending'
    CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  rejection_reason TEXT,
  approved_by UUID REFERENCES auth.users(id),
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE TRIGGER update_doctor_profiles_updated_at
  BEFORE UPDATE ON doctor_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-assign 'doctor' role when doctor profile created
CREATE OR REPLACE FUNCTION assign_doctor_role()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_roles (user_id, role)
  VALUES (NEW.user_id, 'doctor')
  ON CONFLICT (user_id, role) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_doctor_profile_created ON doctor_profiles;
CREATE TRIGGER on_doctor_profile_created
  AFTER INSERT ON doctor_profiles
  FOR EACH ROW EXECUTE FUNCTION assign_doctor_role();

-- ----------------------------------------------------------------
-- TABLE: consent_requests
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS consent_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  doctor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  purpose TEXT NOT NULL,
  scope TEXT NOT NULL CHECK (scope IN ('all', 'category', 'specific')),
  scope_value TEXT,
  duration_days INTEGER NOT NULL CHECK (duration_days > 0),
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  doctor_message TEXT,
  patient_note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE TRIGGER update_consent_requests_updated_at
  BEFORE UPDATE ON consent_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------
-- TABLE: consent_grants
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS consent_grants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID REFERENCES consent_requests(id) ON DELETE CASCADE NOT NULL,
  doctor_id UUID REFERENCES auth.users(id) NOT NULL,
  patient_id UUID REFERENCES auth.users(id) NOT NULL,
  scope TEXT NOT NULL CHECK (scope IN ('all', 'category', 'specific')),
  scope_value TEXT,
  purpose TEXT NOT NULL,
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  is_revoked BOOLEAN DEFAULT FALSE,
  revoked_at TIMESTAMPTZ,
  revoke_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------
-- TABLE: otp_verifications
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS otp_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  otp_code TEXT NOT NULL,
  purpose TEXT NOT NULL CHECK (purpose IN ('consent_approval')),
  reference_id UUID,
  is_used BOOLEAN DEFAULT FALSE,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '10 minutes'),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------
-- TABLE: audit_logs
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES auth.users(id),
  actor_role TEXT CHECK (actor_role IN ('patient', 'doctor', 'admin', 'system')),
  action TEXT NOT NULL,
  target_type TEXT,
  target_id UUID,
  patient_id UUID REFERENCES auth.users(id),
  doctor_id UUID REFERENCES auth.users(id),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------
-- TABLE: ai_insights
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID REFERENCES medical_documents(id) ON DELETE CASCADE NOT NULL UNIQUE,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  summary TEXT,
  key_findings TEXT,
  comparison_with_previous TEXT,
  parameter_changes JSONB DEFAULT '{}',
  health_trends TEXT,
  previous_document_id UUID REFERENCES medical_documents(id),
  model_used TEXT DEFAULT 'gemini-3.6-flash',
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE TRIGGER update_ai_insights_updated_at
  BEFORE UPDATE ON ai_insights
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_doctor_profiles_status ON doctor_profiles(approval_status);
CREATE INDEX IF NOT EXISTS idx_consent_requests_patient ON consent_requests(patient_id);
CREATE INDEX IF NOT EXISTS idx_consent_requests_doctor ON consent_requests(doctor_id);
CREATE INDEX IF NOT EXISTS idx_consent_grants_patient ON consent_grants(patient_id);
CREATE INDEX IF NOT EXISTS idx_consent_grants_doctor ON consent_grants(doctor_id);
CREATE INDEX IF NOT EXISTS idx_consent_grants_expires ON consent_grants(expires_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_patient ON audit_logs(patient_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_insights_document ON ai_insights(document_id);
CREATE INDEX IF NOT EXISTS idx_otp_expires ON otp_verifications(expires_at);

-- ----------------------------------------------------------------
-- ROW LEVEL SECURITY
-- ----------------------------------------------------------------

-- user_roles
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own role" ON user_roles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "System insert roles" ON user_roles FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "Admins view all roles" ON user_roles FOR ALL USING (get_my_role() = 'admin');

-- doctor_profiles
ALTER TABLE doctor_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Doctor manages own profile" ON doctor_profiles FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Patients view approved doctors" ON doctor_profiles FOR SELECT USING (approval_status = 'approved');
CREATE POLICY "Admins manage all doctors" ON doctor_profiles FOR ALL USING (get_my_role() = 'admin');

-- consent_requests
ALTER TABLE consent_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Doctors create requests" ON consent_requests FOR INSERT WITH CHECK (auth.uid() = doctor_id);
CREATE POLICY "Doctors view own requests" ON consent_requests FOR SELECT USING (auth.uid() = doctor_id);
CREATE POLICY "Patients view requests to them" ON consent_requests FOR SELECT USING (auth.uid() = patient_id);
CREATE POLICY "Patients update request status" ON consent_requests FOR UPDATE USING (auth.uid() = patient_id);
CREATE POLICY "Admins manage all requests" ON consent_requests FOR ALL USING (get_my_role() = 'admin');

-- consent_grants
ALTER TABLE consent_grants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Patients view own grants" ON consent_grants FOR SELECT USING (auth.uid() = patient_id);
CREATE POLICY "Patients revoke grants" ON consent_grants FOR UPDATE USING (auth.uid() = patient_id);
CREATE POLICY "Doctors view grants to them" ON consent_grants FOR SELECT USING (auth.uid() = doctor_id);
CREATE POLICY "System insert grants" ON consent_grants FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "Admins manage all grants" ON consent_grants FOR ALL USING (get_my_role() = 'admin');

-- otp_verifications
ALTER TABLE otp_verifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own OTPs" ON otp_verifications FOR ALL USING (auth.uid() = user_id);

-- audit_logs
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Patients view own audit" ON audit_logs FOR SELECT USING (auth.uid() = patient_id);
CREATE POLICY "Doctors view own audit" ON audit_logs FOR SELECT USING (auth.uid() = actor_id OR auth.uid() = doctor_id);
CREATE POLICY "System insert audit" ON audit_logs FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "Admins view all audit" ON audit_logs FOR ALL USING (get_my_role() = 'admin');

-- ai_insights
ALTER TABLE ai_insights ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own insights" ON ai_insights FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "System manage insights" ON ai_insights FOR ALL USING (TRUE);
CREATE POLICY "Doctors view consented insights" ON ai_insights FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM consent_grants cg
    WHERE cg.doctor_id = auth.uid()
      AND cg.patient_id = ai_insights.user_id
      AND cg.is_revoked = FALSE
      AND cg.expires_at > NOW()
      AND (cg.scope = 'all'
        OR (cg.scope = 'specific' AND ai_insights.document_id::TEXT = ANY(string_to_array(cg.scope_value, ','))))
  )
);

-- medical_documents: add doctor access policy (alongside existing)
CREATE POLICY "Doctors read consented documents" ON medical_documents FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM consent_grants cg
    WHERE cg.doctor_id = auth.uid()
      AND cg.patient_id = medical_documents.user_id
      AND cg.is_revoked = FALSE
      AND cg.expires_at > NOW()
      AND (cg.scope = 'all'
        OR (cg.scope = 'category' AND medical_documents.category = cg.scope_value)
        OR (cg.scope = 'specific' AND medical_documents.id::TEXT = ANY(string_to_array(cg.scope_value, ','))))
  )
);

-- ================================================================
-- DONE. Next steps in Supabase Storage:
-- 1. Go to Storage → medical-documents bucket
-- 2. Click bucket settings → uncheck "Public bucket" → Save
-- ================================================================
