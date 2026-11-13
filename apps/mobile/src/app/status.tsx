import { ApiStatusScreen } from "../features/api-status/ApiStatusScreen";

export default function Status() {
  return <ApiStatusScreen baseUrl={process.env.EXPO_PUBLIC_API_URL} showErrorTrigger={__DEV__} />;
}
