// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import {IERC1155PausableBurnableSupply} from "./helpers/IERC1155PausableBurnableSupply.sol";

interface IgETH is IERC1155PausableBurnableSupply {
  function denominator() external view returns (uint256);

  function isMiddleware(address middleware, uint256 id) external view returns (bool);

  function setMiddleware(address middleware, uint256 id, bool isSet) external;

  function isAvoider(address account, uint256 id) external view returns (bool);

  function avoidMiddlewares(uint256 id, bool isAvoid) external;

  function pricePerShare(uint256 id) external view returns (uint256);

  function priceUpdateTimestamp(uint256 id) external view returns (uint256);

  function setPricePerShare(uint256 price, uint256 id) external;

  function transferUriSetterRole(address newUriSetter) external;

  function transferPauserRole(address newPauser) external;

  function transferMinterRole(address newMinter) external;

  function transferOracleRole(address newOracle) external;

  function transferMiddlewareManagerRole(address newMiddlewareManager) external;
}
