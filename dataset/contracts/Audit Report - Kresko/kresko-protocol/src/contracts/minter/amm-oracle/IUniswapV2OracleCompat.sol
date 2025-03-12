// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;
import {IERC20Minimal} from "../../vendor/uniswap/v2-core/interfaces/IERC20Minimal.sol";
import {IUniswapV2Factory} from "../../vendor/uniswap/v2-periphery/libraries/UniswapV2Library.sol";

/// @notice without UQ values
interface IUniswapV2OracleCompat {
    event NewAdmin(address indexed newAdmin);
    event NewMinUpdatePeriod(uint256 newMinUpdatePeriod);
    event NewPair(address indexed pair, address indexed token0, address indexed token1, uint256 updatePeriod);
    event PairUpdated(address indexed pair, address indexed token0, address indexed token1, uint256 updatePeriod);

    event NewKrAssetPair(address indexed krAsset, address indexed pairAddress);

    /// @notice returns the connected univ2 factory
    function factory() external view returns (IUniswapV2Factory);

    /// @notice returns the incentive token for the incentivized update
    function incentiveToken() external view returns (IERC20Minimal);

    /// @notice returns the amount of incentive tokens sent using the incentivized update
    function incentiveAmount() external view returns (uint256);

    /// @notice returns the current admin of the oracle
    function admin() external view returns (address);

    /// @notice returns the TWAP time period in seconds
    function minUpdatePeriod() external view returns (uint256);

    /// @notice returns the pair address for a given krAsset
    function krAssets(address) external returns (address);

    /**
     *
     * @param _newIncentiveToken new incentive token for updater
     * @param amount amount of incentive tokens
     */
    function setIncentiveToken(address _newIncentiveToken, uint256 amount) external;

    /**
     * @notice Configures existing values of an AMM pair
     * @param _pairAddress Pair address
     * @param _updatePeriod Update period (TWAP)
     */
    function configurePair(address _pairAddress, uint256 _updatePeriod) external;

    /**
     * @notice Get the AMM price for an amount of krAsset
     * @param _kreskoAsset Kresko asset address
     * @param _amountIn Amount of Kresko Asset to get value for
     */
    function consultKrAsset(address _kreskoAsset, uint256 _amountIn) external view returns (uint256 amountOut);

    /**
     * @notice General consult function, gets a value for `_amountIn` of `_token` in terms of `_tokenOut`
     * @param _pairAddress Address of the pair that contains the token
     * @param _token Address of the token to get value for
     * @param _amountIn Amount of token to get value for
     * @return amountOut Amount of tokenOut that `_amountIn` of `_token` is worth
     */
    function consult(address _pairAddress, address _token, uint256 _amountIn) external view returns (uint256 amountOut);

    /**
     * @notice Initializes an Uniswap V2 pair to be tracked by this oracle.
     *
     * The criteria for a pair to be tracked:
     * The pair must not already be tracked by this oracle.
     * The pair must exist.
     * The pair must have reserves.
     * The update period must be greater than the minimum update period.
     * @param _pairAddress Liquidity token address for the pair
     * @param _krAsset Kresko Asset in the pair we want to add helper functionality for
     * @param _updatePeriod The update period (TWAP) for this AMM pair
     *
     */
    function initPair(address _pairAddress, address _krAsset, uint256 _updatePeriod) external;

    /**
     * @notice Updates the oracle values for a pair
     * @param _pairAddress Pair address
     */
    function update(address _pairAddress) external;

    /**
     * @notice Sets a new admin
     * @param _newAdmin New admin address
     */
    function setAdmin(address _newAdmin) external;

    /**
     * @notice Set a new min update period
     * @param _minUpdatePeriod The new minimum period that can be set for a pair
     */
    function setMinUpdatePeriod(uint256 _minUpdatePeriod) external;

    /**
     * @notice Move any missent tokens
     * @param _erc20 drain any sent tokens
     * @param _to drain any sent tokens
     */
    function drainERC20(address _erc20, address _to) external;

    /**
     * Update pair data with incentives sent
     * @param _kreskoAsset Kresko Asset in the pair we want to update pair data for
     */
    function updateWithIncentive(address _kreskoAsset) external;
}
