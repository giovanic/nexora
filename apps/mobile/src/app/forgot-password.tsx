import { router } from "expo-router";
import { ForgotPasswordScreen } from "../features/auth/ForgotPasswordScreen";
import { api } from "../shared/api";

export default function ForgotPassword() {
  return <ForgotPasswordScreen api={api} onBack={() => router.replace("/sign-in")} />;
}
