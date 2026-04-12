import type { Metadata } from "next";
import { theme } from "@/lib/theme";

export const metadata: Metadata = {
  title: "Stroompeil - Ondersteuning",
};

export default function SupportPage() {
  return (
    <main
      className="min-h-screen w-full"
      style={{ background: theme.bg, color: theme.ink }}
    >
      <div className="max-w-[600px] mx-auto px-6 py-12">
        <h1
          className="text-[11px] uppercase tracking-[0.2em] mb-8"
          style={{ color: theme.dim }}
        >
          Stroompeil - Ondersteuning
        </h1>

        <section className="mb-10">
          <h2 className="text-lg font-semibold mb-3">Wat is Stroompeil?</h2>
          <p className="text-[15px] leading-relaxed" style={{ color: theme.dim }}>
            Stroompeil laat je in een oogopslag zien hoeveel procent van de
            Nederlandse elektriciteit duurzaam is. De app toont real-time data
            van het Nederlandse elektriciteitsnet, opgesplitst naar bron: wind,
            zon, aardgas, steenkool, kernenergie en meer.
          </p>
        </section>

        <section className="mb-10">
          <h2 className="text-lg font-semibold mb-3">Veelgestelde vragen</h2>
          <dl className="space-y-6">
            <div>
              <dt className="font-medium mb-1">Waar komt de data vandaan?</dt>
              <dd className="text-[15px] leading-relaxed" style={{ color: theme.dim }}>
                Alle energiedata komt van het Nationaal Energie Dashboard
                (NED), de officiele databron van de Nederlandse energiesector.
              </dd>
            </div>
            <div>
              <dt className="font-medium mb-1">Hoe vaak wordt de data bijgewerkt?</dt>
              <dd className="text-[15px] leading-relaxed" style={{ color: theme.dim }}>
                De data wordt elk uur bijgewerkt. De widget op je homescreen
                ververst ook elk uur automatisch.
              </dd>
            </div>
            <div>
              <dt className="font-medium mb-1">Waarom verschilt het groene percentage per uur?</dt>
              <dd className="text-[15px] leading-relaxed" style={{ color: theme.dim }}>
                De energiemix verandert constant. Overdag produceert zon meer,
                's nachts draait wind door. Gas- en kolencentrales schalen op en
                af om aan de vraag te voldoen.
              </dd>
            </div>
            <div>
              <dt className="font-medium mb-1">Verzamelt de app persoonlijke gegevens?</dt>
              <dd className="text-[15px] leading-relaxed" style={{ color: theme.dim }}>
                Nee. Stroompeil verzamelt geen persoonlijke gegevens, heeft geen
                accounts en plaatst geen advertenties.
              </dd>
            </div>
          </dl>
        </section>

        <section className="mb-10">
          <h2 className="text-lg font-semibold mb-3">Contact</h2>
          <p className="text-[15px] leading-relaxed" style={{ color: theme.dim }}>
            Heb je een vraag, suggestie of probleem? Stuur een e-mail
            naar{" "}
            <a
              href="mailto:support@gentle-innovations.nl"
              className="underline"
              style={{ color: theme.ink }}
            >
              support@gentle-innovations.nl
            </a>
          </p>
        </section>

        <footer
          className="pt-8 text-[13px]"
          style={{ borderTop: `1px solid ${theme.rule}`, color: theme.dim2 }}
        >
          Stroompeil is een app van Gentle Innovations.
        </footer>
      </div>
    </main>
  );
}
