// SPDX-License-Identifier: WTFPL
pragma solidity 0.6.12;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./utils/token/ERC20/ERC20.sol";


// "WBTC", "WBTC", 8, 1000000     0x9Bf27E57245DD4232C018f2097b1e999A7161a3B
// "WETH", "WETH", 18, 1000000    0x56D17A54155dCC5Bb2BF9A50c7f6Bf4a21583931
// "ChainLink Token", "LINK", 18, 0xa36085F69e2889c224210F603D836748e7dC0088 address created by ChainLink Team on KOVAN
// "BNB", "BNB", 18, 1000000      0x4260931D230F7a66691aBbFe9aaFb25B2F5B55A8
// "UNI", "UNI", 18, 1000000      0x2dE19249451741935003E1BF819E0dBb3010463d
// "DAI", "DAI", 18, 1000000      0xb3A570feDE54326Aa5Cc66D6C03bC3c72A6E4C86
// "USDC", "USDC", 6, 1000000     0xFfA962796FC63611f8bCc53Fbb24CbA1CB53b273
// "USDT", "USDT", 6, 1000000     0xDc3d34839ba29c76FA295640CE3A07b77FfA8AD9


contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 supply
    ) public ERC20(name, symbol, decimals) {
        _mint(msg.sender, supply * (10 ** uint256(decimals)));
    }
}