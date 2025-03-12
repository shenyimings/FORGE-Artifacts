// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/utils/math/Math.sol";
import "../external/interfaces/strategies/compound/v2/IComptroller.sol";
import "../external/interfaces/strategies/compound/v2/ICErc20.sol";
import "../interfaces/ISwapper.sol";
import "../strategies/Strategy.sol";

/// @notice Used when Compound V2 mint returns an error code.
error BadCompoundV2Deposit();

/// @notice Used Compound V2 redeem returns an error code.
error BadCompoundV2Withdrawal();

contract CompoundV2Strategy is Strategy {
    using SafeERC20 for IERC20;

    uint256 public immutable MANTISSA = 10 ** 18;

    /// @notice Comptroller implementaiton
    ISwapper public immutable swapper;

    /// @notice Comptroller implementaiton
    IComptroller public immutable comptroller;

    /// @notice COMP token
    /// @dev Reward token when participating in the Compound protocol.
    IERC20 public immutable comp;

    /// @notice Compound market
    ICErc20 public cToken;

    /// @notice exchangeRateCurrent at the last DHW.
    uint256 private _lastExchangeRate;

    constructor(
        string memory name_,
        IAssetGroupRegistry assetGroupRegistry_,
        ISpoolAccessControl accessControl_,
        ISwapper swapper_,
        IComptroller comptroller_
    ) Strategy(name_, assetGroupRegistry_, accessControl_) {
        if (
            address(swapper_) == address(0) || address(accessControl_) == address(0)
                || address(comptroller_) == address(0)
        ) {
            revert ConfigurationAddressZero();
        }

        if (!comptroller_.isComptroller()) {
            revert InvalidConfiguration();
        }

        swapper = swapper_;
        comptroller = comptroller_;
        comp = IERC20(comptroller_.getCompAddress());
    }

    function initialize(uint256 assetGroupId_, ICErc20 cToken_) external initializer {
        __Strategy_init(assetGroupId_);

        if (address(cToken_) == address(0)) {
            revert ConfigurationAddressZero();
        }

        address[] memory tokens = assets();

        if (tokens.length != 1 || tokens[0] != cToken_.underlying()) {
            revert InvalidAssetGroup(assetGroupId_);
        }

        address[] memory markets = new address[](1);
        markets[0] = address(cToken_);
        uint256[] memory results = comptroller.enterMarkets(markets);

        if (results[0] > 0) {
            revert InvalidConfiguration();
        }

        cToken = cToken_;
        _lastExchangeRate = cToken_.exchangeRateCurrent();
    }

    function assetRatio() external pure override returns (uint256[] memory) {
        uint256[] memory _assetRatio = new uint256[](1);
        _assetRatio[0] = 1;
        return _assetRatio;
    }

    /**
     * @notice Nothing to swap as it's only one asset.
     */
    function _swapAssets(address[] memory, uint256[] memory, SwapInfo[] calldata) internal override {}

    function _compound(address[] calldata tokens, SwapInfo[] calldata swapInfo, uint256[] calldata)
        internal
        override
        returns (int256 compoundedYieldPercentage)
    {
        if (swapInfo.length > 0) {
            address[] memory markets = new address[](1);
            markets[0] = address(cToken);
            comptroller.claimComp(address(this), markets);

            uint256 compBalance = comp.balanceOf(address(this));

            if (compBalance > 0) {
                comp.safeTransfer(address(swapper), compBalance);
                address[] memory tokensIn = new address[](1);
                tokensIn[0] = address(comp);
                uint256 swappedAmount = swapper.swap(tokensIn, swapInfo, tokens, address(this))[0];

                if (swappedAmount > 0) {
                    uint256 cTokenBalanceBefore = cToken.balanceOf(address(this));
                    _depositToCompoundProtocol(IERC20(tokens[0]), swappedAmount);
                    uint256 cTokenAmountCompounded = cToken.balanceOf(address(this)) - cTokenBalanceBefore;

                    compoundedYieldPercentage = _calculateYieldPercentage(cTokenBalanceBefore, cTokenAmountCompounded);
                }
            }
        }
    }

    function _getYieldPercentage(int256) internal override returns (int256 baseYieldPercentage) {
        uint256 exchangeRateCurrent = cToken.exchangeRateCurrent();

        unchecked {
            uint256 exchangeRateIncrease = exchangeRateCurrent - _lastExchangeRate;

            baseYieldPercentage = _calculateYieldPercentage(_lastExchangeRate, exchangeRateIncrease);
            _lastExchangeRate = exchangeRateCurrent;
        }
    }

    function _depositToProtocol(address[] calldata tokens, uint256[] memory amounts, uint256[] calldata)
        internal
        override
    {
        _depositToCompoundProtocol(IERC20(tokens[0]), amounts[0]);
    }

    function _depositToCompoundProtocol(IERC20 token, uint256 amount) private {
        if (amount > 0) {
            _resetAndApprove(token, address(cToken), amount);

            if (cToken.mint(amount) > 0) {
                revert BadCompoundV2Deposit();
            }
        }
    }

    /**
     * @notice Withdraw lp tokens from the Compound market
     */
    function _redeemFromProtocol(address[] calldata, uint256 ssts, uint256[] calldata) internal override {
        if (ssts == 0) {
            return;
        }

        uint256 cTokenWithdrawAmount = (cToken.balanceOf(address(this)) * ssts) / totalSupply();

        if (cTokenWithdrawAmount > 0) {
            if (cToken.redeem(cTokenWithdrawAmount) > 0) {
                revert BadCompoundV2Withdrawal();
            }
        }
    }

    function _getUsdWorth(uint256[] memory exchangeRates, IUsdPriceFeedManager priceFeedManager)
        internal
        view
        override
        returns (uint256 usdValue)
    {
        uint256 cTokenBalance = cToken.balanceOf(address(this));
        if (cTokenBalance > 0) {
            uint256 tokenValue = _getcTokenValue(cTokenBalance);

            address[] memory assetGroup = _assetGroupRegistry.listAssetGroup(_assetGroupId);
            usdValue = priceFeedManager.assetToUsdCustomPrice(assetGroup[0], tokenValue, exchangeRates[0]);
        }
    }

    /**
     * @dev Get value of the desire cTkoen amount in the asset token amount
     * @param cTokenAmount cToken amount
     * @return tokenAmount value of `cTokenAmount` in asset tokens
     */
    function _getcTokenValue(uint256 cTokenAmount) private view returns (uint256) {
        if (cTokenAmount == 0) {
            return 0;
        }

        // NOTE: can be outdated if noone interacts with the compound protocol for a longer period
        return (cToken.exchangeRateStored() * cTokenAmount) / MANTISSA;
    }

    function beforeDepositCheck(uint256[] memory amounts, uint256[] calldata slippages) public view override {}

    function beforeRedeemalCheck(uint256 ssts, uint256[] calldata slippages) public view override {}

    function _emergencyWithdrawImpl(uint256[] calldata slippages, address recipient) internal pure override {}
}
