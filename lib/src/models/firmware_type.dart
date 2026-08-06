/// The source from which the firmware binary is loaded.
///
/// * [FirmwareType.assets]: Load the firmware from the app's bundled assets
///   (formerly represented by the integer `1`).
/// * [FirmwareType.filepicker]: Let the user pick the firmware file from the
///   device (formerly represented by the integer `2`).
/// * [FirmwareType.url]: Download the firmware from a URL (formerly represented
///   by the integer `3`).
enum FirmwareType { assets, filepicker, url }
