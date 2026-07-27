// Renders the personalized FootballIQ share card as a PNG.
// GET /og-score?score=87&grade=A-&tier=Elite&sub=Coordinator-level%20football%20IQ
//
// Deliberately stateless — takes the numbers as query params instead of
// looking them up by id, so this function needs no database access at
// all. The `share` function is what looks a share up by id and builds
// this URL with the right params in its og:image tag.
//
// DEPLOY: supabase functions deploy og-score
// (this needs the Supabase CLI — the dashboard's function editor
// doesn't reliably support the npm:/multi-file imports used here.)

import satori from "npm:satori@0.10.13";
import { Resvg, initWasm } from "npm:@resvg/resvg-wasm@2.6.2";
import { cardTree, defaultSub } from "../_shared/card.ts";

const FONT_BLACK_URL = "https://fonts.gstatic.com/s/barlowcondensed/v13/HTxwL3I-JCGChYJ8VI-L6OO_au7B45L0_3E.ttf";
const FONT_BOLD_URL = "https://fonts.gstatic.com/s/barlowcondensed/v13/HTxwL3I-JCGChYJ8VI-L6OO_au7B46r2_3E.ttf";
const RESVG_WASM_URL = "https://unpkg.com/@resvg/resvg-wasm@2.6.2/index_bg.wasm";

// Cached across invocations within the same warm function instance —
// fonts/wasm don't change, no need to re-fetch on every request.
let fontsPromise: Promise<{ black: ArrayBuffer; bold: ArrayBuffer }> | null = null;
let wasmReady: Promise<void> | null = null;

function getFonts() {
  if (!fontsPromise) {
    fontsPromise = Promise.all([
      fetch(FONT_BLACK_URL).then((r) => r.arrayBuffer()),
      fetch(FONT_BOLD_URL).then((r) => r.arrayBuffer()),
    ]).then(([black, bold]) => ({ black, bold }));
  }
  return fontsPromise;
}

function getWasm() {
  if (!wasmReady) {
    wasmReady = fetch(RESVG_WASM_URL).then((resp) => initWasm(resp));
  }
  return wasmReady;
}

function clamp(n: number, lo: number, hi: number) {
  return Math.max(lo, Math.min(hi, n));
}

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const score = clamp(parseInt(url.searchParams.get("score") || "0", 10) || 0, 0, 999);
    const grade = (url.searchParams.get("grade") || "—").slice(0, 4);
    const tier = (url.searchParams.get("tier") || "Rookie").slice(0, 24);
    const sub = (url.searchParams.get("sub") || defaultSub(tier)).slice(0, 80);

    const [fonts] = await Promise.all([getFonts(), getWasm()]);

    const svg = await satori(cardTree({ score, grade, tier, sub }) as any, {
      width: 1200,
      height: 630,
      fonts: [
        { name: "Barlow Condensed", data: fonts.black, weight: 900, style: "normal" },
        { name: "Barlow Condensed", data: fonts.bold, weight: 700, style: "normal" },
      ],
    });

    const resvg = new Resvg(svg, { fitTo: { mode: "width", value: 1200 } });
    const png = resvg.render().asPng();

    return new Response(png, {
      headers: {
        "Content-Type": "image/png",
        // Shared-score data never changes once created — cache hard.
        "Cache-Control": "public, max-age=31536000, immutable",
      },
    });
  } catch (err) {
    console.error("og-score render error:", err);
    return new Response("Image generation failed", { status: 500 });
  }
});
