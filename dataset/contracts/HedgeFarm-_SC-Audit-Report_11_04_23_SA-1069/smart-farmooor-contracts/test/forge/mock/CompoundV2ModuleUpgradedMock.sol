// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./BaseModuleUpgradedMock.sol";
import "../../../contracts/yield/interface/compoundV2/ExponentialNoError.sol";
import "../../../contracts/yield/interface/compoundV2/CTokenInterface.sol";
import "../../../contracts/yield/interface/compoundV2/ComptrollerInterface.sol";
import "../../../contracts/dex/interface/IDex.sol";
import "../../../contracts/yield/interface/nativeasset/INativeWrapper.sol";

/**
 * @author  HedgeFarm team
 * @title   CompoundV2 abstraction
 * @dev     The CompoundV2 abstraction is reponsible to abstract the logic of all forks of CompoundV2
 * @notice  Upgradability is needed because most compoundV2 forks are built with Proxy - it's implementation could be updated
 */

contract CompoundV2ModuleUpgraded is BaseModuleUpgradedMock, ExponentialNoError {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev A constant used for calculating shares
    uint256 private constant IOU_DECIMALS = 1e18;

    /// @notice The compoundV2 fork comptroller contract
    address public comptroller;
    /// @notice The compoundV2 fork cToken contrat used by the module
    address public cToken;
    /// @notice The last price per share used by the harvest
    uint256 public lastPricePerShare;

    /// @notice The last price per share used by the harvest
    uint256 public dummyCompound;

    /** proxy **/


    function initializeV2(uint dummy) public {
        dummyCompound = dummy;
        _initializeV2Base(dummy);
    }

    /**
     * @notice  Initializes
     * @dev     Should always be called on deployment
     * @param   _smartFarmooor  Smart Farmooor of the Module
     * @param   _manager  Manager of the Module
     * @param   _baseToken  Asset contract address
     * @param   _executionFee  Execution fee for withdrawals
     * @param   _dex  Dex Router contract address
     * @param   _rewards  Reward contract addresses
     * @param   _comptroller  Compound comtroller
     * @param   _cToken  Compound cToken
     * @param   _name  Name of the Module
     */
    function initialize(
        address _smartFarmooor,
        address _manager,
        address _baseToken,
        uint256 _executionFee,
        address _dex,
        address[] memory _rewards,
        address _comptroller,
        address _cToken,
        string memory _name
    ) public initializer {
        _initializeBase(_smartFarmooor, _manager, _baseToken, _executionFee, _dex, _rewards, _name);

        comptroller = _comptroller;
        cToken = _cToken;
        lastPricePerShare = CTokenInterface(_cToken).exchangeRateCurrent();

        IERC20Upgradeable(baseToken).safeApprove(_cToken, type(uint256).max);

        address[] memory market = new address[](1);
        market[0] = _cToken;
        uint256[] memory errors = ComptrollerInterface(_comptroller)
        .enterMarkets(market);
        require(errors[0] == 0, "CompoundV2: failed to enter market");
    }

    /** manager **/

    /**
     * @notice  Deposit Base token into CompoundV2 fork - provide liquidity
     * @param   amount  Amount of Base token to be deposited
     */
    function deposit(uint256 amount) external onlySmartFarmooor {
        require(amount > 0, "CompoundV2: deposit amount cannot be zero");
        IERC20Upgradeable(baseToken).safeTransferFrom(msg.sender, address(this), amount);
        uint256 error = CErc20Interface(cToken).mint(amount);
        require(error == 0, "CompoundV2: deposit error");
        emit Deposit(baseToken, amount);
    }

    /**
     * @notice  Withdraw Base token from CompoundV2 fork
     * @dev     Amount gets converted to shares for withdrawal
     * @param   shareFraction  Fraction representing user share of Base token to withdraw
     * @param   receiver  Receiver of the funds
     * @return  instant  Instant amount of Base token received
     * @return  pending  Pending amount of base token to be received
     */
    function withdraw(uint256 shareFraction, address receiver)
    external
    payable
    onlySmartFarmooor
    returns (uint256 instant, uint256 pending)
    {
        require(shareFraction > 0, "CompoundV2: shareFraction cannot be zero");
        require(msg.value == 0, "CompoundV2: msg.value must be zero");
        uint256 totalShares = CTokenInterface(cToken).balanceOf(address(this));
        uint256 sharesAmount = shareFraction * totalShares / IOU_DECIMALS;
        uint256 balanceBefore = IERC20Upgradeable(baseToken).balanceOf(address(this));
        uint256 error = CErc20Interface(cToken).redeem(sharesAmount);
        require(error == 0, "CompoundV2: withdraw error");
        uint256 balanceAfter = IERC20Upgradeable(baseToken).balanceOf(address(this));
        uint256 withdrawnAmount = balanceAfter - balanceBefore;
        emit Withdraw(baseToken, withdrawnAmount);
        if (withdrawnAmount > 0) {
            IERC20Upgradeable(baseToken).safeTransfer(receiver, withdrawnAmount);
        }
        return (withdrawnAmount, 0);
    }

    /**
     * @notice  Harvest the rewards from CompoundV2 fork
     * @param   receiver  Receiver of the harvested rewards, in Base token
     * @return  uint256  Total profit harvested
     */
    function harvest(address receiver)
    external
    onlySmartFarmooor
    returns (uint256)
    {
        _lpProfit();
        _rewardsProfit();
        uint256 totalProfit = IERC20Upgradeable(baseToken).balanceOf(address(this));
        if (totalProfit != 0) {
            IERC20Upgradeable(baseToken).safeTransfer(receiver, totalProfit);
        }
        emit Harvest(baseToken, totalProfit);
        return totalProfit;
    }

    /**
     * @notice  Get current balance on CompoundV2 fork
     * @dev     Returns an amount in Base token
     * @return  uint256  Amount of base token
     */
    function getBalance() public returns (uint256) {
        return CTokenInterface(cToken).balanceOfUnderlying(address(this));
    }

    /**
     * @notice  Get last updated balance on CompoundV2 fork
     * @dev     Returns an amount in Base token
     * @return  uint256  Amount of base token
     */
    function getLastUpdatedBalance() public view returns (uint256) {
        (, uint256 supplyBalanceCToken, , uint256 exchangeRateMantissa) = CTokenInterface(cToken).getAccountSnapshot(address(this));
        Exp memory exchangeRate = Exp({mantissa : exchangeRateMantissa});
        return mul_ScalarTruncate(exchangeRate, supplyBalanceCToken);
    }

    /**
     * @notice  Get execution fee needed to withdraw from CompoundV2 fork
     * @dev     Returns an amount in native token
     * @return  uint256  Amount of native token
     */
    function getExecutionFee(uint256 shareFraction)
    external
    view
    override
    returns (uint256)
    {
        return executionFee;
    }

    /** helper **/

    /**
     * @notice  Calculates the profit - the extra Base token earned on top of aum
     */
    function _lpProfit() private {
        uint256 totalShares = CTokenInterface(cToken).balanceOf(address(this));
        uint256 currentPricePerShare = CTokenInterface(cToken).exchangeRateCurrent();
        require(currentPricePerShare >= lastPricePerShare, "CompoundV2: module not profitable");
        uint256 pricePerShareDelta = currentPricePerShare - lastPricePerShare;
        uint256 sharesAmount = totalShares * pricePerShareDelta / currentPricePerShare;
        if (sharesAmount > 0) {
            uint256 error = CErc20Interface(cToken).redeem(sharesAmount);
            require(error == 0, "CompoundV2: withdraw error");
            lastPricePerShare = currentPricePerShare;
        }
    }

    /**
     * @notice  Collects the rewards tokens earned on CompoundV2 fork
     * @dev     Reward tokens are swapped for Base token
     */
    function _rewardsProfit() private {
        CTokenInterface[] memory market = new CTokenInterface[](1);
        market[0] = CTokenInterface(cToken);
        address payable[] memory holder = new address payable[](1);
        holder[0] = payable(address(this));

        for (uint8 i = 0; i < rewards.length; i++) {
            ComptrollerInterface(comptroller).claimReward(
                i,
                holder,
                market,
                false,
                true
            );
        }

        //Wrap any Native token, if any
        uint256 rewardBalance = address(this).balance;
        if (rewardBalance > 0) {
            INativeWrapper(wrappedNativeToken).deposit{value : rewardBalance}();
        }

        for (uint i = 0; i < rewards.length; i++) {
            if (rewards[i] != baseToken) {
                rewardBalance = IERC20Upgradeable(rewards[0]).balanceOf(address(this));
                IDex(dex).swap(rewardBalance, rewards[i], baseToken, address(this));
            }
        }
    }

    /**
     * @notice  CompoundV2 lp token
     * @dev     overridden for cToken address which is CompoundV2 lp token
     * @return  cToken address
     */
    function _lpToken() internal override view returns (address) {
        return cToken;
    }
}
