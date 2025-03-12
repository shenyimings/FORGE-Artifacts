// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IFishingTownRod.sol";

contract FishingTownRodPresale is Ownable {
    using SafeERC20 for IERC20;

    event Purchase(address indexed buyer, uint256 tokenId);

    IERC20 public token;
    IFishingTownRod public fishingRod;
    address public treasuryAddress;
    uint256 public price;
    uint256 public salesQuota;
    uint256 public saleAmount;

    constructor(
        address _token,
        address _fishingRod,
        address _treasuryAddress,
        uint256 _price,
        uint256 _salesQuota
    ) {
        require(
            _token != address(0) &&
                _fishingRod != address(0) &&
                _treasuryAddress != address(0) &&
                _price > 0 &&
                _salesQuota > 0,
            "cannot be zero"
        );

        token = IERC20(_token);
        fishingRod = IFishingTownRod(_fishingRod);
        treasuryAddress = _treasuryAddress;
        price = _price;
        salesQuota = _salesQuota;
    }

    function purchaseFishingRod() external {
        require(saleAmount < salesQuota, "sold out");
        saleAmount++;

        token.safeTransferFrom(msg.sender, treasuryAddress, price);
        uint256 tokenId = fishingRod.safeMint(msg.sender);

        emit Purchase(msg.sender, tokenId);
    }
}
