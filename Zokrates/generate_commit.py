import hashlib
import json

def to_bytes(x: int) -> bytes:
    return x.to_bytes(32, byteorder="big")

def commitment(nullifier: int, secret: int) -> bytes:
    return hashlib.sha256(to_bytes(nullifier) + to_bytes(secret)).digest()

def hash_to_u32(val: bytes) -> str:
    M0 = val.hex()[:128]
    return " ".join(str(int(M0[i:i+8], 16)) for i in range(0, len(M0), 8))

nullifier = 1234545679
secret = 987654321

comm = commitment(nullifier, secret)
print("Commitment (bytes):", comm.hex()) #hash
print("Commitment (u32 format):", hash_to_u32(comm))

commitments_list = []


new_commitment = {
    "nullifier": nullifier,
    "secret": secret,
    "commitment": comm.hex(),
    "u32": hash_to_u32(comm)
}

filename = "commitmentTest.json"

commitments_list.append(new_commitment)

with open(filename, "w") as f:
    json.dump(commitments_list, f, indent=4)
