// Shared card layout used by og-score. Kept separate from index.ts so the
// visual design can be tweaked without touching the render/response plumbing.
// This is the exact tree validated visually (Node + satori + resvg-js
// prototype) before porting here — see the render.js prototype used to
// produce card_base.png / card_anon.png / card_longname.png / card_lowgrade.png.

export interface CardData {
  score: number;   // 0-100
  grade: string;   // "A", "A-", "B+", ...
  tier: string;    // "Elite", "Pro", "Starter", "Contributor", "Developing", "Rookie"
  sub: string;     // short caption under the tier name
}

const TIER_SUB: Record<string, string> = {
  Elite: "Coordinator-level football IQ",
  Pro: "Sharp, seasoned instincts",
  Starter: "Solid, ready to grow",
  Contributor: "The fundamentals are there",
  Developing: "Building the fundamentals",
  Rookie: "Just getting started",
};

export function tierColor(grade: string): string {
  const g = (grade || "").charAt(0).toUpperCase();
  if (g === "A") return "#C1FF22";
  if (g === "B") return "#22D27C";
  if (g === "C") return "#F5A524";
  return "#ff4f1f";
}

export function defaultSub(tier: string): string {
  return TIER_SUB[tier] || "Testing football knowledge";
}

export function cardTree(data: CardData) {
  const accent = tierColor(data.grade);
  const headline = `I scored ${data.tier}.`;

  const dot = (size = "10px") => ({
    type: "div",
    props: { style: { display: "flex", width: size, height: size, background: accent } },
  });

  return {
    type: "div",
    props: {
      style: {
        width: "1200px",
        height: "630px",
        display: "flex",
        flexDirection: "column",
        backgroundColor: "#020f1e",
        backgroundImage:
          `radial-gradient(ellipse 900px 500px at 85% -10%, ${accent}22, transparent 60%), ` +
          `radial-gradient(ellipse 700px 500px at 0% 110%, ${accent}14, transparent 60%)`,
        position: "relative",
        fontFamily: "Barlow Condensed",
      },
      children: [
        {
          type: "div",
          props: {
            style: {
              position: "absolute", inset: 0, display: "flex",
              backgroundImage:
                "repeating-linear-gradient(90deg, transparent, transparent 79px, rgba(255,255,255,0.035) 79px, rgba(255,255,255,0.035) 80px), " +
                "repeating-linear-gradient(0deg, transparent, transparent 79px, rgba(255,255,255,0.035) 79px, rgba(255,255,255,0.035) 80px)",
            },
          },
        },
        {
          type: "div",
          props: {
            style: { display: "flex", alignItems: "center", gap: "14px", padding: "48px 56px 0" },
            children: [
              {
                type: "div",
                props: {
                  style: {
                    width: "44px", height: "44px", background: "#C1FF22", color: "#06100a",
                    display: "flex", alignItems: "center", justifyContent: "center",
                    fontWeight: 900, fontSize: "20px", transform: "skewX(-8deg)",
                  },
                  children: "FD",
                },
              },
              {
                type: "div",
                props: {
                  style: { display: "flex", color: "#fff", fontWeight: 800, fontSize: "26px", letterSpacing: "0.02em", textTransform: "uppercase" },
                  children: "First Down Academy",
                },
              },
            ],
          },
        },
        {
          type: "div",
          props: {
            style: { display: "flex", flex: 1, alignItems: "center", padding: "10px 56px 40px", justifyContent: "space-between" },
            children: [
              {
                type: "div",
                props: {
                  style: { display: "flex", flexDirection: "column", maxWidth: "620px" },
                  children: [
                    {
                      type: "div",
                      props: {
                        style: { display: "flex", alignItems: "center", gap: "10px", color: accent, fontSize: "20px", fontWeight: 800, letterSpacing: "0.18em", textTransform: "uppercase", marginBottom: "18px" },
                        children: [dot(), { type: "div", props: { style: { display: "flex" }, children: "FootballIQ Exam" } }],
                      },
                    },
                    {
                      type: "div",
                      props: {
                        style: { display: "flex", flexWrap: "wrap", color: "#fff", fontSize: "64px", fontWeight: 900, lineHeight: 1.02, textTransform: "uppercase", letterSpacing: "-0.01em" },
                        children: headline,
                      },
                    },
                    {
                      type: "div",
                      props: {
                        style: { display: "flex", color: "#8fa1bb", fontSize: "24px", fontWeight: 500, marginTop: "22px" },
                        children: data.sub,
                      },
                    },
                  ],
                },
              },
              {
                type: "div",
                props: {
                  style: {
                    display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
                    width: "260px", height: "260px", flexShrink: 0,
                    background: "rgba(255,255,255,0.04)", border: `3px solid ${accent}`, borderRadius: "24px",
                  },
                  children: [
                    { type: "div", props: { style: { display: "flex", color: accent, fontSize: "128px", fontWeight: 900, lineHeight: 1 }, children: data.grade } },
                    { type: "div", props: { style: { display: "flex", color: "#fff", fontSize: "30px", fontWeight: 800 }, children: `${data.score}/100` } },
                  ],
                },
              },
            ],
          },
        },
        {
          type: "div",
          props: {
            style: { display: "flex", alignItems: "center", justifyContent: "space-between", padding: "20px 56px", borderTop: "2px solid rgba(255,255,255,0.08)" },
            children: [
              { type: "div", props: { style: { display: "flex", color: "#5f7386", fontSize: "20px", fontWeight: 700, letterSpacing: "0.1em", textTransform: "uppercase" }, children: "firstdownacademy.com" } },
              {
                type: "div",
                props: {
                  style: { display: "flex", alignItems: "center", gap: "10px", color: accent, fontSize: "20px", fontWeight: 800, letterSpacing: "0.1em", textTransform: "uppercase" },
                  children: [{ type: "div", props: { style: { display: "flex" }, children: "Take the Exam" } }, dot()],
                },
              },
            ],
          },
        },
      ],
    },
  };
}
