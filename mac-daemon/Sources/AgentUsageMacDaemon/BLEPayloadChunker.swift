import Foundation

public struct BLEPayloadChunk: Equatable, Sendable {
    public let messageID: UInt16
    public let index: UInt16
    public let count: UInt16
    public let payload: Data
}

public enum BLEPayloadChunkerError: Error, Equatable, Sendable {
    case maximumChunkSizeTooSmall
}

public struct BLEPayloadChunker: Sendable {
    private static let headerSize = 9
    private let maximumChunkSize: Int

    public init(maximumChunkSize: Int) {
        self.maximumChunkSize = maximumChunkSize
    }

    public func chunks(for data: Data, messageID: UInt16) throws -> [BLEPayloadChunk] {
        guard maximumChunkSize > 0 else {
            throw BLEPayloadChunkerError.maximumChunkSizeTooSmall
        }

        let count = UInt16(max(1, Int(ceil(Double(data.count) / Double(maximumChunkSize)))))
        return stride(from: 0, to: data.count, by: maximumChunkSize).enumerated().map { offset, start in
            let end = min(start + maximumChunkSize, data.count)
            return BLEPayloadChunk(
                messageID: messageID,
                index: UInt16(offset),
                count: count,
                payload: data.subdata(in: start..<end)
            )
        }
    }

    public func wireChunks(for data: Data, messageID: UInt16) throws -> [Data] {
        guard maximumChunkSize > Self.headerSize else {
            throw BLEPayloadChunkerError.maximumChunkSizeTooSmall
        }

        let bodySize = maximumChunkSize - Self.headerSize
        let bodyChunks = try BLEPayloadChunker(maximumChunkSize: bodySize).chunks(for: data, messageID: messageID)
        return bodyChunks.map { chunk in
            var wire = Data([0x41, 0x55, 0x01])
            wire.appendUInt16(chunk.messageID)
            wire.appendUInt16(chunk.index)
            wire.appendUInt16(chunk.count)
            wire.append(chunk.payload)
            return wire
        }
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }
}
