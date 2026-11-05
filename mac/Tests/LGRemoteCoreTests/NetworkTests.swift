import Foundation
import Testing
@testable import LGRemoteCore

@Suite struct MagicPacketTests {
    @Test func buildsStandardPacket() throws {
        let packet = try MagicPacket.make(mac: "AA:bb:cc:dd:ee:01")
        #expect(packet.count == 102)
        #expect(Array(packet.prefix(6)) == [UInt8](repeating: 0xFF, count: 6))
        let mac: [UInt8] = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0x01]
        for i in 0..<16 {
            #expect(Array(packet[(6 + i * 6)..<(12 + i * 6)]) == mac)
        }
    }

    @Test func acceptsDashSeparators() throws {
        #expect(try MagicPacket.make(mac: "aa-bb-cc-dd-ee-ff").count == 102)
    }

    @Test(arguments: ["aa:bb:cc", "zz:bb:cc:dd:ee:ff", ""])
    func rejectsInvalidMac(mac: String) {
        #expect(throws: WakeOnLanError.invalidMac(mac)) { try MagicPacket.make(mac: mac) }
    }
}

@Suite struct SSDPResponseTests {
    let response = "HTTP/1.1 200 OK\r\nCACHE-CONTROL: max-age=1800\r\nLocation: http://192.168.1.50:1817/desc.xml\r\nST: upnp:rootdevice\r\n\r\n"

    @Test func parsesLocationCaseInsensitively() {
        #expect(SSDPResponse.location(in: response) == URL(string: "http://192.168.1.50:1817/desc.xml"))
    }

    @Test func missingLocationIsNil() {
        #expect(SSDPResponse.location(in: "HTTP/1.1 200 OK\r\n\r\n") == nil)
    }

    @Test func detectsLGInHeadersAndDescription() {
        #expect(SSDPResponse.mentionsLG("SERVER: WebOS/4.1.0 UPnP/1.0 LGE WebOS TV"))
        #expect(!SSDPResponse.mentionsLG(response))
        #expect(SSDPResponse.descriptionMentionsLG("<manufacturer>LG Electronics</manufacturer>"))
        #expect(!SSDPResponse.descriptionMentionsLG("<manufacturer>Sonos</manufacturer>"))
    }
}

@Suite struct ARPOutputTests {
    @Test func parsesAndNormalizesMac() {
        let output = "? (192.168.1.50) at a:b:c:d:e:f on en0 ifscope [ethernet]\n"
        #expect(ARPOutput.mac(from: output) == "0a:0b:0c:0d:0e:0f")
    }

    @Test func parsesFullMac() {
        #expect(ARPOutput.mac(from: "? (10.0.0.2) at AC:5A:F0:12:34:56 on en0") == "ac:5a:f0:12:34:56")
    }

    @Test func incompleteEntryIsNil() {
        #expect(ARPOutput.mac(from: "? (192.168.1.50) at (incomplete) on en0 ifscope [ethernet]") == nil)
        #expect(ARPOutput.mac(from: "192.168.1.50 (192.168.1.50) -- no entry") == nil)
    }
}
