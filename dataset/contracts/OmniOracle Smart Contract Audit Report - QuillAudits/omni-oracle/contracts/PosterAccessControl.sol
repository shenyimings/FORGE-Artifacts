// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.10;

import "./Administrable.sol";

contract PosterAccessControl is Administrable {
    address public poster;

    event NewPoster(address indexed oldPoster, address indexed newPoster);

    constructor() internal {
        _setPosterInternal(msg.sender);
    }

    function _setPoster(address newPoster) external {
        require(msg.sender == admin, "Unauthorized");

        _setPosterInternal(newPoster);
    }

    function _setPosterInternal(address newPoster) internal {
        emit NewPoster(poster, newPoster);
        poster = newPoster;
    }
}