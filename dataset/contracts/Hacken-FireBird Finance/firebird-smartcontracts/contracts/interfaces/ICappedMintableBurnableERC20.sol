// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ICappedMintableBurnableERC20 {
    function cap() external view returns(uint256);
    function minterCap(address) external view returns(uint256);
    function mint(address, uint256) external;
    function burn(uint256) external;
}
