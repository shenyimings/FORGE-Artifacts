// This file is MIT Licensed.
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
pragma solidity ^0.8.0;
import "../../utils/PairingAndProof.sol";

contract ProofOfCountry {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alpha;
        Pairing.G2Point beta;
        Pairing.G2Point gamma;
        Pairing.G2Point delta;
        Pairing.G1Point[] gamma_abc;
    }

    function verifyingKey() pure internal returns (VerifyingKey memory vk) {
        vk.alpha = Pairing.G1Point(uint256(0x1dcfbcc68c706725d95cae80087f4f803f7c628fd2ebed0c8d8f1c08efb000a2), uint256(0x1db5c895af5af97da17f06a993745f82dc6c3f43b862de01bb499821a2f07f7f));
        vk.beta = Pairing.G2Point([uint256(0x14595f61ba4aede46e251c87d00e8f5ddd659e3a94f14212cabd8642e28f03b7), uint256(0x2ad520f86f05f729da4c87a6732a2b73b5594f54a3433ddbf9329a859717e893)], [uint256(0x12966aef85fa2cb49ba6c72aaf3b519a909369085de41a7a10db36f6aee9a333), uint256(0x2b2aa977f11a4b1d2fa1b43487a3b348fb78658b4948628ae8a0c77a27309607)]);
        vk.gamma = Pairing.G2Point([uint256(0x0e646c79b92eb81e771a8beedcf750922d68c4cae6e674f28386f05db695f087), uint256(0x2f32db257bd38e510b2c46905bf42ee017eb8dd3736ecf94a63ee388e9dcf7c6)], [uint256(0x2bced1358c17d910723e709aefed3c3b9c127401fbb5b8196023af37eb6924a6), uint256(0x200c899f19599e02ee93c8287a7120147c6f8e001e9c7f7e5c643fce1a2aa94a)]);
        vk.delta = Pairing.G2Point([uint256(0x1116bc1932e65897160357ba10be9222ec1e34adffa8b8c9182b60cac7752446), uint256(0x207f45a790597c02fd21413d5d9ed6bd4b633c18ead06295fe9a8b93562380d2)], [uint256(0x05de54e825005fa8bf89ded4db3448d013c2faa95f3e14e4f502ebb076b6ec42), uint256(0x04a769b3533c1f4394d7523639a81fb549d0f086313f93b605ada17b0d7aeaf5)]);
        vk.gamma_abc = new Pairing.G1Point[](7);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x0a0b29d53e75e2681c6cf103f088f351971c06a78c1af4c2c3fad558bd480aba), uint256(0x014db04b3e5fbbd59699890460efd29b5df2491dcade336ed9e58f1920c9b091));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x0ab0d26e0b44acc3f6166a737f25c6b594f8ee0550b0b774a5fc1a9b1c90c2e5), uint256(0x2be4d4802073c03ab7a5160c0f1bfef2f1c8fb0ecfb61c2a2ddfa0f1d64b98f2));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x08539b6e4fa48392fa14e89394f52ff8ca375c23103bfc6f78af24152666cc57), uint256(0x16099e7289a9f2539a9d5abe3665ffaf7236de57ccb24cdff3e4cb8047709198));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x21e5733b57484e09646f512c1c0d95c6670d6701c7540b9487f4f08723c19bb8), uint256(0x11fb6e9d01ab0f58928f40f21da7beee62943aa3c2c5490100ffb6a09d8ce2e5));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x1ea9366f1bee313ec9786dc19facf5dccf3e47e23d9477e274b377e4272bceda), uint256(0x13b1db8802d9fc947ad2ab6ffce35e3e9b147ce6a79760886cefb4e9e4b0212e));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x186067a849502f2e7ce583156758d2aa6d10b98638374d897bd0ab1438f3e45d), uint256(0x2b777f559e2f11fe20903a6b6fe5808a73c93e278effadaad217701caae97063));
        vk.gamma_abc[6] = Pairing.G1Point(uint256(0x151caaf5340893a1c7e92b6fcaa315046b38a29e5904b7f31088994a6554cf47), uint256(0x04ccd8e7e9a8637873c3fc75ae69afa761886cec6e78675f391ed008c20a0083));
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
    // function verifyEncoded(Proof calldata proof, uint[] calldata input_) public view returns (bool r) {
    //     // (Proof memory proof, uint[25] memory input) = abi.decode(b, (Proof, uint[25]));
    //     uint[6] memory input;
    //     for (uint i = 0; i < 6; i++) {
    //         input[i] = input_[i];
    //     }
    //     return verifyTx(proof, input);
    // }
}
