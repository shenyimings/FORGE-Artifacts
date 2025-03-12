// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../DefaultPool.sol";

contract DefaultPoolTester is DefaultPool {
    using SafeMathUpgradeable for uint;
    function unprotectedIncreaseEUSDDebt(uint _amount) external {
        EUSDDebt  = EUSDDebt.add(_amount);
    }

    function unprotectedPayable() external payable {
         // @KingYet: Commented
        // ETH = ETH.add(msg.value);
    }    
}
