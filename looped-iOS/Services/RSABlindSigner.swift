import Foundation
import Security
import BigInt

struct RSAKey {
    let modulus: BigUInt
    let exponent: BigUInt
    let sizeInBytes: Int
}

enum RSAKeyError: Error {
    case invalidPEM
    case invalidDER
    case invalidPublicKey
}

struct RSABlindContext {
    let unblinder: BigUInt
    let modulus: BigUInt
    let keySize: Int
}

enum RSABlindError: Error {
    case invalidMessage
    case invalidSignature
    case invalidRandom
    case inverseUnavailable
}

final class RSABlindSigner {
    func parsePublicKey(pem: String) throws -> RSAKey {
        let cleaned = pem
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----BEGIN") && !$0.hasPrefix("-----END") && !$0.isEmpty }
            .joined()

        guard let der = Data(base64Encoded: cleaned) else {
            throw RSAKeyError.invalidPEM
        }

        if pem.contains("BEGIN RSA PUBLIC KEY") {
            return try parseRSAPublicKey(der: der)
        }

        return try parseSubjectPublicKeyInfo(der: der)
    }

    func blind(message: Data, with key: RSAKey) throws -> (blinded: Data, context: RSABlindContext) {
        let messageInt = BigUInt(message)
        guard messageInt < key.modulus else {
            throw RSABlindError.invalidMessage
        }

        let r = try randomCoprime(under: key.modulus)
        guard let rInv = modInverse(r, modulus: key.modulus) else {
            throw RSABlindError.inverseUnavailable
        }

        let rPow = modPow(base: r, exponent: key.exponent, modulus: key.modulus)
        let blindedInt = (messageInt * rPow) % key.modulus
        let blinded = pad(blindedInt.serialize(), to: key.sizeInBytes)
        let context = RSABlindContext(unblinder: rInv, modulus: key.modulus, keySize: key.sizeInBytes)
        return (blinded: blinded, context: context)
    }

    func unblind(signature: Data, context: RSABlindContext) throws -> Data {
        let signatureInt = BigUInt(signature)
        guard signatureInt < context.modulus else {
            throw RSABlindError.invalidSignature
        }
        let unblindedInt = (signatureInt * context.unblinder) % context.modulus
        return pad(unblindedInt.serialize(), to: context.keySize)
    }

    private func randomCoprime(under modulus: BigUInt) throws -> BigUInt {
        let byteCount = max(1, (modulus.bitWidth + 7) / 8)
        for _ in 0..<32 {
            var bytes = [UInt8](repeating: 0, count: byteCount)
            let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
            guard status == errSecSuccess else { continue }
            let candidate = BigUInt(Data(bytes)) % modulus
            if candidate == 0 { continue }
            if gcd(candidate, modulus) == 1 { return candidate }
        }
        throw RSABlindError.invalidRandom
    }

    private func parseSubjectPublicKeyInfo(der: Data) throws -> RSAKey {
        var reader = ASN1Reader(data: der)
        let spki = try reader.readSequence()
        var spkiReader = ASN1Reader(data: spki)
        _ = try spkiReader.readSequence()
        let bitString = try spkiReader.readBitString()
        return try parseRSAPublicKey(der: bitString)
    }

    private func parseRSAPublicKey(der: Data) throws -> RSAKey {
        var reader = ASN1Reader(data: der)
        let rsaSequence = try reader.readSequence()
        var rsaReader = ASN1Reader(data: rsaSequence)
        let modulusBytes = try rsaReader.readInteger()
        let exponentBytes = try rsaReader.readInteger()

        let modulus = BigUInt(modulusBytes)
        let exponent = BigUInt(exponentBytes)
        guard modulus > 0, exponent > 0 else {
            throw RSAKeyError.invalidPublicKey
        }

        let sizeInBytes = max(1, (modulus.bitWidth + 7) / 8)
        return RSAKey(modulus: modulus, exponent: exponent, sizeInBytes: sizeInBytes)
    }

    private func gcd(_ a: BigUInt, _ b: BigUInt) -> BigUInt {
        var x = a
        var y = b
        while y != 0 {
            let temp = x % y
            x = y
            y = temp
        }
        return x
    }

    private func modPow(base: BigUInt, exponent: BigUInt, modulus: BigUInt) -> BigUInt {
        var result = BigUInt(1)
        var baseValue = base % modulus
        var exp = exponent

        while exp > 0 {
            if exp & 1 == 1 {
                result = (result * baseValue) % modulus
            }
            exp >>= 1
            baseValue = (baseValue * baseValue) % modulus
        }
        return result
    }

    private func modInverse(_ value: BigUInt, modulus: BigUInt) -> BigUInt? {
        var t = BigInt(0)
        var newT = BigInt(1)
        var r = BigInt(modulus)
        var newR = BigInt(value)

        while newR != 0 {
            let quotient = r / newR
            (t, newT) = (newT, t - quotient * newT)
            (r, newR) = (newR, r - quotient * newR)
        }

        guard r == 1 else { return nil }
        if t < 0 {
            t += BigInt(modulus)
        }
        return BigUInt(t)
    }

    private func pad(_ data: Data, to size: Int) -> Data {
        guard data.count < size else { return data }
        return Data(repeating: 0, count: size - data.count) + data
    }
}

private struct ASN1Reader {
    private let data: Data
    private var offset: Int = 0

    init(data: Data) {
        self.data = data
    }

    mutating func readSequence() throws -> Data {
        let length = try readTag(0x30)
        return try readBytes(length)
    }

    mutating func readInteger() throws -> Data {
        let length = try readTag(0x02)
        var bytes = [UInt8](try readBytes(length))
        if bytes.first == 0 { bytes.removeFirst() }
        return Data(bytes)
    }

    mutating func readBitString() throws -> Data {
        let length = try readTag(0x03)
        let bytes = [UInt8](try readBytes(length))
        guard !bytes.isEmpty else { throw RSAKeyError.invalidDER }
        return Data(bytes.dropFirst())
    }

    private mutating func readTag(_ expected: UInt8) throws -> Int {
        let tag = try readByte()
        guard tag == expected else { throw RSAKeyError.invalidDER }
        return try readLength()
    }

    private mutating func readLength() throws -> Int {
        let first = try readByte()
        if first & 0x80 == 0 {
            return Int(first)
        }
        let count = Int(first & 0x7F)
        guard count > 0 else { return 0 }
        var length = 0
        for _ in 0..<count {
            length = (length << 8) | Int(try readByte())
        }
        return length
    }

    private mutating func readByte() throws -> UInt8 {
        guard offset < data.count else { throw RSAKeyError.invalidDER }
        let byte = data[offset]
        offset += 1
        return byte
    }

    private mutating func readBytes(_ count: Int) throws -> Data {
        guard offset + count <= data.count else { throw RSAKeyError.invalidDER }
        let slice = data[offset..<(offset + count)]
        offset += count
        return Data(slice)
    }
}
