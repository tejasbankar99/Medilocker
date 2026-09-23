import { createClient as _createClient, SupabaseClient } from '@supabase/supabase-js'

// Per-tab singleton — uses sessionStorage so each browser tab is completely
// independent. Admin and doctor can be logged in simultaneously in different tabs.
const clients = new Map<string, SupabaseClient>()

export function createClient(): SupabaseClient {
  // Generate a stable key per module scope (page load)
  const key = 'default'
  if (clients.has(key)) return clients.get(key)!

  const storage = typeof window !== 'undefined' ? window.sessionStorage : undefined

  const client = _createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      auth: {
        storage,                    // sessionStorage = tab-isolated
        storageKey: 'ml-auth',
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: true,
      },
    }
  )

  clients.set(key, client)
  return client
}
