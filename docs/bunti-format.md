# Bunti, format version 1

Bunti is a two-dimensional colour code that a camera reads. Its format is a sequence of the DNA bases A, C, G
and T; the coloured picture is how that sequence is shown. This document is precise enough to build an encoder and
a decoder from; the reference is `Wolly.Bunti`, `Wolly.BuntiRs`, `Wolly.BuntiDna` and `Wolly.BuntiScan`
(`src/Wolly/`).

Every rule is marked:

- **fixed**: part of the format, not to be changed;
- **proposed, not confirmed**: chosen while building it, with its reason, open to change;
- **measured**: a number from a run, with the test that gives it.

## 1. Name and nature

- The name is Bunti; it is a proprietary format and part of Wolly, module `Wolly.Bunti`. **fixed**
- A square grid of cells that a camera reads. **fixed**
- Error correction is Reed-Solomon, no complementary strand. **fixed**

## 2. Bases and bytes

- Four colours stand for four bases, two bits a cell: **A = 00, C = 01, G = 10, T = 11**. **fixed**
- A byte is four bases, its highest two bits first. **fixed** Example: `W` = 0x57 = 01 01 01 11 = `CCCT`.
- Vectors (tested in `Bunti.test.hiq`, `testVectors`): `Wolly` = `CCCT CGTT CGTA CGTA CTGC`, `Heiko` = `CAGA CGCC CGGC
  CGGT CGTT`, `W` = `CCCT`, `w` = `CTCT`.
- A cell value in the reference: 0 to 3 a base, 4 black, 5 white.

## 3. The grid

**proposed, not confirmed** in all of section 3 (unless said otherwise):

- **Size**: `size = 4 v + 17` cells on a side for a version `v` from 1 to 60, so 21 to 257. Like QR codes, so that
  the distance of two finders in cells tells the version. Up to 60 so that 4096 bytes fit at level H in both modes
  (`testTooLong`).
- **Coordinates**: column `x` and row `y`, from 0 at the top left.
- **Quiet zone**: 4 white cells around the code when it is drawn.
- **Finder patterns**: three, 7 by 7 cells, top left at (0, 0), top right at (size − 7, 0), bottom left at (0,
  size − 7). A cell (i, j) of a finder is black when i or j is 0 or 6, or both lie in 2 to 4; otherwise white. Across
  its middle this gives the runs black, white, black, white, black of the widths 1 : 1 : 3 : 1 : 1. Black and white
  only, never a colour of a base.
- **Separators**: the cells of the 8 by 8 corner square of each finder that are not part of it are white: the
  squares x < 8 and y < 8; x ≥ size − 8 and y < 8; x < 8 and y ≥ size − 8.
- **Corner pattern** in the fourth corner, 5 by 5 cells at (size − 5, size − 5): black when i or j is 0 or 4, or i
  = j = 2; otherwise white; runs 1 : 1 : 1 : 1 : 1. The square x ≥ size − 6 and y ≥ size − 6 is its own and white
  around it. It does not tell the turn, which the three finders tell already (section 8), so
  it serves as the fourth point of the perspective transformation, which three points cannot give.
- **Reference cells**: twelve, four beside each finder, holding A, C, G, T in that order: k = 0 to 3 at (k, 8)
  below the top left finder, k = 4 to 7 at (size − 4 + (k − 4), 8) below the top right, k = 8 to 11 at (k − 8,
  size − 9) above the bottom left. Reference k holds the base k mod 4.
- **Data cells**: every other cell. They are counted row by row from the top, left to right in a row:
  `D = size² − 240` of them (3 × 64 for the finder squares, 36 for the corner square, 12 references).

## 4. The data sequence

The D data cells, in their order, hold:

1. the first copy of the header, 64 bases;
2. the bases of the payload (section 6 or 7);
3. filling up to the last 64 cells: the cell at position `at` from the first base of the payload holds the base
   `at mod 4` (A, C, G, T, A, ...), so that no long run of one colour appears;
4. the second copy of the header, the last 64 data cells.

The payload may use at most `P = D − 128` cells. **proposed, not confirmed**: two copies far apart, so that one
damaged corner does not cost the header.

## 5. The header

**proposed, not confirmed**: 8 bytes, Reed-Solomon with 8 parity bytes (the code of section 6.1, parity 8, so up to
4 wrong bytes of the 16 are corrected), 16 bytes as 64 bases in mode 1 whatever the mode of the payload: the
mode is known only after the header is read. Protected more than the payload: 50 percent parity against 14 to 60.

