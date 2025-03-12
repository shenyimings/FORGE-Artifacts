// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IHashNFT.sol";

contract MockHashNFT is IHashNFT {

    function dispatcher() external override view returns (address) {
        return address(this);
    }

    function sold() external pure override returns (uint256) {
        return 500000;
    }
}