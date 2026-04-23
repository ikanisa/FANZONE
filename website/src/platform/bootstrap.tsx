import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { api } from "../services/api";
import { setPlatformBootstrapSnapshot } from "./access";
import { normalizePlatformBootstrap } from "./normalize";
import { DEFAULT_PLATFORM_BOOTSTRAP, type PlatformBootstrap } from "./types";

const STORAGE_KEY = "fanzone-platform-bootstrap-v1";

function readStoredBootstrap(): PlatformBootstrap {
  if (typeof window === "undefined") {
    return DEFAULT_PLATFORM_BOOTSTRAP;
  }

  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return DEFAULT_PLATFORM_BOOTSTRAP;
    return normalizePlatformBootstrap(JSON.parse(raw));
  } catch {
    return DEFAULT_PLATFORM_BOOTSTRAP;
  }
}

interface PlatformBootstrapContextValue {
  bootstrap: PlatformBootstrap;
  isReady: boolean;
  lastError: string | null;
  refresh: () => Promise<void>;
}

const PlatformBootstrapContext =
  createContext<PlatformBootstrapContextValue | null>(null);

export function PlatformBootstrapProvider({
  children,
}: {
  children: ReactNode;
}) {
  const [bootstrap, setBootstrap] = useState<PlatformBootstrap>(() => {
    const initial = readStoredBootstrap();
    setPlatformBootstrapSnapshot(initial);
    return initial;
  });
  const [isReady, setIsReady] = useState(false);
  const [lastError, setLastError] = useState<string | null>(null);

  const refresh = async () => {
    try {
      const next = await api.getPlatformBootstrap();
      setBootstrap(next);
      setPlatformBootstrapSnapshot(next);
      if (typeof window !== "undefined") {
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      }
      setLastError(null);
    } catch (error) {
      setLastError(
        error instanceof Error ? error.message : "Could not refresh platform bootstrap.",
      );
    } finally {
      setIsReady(true);
    }
  };

  useEffect(() => {
    void refresh();
  }, []);

  const value = useMemo(
    () => ({ bootstrap, isReady, lastError, refresh }),
    [bootstrap, isReady, lastError],
  );

  return (
    <PlatformBootstrapContext.Provider value={value}>
      {children}
    </PlatformBootstrapContext.Provider>
  );
}

export function usePlatformBootstrap() {
  const context = useContext(PlatformBootstrapContext);
  if (!context) {
    throw new Error(
      "usePlatformBootstrap must be used inside PlatformBootstrapProvider.",
    );
  }
  return context;
}
