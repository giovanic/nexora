import * as ImagePicker from "expo-image-picker";
import { devicePicker } from "../devicePicker";

jest.mock("expo-image-picker", () => ({
  requestCameraPermissionsAsync: jest.fn(),
  launchCameraAsync: jest.fn(),
  launchImageLibraryAsync: jest.fn(),
  UIImagePickerPreferredAssetRepresentationMode: { Compatible: "compatible" },
  PermissionStatus: { GRANTED: "granted", DENIED: "denied" },
}));

const picker = ImagePicker as jest.Mocked<typeof ImagePicker>;
const OPTIONS = { mediaTypes: "images", exif: false, quality: 0.8, preferredAssetRepresentationMode: "compatible" };
const asset = { uri: "file:///cache/p.jpg", mimeType: "image/jpeg", fileSize: 10, fileName: "p.jpg", width: 1, height: 1 };

describe("devicePicker", () => {
  beforeEach(() => jest.clearAllMocks());

  it("asks the camera for compatible images without EXIF and with quality 0.8", async () => {
    picker.requestCameraPermissionsAsync.mockResolvedValue({ granted: true, canAskAgain: true, status: ImagePicker.PermissionStatus.GRANTED, expires: "never" });
    picker.launchCameraAsync.mockResolvedValue({ canceled: false, assets: [asset] });

    expect(await devicePicker.takePhoto()).toEqual({ kind: "photo", photo: { uri: asset.uri, mimeType: "image/jpeg", fileSize: 10, fileName: "p.jpg" } });
    expect(picker.launchCameraAsync).toHaveBeenCalledWith(OPTIONS);
  });

  it("reports a denied camera permission without opening the camera", async () => {
    picker.requestCameraPermissionsAsync.mockResolvedValue({ granted: false, canAskAgain: false, status: ImagePicker.PermissionStatus.DENIED, expires: "never" });

    expect(await devicePicker.takePhoto()).toEqual({ kind: "denied", canAskAgain: false });
    expect(picker.launchCameraAsync).not.toHaveBeenCalled();
  });

  it("opens the library with the same options and reports a cancel", async () => {
    picker.launchImageLibraryAsync.mockResolvedValue({ canceled: true, assets: null });

    expect(await devicePicker.choosePhoto()).toEqual({ kind: "canceled" });
    expect(picker.launchImageLibraryAsync).toHaveBeenCalledWith(OPTIONS);
  });
});
