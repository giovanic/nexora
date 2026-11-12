import { ApiStatusScreen } from "./features/api-status/ApiStatusScreen";

const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:3010";

export default function App() {
  return <ApiStatusScreen baseUrl={API_URL} showErrorTrigger={import.meta.env.DEV} />;
}
