pragma solidity ^0.6.7;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract GovernanceDecisions is AccessControl {

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    uint8 public marketplaceFee;
    string[] private marketplaceCategories;
    string[] private foundationMemberships;

    event MarketplaceFeeChanged(uint8 oldFee, uint8 newFee);
    event MarketplaceCategoryAdded(string category);
    event FoundationMemberAdded(string member);

    constructor(address governor_) public {
        _setupRole(GOVERNOR_ROLE, governor_);
        marketplaceFee = 10; // set default marketplace fee
    }

    function setMarketplaceFee(uint8 fee) external {
        require(hasRole(GOVERNOR_ROLE, msg.sender), "GovernanceDecisions::setMarketplaceFee ACCESS FORBIDDEN");
        require(fee < 100, "GovernanceDecisions::setMarketplaceFee fee must be less than 100");

        uint8 oldFee;
        oldFee = marketplaceFee;
        marketplaceFee = fee;
        emit MarketplaceFeeChanged(oldFee, marketplaceFee);
    }

    function addMarketplaceCategory(string calldata category) external {
        require(hasRole(GOVERNOR_ROLE, msg.sender), "GovernanceDecisions::addMarketplaceCategory ACCESS FORBIDDEN");

        marketplaceCategories.push(category);
        emit MarketplaceCategoryAdded(category);
    }

    function getMarketplaceCategories() public view returns (string[] memory) {
        return marketplaceCategories;
    }

    function addFoundationMember(string calldata member) external {
        require(hasRole(GOVERNOR_ROLE, msg.sender), "GovernanceDecisions::addFoundationMember ACCESS FORBIDDEN");

        foundationMemberships.push(member);
        emit FoundationMemberAdded(member);
    }

    function getMemberships() public view returns (string[] memory) {
        return foundationMemberships;
    }
}
