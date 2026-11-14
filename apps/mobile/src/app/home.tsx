import { Redirect } from "expo-router";

// The first screen after sign in is the camera.
export default function Home() {
  return <Redirect href="/meals" />;
}
