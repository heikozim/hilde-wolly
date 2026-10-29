# Demo: Bunti codes

Three Bunti codes (`Wolly.Bunti`, `docs/bunti-format.md`): a two-dimensional colour code a camera reads.
Four colours carry two bits each (green A, blue C, yellow G, red T), three finder patterns of black and white and a
corner pattern show the camera where the code lies, Reed-Solomon at level M and a CRC-32 protect the payload.

Each PNG was made by `cli/buntipng` from the text beside it, drawn at 8 pixels a cell with the quiet zone of 4 cells,
written to a file, **read again from that file** and decoded with `Wolly.BuntiScan` (it finds the finder patterns in
the pixels, samples every cell and checks Reed-Solomon and the CRC-32). The text read back was the text in each case.

| File | Text | Cells | PNG | SHA-256 |
|---|---|---|---|---|
| `bunti-wolly.png` | `Wolly` | 21 by 21 | 2730 bytes, 232 by 232 px | `76d8da969afd045dcf832b02aa77e6182ac6ea9dd101994490092ba29335a40c` |
| `bunti-satz.png` | `Wolly ist ein Web-Framework in Hilde: Formulare, Sitzungen, Bilder und dieser Farbcode, Bunti, den eine Kamera liest.` | 33 by 33 | 4857 bytes, 328 by 328 px | `28cc19a642cf5f7329394bf4e0ceb5efb6ffd877351c23fdc3eaa96d4644367b` |
| `bunti-lang.png` | the 415 bytes of `bunti-lang.txt` | 53 by 53 | 11451 bytes, 488 by 488 px | `15bdb1c459470dda2ca417f391851139622b72071b4e1d7d1bd28d028a2dfd89` |

The SHA-256 were taken in the container that wrote the file and again on the file here; they agree.

## Making one

In the build environment of `scripts/env.sh`, from the root of the tree:

    CLI=1 ONLY=buntipng bash scripts/build.sh
    _run/bin/buntipng code.png "Wolly"

It prints the cells on a side, the bytes of the PNG and `buntipng: ok, the text read back from the file is the text`
and exits 0, or says why not and exits 1 (a text that does not fit, a file that cannot be written, a picture that
does not decode, another text read back).

`Wolly.BuntiScan` was tested on damaged and turned pictures (`BuntiScan.test.hiq` and its parts `BuntiScanPart1` to `BuntiScanPart3`); no real camera has read
these files.
