export const fanzoneDesignTokens = {
  color: {
    bg: "#09090B",
    surface: "#131418",
    surface2: "#18191E",
    surface3: "#22232A",
    border: "#272831",
    text: "#FDFCF0",
    muted: "#8B8E99",
    accent: "#22D3EE",
    accent2: "#2563EB",
    action: "#FF7F50",
    success: "#98FF98",
    warning: "#EAB308",
    danger: "#EF4444",
    teal: "#0F7B6C",
  },
  spacing: {
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 20,
    "2xl": 24,
    "3xl": 32,
    "4xl": 40,
  },
  radius: {
    button: 12,
    input: 12,
    card: 16,
    panel: 20,
    hero: 28,
    full: 999,
  },
  typography: {
    sans: "Outfit, ui-sans-serif, system-ui, sans-serif",
    display: "Bebas Neue, Outfit, ui-sans-serif, system-ui, sans-serif",
    mono: "JetBrains Mono, ui-monospace, SFMono-Regular, monospace",
  },
} as const;

export type FanzoneDesignTokens = typeof fanzoneDesignTokens;
