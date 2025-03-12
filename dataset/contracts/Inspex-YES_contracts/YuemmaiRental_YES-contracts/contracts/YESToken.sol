//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./modules/kap20/KAP20.sol";

contract YESToken is KAP20 {
    constructor(
        uint256 totalSupply_,
        address committee_,
        address adminRouter_,
        address kyc_,
        uint256 acceptedKycLevel_
    )
        KAP20(
            "YES Token",
            "YES",
            18,
            committee_,
            adminRouter_,
            kyc_,
            acceptedKycLevel_
        )
    {
        _mint(msg.sender, totalSupply_);
    }
}
