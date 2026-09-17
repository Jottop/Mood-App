// Devuelve la burbuja del amigo al widget de comparación (Deno Edge).
//
// Se llama desde la tarea de fondo del widget SIN sesión de usuario (no hay
// JWT), por eso `verify_jwt = false` en la config y la auth se hace acá con
// el token de solo lectura emitido por `widget_token`.
//
// Reglas:
//  * token desconocido/vencido  -> 401
//  * friendId que no es amigo    -> 403
//  * ok -> { entries, catalog } del amigo (misma forma que la Data API),
//          para que la app reutilice `FriendMoodViewData`/`dayBubbleData`.
//
// Los reads usan service role (bypass de RLS intencional: la autorización la
// aplica esta función al verificar token + amistad).
import { createClient } from 'jsr:@supabase/supabase-js@^2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(input),
  );
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const { token, friendId } = await req.json().catch(() => ({}));
  if (typeof token !== 'string' || token === '' ||
      typeof friendId !== 'string' || friendId === '') {
    return json({ error: 'invalid request' }, 400);
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  const tokenHash = await sha256Hex(token);
  const { data: tokenRow, error: tokenError } = await admin
    .from('widget_tokens')
    .select('user_id')
    .eq('token_hash', tokenHash)
    .maybeSingle();
  if (tokenError || !tokenRow) {
    return json({ error: 'unauthorized' }, 401);
  }
  const ownerId = tokenRow.user_id as string;

  // El dueño del token solo puede leer a sus amigos (o su propia burbuja,
  // que la app igualmente nunca pide por aquí).
  const isSelf = friendId === ownerId;
  if (!isSelf) {
    const { data: friendship, error: friendError } = await admin
      .from('friendships')
      .select('friend_id')
      .eq('user_id', ownerId)
      .eq('friend_id', friendId)
      .maybeSingle();
    if (friendError || !friendship) {
      return json({ error: 'forbidden' }, 403);
    }
  }

  await admin
    .from('widget_tokens')
    .update({ updated_at: new Date().toISOString() })
    .eq('user_id', ownerId);

  const [entriesRes, catalogRes] = await Promise.all([
    admin
      .from('mood_entries')
      .select('id, mood_id, timestamp, logged_at')
      .eq('user_id', friendId)
      .order('timestamp'),
    admin
      .from('mood_catalog')
      .select('id, label, emoji, color, is_special, sort_order')
      .eq('user_id', friendId)
      .order('sort_order'),
  ]);
  if (entriesRes.error || catalogRes.error) {
    return json({ error: 'could not read friend data' }, 500);
  }

  return json({ entries: entriesRes.data, catalog: catalogRes.data });
});