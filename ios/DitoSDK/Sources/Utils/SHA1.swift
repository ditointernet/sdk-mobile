import Foundation

infix operator <<< : BitwiseShiftPrecedence
private func <<< (lhs: UInt32, rhs: UInt32) -> UInt32 {
  return lhs << rhs | lhs >> (32 - rhs)
}

struct SHA1 {
  private static let CHUNKSIZE = 80

  private static let h0: UInt32 = 0x6745_2301
  private static let h1: UInt32 = 0xEFCD_AB89
  private static let h2: UInt32 = 0x98BA_DCFE
  private static let h3: UInt32 = 0x1032_5476
  private static let h4: UInt32 = 0xC3D2_E1F0

  /**************************************************
   * SHA1.context                                   *
   * The context struct contains volatile variables *
   * as well as the actual hashing function.        *
   **************************************************/
  private struct context {

    var h: [UInt32] = [SHA1.h0, SHA1.h1, SHA1.h2, SHA1.h3, SHA1.h4]

    mutating func process(chunk: inout ContiguousArray<UInt32>) {
      for i in 0..<16 {
        chunk[i] = chunk[i].bigEndian
      }

      for i in 16...79 {
        chunk[i] = (chunk[i - 3] ^ chunk[i - 8] ^ chunk[i - 14] ^ chunk[i - 16]) <<< 1
      }

      var a: UInt32
      var b: UInt32
      var c: UInt32
      var d: UInt32
      var e: UInt32
      var f: UInt32
      var k: UInt32
      var temp: UInt32
      a = h[0]
      b = h[1]
      c = h[2]
      d = h[3]
      e = h[4]
      f = 0x0
      k = 0x0

      for i in 0...79 {
        switch i {
        case 0...19:
          f = (b & c) | ((~b) & d)
          k = 0x5A82_7999

        case 20...39:
          f = b ^ c ^ d
          k = 0x6ED9_EBA1

        case 40...59:
          f = (b & c) | (b & d) | (c & d)
          k = 0x8F1B_BCDC

        case 60...79:
          f = b ^ c ^ d
          k = 0xCA62_C1D6

        default: break
        }

        temp = a <<< 5 &+ f &+ e &+ k &+ chunk[i]
        e = d
        d = c
        c = b <<< 30
        b = a
        a = temp
      }

      h[0] = h[0] &+ a
      h[1] = h[1] &+ b
      h[2] = h[2] &+ c
      h[3] = h[3] &+ d
      h[4] = h[4] &+ e
    }
  }

  /**************************************************
   * processData()                                  *
   * All inputs are processed as NSData.            *
   * This function splits the data into chunks of   *
   * 16 longwords (64 bytes, 512 bits),             *
   * padding the chunk as necessary.                *
   **************************************************/
  private static func process(data: inout Data) -> SHA1.context? {
    var context = SHA1.context()
    var w = ContiguousArray<UInt32>(repeating: 0x0000_0000, count: CHUNKSIZE)
    let ml = data.count << 3
    var range = 0..<64

    while data.count >= range.upperBound {
      w.withUnsafeMutableBufferPointer { dest in
        data.copyBytes(to: dest, from: range)
      }

      context.process(chunk: &w)
      range = range.upperBound..<range.upperBound + 64
    }

    w = ContiguousArray<UInt32>(repeating: 0x0000_0000, count: CHUNKSIZE)

    range = range.lowerBound..<data.count

    w.withUnsafeMutableBufferPointer { dest in
      data.copyBytes(to: dest, from: range)
    }

    let bytetochange = range.count % 4
    let shift = UInt32(bytetochange * 8)

    w[range.count / 4] |= 0x80 << shift

    if range.count + 1 > 56 {
      context.process(chunk: &w)
      w = ContiguousArray<UInt32>(repeating: 0x0000_0000, count: CHUNKSIZE)
    }

    w[15] = UInt32(ml).bigEndian
    context.process(chunk: &w)

    return context
  }

  /**************************************************
   * hexString()                                    *
   * Render the hash as a hexadecimal string        *
   **************************************************/
  private static func hexString(_ context: SHA1.context?) -> String? {
    context.map {
      String(format: "%08X %08X %08X %08X %08X", $0.h[0], $0.h[1], $0.h[2], $0.h[3], $0.h[4])
    }
  }

  /**************************************************
   * dataFromFile()                                 *
   * Fetch the contents of a file as NSData         *
   * for processing by processData()                *
   **************************************************/
  private static func dataFromFile(named filename: String) -> SHA1.context? {
    (try? Data(contentsOf: URL(fileURLWithPath: filename))).flatMap {
      var file = $0
      return process(data: &file)
    }
  }
}

extension SHA1 {
  /// Return a hexadecimal hash from a file
  static func hexString(fromFile filename: String) -> String? {
    hexString(SHA1.dataFromFile(named: filename))
  }

  /// Return the hash of a file as an array of Ints
  func hash(fromFile filename: String) -> [Int]? {
    SHA1.dataFromFile(named: filename)?.h.map { Int($0) }
  }

  /// Return a hexadecimal hash from NSData
  func hexString(from data: inout Data) -> String? {
    SHA1.hexString(SHA1.process(data: &data))
  }

  /// Return the hash of NSData as an array of Ints
  func hash(from data: inout Data) -> [Int]? {
    SHA1.process(data: &data)?.h.map { Int($0) }
  }

  /// Return a hexadecimal hash from a string
  static func hexString(from str: String) -> String? {
    str.data(using: .utf8).flatMap {
      var data = $0
      return hexString(SHA1.process(data: &data))
    }
  }

  /// Return the hash of a string as an array of Ints
  static func hash(from str: String) -> [Int]? {
    str.data(using: .utf8).flatMap {
      var data = $0
      return process(data: &data)?.h.map { Int($0) }
    }
  }
}
