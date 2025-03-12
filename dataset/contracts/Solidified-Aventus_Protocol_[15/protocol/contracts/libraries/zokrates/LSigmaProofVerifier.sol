pragma solidity 0.5.12;
// This file is abridged and adapted from a file by Christian Reitwiessner. Original licensing below

// This file is LGPL3 Licensed

// This file is MIT Licensed.
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

library Curves {
    struct G1Point {
        uint X;
        uint Y;
    }
    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        assembly {
            success := call(sub(gas, 2000), 6, 0, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
    }
    /// @return the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        assembly {
            success := call(sub(gas, 2000), 7, 0, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success);
    }

    // assume the coordinates have been affined
    function toBytes32(G1Point memory point) internal pure returns (bytes32) {
      return keccak256(abi.encodePacked(point.X, point.Y));
    }
}

library LSigmaProofVerifier {
  using Curves for *;

  uint constant hX = 2203960485148121921418603742825762020974279258880205651966;
  uint constant hY = 2;

  function curveOrder() internal pure returns (uint) {
    return 21888242871839275222246405745257275088548364400416034343698204186575808495617; // field modulus = curve order
  }

  function verifyCommitment(Curves.G1Point[] memory generators, Curves.G1Point memory hGenerator, Curves.G1Point[] memory publicInputs, Curves.G1Point[] memory commitments, uint[2] memory proof)
    internal
    returns (uint)
  {
      Curves.G1Point[] memory allGenerators = new Curves.G1Point[](3);
      allGenerators[0] = generators[0];
      allGenerators[1] = generators[1];
      allGenerators[2] = hGenerator;
      uint fiatShamirChallenge = createFiatShamirVerifierChallenge(curveOrder(), commitments, allGenerators, publicInputs);
      delete allGenerators;

      for (uint i = 0; i < generators.length; i++) {
        Curves.G1Point memory leftHandSide = Curves.addition(
            Curves.scalar_mul(generators[i], proof[0]),
            Curves.scalar_mul(hGenerator, proof[1]));

        Curves.G1Point memory rightHandSide = Curves.addition(Curves.scalar_mul(publicInputs[i], fiatShamirChallenge), commitments[i]);
        if (Curves.toBytes32(leftHandSide) != Curves.toBytes32(rightHandSide)) {
            return 1;
        }
      }

      return 0;
  }

  function verifyHash(Curves.G1Point[] memory generators, Curves.G1Point[] memory publicInputs, Curves.G1Point[] memory commitments, uint proof)
    internal
    returns (uint)
  {
      uint fiatShamirChallenge = createFiatShamirVerifierChallenge(curveOrder(), commitments, generators, publicInputs);
      for (uint i = 0; i < generators.length; i++) {
        Curves.G1Point memory leftHandSide = Curves.scalar_mul(generators[i], proof);
        Curves.G1Point memory rightHandSide = Curves.addition(Curves.scalar_mul(publicInputs[i], fiatShamirChallenge), commitments[i]);
        if (Curves.toBytes32(leftHandSide) != Curves.toBytes32(rightHandSide)) {
            return 1;
        }
      }

      return 0;
  }

  function encodeList(Curves.G1Point[] memory commitments, Curves.G1Point[] memory publicInputs, Curves.G1Point[] memory generators)
    internal
    pure
    returns (bytes memory)
  {

    // this is the cheapest version in gas cost. For the commitment with 3 generators, it takes 318761 gas cost. The hash cost 227115.
    bytes memory encoding = abi.encodePacked(
      commitments[0].X, commitments[0].Y, commitments[1].X, commitments[1].Y,
      publicInputs[0].X, publicInputs[0].Y, publicInputs[1].X, publicInputs[1].Y,
      generators[0].X, generators[0].Y, generators[1].X, generators[1].Y);

    // a version that only works for the hash, by removing this section, costs 227086 gas.
    if (generators.length > 2) {
      encoding = abi.encodePacked(encoding, generators[2].X, generators[2].Y);
    }

    return encoding;
  }

  function combineHashValues(uint h1, uint h2, uint fieldModulus) public pure returns (uint) {
    uint shiftMinus1 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff; // max uint - 1
    uint modShift = shiftMinus1 % fieldModulus + 1;

    uint part1;
    uint part2;

    // We use addmod and mulmod to make the full precision calculation (h1 * modShift) % r
    // If we try to do this in normal Solidity, h1 * modShift will overflow
    // and be reduced mod 2^256 before computing the remainder mod r. That gives the wrong result.
    // If we use assembly, this costs slightly less gas.
    assembly {
        part1 := mulmod(h1, modShift, fieldModulus)
        part2 := addmod(part1, h2, fieldModulus)
    }
    return part2;
  }

  // FiatShamir requires more randomness than 256 to be secure.
  // See analysis in https://crypto.stackexchange.com/questions/62329/randomizing-prime-field-elements/71980#71980
  // This function creates two hashes of 256 bits. These should then be concatenated and modded by a  prime p
  // Because the largest integers we have in Solidity are 256-bit long, this has to be done in pieces
  // The concatenation h1 || h2, where h1,h2 are 256-bit strings, can be written arithmetically as h1 * 2^256 + h2
  // Then, every one of these pieces can be reduced mod p to compute the final result
  function createFiatShamirVerifierChallenge(uint fieldModulus, Curves.G1Point[] memory commitments, Curves.G1Point[] memory generators, Curves.G1Point[] memory publicInputs)
    internal
    pure
    returns (uint)
  {
    bytes memory preImage = encodeList(commitments, publicInputs, generators);
    bytes memory preImage2 = abi.encodePacked(preImage, "Extension");

    uint hash1 = uint(keccak256(preImage));
    uint hash2 = uint(keccak256(preImage2));

    uint result = combineHashValues(hash1, hash2, fieldModulus);

    return result;
  }

  function verifyHashTx(
      uint[2] memory generators1,
      uint[2] memory generators2,
      uint[2] memory publicInput1,
      uint[2] memory publicInput2,
      uint[2] memory commitment1,
      uint[2] memory commitment2,
      uint proof
  ) public returns (bool r) {
      Curves.G1Point[] memory generators = new Curves.G1Point[](2);
      Curves.G1Point[] memory publicInputs = new Curves.G1Point[](2);
      Curves.G1Point[] memory commitments = new Curves.G1Point[](2);

      generators[0] = Curves.G1Point(generators1[0], generators1[1]);
      generators[1] = Curves.G1Point(generators2[0], generators2[1]);

      publicInputs[0] = Curves.G1Point(publicInput1[0], publicInput1[1]);
      publicInputs[1] = Curves.G1Point(publicInput2[0], publicInput2[1]);

      commitments[0] = Curves.G1Point(commitment1[0], commitment1[1]);
      commitments[1] = Curves.G1Point(commitment2[0], commitment2[1]);

      if (verifyHash(generators, publicInputs, commitments, proof) == 0) {
          return true;
      } else {
          return false;
      }
  }

  function hashHexStringToEC(uint fieldModulus, bytes memory hexString) internal returns (Curves.G1Point memory point) {
    bytes memory prefix1 = "hashToEC-left";
    bytes memory prefix2 = "hashToEC-right";

    bytes memory preImage1 = abi.encodePacked(prefix1, hexString);
    bytes memory preImage2 = abi.encodePacked(prefix2, hexString);

    uint fieldElement1 = doubleKeccak256(fieldModulus, preImage1);
    uint fieldElement2 = doubleKeccak256(fieldModulus, preImage2);

    Curves.G1Point memory pt1 = encodingFT12(fieldModulus, fieldElement1);
    Curves.G1Point memory pt2 = encodingFT12(fieldModulus, fieldElement2);

    point = Curves.addition(pt1, pt2);
  }

  function doubleKeccak256(uint fieldModulus, bytes memory preImage1) internal pure returns (uint result) {
    bytes memory preImage2 = abi.encodePacked(preImage1, "Extension");

    uint hash1 = uint(keccak256(preImage1));
    uint hash2 = uint(keccak256(preImage2));

    result = combineHashValues(hash1, hash2, fieldModulus);
  }

  function encodingFT12_x1(uint sqrtMinusThree, uint t, uint w, uint fieldModulus) internal returns (uint) {
    //(-1 + sqrtMinusThree) / 2 - t*w
    uint x1_1 = mulmod((sqrtMinusThree - 1), inverse(2, fieldModulus), fieldModulus);
    uint x1_2 = mulmod(fieldModulus - t, w, fieldModulus);
    uint x1 = addmod(x1_1, x1_2, fieldModulus);
    return x1;
  }

  function encodingFT12_alpha(uint x1, uint b, uint fieldModulus) internal returns (int) {
    uint x1_cubed = cube(x1, fieldModulus);
    return quadraticResidue(addmod(x1_cubed, b, fieldModulus), fieldModulus);
  }

  function encodingFT12_beta(uint x2, uint b, uint fieldModulus) internal returns (int) {
    uint x2_cubed = cube(x2, fieldModulus);
    return quadraticResidue(addmod(x2_cubed, b, fieldModulus), fieldModulus);
  }

  function encodingFT12_getX(uint x1, uint x2, uint x3, uint b, uint fieldModulus) internal returns (uint x) {
    int alpha = encodingFT12_alpha(x1, b, fieldModulus);
    int beta = encodingFT12_beta(x2, b, fieldModulus);
    uint i = uint((3 + (alpha - 1) * beta) % 3);

    if (i == 0) {
      x = x1;
    } else if (i == 1) {
      x = x2;
    } else {
      x = x3;
    }
  }

  function encodingFT12_yCoord(uint[4] memory data) internal returns (uint) {
    (uint x, uint t, uint b, uint fieldModulus) = (data[0], data[1], data[2], data[3]);
    uint rootX3 = squareRoot(addmod(cube(x, fieldModulus), b, fieldModulus), fieldModulus);

    int QR = quadraticResidue(t, fieldModulus);
    if (QR == 1) {
      return rootX3;
    } else {
      return mulmod(fieldModulus - 1, rootX3, fieldModulus);
    }
  }

  function encodingFT12_getW(uint sqrtMinusThree, uint b, uint t, uint fieldModulus) internal returns (uint w) {

      //1 + b + t^2
    uint denominator = addmod(b + 1, square(t, fieldModulus), fieldModulus);
    uint divisionValue = mulmod(t, inverse(denominator, fieldModulus), fieldModulus);
    w = mulmod(sqrtMinusThree, divisionValue, fieldModulus);
  }

  // This function is broken down into several steps due to Stack Too Deep errors
  function encodingFT12(uint fieldModulus, uint t) internal returns (Curves.G1Point memory point) {
    uint  b = 3;
    uint sqrtMinusThree = squareRoot(fieldModulus - 3, fieldModulus);
    uint w = encodingFT12_getW(sqrtMinusThree, b, t, fieldModulus);

    uint x1 = encodingFT12_x1(sqrtMinusThree, t, w, fieldModulus);

    // -x1 - 1
    uint x2 = addmod(fieldModulus - 1, fieldModulus - x1, fieldModulus);

    //1 + 1/w^2
    uint x3 = addmod(1, inverse(square(w, fieldModulus), fieldModulus), fieldModulus);

    uint x = encodingFT12_getX(x1, x2, x3, b, fieldModulus);

    uint y = encodingFT12_yCoord([x, t, b, fieldModulus]);
    point = Curves.G1Point(x, y);
  }

  function quadraticResidue(uint fieldElement, uint fieldModulus) internal returns (int) {
    uint QR = expmod(fieldElement, (fieldModulus - 1) / 2, fieldModulus);

    if (QR == 1) {
      return 1;
    }

    if (QR == fieldModulus - 1) {
      return -1;
    }
    revert(string(abi.encodePacked("quadraticResidue returned an unexpected value: ", QR)));
  }

  function squareRoot(uint fieldElement, uint fieldModulus) internal returns (uint result) {
    result = expmod(fieldElement, (fieldModulus + 1) / 4, fieldModulus);
  }

  function square(uint fieldElement, uint fieldModulus) internal pure returns (uint result) {
    result = mulmod(fieldElement, fieldElement, fieldModulus);
  }

  function cube(uint fieldElement, uint fieldModulus) internal pure returns (uint result) {
    result = mulmod(square(fieldElement, fieldModulus), fieldElement, fieldModulus);
  }

  function inverse(uint fieldElement, uint fieldModulus) internal returns (uint result) {
    result = expmod(fieldElement, fieldModulus - 2, fieldModulus);
  }

  // this case is fundamentally different from the addition and scalar_mul calls to precompiled contracts
  // In those methods, the output variable is a memory pointer, but here it is static
  // Using the same approach as in those methods makes it that we don't get a result, but rather just 0
  // This seems like safer code
  function expmod(uint base, uint exponent, uint fieldModulus) internal returns (uint result) {
    uint[6] memory input;
    input[0] = 0x20; // Length of base in bytes
    input[1] = 0x20; // Length of exponent in bytes
    input[2] = 0x20; // Length of modulus in bytes
    input[3] = base;
    input[4] = exponent;
    input[5] = fieldModulus;

    bool success;
    assembly {
      // Store the result
      let value := 0 // declare and initialize an output variabel for the precompiled contract

      // Call the precompiled contract 0x05 = bigModExp
      success := call(sub(gas, 2000), 5, 0, input, 0xc0, value, 0x20)
      switch success case 0 { invalid() }

      result := mload(value)
    }
    require(success);
  }

  function verifyCommitmentTx(
      bytes memory address1, // public input: vendor's Eth address
      bytes memory address2, // public input: owner's Eth address
      uint[2] memory publicInput1, // vendor's obfuscation of door data
      uint[2] memory publicInput2, // owner's obfuscation of door data
      uint[2] memory commitment1, // first stage of Sigma proof (1)
      uint[2] memory commitment2, // first stage of Sigma proof (2)
      uint[2] memory proof // last stage of Sigma proof
    ) public returns (bool) {

      // create generators
      uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583; // field modulus
      Curves.G1Point memory point1 = hashHexStringToEC(q, address1);
      Curves.G1Point memory point2 = hashHexStringToEC(q, address2);
      uint[2] memory generatorPoint1;
      uint[2] memory generatorPoint2;

      generatorPoint1[0] = point1.X;
      generatorPoint1[1] = point1.Y;
      generatorPoint2[0] = point2.X;
      generatorPoint2[1] = point2.Y;


      return verifySigmaProof(generatorPoint1, generatorPoint2, publicInput1, publicInput2, commitment1, commitment2, proof);
    }

  function verifySigmaProof(
      uint[2] memory generatorPoint1,
      uint[2] memory generatorPoint2,
      uint[2] memory publicInput1,
      uint[2] memory publicInput2,
      uint[2] memory commitment1,
      uint[2] memory commitment2,
      uint[2] memory proof
  ) internal returns (bool) {
      require (proof[0] < curveOrder());
      require (proof[1] < curveOrder());

      Curves.G1Point[] memory generators = new Curves.G1Point[](2);
      Curves.G1Point[] memory publicInputs = new Curves.G1Point[](2);
      Curves.G1Point[] memory commitments = new Curves.G1Point[](2);
      Curves.G1Point memory hGenerator = Curves.G1Point(hX, hY);

      generators[0] = Curves.G1Point(generatorPoint1[0], generatorPoint1[1]);
      generators[1] = Curves.G1Point(generatorPoint2[0], generatorPoint2[1]);

      publicInputs[0] = Curves.G1Point(publicInput1[0], publicInput1[1]);
      publicInputs[1] = Curves.G1Point(publicInput2[0], publicInput2[1]);

      commitments[0] = Curves.G1Point(commitment1[0], commitment1[1]);
      commitments[1] = Curves.G1Point(commitment2[0], commitment2[1]);

      if (verifyCommitment(generators, hGenerator, publicInputs, commitments, proof) == 0) {
          return true;
      } else {
          return false;
      }
  }
}