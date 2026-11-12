import { Pressable, StyleSheet, Text, View } from "react-native";
import { ApiStatusView } from "./ApiStatusView";
import type { FetchFn } from "./fetchReadiness";
import { useApiStatus } from "./useApiStatus";

type Props = {
  baseUrl: string | undefined;
  fetchFn?: FetchFn;
  showErrorTrigger: boolean;
};

export function ApiStatusScreen({ baseUrl, fetchFn, showErrorTrigger }: Props) {
  const state = useApiStatus(baseUrl, fetchFn);

  return (
    <View style={styles.container}>
      <Text role="heading" style={styles.title}>
        Estado da API
      </Text>
      <ApiStatusView state={state} />
      {showErrorTrigger && (
        <Pressable
          role="button"
          accessibilityLabel="Provocar erro de teste"
          style={styles.trigger}
          onPress={() => {
            throw new Error("provoked mobile error");
          }}
        >
          <Text>Provocar erro de teste</Text>
        </Pressable>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, gap: 16, justifyContent: "center", padding: 24 },
  title: { fontSize: 24, fontWeight: "bold" },
  trigger: { alignSelf: "flex-start", borderWidth: 1, justifyContent: "center", minHeight: 48, paddingHorizontal: 16 },
});
