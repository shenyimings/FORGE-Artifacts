// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IFishingTownRod.sol";
import "./interfaces/IPancakePair.sol";

contract FishingTownRodShop is Ownable {
    using SafeERC20 for IERC20;

    event Purchase(address indexed buyer, uint256 tokenId, uint256 price);

    IERC20 public fhtn;
    IFishingTownRod public fishingRod;
    IPancakePair public pair;
    address public treasuryAddress;
    uint256 public priceInFhtn;
    uint256 public maxPriceInUsd;
    uint256 public salesQuota;
    uint256 public saleAmount;

    constructor(
        address _fhtn,
        address _fishingRod,
        address _treasuryAddress,
        address _pairAddress,
        uint256 _priceInFhtn,
        uint256 _maxPriceInUsd,
        uint256 _salesQuota
    ) {
        require(
            _fhtn != address(0) &&
                _fishingRod != address(0) &&
                _treasuryAddress != address(0) &&
                _pairAddress != address(0) &&
                _priceInFhtn > 0 &&
                _maxPriceInUsd > 0 &&
                _salesQuota > 0,
            "cannot be zero"
        );

        fhtn = IERC20(_fhtn);
        fishingRod = IFishingTownRod(_fishingRod);
        treasuryAddress = _treasuryAddress;
        pair = IPancakePair(_pairAddress);
        priceInFhtn = _priceInFhtn;
        maxPriceInUsd = _maxPriceInUsd;
        salesQuota = _salesQuota;
    }

    function purchaseFishingRod() external {
        require(saleAmount < salesQuota, "sold out");
        saleAmount++;

        uint256 _currentPriceInFhtn = currentPriceInFhtn();
        fhtn.safeTransferFrom(msg.sender, treasuryAddress, _currentPriceInFhtn);
        uint256 tokenId = fishingRod.safeMint(msg.sender);

        emit Purchase(msg.sender, tokenId, _currentPriceInFhtn);
    }

    function currentPriceInFhtn() public view returns (uint256) {
        uint256 _fhtnUsdRate = fhtnUsdRate();
        if (maxPriceInUsd < (priceInFhtn * _fhtnUsdRate) / (1 ether)) {
            return (maxPriceInUsd * 1 ether) / _fhtnUsdRate;
        }

        return priceInFhtn;
    }

    function fhtnUsdRate() public view returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        return ((reserve1 * 1 ether) / reserve0);
    }
}
