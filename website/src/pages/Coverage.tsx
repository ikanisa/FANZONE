export default function Coverage() {
  return (
    <div className="section container">
      <div className="text-center mb-16">
        <h1 className="text-4xl md:text-5xl font-bold mb-4">Competitions & Coverage</h1>
        <p className="text-xl text-secondary max-w-2xl mx-auto">
          We intentionally limit our scope to the top-flight leagues and global competitions that matter most to real fans.
        </p>
      </div>

      <div className="grid md:grid-cols-3 gap-6">
        {[
          'Premier League',
          'La Liga',
          'Serie A',
          'Bundesliga',
          'Ligue 1',
          'UEFA Champions League',
          'UEFA Europa League',
          'World Cup / Euros (Seasonal)'
        ].map(league => (
          <div key={league} className="glass-card flex items-center justify-center p-8 text-center">
            <h3 className="text-xl font-bold">{league}</h3>
          </div>
        ))}
      </div>

      <div className="glass-card mt-16 text-center max-w-3xl mx-auto">
        <h2 className="text-2xl font-bold mb-4">Data Quality First</h2>
        <p className="text-secondary text-lg">
          We use proprietary sports data ingestion coupled with advanced Gemini AI processing to ensure odds, standings, and events are processed reliably in real-time, avoiding the bloat of thousands of irrelevant leagues.
        </p>
      </div>
    </div>
  );
}
