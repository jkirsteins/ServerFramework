//
//  JWTUserProvider.swift
//  
//
//  Created by Janis Kirsteins on 09/01/2022.
//

import ServerFramework
import Foundation
import Logging
import SwiftJWT

fileprivate extension Data {
    static func decodeUrlSafeBase64(_ value: String) throws -> Data {
        var stringtoDecode: String = value.replacingOccurrences(of: "-", with: "+")
        stringtoDecode = stringtoDecode.replacingOccurrences(of: "_", with: "/")
        switch (stringtoDecode.utf8.count % 4) {
        case 2:
            stringtoDecode += "=="
        case 3:
            stringtoDecode += "="
        default:
            break
        }
        guard let data = Data(base64Encoded: stringtoDecode, options: [.ignoreUnknownCharacters]) else {
            throw NSError(domain: "decodeUrlSafeBase64", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Can't decode base64 string"])
        }
        return data
    }
}

fileprivate extension String {
    func split(by length: Int) -> [String] {
        var startIndex = self.startIndex
        var results = [Substring]()
        
        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            results.append(self[startIndex..<endIndex])
            startIndex = endIndex
        }
        
        return results.map { String($0) }
    }
}

struct JWTAudience: Codable
{
    let values: [String]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        do {
            self.values = try container.decode([String].self)
        } catch {
            self.values = [
                try container.decode(String.self)
            ]
        }
        
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.values)
    }
}

struct JWTClaims: Claims, CustomStringConvertible {
    /// This is present in Apple-provided claims, but not always Auth0.
    /// Example value "https://appleid.apple.com"
    let iss: String?
    
    /// E.g. bundle ID or Auth0 API ID
    let aud: JWTAudience
    
    let exp: UInt64 // e.g. 1638865349
    let iat: UInt64 // e.g. 1638778949
    let sub: String // e.g. 001216.b9420fcf80c24f0aa4c19862d8e44e8b.1142
    
    /// This is present in Apple-provided claims, but not always Auth0.
    /// Example value: XT9w8JzXpsNc69nALdiPMQ,
    let c_hash: String?
    
    /// This is present in Apple-provided claims, but not always Auth0.
    /// Example value: 1638778949
    let auth_time: UInt64?
    
    /// This is present in Apple-provided claims, but not always Auth0.
    let nonce_supported: Bool?
    
    var description: String {
        "\(String(describing: JWTClaims.self))(sub: \(sub); aud: \(aud); iss: \(iss); exp: \(exp); iat: \(iat); c_hash: \(c_hash ?? "<none>"); auth_time: \(String(describing: auth_time)); nonce_supported: \(String(describing: nonce_supported)))"
    }
}

public struct JWTUser : User
{
    let claims: JWTClaims
    
    public var userId: String {
        self.claims.sub
    }
    
    init(_ claims: JWTClaims) {
        self.claims = claims
    }
}

public enum JWTUserProviderError : Error, CustomStringConvertible
{
    case trustedSigningKeyNotFound
    
    public var description: String {
        switch(self) {
        case .trustedSigningKeyNotFound:
            return "Could not find a trusted key to verify against."
        }
    }
}

public class JWTUserProvider : UserProvider
{
    /// Fixed ASN.1 header for an RSA public key
    static let pemHeader = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA"
    
    let logger = Logger(label: String(describing: JWTUserProvider.self))
    
    let keysetFetcher: JWKSetFetcher
    let audience: String
    
    public init(keysetFetcher: JWKSetFetcher, audience: String)
    {
        self.keysetFetcher = keysetFetcher
        self.audience = audience
    }
    
    func jwkToPem(_ key: JWKSet.Key) throws -> Data
    {
        let headerData = Data(base64Encoded: Self.pemHeader)
        let nData = try Data.decodeUrlSafeBase64(key.n)
        let eData = try Data.decodeUrlSafeBase64(key.e)
        
        let stream = NSMutableData()
        stream.append(headerData!)
        stream.append(nData)
        
        let c: [UInt8] = [2, UInt8(eData.count)]
        stream.append(c, length: 2)
        
        stream.append(eData)
        
        let pemChunks = stream.base64EncodedString().split(by: 64).joined(separator: "\n")
        let pem = "-----BEGIN RSA PUBLIC KEY-----\n\(pemChunks)\n-----END RSA PUBLIC KEY-----"
        
        logger.debug("Converted JWK to PEM", metadata: [
            "pem": .string(pem),
            "jwk": .stringConvertible(key)
        ])
        
        guard let pemData = pem.data(using: .utf8) else {
            logger.fatalAndDie("Failed to convert PEM string to data")
        }
        
        return pemData
    }
    
    public func extract(from request: HttpRequest) async throws -> User? {
        guard let authHeader = request.headers["Authorization"], let token = authHeader.value.split(separator: " ").dropFirst().first else {
            self.logger.debug("No Authorization header specified. Returning nil.")
            return nil
        }
        
        return try await verify(token: String(token))
    }
    
    func verify(token: String) async throws -> User? {
        do {
            let (kid, alg) = try self.getKidAndAlg(from: token)
            let key = try await self.getKey(kid: kid)
            
            let verifier: JWTVerifier
            switch (alg) {
            case "RS256":
                let pemData = try self.jwkToPem(key)
                
                verifier = JWTVerifier.rs256(publicKey: pemData)
                
                let newJWTToValidate: JWT<JWTClaims>
                do {
                    newJWTToValidate = try JWT<JWTClaims>(jwtString: token, verifier: verifier)
                } catch (error: SwiftJWT.JWTError.failedVerification) {
                    logger.error("Verification failed")
                    return nil
                }
                
                let validatedClaims = newJWTToValidate.validateClaims()
                
                guard newJWTToValidate.claims.aud.values.contains(self.audience) else {
                    logger.error("Invalid audience. Got \(newJWTToValidate.claims.aud) expected \(self.audience)")
                    return nil
                }
                
                let currentTime = time(nil)
                guard newJWTToValidate.claims.exp > currentTime else {
                    logger.error("Got an expired token. Exp \(newJWTToValidate.claims.exp) but current is \(currentTime)")
                    return nil
                }
                
                switch (validatedClaims) {
                case .success:
                    return JWTUser(newJWTToValidate.claims)
                default:
                    logger.error("Verification result was negative")
                    return nil
                }
            default:
                fatalError("Unknown alg \(alg)")
            }
        } catch JWTUserProviderError.trustedSigningKeyNotFound {
            self.logger.warning("Received a token with an unknown key.")
            return nil
        }
    }
    
    func getKey(kid: String) async throws -> JWKSet.Key {
        let keyset = try await keysetFetcher.fetch()
        guard let key = keyset.keys.first(where: { $0.kid == kid }) else {
            self.logger.error("Key \(kid) not found.")
            throw JWTUserProviderError.trustedSigningKeyNotFound
        }
        
        return key
    }
    
    func getKidAndAlg(from token: String) throws -> (kid: String, alg: String) {
        let newJWT = try JWT<JWTClaims>(jwtString: token)
        logger.debug("Fetching kid and alg from \(token)")
        guard let kid = newJWT.header.kid else {
            logger.fatalAndDie("Could not get kid from JWT")
        }
        guard let alg = newJWT.header.alg else {
            logger.fatalAndDie("Could not get alg from JWT")
        }
        return (kid, alg)
    }
}
