import { router } from "expo-router";
import { Linking } from "react-native";
import { CameraScreen } from "../../features/meals/CameraScreen";
import { pendingPhotos } from "../../features/meals/PendingPhotos";
import { deviceUploader } from "../../features/meals/UploadFlow";
import { newClientRequestId } from "../../features/meals/clientRequestId";
import { devicePicker } from "../../features/meals/devicePicker";
import { api } from "../../shared/api";

export default function Camera() {
  return (
    <CameraScreen
      api={api}
      picker={devicePicker}
      photos={pendingPhotos}
      uploader={deviceUploader}
      newId={newClientRequestId}
      onResult={(id) => router.push({ pathname: "/meals/[id]", params: { id } })}
      onManual={() => router.push("/meals/manual")}
      onHistory={() => router.push("/meals/history")}
      onOpenSettings={() => router.push("/settings")}
      openDeviceSettings={() => void Linking.openSettings()}
    />
  );
}
