// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Ingest Implementation Contract
 * @author Origin Protocol Inc
 */

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IngestRegistry.sol";

contract IngestImpl {
    using SafeERC20 for IERC20;

    // Registry address replaced at deploy time
    IngestRegistry constant registry =
        IngestRegistry(0xFFbebEbeBEbeBeBEBeBebeBEbeBebebEAAaAaAAA);

    // Special case address for ETH.
    address constant ETHEREUM =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function collect(address asset, uint256 amount) external {
        require(
            msg.sender == registry.master(),
            "Endpoint: Caller is not the master"
        );
        address payable pool = payable(registry.pool());
        if (asset == ETHEREUM) {
            payable(pool).transfer(amount);
        } else {
            IERC20(asset).safeTransfer(pool, amount);
        }
    }

    receive() external payable {
    }
    
    fallback() external payable {
    }
}
