// This file is MIT Licensed.
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
pragma solidity ^0.8.0;
import "../../utils/PairingAndProof.sol";

contract SybilGovIDVerifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alpha;
        Pairing.G2Point beta;
        Pairing.G2Point gamma;
        Pairing.G2Point delta;
        Pairing.G1Point[] gamma_abc;
    }
    function verifyingKey() pure internal returns (VerifyingKey memory vk) {
        vk.alpha = Pairing.G1Point(uint256(0x07cf3ea35ce89bd47ae7884ed63e681cdd2bcc9b1522c8513995b2efe1424bbc), uint256(0x0175240658c74aefc5d7e5f9298254ac527b06a541c5745375d8be7f6618f80a));
        vk.beta = Pairing.G2Point([uint256(0x05b2d5f21d70e3e463cf78c09b6791c65b5a4e220a8e9f598a1eb07db21455fa), uint256(0x2f9e034fc8cd01282b990581a71b3c539a9e8b7670c9c4a7def9ed865c3254be)], [uint256(0x0049736bfe2b83a68f14c7ac8df40ed448eb85344f2116539497062b9628a014), uint256(0x1e49966ae8c5ad615d4f804a1a0733a0f9e0ec802e1102297d1aa89e545cc8b5)]);
        vk.gamma = Pairing.G2Point([uint256(0x09b8b9280d1a535c41cd655d52beb176de2c75c7eaa27f683edc5c3b23fd4d23), uint256(0x2483cc62f2f655231a041c2efe3c0acf8ec228c662367e7643dde9486566083e)], [uint256(0x2acd04fbd40b56b330ae9b7fae61de45078063eef9dc2efa85ac07670c9a8710), uint256(0x289242c611532eb565c01dda2af7fdace4e181b429b1c522f09e2c45a41ec986)]);
        vk.delta = Pairing.G2Point([uint256(0x1fb55ccd4e42f62ea22ec3f2343c6963503de5d52a5886e2de5600bdd6045edf), uint256(0x1a62735f741101477afc183dd602246d45a685556369fa8a3b59e23b3d6bb9b3)], [uint256(0x2d72c8f7af207f2456102b5714d78986ed97f6a1859ff03b808cd1bbafa0ff7d), uint256(0x1a4dacd7a48f92c49b9a0c1e764a70b254ce3f61b2fa138e095237293ce7c3b5)]);
        vk.gamma_abc = new Pairing.G1Point[](6);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x2fbf2edc978f739425e24af07b701b0252aa5ed5fe6d0c1fa93f4e4e762b2043), uint256(0x234cf92ca5acb62d3ca271ef6aa2ca4bb011886016a4fbb38bd78bfd3a3b05ee));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x1cdeace3919620bbdf2c821ff7a5067d36ec9b3e3b291c5871447e675f72dd88), uint256(0x255816c023276c902fb1b59789fc4ff19b23cf0e63cdc34fbd9202e5947a5020));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x18e3ec6edb610ebaaec15f751bf8173d6336d2c5b09b288b9c8a9d4787983935), uint256(0x272e548acd302e7fbda87612c1d68d737f1d816586e2a236b71e80cdd4cc3e07));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x2998028f89a5496e4adb5332b22a054b9c843c4f54dcdca0951444157f0c8db0), uint256(0x11faaa550f3ab63790adb6594e6bd9017e8253e416a4380ab7b8565acfcb82db));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x09a638226cfc46ac9661a3b62870302d3ff62a958ae2b5d141cba275a59932f3), uint256(0x0d46745c05f8ece61658144223e895c54f087cad3923b5e7e3cf44353ab35046));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x26b78e89f8c6fad685ff502edc6d501adf0fff4ca04439412ca7c40a71543df8), uint256(0x0eca22c5c5523eb363bb9df6a48421816aec29029d3d88ce2f4eeb595bf58870));
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
            Proof memory proof, uint[5] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](5);
        
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
    //     uint[5] memory input;
    //     for (uint i = 0; i < 5; i++) {
    //         input[i] = input_[i];
    //     }
    //     return verifyTx(proof, input);
    // }
}
