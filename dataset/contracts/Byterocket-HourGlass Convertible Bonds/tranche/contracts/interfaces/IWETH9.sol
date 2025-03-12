// SPDX-License-Identifier: GPL-3.0-or-later
// derived from https://github.com/gnosis/canonical-weth/

// Interface definition for WETH contract, which wraps ETH into an ERC20 token.
interface IWETH9 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function balanceOf(address) external view returns (uint256);

    function approve(address guy, uint256 wad) external returns (bool);

    function transfer(address dst, uint256 wad) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);
}
