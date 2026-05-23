import Foundation

public enum BLEUsageWire {
    public static let serviceUUIDString = "8B7D2F4E-9678-4A13-A890-A5E89D7D6C01"
    public static let snapshotCharacteristicUUIDString = "0A5B95C6-20B7-4149-8E26-AB0BD034A07C"
    public static let headerSize = 9
    public static let magic: [UInt8] = [0x41, 0x55]
    public static let version: UInt8 = 0x01
}

public enum BLEPayloadReassemblerError: Error, Equatable, Sendable {
    case chunkTooSmall
    case invalidMagic
    case unsupportedVersion(UInt8)
    case invalidChunkIndex
    case emptyChunkSet
}

public struct BLEPayloadReassembler: Sendable {
    private struct MessageBuffer: Sendable {
        let count: UInt16
        var chunks: [UInt16: Data]
    }

    private var buffers: [UInt16: MessageBuffer] = [:]

    public init() {}

    public mutating func reset() {
        buffers.removeAll()
    }

    public mutating func receive(_ wireChunk: Data) throws -> Data? {
        let chunk = try parse(wireChunk)
        var buffer = buffers[chunk.messageID] ?? MessageBuffer(count: chunk.count, chunks: [:])

        if buffer.count != chunk.count {
            buffer = MessageBuffer(count: chunk.count, chunks: [:])
        }

        buffer.chunks[chunk.index] = chunk.payload
        buffers[chunk.messageID] = buffer

        guard buffer.chunks.count == Int(buffer.count) else {
            return nil
        }

        var payload = Data()
        for index in UInt16(0)..<buffer.count {
            guard let part = buffer.chunks[index] else {
                return nil
            }
            payload.append(part)
        }
        buffers.removeValue(forKey: chunk.messageID)
        return payload
    }

    private func parse(_ wireChunk: Data) throws -> BLEPayloadChunk {
        guard wireChunk.count >= BLEUsageWire.headerSize else {
            throw BLEPayloadReassemblerError.chunkTooSmall
        }

        let bytes = [UInt8](wireChunk.prefix(BLEUsageWire.headerSize))
        guard bytes[0] == BLEUsageWire.magic[0], bytes[1] == BLEUsageWire.magic[1] else {
            throw BLEPayloadReassemblerError.invalidMagic
        }
        guard bytes[2] == BLEUsageWire.version else {
            throw BLEPayloadReassemblerError.unsupportedVersion(bytes[2])
        }

        let messageID = Self.uint16(high: bytes[3], low: bytes[4])
        let index = Self.uint16(high: bytes[5], low: bytes[6])
        let count = Self.uint16(high: bytes[7], low: bytes[8])

        guard count > 0 else {
            throw BLEPayloadReassemblerError.emptyChunkSet
        }
        guard index < count else {
            throw BLEPayloadReassemblerError.invalidChunkIndex
        }

        return BLEPayloadChunk(
            messageID: messageID,
            index: index,
            count: count,
            payload: wireChunk.subdata(in: BLEUsageWire.headerSize..<wireChunk.count)
        )
    }

    private static func uint16(high: UInt8, low: UInt8) -> UInt16 {
        (UInt16(high) << 8) | UInt16(low)
    }
}

public struct BLEPayloadChunk: Equatable, Sendable {
    public let messageID: UInt16
    public let index: UInt16
    public let count: UInt16
    public let payload: Data

    public init(messageID: UInt16, index: UInt16, count: UInt16, payload: Data) {
        self.messageID = messageID
        self.index = index
        self.count = count
        self.payload = payload
    }
}
