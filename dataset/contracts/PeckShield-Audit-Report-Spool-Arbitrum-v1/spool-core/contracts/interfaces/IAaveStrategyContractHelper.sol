// SPDX-License-Identifier: BUSL-1.1

import "../external/interfaces/aave/IAToken.sol";

pragma solidity 0.8.11;

interface IAaveStrategyContractHelper {
    function claimRewards(bool executeClaim) external returns(uint256);

    function deposit(uint256 amount) external returns(uint256);

    function withdraw(uint256 cTokenWithdraw) external returns(uint256);

    function withdrawAll(uint256[] calldata data) external returns (uint256);

    function aToken() external returns (IAToken);
}
