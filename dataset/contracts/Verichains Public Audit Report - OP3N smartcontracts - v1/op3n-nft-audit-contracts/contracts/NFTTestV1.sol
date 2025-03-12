//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "./NFTPackage.sol";

contract NFTTestV1 is NFTPackage {
    function _baseURI() internal view virtual override returns (string memory) {
        return "https://boredapeyachtclub.com/api/mutants/";
    }

    function version() public pure virtual returns (string memory) {
        return "v1";
    }
}
