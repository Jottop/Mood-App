// Emite el token de SOLO LECTURA del widget de comparación (Deno Edge).
//
// La tarea de fondo del widget (WorkManager) ya NO usa el refresh token de
// la sesión (rotarlo invalidaba el de la app y deslogueaba cada X min/horas).
// En su lugar, la app (con sesión real, primer plano) pide aquí un token
// opaco por usuario; la tarea de fondo lo presenta a `widget_friend_bubble`
// para leer la burbuja del amigo sin tocar la sesión.
//
// El token se guarda como hash SHA-256 (nunca en claro) en `widget_tokens`
// y solo el service role lo lee: ni anon ni authenticated tienen privilegios
// sobre esa tabla (RLS activo sin políticas). Un token robado únicamente
// permite leer la burbuja de los amigos del dueño (el servidor verifica la
// amistad), nunca controlar la cuenta.
//
// Esta función SIEMPRE emite un token nuevo (rota e invalida los anteriores):
// es un token de un solo uso por dispositivo y el servicio solo lo vuelve a
// pedir cuando la copia local desapareció. Así no hay "get" que devolver
// desde el hash.
import { createClient } from 'jsr:@supabase/supabase-js@^2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return base64UrlEncode(bytes);
}

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

  const authHeader = req.headers.get('Authorization') ?? '';
  const jwt = authHeader.startsWith('Bearer ')
    ? authHeader.slice('Bearer '.length)
    : '';
  if (!jwt) {
    return json({ error: 'unauthorized' }, 401);
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  const {
    data: { user },
    error: userError,
  } = await admin.auth.getUser(jwt);
  if (userError || !user) {
    return json({ error: 'unauthorized' }, 401);
  }

  const token = randomToken();
  const tokenHash = await sha256Hex(token);
  const now = new Date().toISOString();

  const { error: upsertError } = await admin.from('widget_tokens').upsert(
    { user_id: user.id, token_hash: tokenHash, updated_at: now },
    { onConflict: 'user_id' },
  );
  if (upsertError) {
    return json({ error: 'could not issue token' }, 500);
  }

  return json({ token });
});