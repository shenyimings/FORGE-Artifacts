// This file is MIT Licensed.
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
pragma solidity ^0.8.0;
import "../../utils/PairingAndProof.sol";

contract MedicalSpecialtyVerifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alpha;
        Pairing.G2Point beta;
        Pairing.G2Point gamma;
        Pairing.G2Point delta;
        Pairing.G1Point[] gamma_abc;
    }
    function verifyingKey() pure internal returns (VerifyingKey memory vk) {
        vk.alpha = Pairing.G1Point(uint256(0x2564a43c5cadb2a8c83f338766d6040ec6e5189d5e8b56124ec8046709fde14a), uint256(0x29c474f6ef150271b65ace54c9ca62d03144ab0cde999f45f4e46c2581be249a));
        vk.beta = Pairing.G2Point([uint256(0x124e2d02f184a3caddaf4efc066eae6670737ca07533072116706e2278f3383d), uint256(0x1c8448c19aadf4fe386e1c2af9aebbfaef31a39a701c9cd5e1a059de10d41a40)], [uint256(0x09dd50f793b3a977fed521f7210176f06b96ed657ae6b584cb950333d88578d5), uint256(0x0783a528eb1502d65e57adc3c4a177f3c51929197d2aa1506c86a93334608736)]);
        vk.gamma = Pairing.G2Point([uint256(0x1b42f1f7fd8bafc0a8e2055d82146263065c220cd6cc2d955cd00a0b832c0d2b), uint256(0x2d935af658d10387ead39ddcb0a42daf2e6d71a38449927c79ceda0b1f2ab4fb)], [uint256(0x14bc5cb184ee03373a718de62699fef8389fdd042931327cbb8df0b2f2659b0f), uint256(0x300f2f2de8fb6809294908b5a6e50bba6328e7e3d175fcae562f6ab4ec1fc709)]);
        vk.delta = Pairing.G2Point([uint256(0x1c84721319b1aec3f53b0d0240490e0ca2e336789aa6b8472fba9f0ef3f6ddf1), uint256(0x1ef12fab062ad43f02d7aba0938badd6b83fe693b64d37e34643d4ef5d695d59)], [uint256(0x255293647fe0bd11577a95ea1aa7abc13290cb1fb3cce8e45b9df44ddd2efa0d), uint256(0x0363726d50eff8b6df3e3a60d2a7993fc9749450190c99657848d402624c6fac)]);
        vk.gamma_abc = new Pairing.G1Point[](7);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x271472492d4e9d4699b375aa435527b2132d0baa25bfee23357037c9efabec92), uint256(0x117f835f75716fe5b8d85f0e9af7c16704d95e08af6c4ff967ac4d35c200a965));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x1ecf3fbde5368a1b381a37be584782c8ce0aebc32cbbb99394fe19d40c906232), uint256(0x2038a97f3e3e680a3d95aff757688cee4e4a3af6fcdbc8be19007dd800c74b60));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x257d7f21d41ecd5ffdc7525118648ab43bd0450a40fd6964294f9e0f1aa3562b), uint256(0x19c8e8dc90de1e8cac5fff2a0fb0df4a571230561700582597606ed263a6d519));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x02f9c3e1bb80c3d04e929ea09199d1fe08fb6ce91d180708a837ca45d3930d62), uint256(0x06e351ff62bf4a7f3e3910c4fbbf4d4372a5530eee61e98835636c84dd02c89c));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x2a5f02b4cb15302b0a161d87cbb9355867c7369d02daeac8f5fe00b60832c613), uint256(0x08ed7ac93ff484edc408377250da56f688e760fa3dbcb165a15960b4883aac97));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x21d4b5e758adaa20d4f02fbeddc950c861003e541f183cbc7027f17dd6e6fc94), uint256(0x2d72e4296b1904069d5a107a150adbc8063d1705fab34fe16bd8eb6256c21cd0));
        vk.gamma_abc[6] = Pairing.G1Point(uint256(0x2d4b1079e1b57f83a3dd25587b5a507397f76f5912614461398406ace18469a7), uint256(0x0a2cbec22b5568e0be6e7481355c0c5e5c0e660e7d2ee53e7fe2250ef18aced6));
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
            Proof memory proof, uint[6] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](6);
        
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
