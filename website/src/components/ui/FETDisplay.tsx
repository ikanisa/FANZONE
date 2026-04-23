import React, { useEffect, useState } from "react";
import { api, type CurrencyDisplayPreference } from "../../services/api";

const EUR_RATE = 100;
const DEFAULT_PREFERENCE: CurrencyDisplayPreference = {
  code: "EUR",
  symbol: "€",
  decimals: 2,
  spaceSeparated: false,
  rate: 1,
};

export function FETDisplay({
  amount,
  showFiat = true,
  className = "",
  fiatClassName = "text-muted text-[0.85em] ml-1 font-normal tracking-normal",
}: {
  amount: number;
  showFiat?: boolean;
  className?: string;
  fiatClassName?: string;
}) {
  const [preference, setPreference] =
    useState<CurrencyDisplayPreference>(DEFAULT_PREFERENCE);

  useEffect(() => {
    let active = true;
    api.getPreferredCurrencyDisplay().then((value) => {
      if (active) {
        setPreference(value);
      }
    });

    return () => {
      active = false;
    };
  }, []);

  const fiatAmount = (amount / EUR_RATE) * preference.rate;
  const fiatStr = fiatAmount.toLocaleString(undefined, {
    minimumFractionDigits: preference.decimals,
    maximumFractionDigits: preference.decimals,
  });
  const separator = preference.spaceSeparated ? " " : "";

  return (
    <span className={className}>
      FET {amount.toLocaleString()}{" "}
      {showFiat && (
        <span className={fiatClassName}>
          ({preference.symbol}
          {separator}
          {fiatStr})
        </span>
      )}
    </span>
  );
}
