// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/connectors/contracts/stuff/PancakeV2.sol";


/**
 * @dev Contract for swap WBNB on PancakeSwap
 */
contract BuyonSwap {

    function buy(address _tokenAddress, address _router) public payable {
        IPancakeRouter02 router = IPancakeRouter02(_router);

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = _tokenAddress;

        uint[] memory amountsOut = router.getAmountsOut(msg.value, path);

        amountsOut = router.swapExactETHForTokens{value: msg.value}(
            (amountsOut[1] * 9) / 10,
            path,
            msg.sender,
            block.timestamp + 600
        );
    }
}
