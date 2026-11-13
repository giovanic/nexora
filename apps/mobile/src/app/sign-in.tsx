import { router } from "expo-router";
import { SignInScreen } from "../features/auth/SignInScreen";
import { api } from "../shared/api";

export default function SignIn() {
  return (
    <SignInScreen
      api={api}
      onSignedIn={() => router.replace("/")}
      onGoToSignUp={() => router.replace("/sign-up")}
      onGoToForgotPassword={() => router.push("/forgot-password")}
    />
  );
}
