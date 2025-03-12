//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../modules/kap20/KAP20.sol";

contract MintableToken is KAP20 {
    constructor(
        string memory name_,
        string memory symbol_,
        address committee_,
        address adminRouter_,
        address kyc_,
        uint256 acceptedKycLevel_
    )
        KAP20(
            name_,
            symbol_,
            18,
            committee_,
            adminRouter_,
            kyc_,
            acceptedKycLevel_
        )
    {}

    function mint(address account, uint256 amount) public virtual onlyAdmin {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public virtual onlyAdmin {
        _burn(account, amount);
    }
}
