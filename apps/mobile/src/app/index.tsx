import { router } from "expo-router";
import { api } from "../shared/api";
import { ResumeGate } from "../features/onboarding/ResumeGate";

const go = (path: string) => router.replace(path as never);

export default function Index() {
  return <ResumeGate api={api} onRoute={go} />;
}