| Byte | Content |
|---|---|
| 0 | format version × 16 + mode × 4 + level; version 1; mode 1 or 2; level 0 (L), 1 (M), 2 (Q), 3 (H) |
| 1 | the version v of the grid, 1 to 60 |
| 2, 3 | the length of the payload in bytes, highest byte first, 0 to 65535 |
| 4 to 7 | CRC-32 of the payload (polynomial 0xEDB88320 as gzip and zip; Standard.Gzip.crc32), highest byte first |
| 8 to 15 | Reed-Solomon parity of bytes 0 to 7 |

A copy of the header is taken when Reed-Solomon corrects it, the format version is 1, the mode 1 or 2, byte 1 is
the version of the grid read, and the payload of that length, mode and level fits the grid. The first copy is
tried first, then the second.

## 6. Reed-Solomon and blocks

### 6.1 The code

GF(256) with the polynomial x⁸ + x⁴ + x³ + x² + 1 (0x11D), primitive element 2; the generator polynomial of p
parity bytes is (x − 2⁰)(x − 2¹) … (x − 2^(p−1)); a block is its data bytes followed by its parity bytes, at most
255, the first byte the coefficient of the highest power: the code of QR codes (tested against the parity of the
HELLO WORLD example of ISO/IEC 18004, version 1-M, `testIsoVector`). Decoding: syndromes, Berlekamp-Massey, Chien
search, Forney; a block whose error locator does not have as many roots in the block as errors is refused and
left as it was.
**Reed-Solomon fixed; GF(256) with 0x11D proposed, not confirmed** (as in QR codes).

### 6.2 Levels

The parity bytes `F` of a full block of 255 bytes, after the QR levels L/M/Q/H (**proposed, not confirmed**):

| Level | F | Data of a full block | Corrects of 255 |
|---|---|---|---|
| L (0) | 36 | 219 | 18 bytes, 7 % |
| M (1) | 76 | 179 | 38 bytes, 15 % |
| Q (2) | 128 | 127 | 64 bytes, 25 % |
| H (3) | 154 | 101 | 77 bytes, 30 % |

### 6.3 Blocks for n bytes of payload

- n = 0: no block, no codeword.
- `b = ceil(n / (255 − F))` blocks; `s = floor(n / b)`; the first `n − s·b` blocks hold s + 1 data bytes, the
  others s; the payload goes in order, block after block.
- Parity bytes of every block: `p = ceil(L · F / (255 − F))` for the longest block L = ceil(n / b), made even by
  one more if odd, at least 2. So a short payload keeps the share of its level; the same p for all blocks.
- **Codewords**, `C = n + b·p` of them, interleaved: the data bytes column by column (byte j of every block that has
  one, blocks in order, for j = 0 to s), then the parity bytes column by column (parity byte j of each block, for j
  = 0 to p − 1). A burst of damaged cells spreads over the blocks.

**proposed, not confirmed**: block lengths and interleaving as QR does them; the even parity keeps p / 2 errors a
whole number.

## 7. Modes

- **Mode 1 (standard)**: each codeword its four bases (section 2): 4·C cells. **proposed, not confirmed**
- **Mode 2 (DNA-suitable)**, the bases a synthesiser can write: never more than 3 equal bases in a row, between 45
  and 55 percent G and C in each segment. Whether it stays is open; it is built in full.
  **proposed, not confirmed**:
  - The codewords are cut into **segments of 32 bytes**, the last one shorter (m bytes, 1 to 32).
  - A segment is: the seed as 4 bases; the first floor(m / 2) bytes; the seed again; the other bytes; the seed a
    third time. Each byte j of segment s is XOR the byte j of the sequence of the seed, then four bases: 4·m + 12
    bases. The bases for C codewords: `4·C + 12·ceil(C / 32)`.
  - The sequence of a seed (0 to 255) for segment s: a linear congruential generator mod 2³², `x ← 1664525·x +
    1013904223`, started at `x = (seed + 1)·2654435761 + (s + 1)·40503`; before each byte one step, the byte the
    highest 8 bits of x.
  - The encoder takes the first seed from 0 upwards whose segment has no run of 4 equal bases, counted on from the
    end of the segment before, and 45 to 55 percent G and C (`100·gc ≥ 45·len` and `100·gc ≤ 55·len`). If no seed of
    the 256 fits, it fails (NoSeed); not seen in the 1806 cases of `testProperties`.
  - The decoder takes each of the 4 bases of the seed by the vote of its three copies (the first copy when all
    three differ), then removes the sequence.
  - Why: rules checked on the sequence itself instead of a code of its own, and a scrambler whose seed is chosen,
    after the screening of DNA Fountain (Erlich and Zielinski 2017); the seed in three copies so that one wrong base
    of the seed does not cost the segment. 32 bytes as a middle way: a longer segment keeps both rules for fewer
    seeds, a shorter one pays more for its 12 bases of seed.
  - Rate: 256 / 140 = **1.83 bits a base** in full segments, against 2 in mode 1 and about 1.98 of DNA Fountain.
  - The header (section 5) stays in mode 1 and is not held to the rules: the sequence for synthesis is the payload
    bases (`buntiSequence`), not the picture.

