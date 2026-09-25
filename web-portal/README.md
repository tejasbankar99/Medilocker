# MediLocker — Doctor & Hospital Admin Web Portal

The official Next.js web interface for verified physicians and hospital administrators within the **MediLocker** ecosystem.

## Key Capabilities
- **Doctor Portal (`/doctor`):**
  - Search patients by email or MediLocker ID.
  - Request granular, time-bounded access to medical records (All Records, By Category, or Specific Documents).
  - Verify patient-generated OTPs to unlock temporary read-only access.
- **Hospital Admin Dashboard (`/admin`):**
  - Review and verify physician medical licenses (`medical_license_number`).
  - Monitor platform-wide access logs and security audit events in real time.

## Setup & Local Development

1. Install dependencies:
   ```bash
   npm install
   ```
2. Configure environment variables:
   ```bash
   cp .env.example .env.local
   ```
   Fill in `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` in `.env.local`.
3. Start the development server:
   ```bash
   npm run dev
   ```
4. Open [http://localhost:3000](http://localhost:3000) in your browser.
