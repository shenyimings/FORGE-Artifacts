// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {IERC165} from "@animoca/ethereum-contracts-core-1.1.1/contracts/introspection/IERC165.sol";
import {IERC20Receiver} from "./IERC20Receiver.sol";

abstract contract ERC20Receiver is IERC20Receiver, IERC165 {
    bytes4 internal constant _ERC20_RECEIVED = type(IERC20Receiver).interfaceId;
    bytes4 internal constant _ERC20_REJECTED = 0xffffffff;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC20Receiver).interfaceId;
    }
}