**measured** (`BuntiDna.test.hiq`): random codewords of every length 1 to 300 and of 4096, only 0x00, only 0xFF,
0x00 0xFF repeated, 0x01 0x02 0x03 repeated, bytes counting up: 1806 of 1806 cases keep both rules and decode to
their bytes. **One wrong base** in mode 2 (`testOneWrongBase`, every base of 100 codewords changed to each of the
three others, 1344 cases): 144 cost no byte (a base of a seed copy, outvoted), 1200 cost one byte, none more. A
wrong cell costs Reed-Solomon one byte, as in mode 1.

## 8. Reading a picture (informative)

What `Wolly.BuntiScan` does; another decoder may do otherwise as long as it reads the cells.

1. Input: red, green and blue bytes of each pixel, row by row (a frame of a camera). A pixel is **dark** when the
   highest of its three values is at or below the threshold Otsu's method finds over that value of all pixels.
   Black is dark; each base colour has one value near the top and is light, also under a colour cast.
2. **Finders**: along every row the runs dark, light, dark, light, dark with widths 1 : 1 : 3 : 1 : 1, each within
   half a cell (the middle within 1.5 cells); checked down the column of the middle and across the row again, the
   two lengths within 0.6 to 1.67 of each other; found again close by, they are merged. The **corner pattern** the
   same with 1 : 1 : 1 : 1 : 1.
3. Of three finders, the one opposite the longest side is top left; the two others must lie at nearly a right angle
   (|cos| < 0.3) and at nearly equal distance (0.7 to 1.43) and at least 10 cells away. Seen from the top left, the
   top right is the one clockwise of the other on a picture whose y runs down: so a code is read in each of its four
   turns. A mirror image is not read.
4. **Size**: the mean distance of the finders in cells (the cell from the finder width) plus 7 gives v; v and its
   neighbours up to ±3 are tried until a header reads and names that v.
5. **Transformation**: the grid points (3.5, 3.5), (size − 3.5, 3.5), (3.5, size − 3.5) of the finder middles and
   (size − 2.5, size − 2.5) of the corner pattern give a perspective transformation (eight equations, Gaussian
   elimination); the corner pattern is the one nearest to where the finders put it, within 35 % of the finder
   distance and of a cell size between half and twice the finders'. Without one, the affine transformation of the
   three finders.
6. **Cells**: each sampled in its middle (u + 0.5, v + 0.5), the mean of the pixels within a quarter cell. The 12
   reference cells are sampled the same way; a data cell is given the base of the reference whose colour is
   nearest (sum of the squared differences of red, green and blue), **not fixed colour values**. **proposed, not
   confirmed**
7. Header, Reed-Solomon of every block, CRC-32: **a picture gives its payload or an error, never other bytes**.

## 9. Drawing

**proposed, not confirmed**: A green (0, 170, 70) `#00aa46`, C blue (0, 90, 220) `#005adc`, G yellow (250, 205, 0)
`#facd00`, T red (220, 30, 30) `#dc1e1e`; black (0, 0, 0), white (255, 255, 255). The values are chosen so that each has one channel high (light for the threshold of section 8, step 1) and they
lie far apart.
`buntiPixels`, `buntiSvg` (one `rect` a run of equal cells in a row) and `buntiPng` (through Wolly.Image) draw
`scale` pixels a cell with the quiet zone.

## 10. Measured

### 10.1 Density (`Bunti.test.hiq`, `testDensity`)

Bits of payload a cell of the whole grid (`8·capacity / size²`), **measured** from `buntiCapacity`:

| Version (size) | Mode 1 L | M | Q | H | Mode 2 L | M | Q | H |
|---|---|---|---|---|---|---|---|---|
| 1 (21) | 0.253 | 0.217 | 0.145 | 0.108 | 0.217 | 0.163 | 0.126 | 0.090 |
| 10 (57) | 1.521 | 1.240 | 0.879 | 0.694 | 1.381 | 1.130 | 0.805 | 0.635 |
| 30 (137) | 1.680 | 1.373 | 0.974 | 0.774 | 1.531 | 1.255 | 0.891 | 0.704 |
| 60 (257) | 1.705 | 1.390 | 0.984 | 0.782 | 1.560 | 1.274 | 0.903 | 0.717 |

