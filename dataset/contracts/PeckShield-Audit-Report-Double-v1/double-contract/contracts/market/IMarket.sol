// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6 <0.9.0;

interface IMarket {

    struct Lending {
        address lender;
        address nftAddress;
        uint256 nftId;
        uint256 pricePerSecond;
        uint64 maxEndTime;
        uint64 minDuration;
        uint64 nonce;
        uint64 version;
    }
    struct Renting {
        address payable renterAddress;
        uint64 startTime;
        uint64 endTime;
    }

    struct Royalty {
        uint256 fee;
        uint256 balance;
        address payable beneficiary;
    }

    struct Credit{
        mapping(uint256=>Lending) lendingMap;
    }

    event CreateLendOrder(address lender,address nftAddress,uint256 nftId,uint64 maxEndTime,uint64 minDuration,uint256 pricePerSecond);
    event CancelLendOrder(address lender,address nftAddress,uint256 nftId);
    event FulfillOrder(address renter,address lender,address nftAddress,uint256 nftId,uint64 startTime,uint64 endTime,uint256 pricePerSecond,uint256 newId);
    event Paused(address account);
    event Unpaused(address account);
    function mintAndCreateLendOrder(
        address resolverAddress,
        uint256 oNftId,
        uint64 maxEndTime,
        uint64 minDuration,
        uint256 pricePerSecond
    ) external ;

    function createLendOrder(
        address nftAddress,
        uint256 nftId,
        uint64 maxEndTime,
        uint64 minDuration,
        uint256 pricePerSecond
    ) external;

    function cancelLendOrder(address nftAddress,uint256 nftId) external;

    function getLendOrder(address nftAddress,uint256 nftId) external view returns (Lending memory lenting);
    
    function fulfillOrder(address nftAddress,uint256 tokenId,uint256 durationId,uint64 startTime,uint64 endTime) external payable returns(uint256 tid);

    function fulfillOrderNow(address nftAddress,uint256 tokenId,uint256 durationId,uint64 duration) external payable returns(uint256 tid);

    function setFee(uint256 fee) external;

    function setMarketBeneficiary(address payable beneficiary) external;

    function claimFee() external;

    function setRoyalty(address nftAddress,uint256 fee) external;

    function setRoyaltyBeneficiary(address nftAddress,address payable beneficiary) external;

    function claimRoyalty(address nftAddress) external;

    function isLendOrderValid(address nftAddress,uint256 nftId) external view returns (bool);

    function setPause(bool v) external;

}