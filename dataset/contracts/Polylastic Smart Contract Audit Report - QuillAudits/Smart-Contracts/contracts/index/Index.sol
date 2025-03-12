// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "contracts/interfaces/IUniswapV2Router02.sol";
import "contracts/interfaces/IWETH.sol";
import "../partnerProgram/IPartnerProgram.sol";
import "./IIndex.sol";
import "contracts/IndexLP.sol";
import "contracts/extension/ExtensionPause.sol";

abstract contract Index is
    AccessControl,
    IIndex,
    ReentrancyGuard,
    ExtensionPause
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    EnumerableSet.AddressSet private _newAssets;

    bytes32 public constant DAO_ADMIN_ROLE = keccak256("DAO_ADMIN_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 constant PRECISION = 1e18;
    uint256 constant PRECISION_E6 = 1e6;

    string private _nameIndex;

    uint256 private _feeStake;
    uint256 private _feeUnstake;
    uint256 private _amountTax;
    uint256 private _maxShare;
    uint256 private _rebalancePeriod;
    uint256 private _lastRebalance;
    uint256 private _startPriceIndex;

    address private _indexLP;
    address private _actualAcceptToken;
    address private _adapter;
    address private _treasure;
    address public _wETH;
    address private _newAcceptToken;

    bool private _initializer;
    bool _init;
    uint256 public _slippage;

    IPartnerProgram private _ipartnerProgram;

    Asset[] private _activeAssets;

    modifier isZeroAmount(uint256 amount) {
        if (amount <= 0) {
            revert ZeroAmount();
        }
        _;
    }

    /// @notice The modifier prevents the possibility of reuse
    modifier isInitializer() {
        if (_initializer == true) {
            revert Initializer();
        }
        _;
        _initializer = true;
    }

    /**
     * @notice Stops the work of the contract.
     * Blocks a call to the "stake" method.
     * Users can withdraw their funds
     */
    function setPause() external onlyRole(DAO_ADMIN_ROLE) {
        _changeStatusPause();
    }

    /**
     * @notice  Set a new index name
     */
    function setNameIndex(string memory name) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) ||
                hasRole(DAO_ADMIN_ROLE, msg.sender),
            "InvalidRole"
        );
        _nameIndex = name;
        emit SetName(name);
    }

    /**
     * @notice  Set a new commission
     * @dev Enter data taking into account precision
     */
    function setFeeStake(uint256 fee) external onlyRole(DAO_ADMIN_ROLE) {
        require(fee < PRECISION_E6 * 100, "Invalid fee");
        _feeStake = fee;

        emit SetFeeStake(fee);
    }

    /**
     * @notice  Set a new commission
     * @dev Enter data taking into account precision
     */
    function setFeeUnStake(uint256 fee) external onlyRole(DAO_ADMIN_ROLE) {
        require(fee < PRECISION_E6 * 100, "Invalid fee");
        _feeUnstake = fee;

        emit SetFeeUnStake(fee);
    }

    /**
     * @notice Sets the new address of the token. Used to pay for the index
     * changes will take effect after rebalancing
     */
    function setActualToken(
        address newToken
    ) external onlyRole(DAO_ADMIN_ROLE) {
        require(newToken != address(0), "Invalid Token");
        _newAcceptToken = newToken;
        emit SetActualToken(newToken);
    }

    /**
     * The _slippage parameter is needed when calling the rebalance function.
     * To compare the cost of 1LP calculated on the backend side and the smart contract
     * @dev Enter data taking into account precision.
     */
    function setSlippage(uint256 slippage) external onlyRole(DAO_ADMIN_ROLE) {
        require(slippage <= PRECISION_E6 * 10, "Invalid fee");
        _slippage = slippage;

        emit SetSlippage(slippage);
    }

    /**
     * @notice Setting the initial assets in the index
     */
    function init(AssetData[] memory newAssets) external onlyRole(ADMIN_ROLE) {
        require(!_init, "already initialized");
        _rebalance(newAssets, _startPriceIndex);

        uint256 firstPriceIndex = _calcCost(1e18);

        _init = true;
        emit Init(_activeAssets, firstPriceIndex);
    }

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
    ) external onlyRole(ADMIN_ROLE) {
        require(
            block.timestamp > _lastRebalance + _rebalancePeriod,
            "It is not possible to rebalance"
        );
        uint256 oldPrice = _calcCost(1e18); // calculate the cost of 1 LP
        uint256 usdAmount = _exchangeToUSD(); // the value of all assets in USD

        if (_actualAcceptToken != _newAcceptToken) {
            usdAmount = _changeActualToken(usdAmount, path); //replacement of the accepted token from the user
        }

        // we exchange USD for assets included in the index
        _rebalance(newAssets, usdAmount);
        uint256 newPrice = _calcCost(1e18);

        uint256 discrepancy;
        if (calculatedPrice >= newPrice)
            discrepancy = calculatedPrice - newPrice;
        else discrepancy = newPrice - calculatedPrice;

        uint v = (_slippage * calculatedPrice) / (100 * PRECISION_E6);

        if (v < discrepancy) {
            revert RebalancePrice(calculatedPrice, newPrice);
        }

        emit Rebalance(_activeAssets, oldPrice, newPrice);
    }

    /**
     * @notice Buying an index
     * @param amountLP - The number of indexes that will be purchased
     * @param amountUSD - Number of tokens spent + slippage
     */
    function stake(
        uint256 amountLP,
        uint256 amountUSD
    ) external isZeroAmount(amountLP) isPause {
        // debiting tokens from the user to the contract
        IERC20(_actualAcceptToken).safeTransferFrom(
            msg.sender,
            address(this),
            amountUSD
        );

        _stake(amountLP, amountUSD);
    }

    /**
     * @notice Buying an index for ETH
     * @dev msg.value - Number of tokens spent + slippage
     * @param amountLP The number of indexes that will be purchased
     */
    function stakeETH(
        uint256 amountLP
    ) external payable isZeroAmount(amountLP) isPause nonReentrant {
        require(
            _actualAcceptToken == _wETH,
            "The current accepted token is not ETH"
        );
        IWETH(_wETH).deposit{value: msg.value}();

        _stake(amountLP, msg.value);
    }

    /**
     * @notice Selling the LP
     */
    function unstake(
        uint256 amountLP,
        uint256 minAmount
    ) external isZeroAmount(amountLP) {
        (uint256 amountLPWithoutTax, uint256 tax) = _taxation(
            amountLP,
            _feeUnstake
        ); // calculation of the withdrawal fee
        _amountTax += tax;
        _unstake(amountLPWithoutTax, minAmount);

        IndexLP(_indexLP).burn(msg.sender, amountLP); // burning LP
        IndexLP(_indexLP).mint(_treasure, tax); // mint the tax to the treasure

        emit Unstake(msg.sender, amountLP);
    }

    /// @notice Returns the pause state
    /// @return status True - means that the operation of functions using the "isPause" modifier is stopped.
    /// * False- means that the functions using the "isPause" modifier are working

    function getStatusPause() external view returns (bool status) {
        return _statusPause();
    }

    /**
     * @notice Returns the index name
     */
    function getNameIndex() external view returns (string memory nameIndex) {
        return _nameIndex;
    }

    /**
     * @notice Returns the timestamp of the last rebalance
     */
    function getLastRebalance() external view returns (uint256) {
        return _lastRebalance;
    }

    /**
     * @notice Returns a list of assets that will be included in the index after rebalancing
     */
    function getNewAssets() external view returns (address[] memory newAssets) {
        uint256 len = _newAssets.length();
        newAssets = new address[](len);
        for (uint256 i; i < len; i++) {
            newAssets[i] = _newAssets.at(i);
        }
    }

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
        )
    {
        return (_indexLP, _maxShare, _rebalancePeriod, _startPriceIndex);
    }

    /**
     * @notice Returns an array of assets included in the index
     * @return assets An array of assets included in the index with all information about them
     */
    function getActiveAssets() external view returns (Asset[] memory assets) {
        return _activeAssets;
    }

    /**
     * @notice Returns the LP price
     */
    function getCostLP(
        uint256 amountLP
    ) external view returns (uint256 amountUSD) {
        return _calcCost(amountLP);
    }

    /**
     * @notice Returns commissions
     */
    function getFees()
        external
        view
        returns (uint256 feeStake, uint256 feeUnstake)
    {
        return (_feeStake, _feeUnstake);
    }

    /**
     * @notice Returns the address of the token accepted as payment
     */
    function getAcceptToken()
        external
        view
        returns (address actualAddress, address newAddress)
    {
        return (_actualAcceptToken, _newAcceptToken);
    }

    function getTax() external view returns (uint256 tax) {
        return _amountTax;
    }

    /**
     * @notice Returns the number of assets in the rebalancing queue
     */
    function lengthNewAssets() public view returns (uint256 len) {
        return _newAssets.length();
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IIndex).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice  Set the rebalancing period.
    /// After this time, it will be possible to call the "rebalance" function
    function _setRebalancePeriod(uint256 period) internal {
        _rebalancePeriod = period;

        emit SetRebalancePeriod(period);
    }

    ///@notice initialization of the main parameters
    /// @param adminDAO the address that has the right to call functions with the "DAO_ADMIN_ROLE" role
    /// @param admin the address that has the right to call functions with the "ADMIN_ROLE" role
    /// @param acceptToken the token in which the payment is accepted
    /// @param adapter adapter DEX
    /// @param startPrice initial index price
    /// @param rebalancePeriod the time after which rebalancing occurs (seconds)
    /// @param newAssets array with asset addresses
    /// @param treasure a commission will be sent to this address
    /// @param partnerProgram partner Program
    /// @param nameIndex name Index
    function _initialize(
        address adminDAO,
        address admin,
        address acceptToken,
        address adapter,
        uint256 startPrice,
        uint256 rebalancePeriod,
        address[] memory newAssets,
        address treasure,
        address partnerProgram,
        string memory nameIndex
    ) internal isInitializer {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(DAO_ADMIN_ROLE, adminDAO);
        _setupRole(ADMIN_ROLE, admin);

        _actualAcceptToken = acceptToken;
        _newAcceptToken = acceptToken;

        _adapter = adapter;
        _wETH = IUniswapV2Router01(adapter).WETH();
        _startPriceIndex = startPrice;
        _maxShare = 20 * PRECISION_E6;
        _rebalancePeriod = rebalancePeriod;
        _indexLP = _deployIndexLP(partnerProgram);
        _treasure = treasure;
        _ipartnerProgram = IPartnerProgram(partnerProgram);
        _nameIndex = nameIndex;
        _approveDEX(acceptToken);
        _updateNewAssets(newAssets);
        emit Initialize(adminDAO, admin, acceptToken, _indexLP);
    }

    function _stake(uint256 amountLP, uint256 deposit) internal {
        (uint256 amountLPWithoutTax, uint256 tax) = _taxation(
            amountLP,
            _feeStake
        ); //calculation of the commission for "stake"
        _amountTax += tax;

        uint256 stakeCost = _calcStake(amountLP);
        require(deposit >= stakeCost && stakeCost != 0, "InvalidCost");
        _ipartnerProgram.distributeTheReward(msg.sender, amountLP, _indexLP);

        IndexLP(_indexLP).mint(msg.sender, amountLPWithoutTax);
        IndexLP(_indexLP).mint(_treasure, tax);

        uint256 refundAmount = deposit - stakeCost;
        // refund of excess funds
        if (_actualAcceptToken != _wETH) {
            IERC20(_actualAcceptToken).safeTransfer(msg.sender, refundAmount);
        } else {
            IWETH(_wETH).withdraw(refundAmount);
            msg.sender.call{value: refundAmount}("");
        }

        emit Stake(msg.sender, stakeCost, amountLPWithoutTax);
    }

    function _swapDEX(
        uint256 amountForSwap,
        address[] memory path
    ) internal returns (uint256 amount) {
        uint256[] memory amounts = IUniswapV2Router02(_adapter)
            .swapExactTokensForTokens(
                amountForSwap,
                0,
                path,
                address(this),
                block.timestamp
            );
        return amounts[path.length - 1];
    }

    function _swapStake(
        uint256 amountForSwap,
        uint256 amountInMax,
        address[] memory path
    ) internal returns (uint256 amount, uint256 cost) {
        uint256[] memory amounts = IUniswapV2Router02(_adapter)
            .swapTokensForExactTokens(
                amountForSwap,
                amountInMax,
                path,
                address(this),
                block.timestamp
            );
        return (amounts[path.length - 1], amounts[0]);
    }

    /// @notice we exchange all tokens on the contract for USD
    function _exchangeToUSD() internal returns (uint256 sum) {
        uint256 len = _activeAssets.length;

        for (uint256 i; i < len; i++) {
            if (_activeAssets[i].totalAmount != 0) {
                address[] memory reversPath = _reversArray(
                    _activeAssets[i].path
                );
                uint256 amount = _swapDEX(
                    _activeAssets[i].totalAmount,
                    reversPath
                );

                sum += amount;
            }
        }
    }

    function _updateNewAssets(address[] memory assets) internal {
        uint256 len = assets.length;
        require((PRECISION_E6 * 100) / len <= _maxShare, "Invalid MaxShare");
        for (uint256 i; i < len; i++) {
            _addAssetInNewAssets(assets[i]);
        }
    }

    function _addAssetInNewAssets(address asset) internal {
        _newAssets.add(asset);
    }

    function _removeInNewAssets(address asset) internal {
        _newAssets.remove(asset);
    }

    function _changeActualToken(
        uint256 amount,
        address[] memory path
    ) internal returns (uint256 amountActualAcceptToken) {
        amountActualAcceptToken = _swapDEX(amount, path);
        _actualAcceptToken = _newAcceptToken;
        _approveDEX(_actualAcceptToken);
    }

    function _pushAssetInActive(AssetData memory newAsset) internal {
        Asset memory asset;
        asset.share = newAsset.share;
        asset.path = newAsset.path;
        asset.asset = newAsset.asset;

        _activeAssets.push(asset);
    }

    function _clearNewAssets() internal {
        uint256 len = _newAssets.length();
        for (uint256 i = len; i > 0; --i) {
            _newAssets.remove(_newAssets.at(i - 1));
        }
    }

    function _clearActiveAssets() internal {
        delete (_activeAssets);
    }

    /// @notice Set the maximum index share
    function _setMaxShare(uint256 maxShare) internal {
        _maxShare = maxShare;
    }

    /// @notice we exchange assets for USD to send them to the user
    function _unstake(uint256 amountLP, uint256 minAmount) internal {
        uint256 len = _activeAssets.length;
        uint256 sum;

        for (uint256 i; i < len; i++) {
            address[] memory reversPath = _reversArray(_activeAssets[i].path);
            uint256 amountForSwap = (amountLP * _activeAssets[i].fixedAmount) /
                PRECISION;

            uint256 amount = _swapDEX(amountForSwap, reversPath);
            _activeAssets[i].totalAmount -= amountForSwap;
            sum += amount;
        }
        IERC20(_actualAcceptToken).safeTransfer(msg.sender, sum);
        if (minAmount > sum) {
            revert InvalidMinAmount(minAmount, sum);
        }
    }

    /// @notice  exchange the user's USD for the assets included in the index
    function _calcStake(uint256 amountLP) internal returns (uint256 cost) {
        uint256 len = _activeAssets.length;
        for (uint256 i; i < len; i++) {
            uint256 amountForSwap = (amountLP * _activeAssets[i].fixedAmount) /
                PRECISION;

            (uint256 total, uint256 amountUSD) = _swapStake(
                amountForSwap,
                type(uint256).max,
                _activeAssets[i].path
            );
            _activeAssets[i].totalAmount += total;
            cost += amountUSD;
        }
    }

    function _approveDEX(address asset) internal {
        if (IERC20(asset).allowance(address(this), _adapter) == 0) {
            IERC20(asset).safeApprove(_adapter, type(uint256).max);
        }
    }

    /// @notice we exchange USD for assets included in the index
    function _rebalance(
        AssetData[] memory newAssets,
        uint256 usdAmount
    ) internal virtual {
        _clearActiveAssets(); // clearing the array of active assets
        uint256 totalLP = IERC20(_indexLP).totalSupply();
        uint256 len = newAssets.length;
        require((PRECISION_E6 * 100) / len <= _maxShare, "Invalid MaxShare");
        for (uint256 i; i < len; i++) {
            if (!_newAssets.contains(newAssets[i].asset)) {
                revert InvalidAsset(newAssets[i].asset);
            }
            _pushAssetInActive(newAssets[i]); // updating the array of active assets
            _approveDEX(newAssets[i].asset);
            uint256 amountForSwap = _calcShare(newAssets[i].share, usdAmount); // we get the asset's share in the index
            if (totalLP == 0) {
                uint256[] memory amounts = IUniswapV2Router02(_adapter)
                    .getAmountsOut(amountForSwap, newAssets[i].path);
                _activeAssets[i].fixedAmount = amounts[amounts.length - 1]; // saving the number of tokens in 1 LP
            } else {
                uint256 amount = _swapDEX(amountForSwap, newAssets[i].path); // we exchange asset for DEX
                _activeAssets[i].totalAmount += amount;
                _activeAssets[i].fixedAmount = (amount * PRECISION) / totalLP; // saving the number of tokens in 1 LP
            }
        }

        _setTimeRebalance(); // fixing the rebalance time
    }

    function _setTimeRebalance() internal {
        _lastRebalance = block.timestamp;
    }

    function _deployIndexLP(address partnerProgram) internal returns (address) {
        return address(new IndexLP(partnerProgram));
    }

    function _taxation(
        uint256 amount,
        uint256 fee
    ) internal pure returns (uint256 amountWithoutTax, uint256 tax) {
        tax = (amount * fee) / (100 * PRECISION_E6);
        amountWithoutTax = amount - tax;
    }

    function _isValidStake(
        uint256 cost,
        uint256 amountUSD,
        uint256 slippage
    ) internal pure {
        if (
            cost >
            (amountUSD * (100 * PRECISION_E6 + slippage)) / (100 * PRECISION_E6)
        ) {
            revert InvalidStake();
        }
    }

    /// @notice we calculate the percentage of the issuer in byltrct
    function _calcShare(
        uint256 percent,
        uint256 amount
    ) internal pure returns (uint256) {
        return (amount * percent) / (100 * PRECISION_E6);
    }

    function _reversArray(
        address[] memory array
    ) internal pure returns (address[] memory reversArray) {
        uint256 len = array.length;
        reversArray = new address[](len);
        for (uint256 i; i <= len - 1; i++) {
            reversArray[i] = array[len - i - 1];
        }
    }

    /// @notice calculating the cost of LP
    function _calcCost(
        uint256 amountLP
    ) internal view returns (uint256 amountUSD) {
        uint256 len = _activeAssets.length;
        for (uint256 i; i < len; i++) {
            amountUSD += _getPrice(
                _activeAssets[i].path,
                (_activeAssets[i].fixedAmount * amountLP) / PRECISION
            );
        }
        // amountUSD += (amountUSD * 10) / PRECISION_E6;
    }

    function _getPrice(
        address[] memory path,
        uint256 amount
    ) public view returns (uint256) {
        uint256[] memory amounts = IUniswapV2Router02(_adapter).getAmountsIn(
            amount,
            path
        );
        return (amounts[0]);
    }
}
