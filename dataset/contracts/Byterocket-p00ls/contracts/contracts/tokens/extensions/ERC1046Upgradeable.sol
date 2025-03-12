// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC1046.sol";

/// @custom:security-contact security@p00ls.com
abstract contract ERC1046Upgradeable is IERC1046 {
    string public override tokenURI;

    function _setTokenURI(string calldata _tokenURI) internal {
        tokenURI = _tokenURI;
    }
}
