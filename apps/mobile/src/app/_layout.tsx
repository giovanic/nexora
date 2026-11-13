import { router, Slot } from "expo-router";
import { setUnauthorizedHandler } from "../shared/api";
import { initMonitoring } from "../shared/monitoring";

initMonitoring(process.env.EXPO_PUBLIC_ERROR_TRACKING_DSN);

// A session problem anywhere (expired, revoked, missing) ends at sign in.
setUnauthorizedHandler(() => router.replace("/sign-in"));

export default function RootLayout() {
  return <Slot />;
}
