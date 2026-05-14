import { useEffect, useState } from "react";
import { toDataURL } from "qrcode";

export function useQrCode(value: string) {
  const [dataUrl, setDataUrl] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    toDataURL(value, {
      errorCorrectionLevel: "M",
      margin: 1,
      width: 720,
      color: {
        dark: "#050507",
        light: "#ffffff",
      },
    })
      .then((nextValue) => {
        if (active) setDataUrl(nextValue);
      })
      .catch(() => {
        if (active) setDataUrl(null);
      });

    return () => {
      active = false;
    };
  }, [value]);

  return dataUrl;
}
