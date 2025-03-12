// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

// interfaces
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IVirtualToken is IERC20Metadata {
    /* ****************** */
    /*  State modifying   */
    /* ****************** */

    function mint(uint256 amount) external;

    function burn(uint256 amount) external;
}
