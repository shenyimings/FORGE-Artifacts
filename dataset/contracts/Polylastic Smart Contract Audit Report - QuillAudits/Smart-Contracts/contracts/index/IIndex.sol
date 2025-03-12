//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;

interface IIndex {
    event Initialize(address adminDAO, address admin, address USD, address lp);
    event Rebalance(Asset[] assets, uint256 oldPrice, uint256 newPrice);
    event Init(Asset[] assets, uint256 indexPrice);
    event Stake(address indexed account, uint256 amountUSD, uint256 amountLP);
    event Unstake(address indexed account, uint256 amountLP);
    event SetRebalancePeriod(uint256 period);

    event SetFeeUnStake(uint256 newFee);
    event SetSlippage(uint256 newSlippage);
    event SetFeeStake(uint256 newFee);
    event SetActualToken(address newActualToken);
    event SetName(string name);

    error ZeroAmount();
    error InvalidStake();
    error Initializer();
    error RebalancePrice(uint256 priceAdmin, uint256 priceSM);
    error InvalidMinAmount(uint256 minAmount, uint256 amount);

    error InvalidAsset(address asset);

    struct Asset {
        address asset;
        address[] path;
        uint256 fixedAmount;
        uint256 totalAmount;
        uint256 share;
    }
    struct AssetData {
        address asset;
        address[] path;
        uint256 share;
    }

    /**
     * @notice Stops the work of the contract.
     * Blocks a call to the "stake" method.
     * Users can withdraw their funds
     */
    function setPause() external;

    /**
     * @notice  Set a new index name
     */
    function setNameIndex(string memory name) external;

    /**
     * @notice  Set a new commission
     * @dev Enter data taking into account precision
     */
    function setFeeStake(uint256 fee) external;

    /**
     * @notice  Set a new commission
     * @dev Enter data taking into account precision
     */
    function setFeeUnStake(uint256 fee) external;

    /**
     * @notice Sets the new address of the token. Used to pay for the index
     * changes will take effect after rebalancing
     */
    function setActualToken(address newToken) external;

    /**
     * @notice Setting the initial assets in the index
     */
    function init(AssetData[] memory newAssets) external;

    /**
     * @notice  Reconfiguring the index
     * @param newAssets - New assets that will be included in the index after rebalancing
     * @param path - Specify the path to exchange "_actualAcceptToken" to "_newAcceptToken".
     * The exchange will take place on quickSwap
     */
    function rebalance(
        AssetData[] memory newAssets,
        address[] memory path,
        uint256 calculatedPrice
    ) external;

    /**
     * @notice Buying an index
     * @param amountLP - The number of indexes that will be purchased
     * @param amountUSD - Number of tokens spent
     */
    function stake(uint256 amountLP, uint256 amountUSD) external;

    /**
     * @notice Buying an index for ETH
     * @param amountLP The number of indexes that will be purchased
     */
    function stakeETH(uint256 amountLP) external payable;

    /**
     * @notice Selling the index
     */
    function unstake(uint256 amountLP, uint256 minAmount) external;

    /// @notice Returns the pause state
    /// @return status True - means that the operation of functions using the "isPause" modifier is stopped
    /// * False- means that the functions using the "isPause" modifier are working
    function getStatusPause() external view returns (bool status);

    /**
     * @notice Returns the index name
     */
    function getNameIndex() external view returns (string memory nameIndex);

    /**
     * @notice Returns the timestamp of the last rebalance
     */
    function getLastRebalance() external view returns (uint256);

    /**
     * @notice Returns a list of assets that will be included in the index after rebalancing
     */
    function getNewAssets() external view returns (address[] memory newAssets);

    /**
     * @notice Returns information about the index
     * @param indexLP LP token address
     * @param maxShare The maximum share of an asset in the index
     * @param rebalancePeriod The time after which the rebalancing takes place
     * @param startPriceIndex Initial index price
     */
    function getDataIndex()
        external
        view
        returns (
            address indexLP,
            uint256 maxShare,
            uint256 rebalancePeriod,
            uint256 startPriceIndex
        );

    /**
     * @notice Returns an array of assets included in the index
     * @return assets An array of assets included in the index with all information about them
     */
    function getActiveAssets() external view returns (Asset[] memory assets);

    /**
     * @notice Returns the LP price
     */
    function getCostLP(
        uint256 amountLP
    ) external view returns (uint256 amountUSD);

    /**
     * @notice Returns commissions
     */
    function getFees()
        external
        view
        returns (uint256 feeStake, uint256 feeUnstake);

    /**
     * @notice Returns the address of the token accepted as payment
     */
    function getAcceptToken()
        external
        view
        returns (address actualAddress, address newAddress);

    /**
     * @notice Returns the number of assets in the rebalancing queue
     */
    function lengthNewAssets() external view returns (uint256 len);
}
