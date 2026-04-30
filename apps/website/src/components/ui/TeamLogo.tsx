import React, { useMemo, useState } from "react";

interface TeamLogoProps {
  teamName: string;
  src?: string | null;
  size?: number;
  className?: string;
}

export function TeamLogo({
  teamName,
  src,
  size = 24,
  className = "",
}: TeamLogoProps) {
  const [error, setError] = useState(false);
  const initials = useMemo(() => {
    const tokens = teamName
      .split(/\s+/)
      .map((token) => token.trim())
      .filter((token) => token.length > 0)
      .slice(0, 2);

    if (tokens.length === 0) return "?";
    return tokens.map((token) => token[0]?.toUpperCase() ?? "").join("");
  }, [teamName]);

  if (src?.trim() && !error) {
    return (
      <img
        src={src.trim()}
        alt={`${teamName} logo`}
        width={size}
        height={size}
        className={`object-contain ${className}`}
        onError={() => setError(true)}
        referrerPolicy="no-referrer"
      />
    );
  }

  return (
    <div
      aria-label={`${teamName} badge`}
      title={teamName}
      className={`inline-flex items-center justify-center rounded-full bg-surface3 text-text font-bold uppercase ${className}`}
      style={{
        width: size,
        height: size,
        fontSize: Math.max(10, Math.round(size * 0.36)),
      }}
    >
      {initials}
    </div>
  );
}
