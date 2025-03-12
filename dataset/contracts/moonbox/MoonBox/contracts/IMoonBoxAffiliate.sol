// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

interface IMoonBoxAffiliate {
    function setAffiliateRevenue(
        address from,
        uint256 amount,
        bool isBuy
    ) external;

    function claim() external;

    function getAffiliate(address _address) external view returns (uint256, uint256);

    function getF0(address _address) external view returns (address);

    function getTotalAffiliateBuy() external view returns (uint256);

    function getTotalAffiliateSell() external view returns (uint256);

    event SetF0(address f0, address f1);
    event SetAffiliateRevenue(address from, address to, uint32 level, uint256 amount);
    event Claim(address addr, uint256 amount, uint256 amountBnb);
}
