//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./modules/kap20/KAP20.sol";
import "./modules/access/Ownable.sol";
import "./interfaces/ILToken.sol";

contract LToken is KAP20, Ownable, ILToken {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address committee_,
        address adminRouter_,
        address kyc_,
        uint256 acceptedKycLevel_
    )
        KAP20(
            _name,
            _symbol,
            _decimals,
            committee_,
            adminRouter_,
            kyc_,
            acceptedKycLevel_
        )
    {}

    function mint(address account, uint256 amount) public override onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public override onlyOwner {
        _burn(account, amount);
    }
}
