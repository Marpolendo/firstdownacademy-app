// Serves the actual link that gets shared: GET /share?id=<uuid>
//
// score-share.html is a static file — its <meta> tags are fixed at
// deploy time and can't vary per ?id=, and link-preview crawlers
// (iMessage, Facebook, Slack, ...) don't execute JS, so client-side
// setMeta() calls never reach them either. This function looks the
// share up server-side and returns a small HTML shell with the real
// per-score og:title/og:description/og:image already in the markup,
// then bounces an actual visitor on to score-share.html?id=<uuid> for
// the full interactive page.
//
// DEPLOY: supabase functions deploy share

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SITE_ORIGIN = "https://firstdownacademy.com";

function escapeHtml(str: string) {
  return String(str).replace(/[&<>"']/g, (ch) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch] as string)
  );
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const id = url.searchParams.get("id") || "";
  const destination = `${SITE_ORIGIN}/score-share.html?id=${encodeURIComponent(id)}`;

  if (!id) {
    return Response.redirect(destination, 302);
  }

  let row: any = null;
  try {
    const restUrl = `${SUPABASE_URL}/rest/v1/giq_shared_scores?id=eq.${encodeURIComponent(id)}&select=score,grade,tier,tier_sub`;
    const resp = await fetch(restUrl, {
      headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${SUPABASE_ANON_KEY}` },
    });
    const rows = await resp.json();
    row = Array.isArray(rows) ? rows[0] : null;
  } catch (err) {
    console.error("share lookup error:", err);
  }

  if (!row) {
    return Response.redirect(destination, 302);
  }

  const grade = row.grade || "—";
  const tier = row.tier || "";
  const score = row.score ?? 0;
  const sub = row.tier_sub || "";

  const ogTitle = `Someone scored ${grade} on the FootballIQ Exam`;
  const ogDesc = sub ? `${tier} tier · ${score}/100 · ${sub}. Think you can beat it?` : `${tier} tier · ${score}/100. Think you can beat it?`;
  const ogImage =
    `${SUPABASE_URL}/functions/v1/og-score?score=${encodeURIComponent(score)}` +
    `&grade=${encodeURIComponent(grade)}&tier=${encodeURIComponent(tier)}&sub=${encodeURIComponent(sub)}`;

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>${escapeHtml(ogTitle)}</title>
<meta property="og:type" content="website">
<meta property="og:site_name" content="First Down Academy">
<meta property="og:title" content="${escapeHtml(ogTitle)}">
<meta property="og:description" content="${escapeHtml(ogDesc)}">
<meta property="og:image" content="${escapeHtml(ogImage)}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:url" content="${escapeHtml(destination)}">
<meta name="twitter:card" content="summary_large_image">
<meta http-equiv="refresh" content="0; url=${escapeHtml(destination)}">
<script>window.location.replace(${JSON.stringify(destination)});</script>
</head>
<body>
<p>Redirecting to <a href="${escapeHtml(destination)}">your FootballIQ result</a>&hellip;</p>
</body>
</html>`;

  return new Response(html, {
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=300" },
  });
});
