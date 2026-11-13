# device_label is encrypted at the application level now, and the encrypted
# value is longer than the 100 characters the label is cut to. The model still
# cuts the label before encrypting it (Session::MAX_DEVICE_LABEL).
class DropSessionsDeviceLabelLengthCheck < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :sessions, "char_length(device_label) <= 100", name: "sessions_device_label_length"
  end
end
