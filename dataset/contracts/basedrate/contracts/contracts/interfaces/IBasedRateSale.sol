//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IBasedRateSale {
    struct UserData {
        uint256 ethContributed;
        uint256 brateBought;
        uint256 bshareBought;
        bool whitelist;
        bool once;
        uint256 walletLimit;
    }

    function users(address _user) external view returns (UserData memory);

    function userIndex(uint256 index) external view returns (address);

    function userCount() external view returns (uint256);
}
