// This file is MIT Licensed.
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
pragma solidity ^0.8.0;
import "../../utils/PairingAndProof.sol";

contract SybilPhoneVerifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alpha;
        Pairing.G2Point beta;
        Pairing.G2Point gamma;
        Pairing.G2Point delta;
        Pairing.G1Point[] gamma_abc;
    }
    function verifyingKey() pure internal returns (VerifyingKey memory vk) {
        vk.alpha = Pairing.G1Point(uint256(0x23132bf6861e913de025a9e802bf928d06a10210dd607b308311dee176da1557), uint256(0x1005b20be8518d03236d9e31e98c62cd42f029293187ec91669fd5566edda332));
        vk.beta = Pairing.G2Point([uint256(0x1d902265da73829f3fcaca13a0005fad0a57ef29de813b63614c464179af7baf), uint256(0x21f5bf89534e5dece36e982a080ddec97f890dc6b7266f53103787ebf6b80ed9)], [uint256(0x0400f8f69c1ff2e4de45b40051ee37b0c8378eedeeede2328e1b3ccf964ad02f), uint256(0x1da67b1ced07189c66ed794d1ccca073f77489381320652de01ae2bbf7513414)]);
        vk.gamma = Pairing.G2Point([uint256(0x10074f085aaf15336e0485d1200f77efa6961d7841c96a78548bb99875f9acfb), uint256(0x0e5f63a506cbfd9cceb1b9c5c7076e38ce67a44c22a22a38eb2e5ba28d29227a)], [uint256(0x200f34273a63ee976c8482f038cefabcd4393361bddc1ebfefad9ca836a152d0), uint256(0x22147891bfdc30967b20263f4c041d97a4a41cf2f7a613d0d58b82ab1b9cba37)]);
        vk.delta = Pairing.G2Point([uint256(0x14667d77eb04dc1cab5964daee7f4e339ee97453bfb47ae0169641481eaaaf4f), uint256(0x0e3f4cc26eb6862218634cc1af9811b3bd1afdd4fddd63164a7f150ea16846e4)], [uint256(0x0e88177b14ae1daad4fb99884b311537a6b97ba56e890fc831ef7642bb2c9e84), uint256(0x1e360036fcd20171bee89640078f8c0fbdbee292659ffd37684ff6ca4df98241)]);
        vk.gamma_abc = new Pairing.G1Point[](6);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x0d7a890d9e0b064fd5d1792809b815059f838411ae272b8222f8d13cca6976ff), uint256(0x276a8b66ba880df693144b6009642580bbd03ce7f85fc7c1924c79c41c7acf2b));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x056c2a53dedc7e25d411ea907f58b4401b38bd31f96ea056a3df8434502ba34a), uint256(0x22ea4453748c30e727b2903bb25b41cf0f93594383e6a6f4fc7df89a5826b6e0));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x09c1e96a2bafcfdb4ad27a980b3e8ba153afe13af73f03813ebeb8fe2671fbda), uint256(0x015f604910de8ffe0cae3722c1233269a7a86dcdaae78ddfc14d09f52c0d7cff));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x06536a384e2ca196f159b87209a79d98bf20ef80f55c0208efa2a3f178e89ca3), uint256(0x1868b0fa058f733664346efdf115c6ec1b8fcd2d06ce2a786ddf7ddf75de069b));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x2d536326445a1d29cd548c415e3d43f9c36935a20b6ded8b4869aeb13a57e3da), uint256(0x15ea7024462cd6121752035f05032bbcec9c0dd2701bcfa5d5d5eea61895e869));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x1e189d00ca9ba7f56154f183b3e788b386f7206d0bb58267bb2724fa156d44fa), uint256(0x0f2ef392435a97d43648424b4a3e088fea6ca8972b26f6776895e810ccd1f57f));
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
}
