import { Fragment } from "react";
import type { CSSProperties, ReactNode } from "react";

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

export function renderFanzoneText(text: string): ReactNode {
  const parts = text.split("FANZONE");
  if (parts.length === 1) {
    return text;
  }

  return parts.flatMap((part, index) => {
    const nodes: ReactNode[] = [];
    if (part) {
      nodes.push(<Fragment key={`text-${index}`}>{part}</Fragment>);
    }
    if (index < parts.length - 1) {
      nodes.push(<FanzoneWordmark key={`brand-${index}`} />);
    }
    return nodes;
  });
}
