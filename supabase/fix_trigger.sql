-- ================================================================
-- MediLocker: Fix get_my_role() priority + Admin data visibility
-- Run in: Supabase Dashboard → SQL Editor → New Query → Run
-- ================================================================

-- PROBLEM: get_my_role() has no ORDER BY — returns 'patient' or 'admin'
-- randomly when user has both roles (e.g., admin registered via mobile app first).
-- This breaks ALL RLS policies that use get_my_role() = 'admin'.

-- FIX 1: Always return highest privilege role
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT AS $$
  SELECT role FROM user_roles 
  WHERE user_id = auth.uid() AND is_active = TRUE 
  ORDER BY 
    CASE role 
      WHEN 'admin'  THEN 1 
      WHEN 'doctor' THEN 2 
      ELSE 3 
    END
  LIMIT 1;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- FIX 2: Also add a helper to check admin specifically (more reliable in complex policies)
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS(
    SELECT 1 FROM user_roles 
    WHERE user_id = auth.uid() AND role = 'admin' AND is_active = TRUE
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- FIX 3: Make sure admin can always see ALL doctor_profiles
-- Drop and recreate the admin policy to use the new is_admin() helper
DROP POLICY IF EXISTS "Admins manage all doctors" ON doctor_profiles;
CREATE POLICY "Admins manage all doctors" ON doctor_profiles 
  FOR ALL USING (is_admin());

-- Also fix admin policies on other tables to use is_admin()
DROP POLICY IF EXISTS "Admins view all roles" ON user_roles;
CREATE POLICY "Admins view all roles" ON user_roles 
  FOR ALL USING (is_admin());

DROP POLICY IF EXISTS "Admins manage all requests" ON consent_requests;
CREATE POLICY "Admins manage all requests" ON consent_requests 
  FOR ALL USING (is_admin());

DROP POLICY IF EXISTS "Admins manage all grants" ON consent_grants;
CREATE POLICY "Admins manage all grants" ON consent_grants 
  FOR ALL USING (is_admin());

DROP POLICY IF EXISTS "Admins view all audit" ON audit_logs;
CREATE POLICY "Admins view all audit" ON audit_logs 
  FOR ALL USING (is_admin());

-- VERIFY: Run these to confirm it works
-- SELECT get_my_role();           -- Should return 'admin' when logged in as admin
-- SELECT is_admin();              -- Should return TRUE when logged in as admin
-- SELECT * FROM doctor_profiles;  -- Should return all rows when logged in as admin