Capacity at version 60: mode 1 L 14080, M 11480, Q 8128, H 6464 bytes; mode 2 12886, 10526, 7458, 5924.

### 10.2 Reed-Solomon (`BuntiRs.test.hiq`, `Bunti.test.hiq`)

- Every block with up to p / 2 wrong bytes is corrected exactly (all parities 2 to 154; `testCorrect`, 630 blocks).
- One byte more: with 10 and more parity bytes every block is refused (200, 60, 30, 20, 20 of as many); with 2 parity
  bytes 140 of 300 are refused and 160 taken for another block, which the CRC-32 of the header refuses then
  (`testChecksum`: blocks of another payload give BadChecksum).
- In the grid (`testCapacity`, both modes, all levels, 500 bytes): one wrong base in p / 2 bytes of every block, at
  random, gives the payload; one more wrong byte gives an error.

### 10.3 Pictures (`BuntiScan.test.hiq` and `BuntiScanPart1` to `BuntiScanPart3`, every picture written as PNG and read again)

- Read exactly: the four turns (Wolly, mode 1, M; 300 bytes, mode 2, Q); 120 bytes at M with perspective 0.1, cast 20,
  noise ±20 in each turn; 4096 bytes at H in mode 2 at 3 pixels a cell, turned, cast 20, noise ±10.
- **Limits measured**, 120 bytes at M, each distortion alone (`testLimits`, steps of 5 and 10): smallest cell 2
  pixels; perspective 0.25 (0.30 failed; strength s: the picture point (u, v) taken from (u, v)·(1 + s) / (1 + s·u /
  side + s·v / side), so the right and the lower edge are drawn nearer); colour cast 90 percent (red ·(1 − 0.45) + 90,
  green ·(1 − 0.45), blue ·(1 − 0.9): the end of the range tried); noise ±140 on every value (±150 failed).
- A white picture, noise alone and pixels of the wrong length give no code; strong noise (±100 to ±250) gives the
  payload or an error, never other bytes (`testNoCode`).
- Ink spread by a pixel (every pixel within one of a dark one made black, 500 bytes at L, 6 pixels a cell): the finders
  read wider, the size first guessed is too small, the header refuses it and a neighbour reads (`testSpread`; without
  the header check the test fails).

- **Free turns, scale, covering** (`testFreeTurns`, `testScales`, `testCovered`, 120 bytes, 6 pixels a cell): every turn in steps of 5 degrees from 0 to 90 read, also with cast 20, noise ±20 and a scale of 5/4;
  cells of 2 to 12 whole pixels and of 2.25, 2.5, 3.5, 7.5, 10.5 and 14 pixels read. A square over the middle (steps
  of 2 percent of the side): read up to 14 percent at L, up to 36 (black) and 38 (white) at H; 50 percent at H gives
  the payload or an error. A finder covered (7 cells white) gives no code, covered black an honest answer; the corner
  pattern covered reads through the three finders.

### 10.4 Time (aarch64, 16 cores)

- `encodeBunti` and `decodeBunti` apart, 6 runs each, all read back. The tables and the generator are made once a
  code, the logarithm of the factor once a byte, and the bytes of a block are taken as numbers once for the
  syndromes:

  | | encoding | decoding |
  |---|---|---|
  | mode 1, L, 4096 bytes | 35–39 ms | 20 ms |
  | mode 1, H, 1024 bytes | 34 ms | 33 ms |
  | mode 1, H, 4096 bytes | 137–152 ms | 135–138 ms |
  | mode 2, H, 4096 bytes | 204–210 ms | 135–138 ms |
- Reading a picture, the code at 6 pixels a cell in the middle of a white picture, 10 runs each, all read exactly:
  640×480 41–48 ms, 1280×720 126–171 ms. Dark is taken straight from the pixels, Otsu from every other pixel of every
  other row, and the finders are searched along every third row (the middle band of a finder is 6 pixels high at 2
  pixels a cell).
- The round trip of every length 0 to 4096 in both modes and at all levels (`sweep/BuntiSweepAll.test.hiq`,
  `scripts/bunti-sweep.sh`): estimated from every 16th length about 5050 s together, mode 2 H alone 1206 s. One round
  trip grows about linearly with the length (the four quarters stand 1 : 3 : 5 : 7), so the whole sweep with the
  square. So `scripts/test.sh` runs only the sample `src/Wolly/BuntiSweep.test.hiq`,
  100 lengths a mode and level.

## 11. Not in version 1

- An alignment pattern in the middle for large codes bent by a lens; a mirrored picture; codes with a colour of
  their own beside the four. A reader in the browser, through Hilde's WebAssembly target.
