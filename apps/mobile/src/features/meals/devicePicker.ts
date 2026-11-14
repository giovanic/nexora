import * as ImagePicker from "expo-image-picker";

export type PickedPhoto = { uri: string; mimeType?: string | null; fileSize?: number | null; fileName?: string | null };

export type PickResult =
  | { kind: "photo"; photo: PickedPhoto }
  | { kind: "canceled" }
  | { kind: "denied"; canAskAgain: boolean };

export type Picker = {
  takePhoto: () => Promise<PickResult>;
  choosePhoto: () => Promise<PickResult>;
};

// "compatible" asks iOS for the most compatible representation (not HEIC when it
// can be avoided). The docs do not promise JPEG; HEIC and HEIF are accepted and the
// backend converts them to JPEG, so the flow only refuses types outside the list.
const OPTIONS: ImagePicker.ImagePickerOptions = {
  mediaTypes: "images",
  exif: false,
  quality: 0.8,
  preferredAssetRepresentationMode: ImagePicker.UIImagePickerPreferredAssetRepresentationMode.Compatible,
};

function toResult(result: ImagePicker.ImagePickerResult): PickResult {
  const asset = result.canceled ? undefined : result.assets?.[0];
  if (!asset) return { kind: "canceled" };
  return { kind: "photo", photo: { uri: asset.uri, mimeType: asset.mimeType, fileSize: asset.fileSize, fileName: asset.fileName } };
}

export const devicePicker: Picker = {
  async takePhoto() {
    const permission = await ImagePicker.requestCameraPermissionsAsync();
    if (!permission.granted) return { kind: "denied", canAskAgain: permission.canAskAgain };
    return toResult(await ImagePicker.launchCameraAsync(OPTIONS));
  },
  // The system photo picker needs no permission on current iOS and Android.
  async choosePhoto() {
    return toResult(await ImagePicker.launchImageLibraryAsync(OPTIONS));
  },
};
