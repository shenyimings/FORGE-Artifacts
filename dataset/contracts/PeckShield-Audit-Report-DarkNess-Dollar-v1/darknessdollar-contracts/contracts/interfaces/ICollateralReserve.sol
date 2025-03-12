// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ICollateralReserve {
    function fundBalance(address _token) external view returns (uint256);

    function transferTo(address _token, address _receiver, uint256 _amount) external;

    function burnToken(address _token, uint256 _amount) external;

    function receiveDarks(uint256 _amount) external;

    function receiveShares(uint256 _amount) external;
}
