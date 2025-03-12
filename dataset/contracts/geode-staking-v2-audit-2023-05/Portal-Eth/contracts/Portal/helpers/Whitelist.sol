// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IWhitelist} from "../interfaces/helpers/IWhitelist.sol";

/**
 * @title A minimal whitelisting contract
 *
 * @notice This contract is not used by any of the other contracts,
 * * but useful when testing or simply a referance for others.
 *
 * @dev Even though this is a fairly small contract, use it at your own risk.
 */
contract Whitelist is IWhitelist, Ownable {
  mapping(address => bool) private whitelist;

  event Listed(address indexed account, bool isWhitelisted);

  function isAllowed(address _address) external view virtual override returns (bool) {
    return whitelist[_address];
  }

  function setAddress(address _address, bool allow) external virtual onlyOwner {
    require(whitelist[_address] != allow, "Whitelist: already set");

    whitelist[_address] = allow;

    emit Listed(_address, allow);
  }
}
