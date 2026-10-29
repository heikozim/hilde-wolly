# Signs a file with an Ed25519 key, for the e2e cases of examples/hello on
# systems whose openssl cannot: LibreSSL 4.3 (OpenBSD 7.9) refuses Ed25519 in
# pkeyutl ("operation not supported for this keytype") and has no -rawin.
# RFC 8032, section 5.1.6, after the reference code of its
# section 6; slow and not constant-time, for the keys of a test run only.
#
#     python3 -I scripts/ed25519-sign.py <key.der> <file>   # the signature, base64, one line
#     python3 -I scripts/ed25519-sign.py --vector           # RFC 8032 7.1 TEST 1: exit 0 when it is met
#
# key.der is the private key as PKCS #8 DER (openssl pkey -outform DER).
import base64
import hashlib
import sys

p = 2**255 - 19
L = 2**252 + 27742317777372353535851937790883648493
d = -121665 * pow(121666, p - 2, p) % p


def add(P, Q):
    A = (P[1] - P[0]) * (Q[1] - Q[0]) % p
    B = (P[1] + P[0]) * (Q[1] + Q[0]) % p
    C = 2 * P[3] * Q[3] * d % p
    D = 2 * P[2] * Q[2] % p
    E, F, G, H = B - A, D - C, D + C, B + A
    return (E * F % p, G * H % p, F * G % p, E * H % p)


def mul(s, P):
    Q = (0, 1, 1, 0)
    while s > 0:
        if s & 1:
            Q = add(Q, P)
        P = add(P, P)
        s >>= 1
    return Q


def encode(P):
    zi = pow(P[2], p - 2, p)
    x, y = P[0] * zi % p, P[1] * zi % p
    return (y | (x & 1) << 255).to_bytes(32, "little")


def recover_x(y, sign):
    x2 = (y * y - 1) * pow(d * y * y + 1, p - 2, p) % p
    x = pow(x2, (p + 3) // 8, p)
    if (x * x - x2) % p != 0:
        x = x * pow(2, (p - 1) // 4, p) % p
    if x & 1 != sign:
        x = p - x
    return x


gy = 4 * pow(5, p - 2, p) % p
gx = recover_x(gy, 0)
G = (gx, gy, 1, gx * gy % p)


def sha512_int(b):
    return int.from_bytes(hashlib.sha512(b).digest(), "little")


def sign(seed, msg):
    h = hashlib.sha512(seed).digest()
    a = int.from_bytes(h[:32], "little")
    a &= (1 << 254) - 8
    a |= 1 << 254
    A = encode(mul(a, G))
    r = sha512_int(h[32:] + msg) % L
    R = encode(mul(r, G))
    s = (r + sha512_int(R + A + msg) % L * a) % L
    return R + s.to_bytes(32, "little")


# PKCS #8 of an Ed25519 key (RFC 8410): this head, then the 32 bytes of the seed.
HEAD = bytes.fromhex("302e020100300506032b657004220420")

if sys.argv[1:] == ["--vector"]:
    seed = bytes.fromhex("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")
    want = bytes.fromhex("e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b")
    sys.exit(0 if sign(seed, b"") == want else 1)
if len(sys.argv) != 3:
    sys.exit("usage: ed25519-sign.py <key.der> <file> | --vector")
with open(sys.argv[1], "rb") as f:
    der = f.read()
if len(der) != 48 or der[:16] != HEAD:
    sys.exit("ed25519-sign.py: %s is not an Ed25519 key in PKCS #8 DER" % sys.argv[1])
with open(sys.argv[2], "rb") as f:
    msg = f.read()
print(base64.b64encode(sign(der[16:], msg)).decode())
