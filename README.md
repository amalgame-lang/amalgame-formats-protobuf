# amalgame-formats-protobuf

Protocol Buffers (**proto3**) wire-format codec for Amalgame — the
foundation layer for a future gRPC server (`amalgame-net-grpc`).
Encode and decode protobuf messages directly on `List<int>` byte
buffers.

```amalgame
import Amalgame.Formats.Protobuf

// message Person { string name = 1; int32 age = 2; }
let body = ProtoWriter.New()
    .Str(1, "Ada")
    .Varint(2, 36)
    .ToBytes()

let r = ProtoReader.New(body)
while (!r.AtEnd()) {
    let f = r.ReadTag()
    if      (f == 1) { name = r.Str() }
    else if (f == 2) { age  = r.Varint() }
    else             { r.Skip() }      // unknown field — stay compatible
}
```

## Binary-safe by construction

The buffer is a `List<int>` of bytes (each 0..255), never a `string`,
so embedded NUL bytes and the full 0..255 range survive byte-for-byte
(string-based handling would `strlen`-truncate at the first NUL — fatal
for a binary format). The test suite proves a bytes field carrying
`00 01 FF 00 80` round-trips exactly.

## API

`ProtoWriter` (fluent; `.ToBytes()` returns the `List<int>`):

| Method | proto type | wire |
|---|---|---|
| `.Varint(field, v)` | int32/64, uint32/64, enum (v ≥ 0) | 0 |
| `.Sint(field, v)` | sint32/64 (ZigZag — use for negatives) | 0 |
| `.Bool(field, b)` | bool | 0 |
| `.Fixed64(field, v)` / `.Fixed32(field, v)` | fixed/sfixed/double/float | 1 / 5 |
| `.Bytes(field, List<int>)` | bytes | 2 |
| `.Str(field, string)` | string (UTF-8) | 2 |
| `.Message(field, List<int>)` | embedded message | 2 |

`ProtoReader` (call `ReadTag()` → field number, then the matching
reader; `Skip()` for unknown fields; `AtEnd()` to stop): `Varint()`,
`Sint()`, `Bool()`, `Fixed64()`, `Fixed32()`, `Bytes()`, `Str()`.

## Scope (v0.1.0 — honest)

Wire-format codec only. **Not yet:** `.proto` IDL parsing / codegen,
gRPC HTTP/2 framing + streaming (these are the `amalgame-net-grpc`
layer that builds on this), groups (deprecated wire types 3/4), and
full-range negative *plain* varints — use `Sint` for negatives; plain
`Varint` expects a non-negative value in `[0, 2^62)`.

## Build & test

```bash
./tests/run_tests.sh          # 7 round-trip tests incl. binary-safety
```

Self-contained: needs only `amc`, a C toolchain and `libgc`. No
sibling-package dependencies; links nothing beyond the runtime.

## License

Apache-2.0.
