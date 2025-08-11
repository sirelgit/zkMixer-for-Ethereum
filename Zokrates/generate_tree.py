import hashlib
import random
import json
import os

def sha256(x: bytes) -> bytes:
    return hashlib.sha256(x).digest()

def to_bytes(x: int) -> bytes:
    return x.to_bytes(32, "big")

def hash_to_u32(val: bytes) -> list[str]:
    h = val.hex()[:128]
    return [str(int(h[i:i+8], 16)) for i in range(0, len(h), 8)]


def nullifier_hash(nullifier: int) -> bytes:
    return sha256(to_bytes(nullifier) + b"\x00" * 32)

class MerkleTree:
    def __init__(self, depth=3):
        self.depth = depth
        self.max_leaves = 2 ** depth
        self.leaves = []

    def add_leaf(self, leaf: bytes):
        assert len(self.leaves) < self.max_leaves, "Tree full"
        self.leaves.append(leaf)

    def build_tree(self):
        levels = [self.leaves[:]]
        while len(levels[-1]) > 1:
            curr = levels[-1]
            next_level = []
            for i in range(0, len(curr), 2):
                left = curr[i]
                right = curr[i+1] if i+1 < len(curr) else curr[i]
                next_level.append(sha256(left + right))
            levels.append(next_level)
        return levels

    def get_root(self) -> bytes:
        tree = self.build_tree()
        return tree[-1][0] if tree else b"\x00" * 32

    def get_proof(self, index: int):
        tree = self.build_tree()
        path = []
        directions = []
        for level in tree[:-1]:
            sibling_index = index ^ 1
            sibling = level[sibling_index] if sibling_index < len(level) else level[index]
            path.append(sibling)
            directions.append(bool(index % 2))
            index //= 2
        return path, directions


def commitment(nullifier: int, secret: int) -> bytes:
    return sha256(to_bytes(nullifier) + to_bytes(secret))

if __name__ == "__main__":
    #nullifier = random.randint(1, 2**250)
    #secret = random.randint(1, 2**250)
    #comm = commitment(nullifier, secret)


    with open("commitmentTest.json", "r") as f:
        data = json.load(f)
        nullifier = data[0]["nullifier"]
        secret = data[0]["secret"]
        comm = bytes.fromhex(data[0]["commitment"])
        u32=data[0]["u32"]
        

    tree = MerkleTree(depth=3)

    tree.add_leaf(comm)  # leaf 0 = commitment
    for _ in range(7):  # dummy
        tree.add_leaf(sha256(random.randbytes(64)))

    root = tree.get_root()
    path, dirs = tree.get_proof(0)

    nullifier_h = nullifier_hash(nullifier)

    print(" ".join(hash_to_u32(root))) #pub
    
    print(" ".join(hash_to_u32(nullifier_h))) #pub

    print(" ".join(hash_to_u32(to_bytes(nullifier))))

    print(" ".join(hash_to_u32(to_bytes(secret))))

    print(" ".join(hash_to_u32(comm)))

    print(" ".join(["1" if d else "0" for d in dirs]))

    for p in path:
        print(" ".join(hash_to_u32(p)))

new_commitment = {
    "nullifier": nullifier,
    "secret": secret,
    "commitment": comm.hex(),
    "u32": hash_to_u32(comm),
    "rootHash": root.hex()
}

filename = "commitmentHistory.json"

if os.path.exists(filename):
    with open(filename, "r") as f:
        try:
            commitments_list = json.load(f)
        except json.JSONDecodeError:
            commitments_list = []
else:
    commitments_list = []

if new_commitment not in commitments_list:
    commitments_list.append(new_commitment)

with open(filename, "w") as f:
    json.dump(commitments_list, f, indent=4)
