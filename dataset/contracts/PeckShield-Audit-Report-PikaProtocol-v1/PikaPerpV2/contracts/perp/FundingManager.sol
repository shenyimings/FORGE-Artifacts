pragma solidity ^0.8.0;

import "./IPikaPerp.sol";
import "../access/Governable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";

contract FundingManager is Governable {

    address public pikaPerp;
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    event UpdateOwner(address owner);

    uint256 constant public FUNDING_BASE = 10**12;
    uint256 maxFundingRate = 10 * FUNDING_BASE;
    uint256 minFundingMultiplier = 2 * FUNDING_BASE;
    mapping(uint256 => uint256) public fundingMultipliers;
    mapping(uint256 => int256) public cumulativeFundings;
    mapping(uint256 => uint256) public lastUpdateTimes;

    event FundingUpdated(uint256 productId, int256 fundingRate, int256 fundingChange, int256 cumulativeFunding);
    event PikaPerpSet(address pikaPerp);
    event MinFundingMultiplierSet(uint256 minFundingMultiplier);
    event FundingMultiplierSet(uint256 productId, uint256 fundingMultiplier);
    event MaxFundingRateSet(uint256 maxFundingRate);

    function updateFunding(uint256 _productId) external {
        require(msg.sender == pikaPerp, "FundingManager: !pikaPerp");
        if (lastUpdateTimes[_productId] == 0) {
            lastUpdateTimes[_productId] = block.timestamp;
            return;
        }
        int256 fundingRate = getFundingRate(_productId);
        int256 fundingChange = fundingRate * int256(block.timestamp - lastUpdateTimes[_productId]) / int256(365 days);
        cumulativeFundings[_productId] = cumulativeFundings[_productId] + fundingChange;
        lastUpdateTimes[_productId] = block.timestamp;
        emit FundingUpdated(_productId, fundingRate, fundingChange, cumulativeFundings[_productId]);
    }

    function getFundingRate(uint256 _productId) public view returns(int256) {
        (,,,,uint256 openInterestLong, uint256 openInterestShort,,uint256 productWeight,) = IPikaPerp(pikaPerp).getProduct(_productId);
        uint256 maxExposure = IPikaPerp(pikaPerp).getMaxExposure(productWeight);
        uint256 fundingMultiplier = Math.max(fundingMultipliers[_productId], minFundingMultiplier);
        if (openInterestLong > openInterestShort) {
            return int256(Math.min((openInterestLong - openInterestShort) * fundingMultiplier / maxExposure, maxFundingRate));
        } else {
            return -1 * int256(Math.min((openInterestShort - openInterestLong) * fundingMultiplier / maxExposure, maxFundingRate));
        }
    }

    function getFunding(uint256 _productId) external view returns(int256) {
        return cumulativeFundings[_productId];
    }

    function setPikaPerp(address _pikaPerp) external onlyOwner {
        pikaPerp = _pikaPerp;
        emit PikaPerpSet(_pikaPerp);
    }

    function setMinFundingMultiplier(uint256 _minFundingMultiplier) external onlyOwner {
        minFundingMultiplier = _minFundingMultiplier;
        emit MinFundingMultiplierSet(_minFundingMultiplier);
    }

    function setFundingMultiplier(uint256 _productId, uint256 _fundingMultiplier) external onlyOwner {
        fundingMultipliers[_productId] = _fundingMultiplier;
        emit FundingMultiplierSet(_productId, _fundingMultiplier);
    }

    function setMaxFundingRate(uint256 _maxFundingRate) external onlyOwner {
        maxFundingRate = _maxFundingRate;
        emit MaxFundingRateSet(_maxFundingRate);
    }

    function setOwner(address _owner) external onlyGov {
        owner = _owner;
        emit UpdateOwner(_owner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "FundingManager: !owner");
        _;
    }

}
