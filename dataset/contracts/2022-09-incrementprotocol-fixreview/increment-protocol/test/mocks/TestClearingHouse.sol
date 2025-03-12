// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {ClearingHouse} from "../../contracts/ClearingHouse.sol";

// interfaces
import {IInsurance} from "../../contracts/interfaces/IInsurance.sol";
import {IVault} from "../../contracts/interfaces/IVault.sol";

contract TestClearingHouse is ClearingHouse {
    constructor(IVault _vault, IInsurance _insurance, ClearingHouseParams memory _params)
        ClearingHouse(_vault, _insurance, _params)
    {}

    function __TestClearingHouse__settleUserFundingPayments(address account) external {
        _settleUserFundingPayments(account);
    }
}
