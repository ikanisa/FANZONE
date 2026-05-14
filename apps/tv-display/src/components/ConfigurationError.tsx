import { tvEnvError } from "../lib/supabase";

export function ConfigurationError() {
  return (
    <main className="center-stage">
      <section className="operator-panel">
        <p className="eyebrow">Configuration</p>
        <h1>TV display unavailable</h1>
        <p>{tvEnvError}</p>
      </section>
    </main>
  );
}
