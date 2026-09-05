import CryptoKit
import Foundation

guard CommandLine.arguments.count == 4 else {
    fputs("Usage: verify-sparkle-signature <archive> <signature> <Info.plist>\n", stderr)
    exit(2)
}

let archiveURL = URL(fileURLWithPath: CommandLine.arguments[1])
let signatureText = CommandLine.arguments[2]
let infoURL = URL(fileURLWithPath: CommandLine.arguments[3])
let archive = try Data(contentsOf: archiveURL)
guard let signature = Data(base64Encoded: signatureText) else {
    fputs("Invalid Sparkle signature encoding.\n", stderr)
    exit(1)
}
let plistData = try Data(contentsOf: infoURL)
guard let plist = try PropertyListSerialization.propertyList(
    from: plistData,
    options: [],
    format: nil
) as? [String: Any],
      let publicKeyText = plist["SUPublicEDKey"] as? String,
      let publicKeyData = Data(base64Encoded: publicKeyText) else {
    fputs("Missing or invalid SUPublicEDKey.\n", stderr)
    exit(1)
}
let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
guard publicKey.isValidSignature(signature, for: archive) else {
    fputs("Sparkle archive signature is invalid.\n", stderr)
    exit(1)
}
print("Verified Sparkle archive signature")
