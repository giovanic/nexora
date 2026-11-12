import { ApiStatusScreen } from "../features/api-status/ApiStatusScreen";

export default function Index() {
  return <ApiStatusScreen baseUrl={process.env.EXPO_PUBLIC_API_URL} showErrorTrigger={__DEV__} />;
}
