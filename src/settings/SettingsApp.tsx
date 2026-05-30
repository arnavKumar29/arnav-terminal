import { WindowControls } from "@/components/WindowControls";
import { IS_MAC, USE_CUSTOM_WINDOW_CONTROLS } from "@/lib/platform";
import type { SettingsTab } from "@/modules/settings/openSettingsWindow";
import { usePreferencesStore } from "@/modules/settings/preferences";
import {
  AiScanIcon,
  InformationCircleIcon,
  PaintBoardIcon,
  Settings01Icon,
  UserMultiple02Icon,
  KeyboardIcon,
} from "@hugeicons/core-free-icons";
import { HugeiconsIcon } from "@hugeicons/react";
import { getCurrentWebviewWindow } from "@tauri-apps/api/webviewWindow";
import { JSX, useEffect, useState } from "react";
import { AboutSection } from "./sections/AboutSection";
import { AgentsSection } from "./sections/AgentsSection";
import { GeneralSection } from "./sections/GeneralSection";
import { ModelsSection } from "./sections/ModelsSection";
import { ShortcutsSection } from "./sections/ShortcutsSection";
import { ThemesSection } from "./sections/ThemesSection";

const TABS: { id: SettingsTab; label: string; icon: typeof Settings01Icon, component: () => JSX.Element }[] =
  [
    { id: "general", label: "General", icon: Settings01Icon, component: GeneralSection },
    { id: "themes", label: "Themes", icon: PaintBoardIcon, component: ThemesSection },
    { id: "shortcuts", label: "Shortcuts", icon: KeyboardIcon, component: ShortcutsSection },
    { id: "models", label: "Models", icon: AiScanIcon, component: ModelsSection },
    { id: "agents", label: "Agents", icon: UserMultiple02Icon, component: AgentsSection },
    { id: "about", label: "About", icon: InformationCircleIcon, component: AboutSection },
  ];

const VALID_TABS: SettingsTab[] = [
  "general",
  "themes",
  "shortcuts",
  "models",
  "agents",
  "about",
];

function readInitialTab(): SettingsTab {
  if (typeof window === "undefined") return "general";
  const url = new URL(window.location.href);
  const t = url.searchParams.get("tab");
  // Back-compat: legacy "ai" / "connections" → "models".
  if (t === "ai" || t === "connections") return "models";
  if (t && (VALID_TABS as string[]).includes(t)) return t as SettingsTab;
  return "general";
}

export function SettingsApp() {
  const [active, setActive] = useState<SettingsTab>(readInitialTab);
  const init = usePreferencesStore((s) => s.init);
  const ActiveSection = TABS.find(t => t.id === active)?.component;

  useEffect(() => {
    void init();
  }, [init]);

  useEffect(() => {
    const apply = (detail: string) => {
      if (detail === "ai" || detail === "connections") {
        setActive("models");
        return;
      }
      if ((VALID_TABS as string[]).includes(detail)) {
        setActive(detail as SettingsTab);
      }
    };
    const unlistenPromise = getCurrentWebviewWindow().listen<string>(
      "arnavterminal:settings-tab",
      (e) => apply(e.payload),
    );
    return () => {
      void unlistenPromise.then((un) => un());
    };
  }, []);

  return (
    <div className="flex h-screen bg-background/80 backdrop-blur-2xl text-foreground select-none">
      {/* Absolute Header for Drag Region */}
      <div 
        data-tauri-drag-region
        className={`absolute top-0 left-0 right-0 h-10 flex items-center z-50 ${IS_MAC ? "pl-22" : "pr-2"}`}
      >
        {USE_CUSTOM_WINDOW_CONTROLS && (
          <div className="ml-auto flex items-center pointer-events-auto">
             <WindowControls closeOnly />
          </div>
        )}
      </div>

      {/* Sidebar Navigation */}
      <aside className="w-56 shrink-0 border-r border-border/40 bg-muted/10 flex flex-col pt-12 px-4 gap-1.5 z-40">
        <div className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground/80 mb-3 px-2">Settings</div>
        {TABS.map((t) => (
          <button
            key={t.id}
            onClick={() => setActive(t.id)}
            className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-all ${
              active === t.id 
                ? "bg-primary text-primary-foreground shadow-sm" 
                : "text-muted-foreground hover:bg-muted/40 hover:text-foreground"
            }`}
          >
            <HugeiconsIcon icon={t.icon} size={16} strokeWidth={2} />
            <span>{t.label}</span>
          </button>
        ))}
      </aside>

      {/* Main Content */}
      <main className="flex-1 overflow-y-auto px-10 pt-12 pb-10 bg-background/50">
        <div className="mx-auto w-full max-w-2xl">
          {ActiveSection && <ActiveSection />}
        </div>
      </main>
    </div>
  );
}
