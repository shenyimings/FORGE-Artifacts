// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

interface StMaticProxy {
    function submit(uint256 _amount) external returns (uint256);

    function requestWithdraw(uint256 _amount) external;

    function claimTokens(uint256 _tokenId) external;
}

interface RootchainManagerProxy {
    function depositFor(
        address user,
        address rootToken,
        bytes calldata depositData
    ) external;
}

interface OneInchInterace {
    function swap(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable toToken,
        uint256 fromTokenAmount,
        uint256 minReturnAmount,
        uint256 guaranteedAmount,
        address payable referrer,
        address[] calldata callAddresses,
        bytes calldata callDataConcat,
        uint256[] calldata starts,
        uint256[] calldata gasLimitsAndValues
    )
    external
    payable
    returns (uint256 returnAmount);
}

struct OneInchData {
    IERC20Upgradeable sellToken;
    IERC20Upgradeable buyToken;
    uint _sellAmt;
    uint _buyAmt;
    uint unitAmt;
    bytes callData;
}
