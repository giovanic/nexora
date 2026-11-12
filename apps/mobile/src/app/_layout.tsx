import { Slot } from "expo-router";
import { initMonitoring } from "../shared/monitoring";

initMonitoring(process.env.EXPO_PUBLIC_ERROR_TRACKING_DSN);

export default function RootLayout() {
  return <Slot />;
}
