/**
 * Shared Edge Function Logger
 *
 * Minden edge function catch blokkjában ezt hívja,
 * hogy a hiba egyszerre kerüljön console-ra ÉS az app_error_logs táblába.
 *
 * Használat:
 *   import { logError } from '../_shared/logger.ts';
 *   ...
 *   } catch (err) {
 *     await logError({ fn: 'admin-invite', error: err, context: { email } });
 *     return new Response(...);
 *   }
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

interface LogErrorOptions {
  fn: string;                          // edge function neve, pl. 'admin-invite'
  error: unknown;                      // a catch-elt hiba
  context?: Record<string, unknown>;  // opcionális extra adat (userId, email stb.)
}

export async function logError({ fn, error, context = {} }: LogErrorOptions): Promise<void> {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[${fn}]`, message, context);

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    await supabase.from('app_error_logs').insert({
      app:           fn,
      error_type:    'edge_function_error',
      error_message: message,
      context:       { ...context, raw: String(error) },
    });
  } catch (logErr) {
    // Ha maga a logolás sem sikerül, legalább a console-on legyen
    console.error(`[${fn}] LOGGER FAILED:`, logErr);
  }
}
