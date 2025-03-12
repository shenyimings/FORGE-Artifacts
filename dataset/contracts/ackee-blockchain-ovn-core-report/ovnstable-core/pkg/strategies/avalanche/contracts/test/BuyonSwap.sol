// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/connectors/contracts/stuff/TraderJoe.sol";

/**
 * @dev Contract for swap AVAX in Trader Joe
 */
contract BuyonSwap {

    function buy(address _tokenAddress, address _router) public payable {
        IJoeRouter02 router = IJoeRouter02(_router);

        address[] memory path = new address[](2);
        path[0] = router.WAVAX();
        path[1] = _tokenAddress;

        uint[] memory amountsOut = router.getAmountsOut(msg.value, path);

        amountsOut = router.swapExactAVAXForTokens{value: msg.value}(
            (amountsOut[1] * 9) / 10,
            path,
            msg.sender,
            block.timestamp + 600
        );
    }
}
