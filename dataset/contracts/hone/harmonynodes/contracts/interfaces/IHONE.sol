// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IHONE is IERC20 {
   function setSaleFee(uint saleFee) external;
   function setTransferFee(uint transferFee) external;
   function setFeeCollectWallet(address feeCollectWallet) external;
   function setNodeManagementContract(address _honeNode) external;
   function enableBlacklist(address account) external;
   function disableBlacklist(address account) external;
   function isBlacklisted(address account) external view returns (bool);
   function mint(uint256 _amount) external;
   function burn(uint256 _amount) external;
}