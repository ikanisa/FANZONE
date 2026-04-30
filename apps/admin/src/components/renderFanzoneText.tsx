import { Fragment } from "react";
import type { ReactNode } from "react";

import { FanzoneWordmark } from "./FanzoneWordmark";

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
