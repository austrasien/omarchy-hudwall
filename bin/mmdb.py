"""A minimal MaxMind DB (.mmdb) reader, stdlib only.

Enough for the city databases (DB-IP lite, GeoLite2): a lookup returns the
decoded record, a dict. The whole file is memory-mapped, so a lookup is a
walk down the search tree plus the decoding of one record.
"""

import ipaddress
import mmap
import struct

METADATA_MARKER = b"\xab\xcd\xefMaxMind.com"


class Reader:
    def __init__(self, path):
        f = open(path, "rb")
        self._buf = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        f.close()
        start = self._buf.rfind(METADATA_MARKER, max(0, len(self._buf) - 128 * 1024))
        if start < 0:
            raise ValueError("not a MaxMind DB file")
        meta_start = start + len(METADATA_MARKER)
        self.metadata, _ = Decoder(self._buf, meta_start).decode(meta_start)
        self.node_count = self.metadata["node_count"]
        self.record_size = self.metadata["record_size"]
        self.ip_version = self.metadata["ip_version"]
        self._node_bytes = self.record_size * 2 // 8
        self._search_size = self._node_bytes * self.node_count
        self._data = Decoder(self._buf, self._search_size + 16)
        self._ipv4_start = None

    def _read_node(self, node, index):
        off = node * self._node_bytes
        b = self._buf
        if self.record_size == 24:
            o = off + index * 3
            return int.from_bytes(b[o:o + 3], "big")
        if self.record_size == 28:
            middle = b[off + 3]
            if index == 0:
                return ((middle & 0xF0) << 20) | int.from_bytes(b[off:off + 3], "big")
            return ((middle & 0x0F) << 24) | int.from_bytes(b[off + 4:off + 7], "big")
        if self.record_size == 32:
            o = off + index * 4
            return int.from_bytes(b[o:o + 4], "big")
        raise ValueError("unsupported record size %d" % self.record_size)

    def _start_node(self, bits):
        if self.ip_version == 6 and bits == 32:
            if self._ipv4_start is None:
                node = 0
                for _ in range(96):
                    if node >= self.node_count:
                        break
                    node = self._read_node(node, 0)
                self._ipv4_start = node
            return self._ipv4_start
        return 0

    def get(self, ip):
        addr = ipaddress.ip_address(ip)
        packed = addr.packed
        bits = len(packed) * 8
        if bits == 128 and self.ip_version == 4:
            return None
        node = self._start_node(bits)
        for i in range(bits):
            if node >= self.node_count:
                break
            bit = (packed[i >> 3] >> (7 - (i & 7))) & 1
            node = self._read_node(node, bit)
        if node == self.node_count:
            return None
        if node > self.node_count:
            offset = (node - self.node_count) - 16
            value, _ = self._data.decode(self._data.base + offset)
            return value
        return None


class Decoder:
    def __init__(self, buf, base):
        self.buf = buf
        self.base = base

    def _size(self, offset, ctrl):
        size = ctrl & 0x1F
        if size < 29:
            return size, offset
        n = size - 28
        v = int.from_bytes(self.buf[offset:offset + n], "big")
        if size == 29:
            return 29 + v, offset + 1
        if size == 30:
            return 285 + v, offset + 2
        return 65821 + v, offset + 3

    def decode(self, offset):
        buf = self.buf
        ctrl = buf[offset]
        offset += 1
        kind = ctrl >> 5
        if kind == 1:  # pointer
            ss = (ctrl >> 3) & 0x3
            vvv = ctrl & 0x7
            if ss == 0:
                p = (vvv << 8) | buf[offset]
                offset += 1
            elif ss == 1:
                p = ((vvv << 16) | int.from_bytes(buf[offset:offset + 2], "big")) + 2048
                offset += 2
            elif ss == 2:
                p = ((vvv << 24) | int.from_bytes(buf[offset:offset + 3], "big")) + 526336
                offset += 3
            else:
                p = int.from_bytes(buf[offset:offset + 4], "big")
                offset += 4
            value, _ = self.decode(self.base + p)
            return value, offset
        if kind == 0:
            kind = 7 + buf[offset]
            offset += 1
        size, offset = self._size(offset, ctrl)
        if kind == 2:  # utf-8 string
            return bytes(buf[offset:offset + size]).decode("utf-8", "replace"), offset + size
        if kind == 3:  # double
            return struct.unpack(">d", buf[offset:offset + 8])[0], offset + 8
        if kind == 4:  # bytes
            return bytes(buf[offset:offset + size]), offset + size
        if kind in (5, 6, 9, 10):  # unsigned ints
            return int.from_bytes(buf[offset:offset + size], "big"), offset + size
        if kind == 7:  # map
            out = {}
            for _ in range(size):
                k, offset = self.decode(offset)
                v, offset = self.decode(offset)
                out[k] = v
            return out, offset
        if kind == 8:  # int32
            v = int.from_bytes(buf[offset:offset + size], "big", signed=False)
            if size == 4 and v & 0x80000000:
                v -= 1 << 32
            return v, offset + size
        if kind == 11:  # array
            out = []
            for _ in range(size):
                v, offset = self.decode(offset)
                out.append(v)
            return out, offset
        if kind == 14:  # boolean
            return size != 0, offset
        if kind == 15:  # float
            return struct.unpack(">f", buf[offset:offset + 4])[0], offset + 4
        raise ValueError("unknown mmdb type %d" % kind)
