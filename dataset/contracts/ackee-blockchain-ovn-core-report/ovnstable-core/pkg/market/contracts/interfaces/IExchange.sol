// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IExchange {

    function buyFee() external view returns (uint256);

    function buyFeeDenominator() external view returns (uint256);

    function redeemFee() external view returns (uint256);

    function redeemFeeDenominator() external view returns (uint256);

    function balance() external view returns (uint256);

    /**
     * @param _addrTok Token to withdraw
     * @param _amount Amount of USD+ tokens to burn
     * @return Amount of minted to caller tokens
     */
    function buy(address _addrTok, uint256 _amount) external returns (uint256);

    /**
     * @param _addrTok Token to withdraw
     * @param _amount Amount of USD+ tokens to burn
     * @return Amount of unstacked and transferred to caller tokens
     */
    function redeem(address _addrTok, uint256 _amount) external returns (uint256);

    function payout() external;

}
