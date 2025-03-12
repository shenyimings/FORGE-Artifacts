// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";
import {IPool} from "aave-v3/interfaces/IPool.sol";
import {IAaveIncentivesController} from "aave-v3/interfaces/IAaveIncentivesController.sol";

import {MockAavePool} from "./MockAavePool.sol";
import {MockUSDC} from "../MockUSDC.sol";

contract MockAUsdc is IAToken {
    MockAavePool public aavePool;
    MockUSDC public mockUsdc;

    constructor(MockAavePool _aavePool, MockUSDC _mockUsdc) {
        aavePool = _aavePool;
        mockUsdc = _mockUsdc;
    }

    function balanceOf(address account) external view returns (uint256) {
        (uint256 supplyAmount,) = aavePool.book(account, address(mockUsdc));
        return supplyAmount;
    }

    /*//////////////////////////////////////////////////////////////
                            UNUSED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mint(address caller, address onBehalfOf, uint256 amount, uint256 index) external override returns (bool) {}

    function burn(address from, address receiverOfUnderlying, uint256 amount, uint256 index) external override {}

    function mintToTreasury(uint256 amount, uint256 index) external override {}

    function transferOnLiquidation(address from, address to, uint256 value) external override {}

    function transferUnderlyingTo(address target, uint256 amount) external override {}

    function handleRepayment(address user, address onBehalfOf, uint256 amount) external override {}

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        override
    {}

    function UNDERLYING_ASSET_ADDRESS() external view override returns (address) {}

    function RESERVE_TREASURY_ADDRESS() external view override returns (address) {}

    function DOMAIN_SEPARATOR() external view override returns (bytes32) {}

    function nonces(address owner) external view override returns (uint256) {}

    function rescueTokens(address token, address to, uint256 amount) external override {}

    function allowance(address owner, address spender) external view returns (uint256) {}

    function approve(address spender, uint256 amount) external returns (bool) {}
    function getPreviousIndex(address user) external view returns (uint256) {}
    function getScaledUserBalanceAndSupply(address user) external view returns (uint256, uint256) {}
    function scaledTotalSupply() external view returns (uint256) {}
    function totalSupply() external view returns (uint256) {}
    function transfer(address recipient, uint256 amount) external returns (bool) {}
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {}
    function scaledBalanceOf(address user) external view returns (uint256) {}

    function initialize(
        IPool pool,
        address treasury,
        address underlyingAsset,
        IAaveIncentivesController incentivesController,
        uint8 aTokenDecimals,
        string calldata aTokenName,
        string calldata aTokenSymbol,
        bytes calldata params
    ) external {}
}
