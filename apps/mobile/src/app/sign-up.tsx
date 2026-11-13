import { router } from "expo-router";
import { SignUpScreen } from "../features/auth/SignUpScreen";
import { api } from "../shared/api";

export default function SignUp() {
  return <SignUpScreen api={api} onSignedUp={() => router.replace("/")} onGoToSignIn={() => router.replace("/sign-in")} />;
}
