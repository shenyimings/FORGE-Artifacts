// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {BaseERC20} from "./BaseERC20.sol";
import {PerpOwnable} from "../utils/PerpOwnable.sol";

// interfaces
import {IVirtualToken} from "../interfaces/IVirtualToken.sol";

contract VirtualToken is IVirtualToken, BaseERC20, PerpOwnable {
    constructor(string memory _name, string memory _symbol) BaseERC20(_name, _symbol) {}

    function mint(uint256 amount) external override onlyPerp {
        _mint(perp, amount);
    }

    function burn(uint256 amount) external override onlyPerp {
        _burn(perp, amount);
    }
}
