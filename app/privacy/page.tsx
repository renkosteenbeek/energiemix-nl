import type { Metadata } from "next";
import { theme } from "@/lib/theme";

export const metadata: Metadata = {
  title: "Stroompeil - Privacybeleid",
};

export default function PrivacyPage() {
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
          Stroompeil - Privacybeleid
        </h1>

        <section className="mb-10">
          <h2 className="text-lg font-semibold mb-3">Geen persoonlijke gegevens</h2>
          <p className="text-[15px] leading-relaxed" style={{ color: theme.dim }}>
            Stroompeil verzamelt, bewaart of deelt geen persoonlijke gegevens.
            Er zijn geen accounts, geen tracking en geen advertenties.
          </p>
        </section>

        <section className="mb-10">
          <h2 className="text-lg font-semibold mb-3">Welke data gebruikt de app?</h2>
          <p className="text-[15px] leading-relaxed" style={{ color: theme.dim }}>
            De app haalt publiek beschikbare energiedata op van het Nationaal
            Energie Dashboard (NED) via api.ned.nl. Deze data bevat geen
            persoonlijke informatie.
          </p>
        </section>

        <section className="mb-10">
          <h2 className="text-lg font-semibold mb-3">Externe diensten</h2>
          <p className="text-[15px] leading-relaxed mb-3" style={{ color: theme.dim }}>
            Stroompeil maakt gebruik van de volgende externe diensten, uitsluitend
            server-side:
          </p>
          <ul className="list-disc pl-5 space-y-2 text-[15px]" style={{ color: theme.dim }}>
            <li>
              <strong style={{ color: theme.ink }}>NED API</strong> (api.ned.nl)
              voor energieproductiedata van het Nederlandse elektriciteitsnet.
            </li>
            <li>
              <strong style={{ color: theme.ink }}>OpenAI API</strong> voor het
              genereren van een korte tekstuele duiding van de energiemix. Er
              worden geen gebruikersgegevens naar deze dienst gestuurd.
            </li>
          </ul>
        </section>

        <section className="mb-10">
          <h2 className="text-lg font-semibold mb-3">Opslag op je apparaat</h2>
          <p className="text-[15px] leading-relaxed" style={{ color: theme.dim }}>
            De app slaat geen gegevens lokaal op. Er worden geen cookies geplaatst
            en er is geen lokale database.
          </p>
        </section>

        <section className="mb-10">
          <h2 className="text-lg font-semibold mb-3">Contact</h2>
          <p className="text-[15px] leading-relaxed" style={{ color: theme.dim }}>
            Vragen over privacy? Neem contact op
            via{" "}
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
          Laatst bijgewerkt: april 2025
        </footer>
      </div>
    </main>
  );
}
