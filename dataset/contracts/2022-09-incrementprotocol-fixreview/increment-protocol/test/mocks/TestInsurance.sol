// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {Insurance} from "../../contracts/Insurance.sol";

// interfaces
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IVault} from "../../contracts/interfaces/IVault.sol";

contract TestInsurance is Insurance {
    constructor(IERC20Metadata _token, IVault _vault) Insurance(_token, _vault) {}

    function __TestInsurance__fundInsurance(uint256 amount) external {
        return _fundInsurance(amount);
    }

    function __TestInsurance__setSystemBadDebt(uint256 newSystemBadDebt) external {
        systemBadDebt = newSystemBadDebt;
    }
}
