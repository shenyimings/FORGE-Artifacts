// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Whitelist} from "../Whitelist.sol";

interface IWhitelistChecker {
    function getAllTokens(address _owner) external view returns (uint256[] memory);
    function addWhitelist(Whitelist _whitelist) external;
    function removeWhitelist(Whitelist _whitelist) external;
    function acceptsRemoval(Whitelist _whitelist, address _owner, uint256 _tokenId) external view returns(bool);
}
