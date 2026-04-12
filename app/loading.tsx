import { theme } from "@/lib/theme";

const SKEL = theme.rule2;

export default function Loading() {
  return (
    <main className="min-h-screen w-full" style={{ background: theme.bg }}>
      <div className="max-w-[640px] mx-auto px-5 sm:px-6">
        <header
          className="py-5 flex items-center justify-between"
          style={{ borderBottom: `1px solid ${theme.rule}` }}
        >
          <div
            className="text-[11px] uppercase tracking-[0.2em]"
            style={{ color: theme.dim }}
          >
            Stroompeil
          </div>
          <div
            className="w-3 h-3 rounded-full animate-spin"
            style={{
              border: `1px solid ${theme.dim}`,
              borderTopColor: "transparent",
            }}
          />
        </header>

        <div className="pt-6 pb-4">
          <div
            className="w-full rounded-[28px] animate-pulse"
            style={{ height: 220, background: SKEL }}
          />
        </div>

        <section className="pt-8 pb-10">
          <div
            className="h-2.5 w-16 rounded-full animate-pulse mb-6"
            style={{ background: SKEL }}
          />
          <div className="flex items-end gap-[1.5px] h-[96px] mb-8">
            {Array.from({ length: 73 }, (_, i) => (
              <div
                key={i}
                className="flex-1 rounded-[1px] animate-pulse"
                style={{
                  height: `${28 + ((i * 7 + 13) % 40)}%`,
                  background: SKEL,
                  animationDelay: `${(i % 8) * 100}ms`,
                }}
              />
            ))}
          </div>
        </section>

        <section className="py-10">
          <div
            className="h-2.5 w-14 rounded-full animate-pulse mb-5"
            style={{ background: SKEL }}
          />
          <div className="space-y-2.5">
            <div
              className="h-3 rounded-full animate-pulse"
              style={{ background: SKEL, width: "88%" }}
            />
            <div
              className="h-3 rounded-full animate-pulse"
              style={{ background: SKEL, width: "72%" }}
            />
            <div
              className="h-3 rounded-full animate-pulse"
              style={{ background: SKEL, width: "56%" }}
            />
          </div>
        </section>

        <section className="py-10">
          <div
            className="h-2.5 w-28 rounded-full animate-pulse mb-5"
            style={{ background: SKEL }}
          />
          <div className="flex gap-2">
            {[90, 110, 80].map((w, i) => (
              <div
                key={i}
                className="h-8 rounded-full animate-pulse"
                style={{ background: SKEL, width: w }}
              />
            ))}
          </div>
        </section>
      </div>
    </main>
  );
}
