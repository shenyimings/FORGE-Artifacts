// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0.0;

interface IAccessControlNFT {

    struct User {
        UserRoleData[] userRoleDataArray;
        mapping(uint8 => uint256) indexByRole;
    }
    struct RoleData {
        // if false, the role cannot be purchased
        bool isPurchaseable;
        // amount of seconds per interval
        uint40 intervalLength;  // => cannot be 0 !! => every role has some kind of time limit
        // total calls per interval
        uint40 callsPerInterval;  // => 0 means unlimited calls
        uint16 maxIntervalsAtOnce;
        uint8 maxRebate;
        uint8 rebatePerInterval;
        uint16 referralBonusInUSD;
        mapping(Tier => uint256) feeByTier;
    }
    struct RoleSetup {
        uint8 roleId;
        bool isPurchaseable;
        uint40 intervalLength; 
        uint40 callsPerInterval;
        uint16 maxIntervalsAtOnce;
        uint8 maxRebate;
        uint8 rebatePerInterval;
        uint16 referralBonusInUSD;
    }
    struct GiveRoleParams {
        address recipient;
        uint8 roleId;
        Tier tier;
        uint256 intervals;
    }
    enum Tier {
        NO_TIER,
        ONE,
        TWO,
        THREE,
        FOUR,
        FIVE,
        SIX,
        SEVEN,
        EIGHT,
        NINE,
        TEN
    }
    struct UserRoleData {
        uint8 roleId;
        Tier tier;
        uint40 expiration;
        uint40 callsTotal;
        uint40 callsUsedTotal;
    }
    struct CurrencyData {
        address oracle;
        uint64 tokenDecimals;
    }

    struct Airdrop {
        uint8 roleId;
        Tier tier;
        uint128 intervals;
        bool onlyFirstTime;
        bool onlyFirstTimeRole;
        uint40 start;
        uint40 end;
        bytes32 root;
    }   

    function purchaseRole(
        GiveRoleParams memory params,
        address currency,
        bytes memory referralSig
    ) external payable returns(uint256);

    event RoleChanged(address who, bytes32 what);
/*     //// OWNER ////

    function setupRole(RoleSetup memory roleSetup, Tier[] memory enabledTiers, uint256[] memory feeByTier) external;
    function setFee(uint8 roleId, Tier tier, uint256 feeForTier) external;
    function setRoleStatus(uint8 roleId, bool isActive) external;
    function setIntervalLength(uint8 roleId, uint40 newIntervalLength) external;
    function setCallsPerInterval(uint8 roleId, uint40 callsPerInterval) external;
    function setMaxIntervalsAtOnce(uint8 roleId, uint16 newMaxIntervals) external;
    function setRebate(uint8 roleId, uint8 rebatePerInterval, uint8 maxRebate) external;
    function setCurrency(address currency, address oracle) external;
    function setUsedCalls(address account, uint8 roleId, uint40 callsUsedTotal) external;
    function setTransferability(bool isTransferable) external;
    function setRevenueSplitter(address revenueSplitter) external;
    function setMghPool(address pairContract) external; */

    //// VIEWS ////

/*     function getRoleInfo(uint8 roleId) external view returns(bool isActive, uint40 intervalLength, uint40 callsPerInterval);
    function getTierInfo(uint8 roleId, Tier tier) external view returns(bool isActive, uint256 fee);
    function getUserRolesComplete(address account) external view returns(bytes32[] memory ret);
    function getNFTRolesComplete(uint256 tokenId) external view returns(UserRoleData[] memory);
    function getCurrencyInfo(address currency) external view returns(CurrencyData memory); */
}