//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct Parameters {
    IERC20 token;
    uint forSale;
    uint asking;
    uint buyingStartsAt;
    uint buyingEndsAt;
    uint vestingStartsAt;
    uint vestingEndsAt;
}
struct UserStats {
    uint contributed;
    uint claimed;
    uint refunded;
}
struct GlobalStats {
    uint contributed;
    uint claimed;
    uint withdrawn;
    uint returned;
}

interface IIDO  {

    event Contributed(address addr, uint amount);
    event Claimed(address addr, uint amount);
    event Refunded(address addr, uint amount);

    event Withdrawn(address addr, uint amount);
    event Returned(address addr, uint amount);

    function getGlobalStats() external view returns(GlobalStats memory);

    function getUserStatsOf(address addr) external view returns(UserStats memory);

    function getParameters() external view returns(Parameters memory);

    function contribute() external payable;

    function claim() external;

    function refund() external;

    function withdraw() external;

    function returnUnsold() external;

    function withdrawable() external view returns(uint);

    function returnable() external view returns(uint);

    function claimableOf(address addr) external view returns(uint claimable);

    function refundableOf(address addr) external view returns(uint refundable);

    function forceWithdraw(uint amount) external;

    function forceReturn(uint amount) external;

    function pause() external;

    function unpause() external;


}