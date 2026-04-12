import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Stroompeil - Support",
  description: "Hulp en ondersteuning voor Stroompeil",
};

export default function SupportPage() {
  return (
    <main
      className="min-h-screen flex items-center justify-center px-6"
      style={{ background: "var(--color-bg)", color: "var(--color-ink)" }}
    >
      <div className="max-w-md w-full space-y-8 py-16">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">
            Stroompeil Support
          </h1>
          <p
            className="mt-2 text-sm"
            style={{ color: "var(--color-dim)" }}
          >
            Hulp en ondersteuning
          </p>
        </div>

        <div className="space-y-6 text-[15px] leading-relaxed">
          <section>
            <h2 className="font-medium mb-2">Wat is Stroompeil?</h2>
            <p style={{ color: "var(--color-dim)" }}>
              Stroompeil laat je in een oogopslag zien hoeveel procent van
              de Nederlandse elektriciteit duurzaam wordt opgewekt. De app
              toont real-time data van het Nationaal Energie Dashboard (NED),
              opgesplitst naar bron: wind, zon, aardgas, steenkool,
              kernenergie en meer.
            </p>
          </section>

          <section>
            <h2 className="font-medium mb-2">Veelgestelde vragen</h2>
            <div className="space-y-4" style={{ color: "var(--color-dim)" }}>
              <div>
                <p className="font-medium" style={{ color: "var(--color-ink)" }}>
                  Waar komt de data vandaan?
                </p>
                <p>
                  Alle energiedata komt van het Nationaal Energie Dashboard
                  (NED), de officiele databron van de Nederlandse
                  energiesector.
                </p>
              </div>
              <div>
                <p className="font-medium" style={{ color: "var(--color-ink)" }}>
                  Hoe vaak wordt de data bijgewerkt?
                </p>
                <p>
                  De energiemix wordt elk uur bijgewerkt. De widget op je
                  homescreen ververst automatisch.
                </p>
              </div>
              <div>
                <p className="font-medium" style={{ color: "var(--color-ink)" }}>
                  Waarom verschilt het percentage soms?
                </p>
                <p>
                  De energiemix verandert continu. Wind en zon zijn
                  weersafhankelijk, waardoor het groene percentage
                  gedurende de dag kan fluctueren.
                </p>
              </div>
              <div>
                <p className="font-medium" style={{ color: "var(--color-ink)" }}>
                  Slaat de app persoonlijke gegevens op?
                </p>
                <p>
                  Nee. Stroompeil verzamelt geen persoonlijke data, heeft
                  geen accounts en bevat geen advertenties.
                </p>
              </div>
            </div>
          </section>

          <section>
            <h2 className="font-medium mb-2">Contact</h2>
            <p style={{ color: "var(--color-dim)" }}>
              Vragen, feedback of problemen? Stuur een e-mail
              naar support@gentle-innovations.nl
            </p>
          </section>
        </div>
      </div>
    </main>
  );
}
