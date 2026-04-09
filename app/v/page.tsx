import Link from "next/link";

type Variant = {
  slug: string;
  name: string;
  tagline: string;
  swatches: string[];
  previewBg: string;
  previewText: string;
};

const VARIANTS: Variant[] = [
  {
    slug: "ritme",
    name: "Ritme",
    tagline: "Lichte editorial met kleurrijke tijdlijn-histogram.",
    swatches: ["#FAFAF7", "#65C46A", "#D97706"],
    previewBg: "linear-gradient(135deg, #FAFAF7 0%, #FAFAF7 60%, #65C46A 140%)",
    previewText: "#0B0B0A",
  },
  {
    slug: "halo",
    name: "Halo",
    tagline: "Radiale compositie. Alles cirkelt om één ring.",
    swatches: ["#0B3D2A", "#F5F5F0", "#65C46A"],
    previewBg: "#0B3D2A",
    previewText: "#F5F5F0",
  },
  {
    slug: "tafel",
    name: "Tafel",
    tagline: "Typografische tabel. Whitespace en ritme.",
    swatches: ["#FAF8F3", "#151414", "#2E5E3E"],
    previewBg: "#FAF8F3",
    previewText: "#151414",
  },
  {
    slug: "horizon",
    name: "Horizon",
    tagline: "Atmosferisch landschap. Data als terrein.",
    swatches: ["#1a2a3a", "#f0c078", "#65C46A"],
    previewBg: "linear-gradient(180deg, #65C46A 0%, #5fa8c8 45%, #f0c078 100%)",
    previewText: "#0a0a0a",
  },
  {
    slug: "paneel",
    name: "Paneel",
    tagline: "Instrumentpaneel op textuur. Tactiel object.",
    swatches: ["#E8E4DC", "#F5F2EB", "#1A1814"],
    previewBg: "#E8E4DC",
    previewText: "#1A1814",
  },
  {
    slug: "lijn",
    name: "Lijn",
    tagline: "Verticale editorial. Hairlines en typografie.",
    swatches: ["#FFFFFF", "#0A0A0A", "#2E5E3E"],
    previewBg: "#FFFFFF",
    previewText: "#0A0A0A",
  },
  {
    slug: "licht",
    name: "Licht",
    tagline: "Huidig design, wit en kleurrijk.",
    swatches: ["#FAFAFA", "#0A0A0A", "#65C46A"],
    previewBg: "#FAFAFA",
    previewText: "#0A0A0A",
  },
];

export default function VariantsIndex() {
  return (
    <main className="min-h-screen w-full bg-black text-neutral-100">
      <div className="max-w-[1120px] mx-auto px-6 sm:px-10 pt-16 pb-24">
        <header className="mb-14">
          <div className="text-[11px] uppercase tracking-[0.22em] text-neutral-500 mb-3">
            Designstudie
          </div>
          <h1 className="text-4xl sm:text-5xl font-semibold tracking-tight text-white">
            Zeven layouts
          </h1>
          <p className="mt-3 text-neutral-400 text-[15px] max-w-xl leading-relaxed">
            Elke variant verkent een ander compositieprincipe voor dezelfde data.
            Content is de held, chrome tot het minimum.
          </p>
          <div className="mt-6">
            <Link
              href="/"
              className="text-[13px] text-neutral-500 hover:text-neutral-200 transition-colors"
            >
              ← huidige versie
            </Link>
          </div>
        </header>

        <ul className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {VARIANTS.map((v, i) => (
            <li key={v.slug}>
              <Link
                href={`/v/${v.slug}`}
                className="group block rounded-2xl overflow-hidden border border-neutral-900 hover:border-neutral-700 transition-colors"
              >
                <div
                  className="aspect-[4/3] flex items-end p-5 relative"
                  style={{ background: v.previewBg, color: v.previewText }}
                >
                  <div className="absolute top-4 right-4 text-[10px] tabular-nums tracking-wider opacity-50">
                    0{i + 1}
                  </div>
                  <div className="text-3xl font-semibold tracking-tight leading-none">
                    {v.name}
                  </div>
                </div>
                <div className="bg-neutral-950 px-5 py-4 flex items-center justify-between gap-3">
                  <div className="text-[13px] text-neutral-400 leading-snug flex-1">
                    {v.tagline}
                  </div>
                  <div className="flex gap-1 flex-shrink-0">
                    {v.swatches.map((s, idx) => (
                      <span
                        key={idx}
                        className="w-2.5 h-2.5 rounded-full border border-white/10"
                        style={{ background: s }}
                      />
                    ))}
                  </div>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      </div>
    </main>
  );
}
