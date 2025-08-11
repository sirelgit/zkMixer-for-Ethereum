// SPDX-License-Identifier: MIT
// This file is MIT Licensed.
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
pragma solidity ^0.8.0;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() pure internal returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() pure internal returns (G2Point memory) {
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
    }
    /// @return the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) pure internal returns (G1Point memory) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
    }


    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success);
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length);
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[1];
            input[i * 6 + 3] = p2[i].X[0];
            input[i * 6 + 4] = p2[i].Y[1];
            input[i * 6 + 5] = p2[i].Y[0];
        }
        uint[1] memory out;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}

contract Verifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alpha;
        Pairing.G2Point beta;
        Pairing.G2Point gamma;
        Pairing.G2Point delta;
        Pairing.G1Point[] gamma_abc;
    }
    struct Proof {
        Pairing.G1Point a;
        Pairing.G2Point b;
        Pairing.G1Point c;
    }
    function verifyingKey() pure internal returns (VerifyingKey memory vk) {
        vk.alpha = Pairing.G1Point(uint256(0x04f0d24fa60b10dfa3308c5ac7bc2ec7515f3bafbd39e10b6fc5712f7063adef), uint256(0x1b85a16c8e82c8dbb27c2f36c8ec5aafc1c3124876ef3dd16c1df421d8a45934));
        vk.beta = Pairing.G2Point([uint256(0x1e84b78f11961de1a238f16a1a4aaf3816a40681260dcfc6d55f103c57c3c566), uint256(0x12521ba8c47e2862bd0f3a533da787254303f51949e8466559b922ad1fd7aa4f)], [uint256(0x1374d418b1df6de6746ab2719392376c69bdeca220c2443a19db2f430618212e), uint256(0x27b33fc4d9b4522d924276d42463ea8848e20e530f4eab1b43a84efc00763a3e)]);
        vk.gamma = Pairing.G2Point([uint256(0x0a218c34c9159ad5896ecec3f00b1abfc7b35bee515b54e2e6b616661d21c8db), uint256(0x0e332e62e0618fde0aff66b11967d7c63d34a65afaea333f9d412bbda4e4fe47)], [uint256(0x2ac42cb7baadb14115907f89c46654dce18ab84fb520b9072936f6fb7006ae37), uint256(0x1b146754ef766f48372214c2d9f0b38c8226ec5768385342bcfd5c3dfbdfbc34)]);
        vk.delta = Pairing.G2Point([uint256(0x1270ea6a89b1e8b29a70e10683185f53c557902a02e7e860ec96077a8911282f), uint256(0x078bf2f66b2848d8a67b64e1492697a28c250e8e49b845f391fab97b54a820e5)], [uint256(0x08a655a2b7378b9c1e0f9b4525df0d6dae00459f4e5b121713a05130ee10760c), uint256(0x157b0c838f7765dccd821dd7bc93e5e6c54c5b9564a0e174a64d878d6aeb99db)]);
        vk.gamma_abc = new Pairing.G1Point[](17);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x2b27017ae9fcfb70c780eba12257b2974f2b5f575d59d7fe56cbbfdee6b1cbc0), uint256(0x1471f5a1126f4c00dbce4026f89b8dec43912252db22f5a506cb4a8f5bc21acd));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x256af05cbac3eeeb0826b012fdb32f850fe4cc7fedf966c341faff6ae75600e9), uint256(0x2d2f4594e84c4b6a75aa440acb2f0dd53e5d49edde8c849eb8f113cbcb0c68fe));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x1f0b7b08587c9c39c3f2c5653d3e2c18bb5743b7309dcf150dfa2c574db9abeb), uint256(0x14448d826835d76786e167fb5bac18cbb80974206f8b87cef760ed28f40f446b));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x0d9e1fa44dee0a827694b74139a88852c2ffb777f9d729e4ce34c3110e2f7375), uint256(0x06fb6b74a0890a86ece39ae0df7b8c4d667b28942056083db10da40f6244f635));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x06ed6c931912d502228c69de2a5eddf772bbcbf567cd4cd60e3f81e4bafadd45), uint256(0x18e6f505ff5645bf99f2388db18851bb110dee7a38728a126626f1c3d92c1895));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x14f3ba925efcd12ca3a6fd3635631153fb64d5db9ad358d60292c625ed753884), uint256(0x016f3cf14cf5c1452dade2153fcfa0ef4ccf88549a929ab27dc4501e4fe98068));
        vk.gamma_abc[6] = Pairing.G1Point(uint256(0x00d15c63797e33939992a93d3c7e9892be0ac2e14ca5f1bf0000a863746f5364), uint256(0x10b1533d9fe3c96a2118c489d12f87cfd4d6592f58099743421f4221cf755dd8));
        vk.gamma_abc[7] = Pairing.G1Point(uint256(0x051a7227619cf58bc999b1b3b4ea04a8f999f85bf1228411d26cc592fb2ed7bd), uint256(0x19bbd90bdc5121b833dc10c2acc38fccfccce926232da495ec5355d783616de1));
        vk.gamma_abc[8] = Pairing.G1Point(uint256(0x1aa4b0eb83cfd73eeb697abd0a05b91cc7e2ce10faaf1baf88c7cb68f45d772a), uint256(0x2a51aa4752f0e372871c720ceea3769a781485f814f0f45b569a698347004883));
        vk.gamma_abc[9] = Pairing.G1Point(uint256(0x040b9301973f326ae96d6bf8d4ae4ca151df5d037464142d259e438921d377e9), uint256(0x1d81552b410fe1e10f658883e1ceff0da7ae61026cc59ed6e88691058d5a057e));
        vk.gamma_abc[10] = Pairing.G1Point(uint256(0x079576ad8cd474115127e690a6a794a9d5f86f805af1ae9575b89f84d71bba10), uint256(0x222f09520c46d0f2239043c1db804b2ab1a9ecd9ba0a43f055ee60d9603e2180));
        vk.gamma_abc[11] = Pairing.G1Point(uint256(0x2f254a17fe4f4de56bff44a8f8082584c39472633982df38486b8983bb57ce85), uint256(0x0ec67bd957880e4dfd7aec73033442127021300dd399eced616eee967a4a2bc4));
        vk.gamma_abc[12] = Pairing.G1Point(uint256(0x01ef6a604b0fb9e5b9181444a4551d3a3e6f55ac5b2f262a1d3bb378c23317f7), uint256(0x088940ca4716a278e9e5c6f608965a17593b8b6568ec3ff39956f8e54cc9d3ef));
        vk.gamma_abc[13] = Pairing.G1Point(uint256(0x2b914fe5884104a4d95e8b84373d02c7bffc3b10692df180a69965c3d95c4df0), uint256(0x02810ada081e7709cb92e9c599022c3bd55cd36d1ebaf6bf742ca3392ad52fe7));
        vk.gamma_abc[14] = Pairing.G1Point(uint256(0x1d9c40682ba8264e3e0c246e95f1c61212675bab997a619e725678f19152673e), uint256(0x17f55488c7134de76e6f4824cff45a75e363f446a0530c0ee4333a70794d4f45));
        vk.gamma_abc[15] = Pairing.G1Point(uint256(0x00f18fc2f73d9f3813f652cb2a5e95d8dcdbde608b4fbc03a0fabdaf71adc6e5), uint256(0x131fed44e1f74dd5799b4cc3dde6efc0f76bb8ed58feddacd5ca8030f959fd25));
        vk.gamma_abc[16] = Pairing.G1Point(uint256(0x12ae27ef00fc7706651389629e5b0b640bf71270f91c7fc29fa1bbd1bb86caed), uint256(0x030c23a5fa748a33646849da8ea290548740e5bf15fb0f764e809e43b1323e20));
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.gamma_abc.length);
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field);
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.gamma_abc[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.gamma_abc[0]);
        if(!Pairing.pairingProd4(
             proof.a, proof.b,
             Pairing.negate(vk_x), vk.gamma,
             Pairing.negate(proof.c), vk.delta,
             Pairing.negate(vk.alpha), vk.beta)) return 1;
        return 0;
    }
    function verifyTx(
            Proof memory proof, uint[16] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](16);
        
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
