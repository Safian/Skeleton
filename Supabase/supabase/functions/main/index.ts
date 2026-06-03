// Edge Runtime main entry point – routes requests to individual functions.
// Each function is served at /functions/v1/<function-name>
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const functionMap: Record<string, string> = {
  'translate-language': '../translate-language/index.ts',
};

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  // path: /functions/v1/<name> → after strip_path by Kong: /<name>
  const name = url.pathname.replace(/^\//, '').split('/')[0];
  const mod = functionMap[name];
  if (!mod) {
    return new Response(JSON.stringify({ error: `Function "${name}" not found` }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  const { default: handler } = await import(mod);
  return handler(req);
});
