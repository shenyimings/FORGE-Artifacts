// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeCast.sol';
import '../staking/PikaMine.sol';

/** @title VePika
    @notice Vote escrowed non-transferable token
 */
contract VePika is ERC20 {
    PikaMine public pikaMine;

    constructor(address _pikaMine) ERC20("Vote Escrowed Pika", "vePIKA") {
        pikaMine = PikaMine(_pikaMine);
    }

    function totalSupply() public view override returns (uint256) {
        return pikaMine.totalLpToken();
    }

    function balanceOf(address _account) public view override returns (uint256) {
        uint256 accountBalance = 0;
        uint256[] memory allUserDepositIds = pikaMine.getAllUserDepositIds(_account);
        uint256 len = allUserDepositIds.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 depositId = allUserDepositIds[i];
            (uint256 depositAmount,,,PikaMine.Lock lock) = pikaMine.userInfo(_account, depositId);
            (uint256 lockBoost, ) = pikaMine.getLockBoost(lock);
            uint256 lpAmount = depositAmount * lockBoost / pikaMine.ONE();
            accountBalance += lpAmount;
        }
        return accountBalance;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal pure override {
        revert("Non-transferable");
    }
}