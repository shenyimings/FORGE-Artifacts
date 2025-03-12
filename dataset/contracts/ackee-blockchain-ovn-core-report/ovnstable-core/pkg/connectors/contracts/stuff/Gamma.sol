// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IHypervisor {

    function deposit(
        uint256,
        uint256,
        address,
        address,
        uint256[4] memory minIn
    ) external returns (uint256);

    function withdraw(
        uint256,
        address,
        address,
        uint256[4] memory
    ) external returns (uint256, uint256);

    function rebalance(
        int24 _baseLower,
        int24 _baseUpper,
        int24 _limitLower,
        int24 _limitUpper,
        address _feeRecipient,
        uint256[4] memory minIn,
        uint256[4] memory outMin
    ) external;

    function addBaseLiquidity(
        uint256 amount0,
        uint256 amount1,
        uint256[2] memory minIn
    ) external;

    function addLimitLiquidity(
        uint256 amount0,
        uint256 amount1,
        uint256[2] memory minIn
    ) external;

    function pullLiquidity(
        uint256 shares,
        uint256[4] memory minAmounts
    ) external returns (
        uint256 base0,
        uint256 base1,
        uint256 limit0,
        uint256 limit1
    );

    function compound() external returns (

        uint128 baseToken0Owed,
        uint128 baseToken1Owed,
        uint128 limitToken0Owed,
        uint128 limitToken1Owed
    );

    function pool() external view returns (address);

    function currentTick() external view returns (int24 tick);

    function token0() external view returns (IERC20);

    function token1() external view returns (IERC20);

    function deposit0Max() external view returns (uint256);

    function deposit1Max() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function approve(address, uint256) external returns (bool);

    function transferFrom(address, address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function getTotalAmounts() external view returns (uint256 total0, uint256 total1);

    function totalSupply() external view returns (uint256 );

    function setWhitelist(address _address) external;

    function removeWhitelisted() external;

    function transferOwnership(address newOwner) external;

}

/// @title UniProxy
/// @notice Proxy contract for hypervisor positions management
interface IUniProxy {

    /// @notice Deposit into the given position
    /// @param deposit0 Amount of token0 to deposit
    /// @param deposit1 Amount of token1 to deposit
    /// @param to Address to receive liquidity tokens
    /// @param pos Hypervisor Address
    /// @return shares Amount of liquidity tokens received
    function deposit(
        uint256 deposit0,
        uint256 deposit1,
        address to,
        address pos,
        uint256[4] memory minIn
    ) external returns (uint256 shares);

    /// @notice Get the amount of token to deposit for the given amount of pair token
    /// @param pos Hypervisor Address
    /// @param token Address of token to deposit
    /// @param _deposit Amount of token to deposit
    /// @return amountStart Minimum amounts of the pair token to deposit
    /// @return amountEnd Maximum amounts of the pair token to deposit
    function getDepositAmount(
        address pos,
        address token,
        uint256 _deposit
    ) external view returns (uint256 amountStart, uint256 amountEnd);

    /// @notice Check if the price change overflows or not based on given twap and threshold in the hypervisor
    /// @param pos Hypervisor Address
    /// @param _twapInterval Time intervals
    /// @param _priceThreshold Price Threshold
    /// @return price Current price
    function checkPriceChange(
        address pos,
        uint32 _twapInterval,
        uint256 _priceThreshold
    ) external view returns (uint256 price);

    /// @notice Get the sqrt price before the given interval
    /// @param pos Hypervisor Address
    /// @param _twapInterval Time intervals
    /// @return sqrtPriceX96 Sqrt price before interval
    function getSqrtTwapX96(address pos, uint32 _twapInterval) external view returns (uint160 sqrtPriceX96);

}

/// @notice The (older) MasterChef contract gives out a constant number of SUSHI tokens per block.
/// It is the only address with minting rights for SUSHI.
/// The idea for this MasterChef V2 (MCV2) contract is therefore to be the owner of a dummy token
/// that is deposited into the MasterChef V1 (MCV1) contract.
/// The allocation point for this pool on MCV1 is the total allocation point for all pools that receive double incentives.
interface IMasterChef {

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of SUSHI entitled to the user.
    function userInfo(uint256 pid, address user) external view returns (uint256 amount, uint256 rewardDebt);

    /// @notice Deposit LP tokens to MCV2 for SUSHI allocation.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to deposit.
    /// @param to The receiver of `amount` deposit benefit.
    function deposit(uint256 pid, uint256 amount, address to) external;

    /// @notice Withdraw LP tokens from MCV2.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens.
    function withdraw(uint256 pid, uint256 amount, address to) external;

    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of SUSHI rewards.
    function harvest(uint256 pid, address to) external;

    /// @notice Withdraw LP tokens from MCV2 and harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens and SUSHI rewards.
    function withdrawAndHarvest(uint256 pid, uint256 amount, address to) external;

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of the LP tokens.
    function emergencyWithdraw(uint256 pid, address to) external;
}