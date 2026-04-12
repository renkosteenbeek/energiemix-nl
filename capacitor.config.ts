import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "nl.gentleinnovations.stroompeil",
  appName: "Stroompeil",
  webDir: "out",
  server: {
    allowNavigation: ["energiemix.gentle-innovations.nl"],
  },
  plugins: {
    SplashScreen: {
      launchAutoHide: true,
      launchShowDuration: 0,
    },
    StatusBar: {
      style: "DEFAULT",
    },
  },
};

export default config;
