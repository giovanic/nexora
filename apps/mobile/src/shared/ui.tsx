import type { ComponentRef, ReactNode, Ref } from "react";
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  type TextInputProps,
} from "react-native";
import type { Failure } from "./api";
import { errorMessage } from "./messages";

const INK = "#1b1f23";
const ACCENT = "#0b5cad";
const DANGER = "#8f2d1f";
const LINE = "#8c959f";

export function Screen({ children }: { children: ReactNode }) {
  return (
    <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === "ios" ? "padding" : undefined}>
      <ScrollView contentContainerStyle={styles.screen} keyboardShouldPersistTaps="handled">
        {children}
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

export function Title({ children }: { children: string }) {
  return (
    <Text role="heading" style={styles.title}>
      {children}
    </Text>
  );
}

export function Subtitle({ children }: { children: string }) {
  return (
    <Text role="heading" style={styles.subtitle}>
      {children}
    </Text>
  );
}

export function Body({ children }: { children: ReactNode }) {
  return <Text style={styles.body}>{children}</Text>;
}

export function ErrorText({ children }: { children: string | null | undefined }) {
  if (!children) return null;
  return (
    <Text role="alert" accessibilityLiveRegion="polite" style={styles.error}>
      {children}
    </Text>
  );
}

export function InfoText({ children }: { children: string | null | undefined }) {
  if (!children) return null;
  return (
    <Text role="status" accessibilityLiveRegion="polite" style={styles.body}>
      {children}
    </Text>
  );
}

export type InputRef = ComponentRef<typeof TextInput>;

type FieldProps = TextInputProps & { label: string; inputRef?: Ref<InputRef> };

export function Field({ label, inputRef, ...input }: FieldProps) {
  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label}</Text>
      <TextInput
        ref={inputRef}
        accessibilityLabel={label}
        autoCapitalize="none"
        autoCorrect={false}
        style={styles.input}
        {...input}
      />
    </View>
  );
}

type ButtonProps = {
  label: string;
  onPress: () => void;
  busy?: boolean;
  disabled?: boolean;
  variant?: "primary" | "secondary" | "danger";
};

export function Button({ label, onPress, busy = false, disabled = false, variant = "primary" }: ButtonProps) {
  const inactive = busy || disabled;
  return (
    <Pressable
      role="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: inactive, busy }}
      disabled={inactive}
      onPress={onPress}
      style={[styles.button, variant === "primary" && styles.primary, variant === "danger" && styles.danger, inactive && styles.inactive]}
    >
      <Text style={[styles.buttonText, variant === "primary" && styles.onPrimary, variant === "danger" && styles.onPrimary]}>
        {busy ? "Aguarde…" : label}
      </Text>
    </Pressable>
  );
}

export function LinkButton({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable role="link" accessibilityLabel={label} onPress={onPress} style={styles.link}>
      <Text style={styles.linkText}>{label}</Text>
    </Pressable>
  );
}

type ChoiceProps = { label: string; selected: boolean; onPress: () => void; kind?: "checkbox" | "radio" };

export function Choice({ label, selected, onPress, kind = "checkbox" }: ChoiceProps) {
  return (
    <Pressable
      role={kind}
      accessibilityLabel={label}
      accessibilityState={{ checked: selected }}
      onPress={onPress}
      style={[styles.choice, selected && styles.choiceOn]}
    >
      <Text style={styles.choiceText}>{`${selected ? "[x]" : "[ ]"} ${label}`}</Text>
    </Pressable>
  );
}

export function LoadingView({ label = "Carregando…" }: { label?: string }) {
  return (
    <View style={styles.center} accessibilityLiveRegion="polite">
      <ActivityIndicator accessibilityLabel={label} />
      <Text role="status" style={styles.body}>
        {label}
      </Text>
    </View>
  );
}

export function ErrorView({ error, onRetry }: { error: Failure; onRetry: () => void }) {
  return (
    <View style={styles.center}>
      <ErrorText>{errorMessage(error)}</ErrorText>
      <Button label="Tentar de novo" variant="secondary" onPress={onRetry} />
    </View>
  );
}

export function EmptyView({ children }: { children: string }) {
  return (
    <Text role="status" style={styles.body}>
      {children}
    </Text>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  screen: { flexGrow: 1, gap: 14, padding: 24, paddingTop: 48 },
  title: { color: INK, fontSize: 26, fontWeight: "bold" },
  subtitle: { color: INK, fontSize: 19, fontWeight: "bold", marginTop: 12 },
  body: { color: INK, fontSize: 16, lineHeight: 23 },
  error: { color: DANGER, fontSize: 16 },
  field: { gap: 4 },
  label: { color: INK, fontSize: 15 },
  input: { borderColor: LINE, borderRadius: 8, borderWidth: 1, color: INK, fontSize: 16, minHeight: 48, paddingHorizontal: 12 },
  button: { alignItems: "center", borderColor: ACCENT, borderRadius: 8, borderWidth: 1, justifyContent: "center", minHeight: 48, paddingHorizontal: 16 },
  primary: { backgroundColor: ACCENT },
  danger: { backgroundColor: DANGER, borderColor: DANGER },
  inactive: { opacity: 0.55 },
  buttonText: { color: ACCENT, fontSize: 16, fontWeight: "600" },
  onPrimary: { color: "#ffffff" },
  link: { justifyContent: "center", minHeight: 48 },
  linkText: { color: ACCENT, fontSize: 16, textDecorationLine: "underline" },
  choice: { borderColor: LINE, borderRadius: 8, borderWidth: 1, justifyContent: "center", minHeight: 48, paddingHorizontal: 12 },
  choiceOn: { borderColor: ACCENT, borderWidth: 2 },
  choiceText: { fontSize: 16 },
  center: { gap: 12, paddingVertical: 12 },
});
