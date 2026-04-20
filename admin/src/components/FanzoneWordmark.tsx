import type { CSSProperties } from "react";

interface FanzoneWordmarkProps {
  className?: string;
  style?: CSSProperties;
  ariaLabel?: string;
}

export function FanzoneWordmark({
  className,
  style,
  ariaLabel = "FANZONE",
}: FanzoneWordmarkProps) {
  return (
    <span
      className={["fz-wordmark", className].filter(Boolean).join(" ")}
      style={style}
      aria-label={ariaLabel}
    >
      <span className="fz-wordmark-fan">FAN</span>
      <span className="fz-wordmark-zone">ZONE</span>
    </span>
  );
}
