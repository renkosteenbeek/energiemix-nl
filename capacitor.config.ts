import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "nl.gentleinnovations.energiemix",
  appName: "Energiemix NL",
  webDir: "out",
  ios: {
    scrollEnabled: true,
    allowsLinkPreview: false,
    contentInset: "always",
  },
  server: {
    allowNavigation: ["energiemix.gentle-innovations.nl"],
  },
  plugins: {
    SplashScreen: {
      launchAutoHide: true,
      backgroundColor: "#FAFAF7",
      showSpinner: false,
      androidScaleType: "CENTER_CROP",
      splashFullScreen: false,
      splashImmersive: false,
    },
    StatusBar: {
      style: "LIGHT",
      backgroundColor: "#FAFAF7",
    },
  },
};

export default config;
