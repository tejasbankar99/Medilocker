import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { document_id } = await req.json();
    if (!document_id) throw new Error("document_id is required");

    // ── Service-role Supabase client (bypasses RLS) ─────────────────────────
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ── 1. Fetch document metadata ──────────────────────────────────────────
    const { data: doc, error: docError } = await supabase
      .from("medical_documents")
      .select("*")
      .eq("id", document_id)
      .single();

    if (docError || !doc) throw new Error(`Document not found: ${docError?.message}`);

    // ── 2. Mark as processing ───────────────────────────────────────────────
    await supabase.from("ai_insights").upsert({
      document_id,
      user_id: doc.user_id,
      status: "processing",
    }, { onConflict: "document_id" });

    // ── 3. Get previous document of same category ───────────────────────────
    const { data: prevDocs } = await supabase
      .from("medical_documents")
      .select("*")
      .eq("user_id", doc.user_id)
      .eq("category", doc.category)
      .neq("id", document_id)
      .order("document_date", { ascending: false })
      .limit(1);

    const prevDoc = prevDocs?.[0] ?? null;

    // ── 4. Download file from storage ───────────────────────────────────────
    const storagePath = doc.file_url; // stored as path after migration
    let fileBase64 = "";
    let mimeType = doc.file_type || "application/pdf";

    try {
      const { data: fileData, error: fileError } = await supabase.storage
        .from("medical-documents")
        .download(storagePath);

      if (!fileError && fileData) {
        const arrayBuffer = await fileData.arrayBuffer();
        const uint8 = new Uint8Array(arrayBuffer);
        // Convert to base64
        let binary = "";
        uint8.forEach((b) => (binary += String.fromCharCode(b)));
        fileBase64 = btoa(binary);
      }
    } catch (_) {
      // If file download fails, proceed with metadata-only analysis
    }

    // ── 5. Build Gemini prompt ──────────────────────────────────────────────
    const prevContext = prevDoc
      ? `\n\nPREVIOUS REPORT (same category, for comparison):
Title: ${prevDoc.title}
Date: ${prevDoc.document_date || prevDoc.created_at}
Doctor: ${prevDoc.doctor_name || "Not specified"}
Hospital: ${prevDoc.hospital_name || "Not specified"}
Description: ${prevDoc.description || "No description"}`
      : "";

    const systemPrompt = `You are a medical document analysis assistant.
Analyze the provided medical document and return a JSON object ONLY — no markdown, no extra text.

DOCUMENT METADATA:
Title: ${doc.title}
Category: ${doc.category}
Date: ${doc.document_date || doc.created_at}
Doctor: ${doc.doctor_name || "Not specified"}
Hospital: ${doc.hospital_name || "Not specified"}
Description: ${doc.description || "No description"}
${prevContext}

STRICT RULES:
1. Do NOT diagnose any disease or medical condition
2. Do NOT prescribe or recommend medication or treatment  
3. Use only informational, observational language
4. Always note that this is AI-generated information only

Return ONLY this JSON structure (no extra text):
{
  "summary": "Brief 2-3 sentence overview of what this document contains",
  "key_findings": "Bullet-point style list of notable values or observations from the document (informational only)",
  "comparison_with_previous": "${prevDoc ? "Comparison with the previous report listed above" : "null - no previous report of this category"}",
  "parameter_changes": {"parameter_name": "change description"},
  "health_trends": "General informational observations about trends across documents"
}`;

    // ── 6. Call Gemini API ──────────────────────────────────────────────────
    const geminiKey = Deno.env.get("GEMINI_API_KEY")!;
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${geminiKey}`;

    const parts: unknown[] = [{ text: systemPrompt }];

    // Attach file if available and it's a supported type
    const supportedMimes = ["application/pdf", "image/jpeg", "image/png", "image/webp", "image/gif"];
    if (fileBase64 && supportedMimes.includes(mimeType)) {
      parts.push({ inline_data: { mime_type: mimeType, data: fileBase64 } });
    }

    const geminiRes = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: {
          temperature: 0.2,
          maxOutputTokens: 2048,
        },
      }),
    });

    const geminiData = await geminiRes.json();

    if (!geminiRes.ok) {
      throw new Error(`Gemini API error: ${JSON.stringify(geminiData)}`);
    }

    const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    // ── 7. Parse Gemini JSON response ───────────────────────────────────────
    let insights = {
      summary: "",
      key_findings: "",
      comparison_with_previous: null as string | null,
      parameter_changes: {} as Record<string, string>,
      health_trends: "",
    };

    try {
      // Strip markdown code blocks if present
      const cleaned = rawText.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim();
      const parsed = JSON.parse(cleaned);
      insights = {
        summary: parsed.summary ?? "",
        key_findings: parsed.key_findings ?? "",
        comparison_with_previous: parsed.comparison_with_previous !== "null - no previous report of this category"
          ? parsed.comparison_with_previous
          : null,
        parameter_changes: parsed.parameter_changes ?? {},
        health_trends: parsed.health_trends ?? "",
      };
    } catch (_) {
      // If JSON parse fails, store raw text as summary
      insights.summary = rawText.slice(0, 1000);
    }

    // ── 8. Store result ─────────────────────────────────────────────────────
    await supabase.from("ai_insights").upsert({
      document_id,
      user_id: doc.user_id,
      status: "completed",
      summary: insights.summary,
      key_findings: insights.key_findings,
      comparison_with_previous: insights.comparison_with_previous,
      parameter_changes: insights.parameter_changes,
      health_trends: insights.health_trends,
      previous_document_id: prevDoc?.id ?? null,
      model_used: "gemini-3.6-flash",
    }, { onConflict: "document_id" });

    return new Response(
      JSON.stringify({ success: true, document_id }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);

    // Try to mark as failed in DB
    try {
      const supabase = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
      );
      const body = await new Request(new URL(Deno.env.get("SUPABASE_URL")!)).json?.() ?? {};
      if (body?.document_id) {
        await supabase.from("ai_insights").update({
          status: "failed",
          error_message: message,
        }).eq("document_id", body.document_id);
      }
    } catch (_) {}

    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
