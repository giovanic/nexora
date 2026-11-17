import { router } from "expo-router";
import { ManualEntryScreen } from "../../features/meals/ManualEntryScreen";
import { newClientRequestId } from "../../features/meals/clientRequestId";
import { api } from "../../shared/api";

export default function Manual() {
  return <ManualEntryScreen api={api} newId={newClientRequestId} onCreated={(id) => router.replace({ pathname: "/meals/[id]", params: { id } })} />;
}
