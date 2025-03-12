// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../access/Governable.sol";
import "./IPikaPerp.sol";
import './IFundingManager.sol';
import './FundingManager.sol';
import "../oracle/IOracle.sol";
import '../lib/PerpLib.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// In PikaPerpV3 contract, the liquidatePosition function has an issue where the open interest can be decreased even if the position is not liquidatable.
// This contract is created to avoid that issue. The liquidateWithPrices and liquidatePosition functions in this contract are the only functions used for liquidation.
// The canLiquidate function has the same validation logic as those in PikaPerpV3, to make sure the position is truly liquidatble if the validation passes,
// so that the open interest in PikaPerpV3 can only be decreased if the position is truly liquidated. This contract is set as the only liquidator address for PikaPerpV3.
contract Liquidator is Governable {

    address public owner;
    address public pikaPerp;
    address public rewardToken;
    address public priceFeed;
    address public fundingManager;
    // a forever locked timelock account that was used one time to open positions to correct the totalOpenInterest in PikaPerpV3 and this account should never be liquidated
    address public immutable lockedAccount;
    bool public allowPublicLiquidator;
    uint256[] positionIds;
    mapping (address => bool) public isKeeper;
    mapping (address => bool) public isLiquidator;
    uint256 private constant BASE = 10**8;
    uint256 private constant FUNDING_BASE = 10**12;

    event NotLiquidate(uint256 positionId);
    event RewardWithdraw(address indexed receiver, uint256 rewardAmount);
    event PikaPerpSet(address pikaPerp);
    event RewardTokenSet(address rewardToken);
    event PriceFeedSet(address priceFeed);
    event FundingManagerSet(address fundingManager);
    event AllowPublicLiquidatorSet(bool allowPublicLiquidator);
    event UpdateKeeper(address keeper, bool isAlive);
    event UpdateLiquidator(address liquidator, bool isAlive);
    event UpdateOwner(address owner);

    constructor(address _pikaPerp, address _rewardToken, address _priceFeed, address _fundingManager, address _lockedAccount) public {
        owner = msg.sender;
        pikaPerp = _pikaPerp;
        rewardToken = _rewardToken;
        priceFeed = _priceFeed;
        fundingManager = _fundingManager;
        lockedAccount = _lockedAccount;
    }

    function liquidateWithPrices(
        bytes[] calldata _priceUpdateData,
        address[] calldata accounts,
        uint256[] calldata productIds,
        bool[] calldata isLongs)
    external onlyKeeper {
        IOracle(priceFeed).setPrices(_priceUpdateData);
        liquidatePositions(accounts, productIds, isLongs);
    }

    function liquidatePositions(address[] calldata accounts, uint256[] calldata productIds, bool[] calldata isLongs) public {
        require(isLiquidator[msg.sender] || allowPublicLiquidator, "!liquidator");
        for (uint256 i = 0; i < accounts.length; i++) {
            if (canLiquidate(accounts[i], productIds[i], isLongs[i])) {
                positionIds.push(getPositionId(accounts[i], productIds[i], isLongs[i]));
            } else {
                emit NotLiquidate(getPositionId(accounts[i], productIds[i], isLongs[i]));
            }
        }
        IPikaPerp(pikaPerp).liquidatePositions(positionIds);
        delete positionIds;
    }

    function liquidatePosition(address account, uint256 productId, bool isLong) external {
        require(isLiquidator[msg.sender] || allowPublicLiquidator, "!liquidator");
        require(canLiquidate(account, productId, isLong), "!liquidate");
        positionIds.push(getPositionId(account, productId, isLong));
        IPikaPerp(pikaPerp).liquidatePositions(positionIds);
        delete positionIds;
    }

    function canLiquidate(address account, uint256 productId, bool isLong) public returns(bool) {
        if (account == lockedAccount) {
            return false;
        }
        (uint256 _productId,uint256 leverage,uint256 positionPrice,,uint256 margin,,,,int256 funding) = IPikaPerp(pikaPerp).getPosition(account, productId, isLong);
        if (_productId == 0) {
            return false;
        }
        (address productToken,,,,,,,,) = IPikaPerp(pikaPerp).getProduct(productId);
        int256 fundingRate = IFundingManager(fundingManager).getFundingRate(productId);
        int256 fundingChange = fundingRate * int256(block.timestamp - FundingManager(fundingManager).lastUpdateTimes(productId)) / int256(365 days);
        int256 prevCumFunding = FundingManager(fundingManager).cumulativeFundings(productId);
        int256 cumulativeFunding = FundingManager(fundingManager).cumulativeFundings(productId) + fundingChange;
        int256 fundingPayment = _getFundingPayment(isLong, productId, leverage, margin, funding, cumulativeFunding);
        int256 pnl = PerpLib._getPnl(isLong, positionPrice, leverage, margin, IOracle(priceFeed).getPrice(productToken)) - fundingPayment;
        if (pnl >= 0 || uint256(-1 * pnl) < uint256(margin) * IPikaPerp(pikaPerp).liquidationThreshold() / (10**4)) {
            return false;
        }
        return true;
    }

    function _getFundingPayment(
        bool isLong,
        uint256 productId,
        uint256 positionLeverage,
        uint256 margin,
        int256 funding,
        int256 cumulativeFunding
    ) internal view returns(int256) {
        return isLong ? int256(margin * positionLeverage) * (cumulativeFunding - funding) / int256(BASE * FUNDING_BASE) :
        int256(margin * positionLeverage) * (funding - cumulativeFunding) / int256(BASE * FUNDING_BASE);
    }

    function getPositionId(
        address account,
        uint256 productId,
        bool isLong
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(account, productId, isLong)));
    }

    function withdrawReward(address receiver) external onlyOwner {
        uint256 rewardAmount = IERC20(rewardToken).balanceOf(address(this));
        IERC20(rewardToken).transfer(receiver, rewardAmount);
        emit RewardWithdraw(receiver, rewardAmount);
    }

    function setPikaPerp(address _pikaPerp) external onlyOwner {
        pikaPerp = _pikaPerp;
        emit PikaPerpSet(_pikaPerp);
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = _rewardToken;
        emit RewardTokenSet(_rewardToken);
    }

    function setPriceFeed(address _priceFeed) external onlyOwner {
        priceFeed = _priceFeed;
        emit PriceFeedSet(_priceFeed);
    }

    function setFundingManager(address _fundingManager) external onlyOwner {
        fundingManager = _fundingManager;
        emit FundingManagerSet(_fundingManager);
    }

    function setAllowPublicLiquidator(bool _allowPublicLiquidator) external onlyOwner {
        allowPublicLiquidator = _allowPublicLiquidator;
        emit AllowPublicLiquidatorSet(_allowPublicLiquidator);
    }

    function setOwner(address _owner) external onlyGov {
        owner = _owner;
        emit UpdateOwner(_owner);
    }

    function setKeeper(address _account, bool _isActive) external onlyOwner {
        isKeeper[_account] = _isActive;
        emit UpdateKeeper(_account, _isActive);
    }

    function setLiquidator(address _account, bool _isActive) external onlyOwner {
        isLiquidator[_account] = _isActive;
        emit UpdateLiquidator(_account, _isActive);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Liquidator: !owner");
        _;
    }

    modifier onlyKeeper() {
        require(isKeeper[msg.sender], "Liquidator: !keeper");
        _;
    }

}
