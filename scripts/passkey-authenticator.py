# Part of Wolly, a web framework in Hilde.
#
# SPDX-FileCopyrightText: 2026 Heiko Zimmermann
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# A passkey authenticator for scripts/e2e-login.sh, written apart from
# Wolly.Passkey and its tests: CBOR by hand after RFC 8949, the COSE key
# after RFC 9052, the signature by openssl.  It prints the fields of the
# form, base64url without padding.
#
#     python3 -I passkey-authenticator.py create KEY CHALLENGE ORIGIN RPID
#     python3 -I passkey-authenticator.py get KEY CHALLENGE ORIGIN RPID COUNTER [FLAGS]
import base64
import hashlib
import json
import subprocess
import sys

CREDENTIAL = bytes(range(16, 32))


def url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def head(major, value):
    if value < 24:
        return bytes([major * 32 + value])
    if value < 256:
        return bytes([major * 32 + 24, value])
    return bytes([major * 32 + 25]) + value.to_bytes(2, "big")


def text(s):
    b = s.encode()
    return head(3, len(b)) + b


def blob(b):
    return head(2, len(b)) + b


def public_xy(key):
    der = subprocess.run(["openssl", "ec", "-in", key, "-pubout", "-outform", "DER"],
                         check=True, capture_output=True).stdout
    return der[-64:-32], der[-32:]


def client_data(kind, challenge, origin):
    return json.dumps({"type": kind, "challenge": challenge, "origin": origin, "crossOrigin": False},
                      separators=(",", ":")).encode()


def main():
    mode, key, challenge, origin, rp = sys.argv[1:6]
    rp_hash = hashlib.sha256(rp.encode()).digest()
    if mode == "create":
        x, y = public_xy(key)
        # {1: 2, 3: -7, -1: 1, -2: x, -3: y}: kty EC2, alg ES256, crv P-256.
        cose = b"\xa5" + b"\x01\x02" + b"\x03\x26" + b"\x20\x01" + b"\x21" + blob(x) + b"\x22" + blob(y)
        data = rp_hash + bytes([0x45]) + (0).to_bytes(4, "big") + bytes(16) + len(CREDENTIAL).to_bytes(2, "big") + CREDENTIAL + cose
        attestation = b"\xa3" + text("fmt") + text("none") + text("attStmt") + b"\xa0" + text("authData") + blob(data)
        cd = client_data("webauthn.create", challenge, origin)
        print("clientData=%s&attestation=%s" % (url(cd), url(attestation)))
        return
    counter = int(sys.argv[6])
    flags = int(sys.argv[7]) if len(sys.argv) > 7 else 0x05
    data = rp_hash + bytes([flags]) + counter.to_bytes(4, "big")
    cd = client_data("webauthn.get", challenge, origin)
    signature = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key],
                               input=data + hashlib.sha256(cd).digest(), check=True, capture_output=True).stdout
    print("credential=%s&clientData=%s&authenticatorData=%s&signature=%s" % (url(CREDENTIAL), url(cd), url(data), url(signature)))


main()
