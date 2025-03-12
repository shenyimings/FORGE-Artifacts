// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BondedToken.sol";

contract BondedPION is BondedToken {
    function initialize(address _Token, address _treasury) public initializer {
        BondedToken._initialize(_Token, _treasury, "Bonded PION NFT", "bonPION");
    }
}
