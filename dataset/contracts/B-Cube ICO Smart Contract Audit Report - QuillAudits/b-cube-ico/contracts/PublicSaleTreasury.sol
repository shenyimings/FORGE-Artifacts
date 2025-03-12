// SPDX-License-Identifier: Unlicense
pragma solidity 0.5.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./BCubePublicSale.sol";

/**
 * @title BCUBE Treasury for Public Sale
 * @notice Contract in which 15m BCUBE will be transfered after public sale,
 * and distributed to stakeholders to whomever applicable
 **/

contract PublicSaleTreasury is BCubePublicSale {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice timestamp at which BCUBE will be listed on CEXes/DEXes
    uint256 public listingTime;

    IERC20 public token;

    event LogEtherReceived(address indexed sender, uint256 value);
    event LogListingTimeChange(uint256 prevListingTime, uint256 newListingTime);
    event LogPublicSaleShareWithdrawn(
        address indexed participant,
        uint256 bcubeAmountWithdrawn
    );

    modifier onlyAfterListing() {
        require(now >= listingTime, "Only callable after listing");
        _;
    }

    function() external payable {
        emit LogEtherReceived(_msgSender(), msg.value);
    }

    constructor(
        address payable _wallet,
        address _admin,
        IERC20 _token,
        uint256 _openingTime,
        uint256 _closingTime,
        address _chainlinkETHPriceFeed,
        address _chainlinkUSDTPriceFeed,
        address _usdtContract,
        address _privateSale,
        uint256 _listingTime
    )
        public
        BCubePublicSale(
            _openingTime,
            _closingTime,
            _chainlinkETHPriceFeed,
            _chainlinkUSDTPriceFeed,
            _usdtContract,
            _privateSale,
            _wallet
        )
    {
        setAdmin(_admin);
        token = _token;
        listingTime = _listingTime;
    }

    /// @dev WhitelistAdmin is the deployer
    /// @dev allows deployer to change listingTime, before current listingTime
    function setListingTime(uint256 _startTime) external onlyWhitelistAdmin {
        require(now < listingTime, "listingTime unchangable after listing");
        uint256 prevListingTime = listingTime;
        listingTime = _startTime;
        emit LogListingTimeChange(prevListingTime, listingTime);
    }
    
    /// @dev allows public sale participants to withdraw their allocated share of
    function publicSaleShareWithdraw(uint256 bcubeAmount)
        external
        onlyAfterListing
    {
        require(
            bcubeAllocationRegistry[_msgSender()].allocatedBcubePreICO > 0 || bcubeAllocationRegistry[_msgSender()].allocatedBcubeICO > 0,
            "!publicSaleParticipant || 0 BCUBE allocated"
        );
        uint256 allowance;
        uint256 increasePreICO = bcubeAllocationRegistry[_msgSender()].allocatedBcubePreICO.div(4);
        uint256 increaseICO = bcubeAllocationRegistry[_msgSender()].allocatedBcubeICO.div(4);
        if (now >= listingTime + 90 days) {
            // From listing date + 90 days: public sale participants can withdraw 100% of Pre-ICO tokens & 100% of ICO tokens
            allowance = increasePreICO.mul(4) + increaseICO.mul(4);
        } else if (now >= listingTime + 60 days) {
            // From listing date + 60 days: public sale participants can withdraw  75% of Pre-ICO tokens & 100% of ICO tokens
            allowance = increasePreICO.mul(3) + increaseICO.mul(4);
        } else if (now >= listingTime + 30 days) {
            // From listing date + 30 days: public sale participants can withdraw  50% of Pre-ICO tokens &  75% of ICO tokens
            allowance = increasePreICO.mul(2) + increaseICO.mul(3);
        } else {
            // From listing date: public sale participants can withdraw            25% of Pre-ICO tokens &  50% of ICO tokens
            allowance = increasePreICO + increaseICO.mul(2);
        }
        if (allowance != bcubeAllocationRegistry[_msgSender()].currentAllowance)
            bcubeAllocationRegistry[_msgSender()].currentAllowance = allowance;

        uint256 finalWithdrawn = bcubeAllocationRegistry[_msgSender()]
            .shareWithdrawn
            .add(bcubeAmount);
        require(
            finalWithdrawn <=
                bcubeAllocationRegistry[_msgSender()].currentAllowance,
            "Insufficient allowance"
        );
        bcubeAllocationRegistry[_msgSender()].shareWithdrawn = finalWithdrawn;
        token.safeTransfer(_msgSender(), bcubeAmount);
        emit LogPublicSaleShareWithdrawn(_msgSender(), bcubeAmount);
    }
}
