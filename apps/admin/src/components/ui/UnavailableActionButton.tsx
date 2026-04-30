import type { ReactNode } from "react";

interface UnavailableActionButtonProps {
  icon: ReactNode;
  label: string;
  title?: string;
  variant?: "primary" | "secondary";
}

export function UnavailableActionButton({
  icon,
  label,
  title,
  variant = "primary",
}: UnavailableActionButtonProps) {
  return (
    <button
      className={`btn ${variant === "secondary" ? "btn-secondary" : "btn-primary"}`}
      type="button"
      disabled
      aria-disabled="true"
      title={title ?? `${label} is not live in this build.`}
    >
      {icon} {label}
    </button>
  );
}
