// Copyright (C) 2017 DappHub, LLC

pragma solidity ^0.4.11;

import "ds-token/token.sol";

contract KeyTokenReborn is DSStop{

    DSToken public key;

    uint128 public constant TOTAL_SUPPLY = 10 ** 11 * 1 ether;  // 100 billion KEY in total

    address public keyFoundation; //multisig account , 4-of-6

    function KeyTokenReborn(address _keyFoundation) {

        require(_keyFoundation != 0x0);

        keyFoundation = _keyFoundation;

        key = new DSToken("KEY");
        key.setName("KEY");

        key.mint(TOTAL_SUPPLY);
        key.transfer(keyFoundation, TOTAL_SUPPLY);
        key.setOwner(keyFoundation);
    }

}
