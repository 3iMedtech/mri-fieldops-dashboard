/**
 * notify-work-order — Supabase Edge Function
 * Sends a WhatsApp notification to the assigned engineer via
 * Meta WhatsApp Cloud API when a work order is assigned.
 *
 * Required Supabase secrets (set in project dashboard → Settings → Edge Functions):
 *   WHATSAPP_ACCESS_TOKEN    — permanent token from Meta Business Portal
 *   WHATSAPP_PHONE_NUMBER_ID — Phone Number ID from Meta Developer Console
 *   WHATSAPP_TEMPLATE_NAME   — approved template name (default: fieldops_wo_assignment)
 *
 * Template: fieldops_wo_assignment (6 variables)
 *   {{1}} WO ID          e.g. SVC-202605-0070
 *   {{2}} Customer       e.g. Chandru Diagnostics
 *   {{3}} Location       e.g. Ramanagara, Bangalore
 *   {{4}} Machine/Model  e.g. Philips 1.5 T Intera
 *   {{5}} Issue          e.g. System down — gradient coil (truncated 100 chars)
 *   {{6}} SLA / Call date e.g. 29 May 2026, 02:56 pm
 *
 * Exact template body to register in Meta Business Portal:
 * ─────────────────────────────────────────────────────────
 * 🔧 *New Work Order Assigned*
 *
 * *WO:* {{1}}
 * *Customer:* {{2}}
 * *Location:* {{3}}
 * *Machine:* {{4}}
 * *Issue:* {{5}}
 * *SLA Due:* {{6}}
 *
 * Open FieldOps to view full details and update status.
 * — 3i MEDTECH | MRI FieldOps
 * ─────────────────────────────────────────────────────────
 *
 * Request body (sent from index.html notifyWorkOrder()):
 *   { ticket: { id, customer, town, region, model, sys_status,
 *               issue_description, sla_due_at, call_date },
 *     engineer_phone: "919876543210",
 *     engineer_name: "Siva Subramanian" }
 *
 * Response:
 *   { method: 'whatsapp', success: true, message_id: '...' }
 *   { method: 'whatsapp', success: false, error: {...} }
 *   { method: 'email', reason: 'no_phone' }  — caller falls back to mailto
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

function normalizePhone(raw: string): string {
  // Strip everything except digits
  let p = (raw || '').replace(/\D/g, '');
  // Leading 0 → replace with India country code 91
  if (p.startsWith('0')) p = '91' + p.slice(1);
  // 10-digit → assume India, prepend 91
  if (p.length === 10) p = '91' + p;
  return p;
}

function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  try {
    return new Date(iso + (iso.length === 10 ? 'T00:00:00' : ''))
      .toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  } catch { return iso; }
}

function fmtDateTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString('en-IN', {
      day: '2-digit', month: 'short', year: 'numeric',
      hour: '2-digit', minute: '2-digit',
    });
  } catch { return iso; }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  const WA_TOKEN    = Deno.env.get('WHATSAPP_ACCESS_TOKEN');
  const WA_PHONE_ID = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID');
  const WA_TEMPLATE = Deno.env.get('WHATSAPP_TEMPLATE_NAME') || 'fieldops_wo_assignment';

  if (!WA_TOKEN || !WA_PHONE_ID) {
    // Secrets not configured — tell caller to fall back to email
    return json({ method: 'email', reason: 'whatsapp_not_configured' });
  }

  let body: { ticket: Record<string, unknown>; engineer_phone?: string; engineer_name?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  const { ticket, engineer_phone, engineer_name } = body;

  // Validate phone
  const phone = normalizePhone(engineer_phone || '');
  if (!phone || phone.length < 10 || phone.length > 15) {
    return json({ method: 'email', reason: 'no_phone' });
  }

  // Build the 6 template variables — mirror the existing email content
  const t = ticket as Record<string, string | null | undefined>;
  const location  = [t.town, t.region].filter(Boolean).join(', ') || '—';
  const machine   = t.model || t.sys_status || '—';
  const issue     = ((t.issue_description || '') as string).slice(0, 100) || '—';
  const slaDue    = t.sla_due_at
    ? fmtDateTime(t.sla_due_at as string)
    : fmtDate(t.call_date as string);

  const variables = [
    String(t.id         || '—'),
    String(t.customer   || '—'),
    String(location),
    String(machine),
    String(issue),
    String(slaDue),
  ];

  const waPayload = {
    messaging_product: 'whatsapp',
    to: phone,
    type: 'template',
    template: {
      name: WA_TEMPLATE,
      language: { code: 'en' },
      components: [{
        type: 'body',
        parameters: variables.map(text => ({ type: 'text', text })),
      }],
    },
  };

  const waRes = await fetch(
    `https://graph.facebook.com/v21.0/${WA_PHONE_ID}/messages`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${WA_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(waPayload),
    },
  );

  const waData = await waRes.json();

  if (!waRes.ok) {
    console.error('[notify-work-order] WhatsApp API error:', JSON.stringify(waData));
    return json({ method: 'whatsapp', success: false, error: waData }, 500);
  }

  console.log(`[notify-work-order] sent WO ${t.id} to ${engineer_name} (${phone})`);
  return json({
    method: 'whatsapp',
    success: true,
    message_id: (waData as Record<string, unknown[]>).messages?.[0]
      ? (waData.messages[0] as Record<string, string>).id
      : null,
  });
});
